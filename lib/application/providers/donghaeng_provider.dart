import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/donghaeng_session.dart';
import '../../data/models/pin_model.dart';

// ─── State ─────────────────────────────────────────────────────────────────────

class DonghaengState {
  final DonghaengSession? session;
  final double? myLat;
  final double? myLng;

  const DonghaengState({this.session, this.myLat, this.myLng});

  bool get isActive => session != null;

  DonghaengState copyWith({
    DonghaengSession? session,
    double? myLat,
    double? myLng,
    bool clearSession = false,
  }) =>
      DonghaengState(
        session: clearSession ? null : (session ?? this.session),
        myLat: myLat ?? this.myLat,
        myLng: myLng ?? this.myLng,
      );
}

// ─── Notifier ──────────────────────────────────────────────────────────────────

class DonghaengNotifier extends StateNotifier<DonghaengState> {
  StreamSubscription? _gpsSub;
  RealtimeChannel? _channel;

  DonghaengNotifier() : super(const DonghaengState());

  String get _myUid =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> startSession(PinModel pin, String myNickname) async {
    if (state.isActive) return;

    final myUid = _myUid;
    if (myUid.isEmpty) return;

    final self = DonghaengParticipant(uid: myUid, nickname: '나');
    final others = pin.taggedFriendCodes
        .map((code) => DonghaengParticipant(uid: code, nickname: code))
        .toList();

    final session = DonghaengSession(
      pinId: pin.id,
      pinTitle: pin.title,
      participants: [self, ...others],
      startedAt: DateTime.now(),
    );

    state = DonghaengState(session: session);

    await _joinChannel(pin.id, myUid);
    _startGps(myUid);
  }

  Future<void> _joinChannel(String pinId, String myUid) async {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client.channel('donghaeng_$pinId');

    _channel!.onPresenceSync((_) {
      final states = _channel!.presenceState();
      if (!mounted) return;
      _handlePresenceSync(states, myUid);
    });

    _channel!.subscribe();
  }

  void _handlePresenceSync(List<SinglePresenceState> states, String myUid) {
    final session = state.session;
    if (session == null) return;

    final updated = Map<String, DonghaengParticipant>.fromEntries(
      session.participants.map((p) => MapEntry(p.uid, p)),
    );

    for (final s in states) {
      for (final p in s.presences) {
        final payload = p.payload;
        final uid = payload['uid'] as String?;
        if (uid == null || uid == myUid) continue;

        final lat = (payload['lat'] as num?)?.toDouble();
        final lng = (payload['lng'] as num?)?.toDouble();
        final arrivedHome = (payload['arrived_home'] as bool?) ?? false;

        final nickname = (payload['nickname'] as String?) ?? uid.substring(0, 6);

        updated[uid] = DonghaengParticipant(
          uid: uid,
          nickname: nickname,
          lat: lat,
          lng: lng,
          arrivedHome: arrivedHome,
          lastSeen: DateTime.now(),
        );
      }
    }

    state = state.copyWith(
      session: session.copyWith(participants: updated.values.toList()),
    );
  }

  void _startGps(String myUid) {
    _gpsSub?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
      if (!mounted) return;
      state = state.copyWith(myLat: pos.latitude, myLng: pos.longitude);

      final session = state.session;
      if (session == null) return;

      try {
        final nickname = session.participants
            .firstWhere((p) => p.uid == myUid,
                orElse: () => DonghaengParticipant(uid: myUid, nickname: '나'))
            .nickname;
        await _channel?.track({
          'uid': myUid,
          'nickname': nickname,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'arrived_home': false,
        });
      } catch (e) {
        debugPrint('[Donghaeng] broadcast error: $e');
      }
    });
  }

  Future<void> markArrivedHome() async {
    final myUid = _myUid;
    if (myUid.isEmpty) return;
    try {
      final myLat = state.myLat;
      final myLng = state.myLng;
      await _channel?.track({
        'uid': myUid,
        'lat': myLat,
        'lng': myLng,
        'arrived_home': true,
      });
    } catch (_) {}
    await endSession();
  }

  Future<void> endSession() async {
    _gpsSub?.cancel();
    _gpsSub = null;
    try {
      await _channel?.untrack();
      _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    state = const DonghaengState();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _channel?.untrack().ignore();
    _channel?.unsubscribe();
    super.dispose();
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────────

final donghaengProvider =
    StateNotifierProvider<DonghaengNotifier, DonghaengState>(
  (ref) => DonghaengNotifier(),
);
