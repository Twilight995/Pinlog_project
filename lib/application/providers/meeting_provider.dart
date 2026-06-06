import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/secrets.dart';
import '../../data/models/meeting.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../data/repositories/profile_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MeetingState {
  final Meeting? activeMeeting;
  final bool isLoading;

  /// My live GPS position
  final double? myLat;
  final double? myLng;

  /// Friend's live GPS position (from Realtime presence)
  final double? friendLat;
  final double? friendLng;

  /// Straight-line distance in metres
  final double? distanceMeters;

  /// ETA from Mapbox Directions API (seconds). null = not yet fetched.
  final int? etaSeconds;

  const MeetingState({
    this.activeMeeting,
    this.isLoading = false,
    this.myLat,
    this.myLng,
    this.friendLat,
    this.friendLng,
    this.distanceMeters,
    this.etaSeconds,
  });

  bool get isApproaching =>
      activeMeeting?.status == MeetingStatus.approaching ||
      activeMeeting?.status == MeetingStatus.meeting;

  MeetingState copyWith({
    Meeting? activeMeeting,
    bool? isLoading,
    double? myLat,
    double? myLng,
    double? friendLat,
    double? friendLng,
    double? distanceMeters,
    int? etaSeconds,
    bool clearEta = false,
    bool clearMeeting = false,
  }) =>
      MeetingState(
        activeMeeting: clearMeeting ? null : activeMeeting ?? this.activeMeeting,
        isLoading: isLoading ?? this.isLoading,
        myLat: myLat ?? this.myLat,
        myLng: myLng ?? this.myLng,
        friendLat: friendLat ?? this.friendLat,
        friendLng: friendLng ?? this.friendLng,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        etaSeconds: clearEta ? null : etaSeconds ?? this.etaSeconds,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MeetingNotifier extends StateNotifier<MeetingState> {
  final MeetingRepository _repo;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<(double, double)>? _friendSub;
  DateTime? _lastEtaFetch;

  MeetingNotifier(this._repo) : super(const MeetingState()) {
    _loadActiveMeeting();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _friendSub?.cancel();
    // _repo는 meetingRepositoryProvider의 ref.onDispose에서 처리됨 — 이중 호출 방지
    super.dispose();
  }

  // 30초 쓰로틀로 Mapbox Directions API 호출
  Future<void> _refreshEta() async {
    final now = DateTime.now();
    if (_lastEtaFetch != null &&
        now.difference(_lastEtaFetch!).inSeconds < 30) {
      return;
    }

    final s = state;
    final meeting = s.activeMeeting;
    if (meeting == null) return;
    if (s.myLat == null || s.myLng == null) return;

    // 대중교통 → 거리 기반 fallback (API 미지원)
    if (meeting.transitMode == TransitMode.transit) return;

    final profile = meeting.transitMode == TransitMode.driving
        ? 'driving-traffic'
        : 'walking';

    final toLat = s.friendLat ?? meeting.targetLat;
    final toLng = s.friendLng ?? meeting.targetLng;

    try {
      _lastEtaFetch = now;
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/$profile'
        '/${s.myLng},${s.myLat};$toLng,$toLat'
        '?access_token=${Secrets.mapboxPublicToken}'
        '&overview=false'
        '&geometries=geojson',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final seconds = (routes.first['duration'] as num).toInt();
      if (mounted) state = state.copyWith(etaSeconds: seconds);
    } catch (_) {}
  }

  Future<void> _loadActiveMeeting() async {
    state = state.copyWith(isLoading: true);
    var meeting = await _repo.getActiveMeeting();

    // 약속 날짜가 도래했는데 아직 upcoming 상태면 자동으로 approaching 전환
    if (meeting != null && meeting.status == MeetingStatus.upcoming) {
      final now = DateTime.now();
      final diff = now.difference(meeting.scheduledAt);
      if (diff.inMinutes >= -30) {
        await _repo.updateStatus(meeting.id, MeetingStatus.approaching);
        meeting = meeting.copyWith(status: MeetingStatus.approaching);
      }
    }

    state = state.copyWith(activeMeeting: meeting, isLoading: false);
    if (meeting?.status == MeetingStatus.approaching ||
        meeting?.status == MeetingStatus.meeting) {
      await _startLiveTracking(meeting!);
    }
  }

  /// Creates a new meeting and sets it as active
  Future<bool> createMeeting({
    required String inviteeUid,
    required double targetLat,
    required double targetLng,
    String? targetName,
    required DateTime scheduledAt,
    TransitMode transitMode = TransitMode.transit,
  }) async {
    state = state.copyWith(isLoading: true);
    final meeting = await _repo.createMeeting(
      inviteeUid: inviteeUid,
      targetLat: targetLat,
      targetLng: targetLng,
      targetName: targetName,
      scheduledAt: scheduledAt,
      transitMode: transitMode,
    );
    state = state.copyWith(activeMeeting: meeting, isLoading: false);
    if (meeting != null) _notifyInvitee(inviteeUid, targetName);
    return meeting != null;
  }

  void _notifyInvitee(String inviteeUid, String? placeName) {
    final myNickname = ProfileRepository().getNickname();
    final displayName = myNickname.isEmpty ? '친구' : myNickname;
    final body = placeName != null && placeName.isNotEmpty
        ? '$displayName님이 $placeName에서 만남을 요청했어요'
        : '$displayName님이 만남을 요청했어요';
    Supabase.instance.client.functions.invoke(
      'send-fcm',
      body: {
        'target_uid': inviteeUid,
        'title': '약속 요청이 왔어요',
        'body': body,
        'data': {'type': 'meeting'},
      },
    ).ignore();
  }

  /// Called when user taps "출발하기"
  Future<void> depart() async {
    final meeting = state.activeMeeting;
    if (meeting == null) return;
    await _repo.updateStatus(meeting.id, MeetingStatus.approaching);
    final updated = meeting.copyWith(status: MeetingStatus.approaching);
    state = state.copyWith(activeMeeting: updated);
    await _startLiveTracking(updated);
  }

  Future<void> updateTransitMode(TransitMode mode) async {
    final meeting = state.activeMeeting;
    if (meeting == null) return;
    await _repo.updateTransitMode(meeting.id, mode);
    state = state.copyWith(activeMeeting: meeting.copyWith(transitMode: mode));
  }

  /// 데모용 약속 주입 — Supabase 없이 S4 화면 프리뷰
  void injectDemoMeeting() {
    state = MeetingState(
      activeMeeting: Meeting(
        id: 'demo_meeting_001',
        meetUid: 'demo_me',
        inviteeUid: 'demo_jihu_001',
        targetLat: 37.5446,
        targetLng: 127.0566,
        targetName: '성수역 2번 출구',
        scheduledAt: DateTime.now().add(const Duration(minutes: 18)),
        transitMode: TransitMode.transit,
        status: MeetingStatus.approaching,
        friendNickname: '김지후',
      ),
      myLat: 37.5573,
      myLng: 126.9245,
      friendLat: 37.5756,
      friendLng: 127.0480,
      distanceMeters: 4800.0,
    );
  }

  void clearDemoMeeting() {
    if (state.activeMeeting?.id.startsWith('demo_') == true) {
      state = const MeetingState();
    }
  }

  Future<void> completeMeeting() async {
    final meeting = state.activeMeeting;
    if (meeting == null) return;
    await _stopLiveTracking();
    await _repo.updateStatus(meeting.id, MeetingStatus.completed);
    state = const MeetingState();
  }

  Future<void> _startLiveTracking(Meeting meeting) async {
    await _repo.joinLocationChannel(meeting.id);

    // Listen for friend's location updates
    _friendSub?.cancel();
    _friendSub = _repo.friendLocationStream.listen((pos) {
      final (lat, lng) = pos;
      final dist = _haversine(
        state.myLat ?? meeting.targetLat,
        state.myLng ?? meeting.targetLng,
        lat,
        lng,
      );
      state = state.copyWith(friendLat: lat, friendLng: lng, distanceMeters: dist);
      // Auto-complete when within 5m
      if (dist <= 5 && state.activeMeeting?.status == MeetingStatus.approaching) {
        _repo.updateStatus(meeting.id, MeetingStatus.meeting);
        state = state.copyWith(
          activeMeeting: meeting.copyWith(status: MeetingStatus.meeting),
        );
        unawaited(_stopLiveTracking());
      }
    });

    // M-01: GPS 권한 확인
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Stream my GPS
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      _repo.broadcastLocation(pos.latitude, pos.longitude);
      state = state.copyWith(myLat: pos.latitude, myLng: pos.longitude);
      _refreshEta();
    });
  }

  Future<void> _stopLiveTracking() async {
    _gpsSub?.cancel();
    _friendSub?.cancel();
    _gpsSub = null;
    _friendSub = null;
    await _repo.leaveLocationChannel();
  }

  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLam = (lng2 - lng1) * math.pi / 180;
    final sinHalfDPhi = math.sin(dPhi / 2);
    final sinHalfDLam = math.sin(dLam / 2);
    final a = sinHalfDPhi * sinHalfDPhi +
        math.cos(phi1) * math.cos(phi2) * sinHalfDLam * sinHalfDLam;
    return 2 * r * math.asin(math.sqrt(a));
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) {
    final repo = MeetingRepository();
    ref.onDispose(repo.dispose);
    return repo;
  },
);

final meetingProvider =
    StateNotifierProvider<MeetingNotifier, MeetingState>((ref) {
  return MeetingNotifier(ref.watch(meetingRepositoryProvider));
});
