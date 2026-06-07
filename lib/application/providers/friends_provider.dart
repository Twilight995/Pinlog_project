import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/pin_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/shared_map_repository.dart';
import 'profile_provider.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class Friend {
  final String code;
  final String name;
  final DateTime addedAt;
  final String? supabaseUid;
  /// 1~5 친밀도 단계 (별 개수로 표시)
  final int intimacyLevel;

  const Friend({
    required this.code,
    required this.name,
    required this.addedAt,
    this.supabaseUid,
    this.intimacyLevel = 1,
  });

  Friend copyWith({
    String? code,
    String? name,
    DateTime? addedAt,
    String? supabaseUid,
    int? intimacyLevel,
  }) =>
      Friend(
        code: code ?? this.code,
        name: name ?? this.name,
        addedAt: addedAt ?? this.addedAt,
        supabaseUid: supabaseUid ?? this.supabaseUid,
        intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'addedAt': addedAt.toIso8601String(),
        if (supabaseUid != null) 'firestoreUid': supabaseUid,
        'intimacyLevel': intimacyLevel,
      };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        code: json['code'] as String,
        name: json['name'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        supabaseUid: json['firestoreUid'] as String?,
        intimacyLevel: (json['intimacyLevel'] as int?) ?? 1,
      );
}

// ─── 데모 친구 상수 ────────────────────────────────────────────────────────────

const _kDemoUidJihu = 'demo_jihu_001';
const _kDemoUidSeoyeon = 'demo_seoyeon_002';

/// 데모용 핀 목록 (소셜 지도에 표시).
List<SharedPinEntry> buildDemoPins() {
  final jihuPins = [
    SharedPinEntry(
      ownerUid: _kDemoUidJihu,
      ownerNickname: '김지후',
      pin: PinModel(
        id: 'demo_j1', title: '을지로 감성 카페', description: '숨겨진 루프탑',
        latitude: 37.5662, longitude: 126.9938, emotion: '좋아요', weather: '맑음',
        companions: [], intensityLevel: 4, pinShape: 'cafe',
        visibility: '👥 친구 공개', photoPaths: [], countryCode: 'KR',
        taggedFriendCodes: [], createdAt: DateTime(2026, 5, 28),
      ),
    ),
    SharedPinEntry(
      ownerUid: _kDemoUidJihu,
      ownerNickname: '김지후',
      pin: PinModel(
        id: 'demo_j2', title: '홍대 새벽 공연', description: '버스킹 최고였다',
        latitude: 37.5573, longitude: 126.9245, emotion: '좋아요', weather: '맑음',
        companions: [], intensityLevel: 5, pinShape: 'music',
        visibility: '👥 친구 공개', photoPaths: [], countryCode: 'KR',
        taggedFriendCodes: [], createdAt: DateTime(2026, 6, 1),
      ),
    ),
    SharedPinEntry(
      ownerUid: _kDemoUidJihu,
      ownerNickname: '김지후',
      pin: PinModel(
        id: 'demo_j3', title: '성수동 팝업', description: '줄 서서 들어간 보람',
        latitude: 37.5446, longitude: 127.0566, emotion: '좋아요', weather: '구름 조금',
        companions: [], intensityLevel: 3, pinShape: 'shopping',
        visibility: '👥 친구 공개', photoPaths: [], countryCode: 'KR',
        taggedFriendCodes: [], createdAt: DateTime(2026, 6, 3),
      ),
    ),
  ];

  final seoyeonPins = [
    SharedPinEntry(
      ownerUid: _kDemoUidSeoyeon,
      ownerNickname: '이서연',
      pin: PinModel(
        id: 'demo_s1', title: '한강 일몰', description: '노을이 너무 예뻤다',
        latitude: 37.5283, longitude: 126.9340, emotion: '좋아요', weather: '맑음',
        companions: [], intensityLevel: 5, pinShape: 'nature',
        visibility: '👥 친구 공개', photoPaths: [], countryCode: 'KR',
        taggedFriendCodes: [], createdAt: DateTime(2026, 5, 30),
      ),
    ),
    SharedPinEntry(
      ownerUid: _kDemoUidSeoyeon,
      ownerNickname: '이서연',
      pin: PinModel(
        id: 'demo_s2', title: '북촌 한옥마을', description: '고요한 골목',
        latitude: 37.5826, longitude: 126.9852, emotion: '좋아요', weather: '맑음',
        companions: [], intensityLevel: 3, pinShape: 'palace',
        visibility: '👥 친구 공개', photoPaths: [], countryCode: 'KR',
        taggedFriendCodes: [], createdAt: DateTime(2026, 6, 2),
      ),
    ),
  ];

  return [...jihuPins, ...seoyeonPins];
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class FriendsNotifier extends StateNotifier<List<Friend>> {
  static const _friendsKey = 'friendsList';

  Box<dynamic> get _box => Hive.box<dynamic>('settings');

  FriendsNotifier() : super([]) {
    _load();
  }

  void _load() {
    final raw = _box.get(_friendsKey) as String?;
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Friend.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> addFriend(String code, String name, {String? uid, bool notify = true}) async {
    final normalized = code.toUpperCase().trim();
    if (state.any((f) => f.code == normalized)) return;
    state = [
      ...state,
      Friend(
        code: normalized,
        name: name.trim(),
        addedAt: DateTime.now(),
        supabaseUid: uid,
      ),
    ];
    await _persist();
    if (uid != null && notify) _notifyFriend(uid);
  }

  void _notifyFriend(String targetUid) {
    final myNickname = ProfileRepository().getNickname();
    final displayName = myNickname.isEmpty ? '누군가' : myNickname;
    Supabase.instance.client.functions.invoke(
      'send-fcm',
      body: {
        'target_uid': targetUid,
        'title': '새 친구 요청이 왔어요',
        'body': '$displayName님이 친구를 추가했어요',
        'data': {'type': 'friend_request'},
      },
    ).ignore();
  }

  void notifyPinTag(List<String> friendCodes, String pinTitle) {
    if (friendCodes.isEmpty) return;
    final myNickname = ProfileRepository().getNickname();
    final displayName = myNickname.isEmpty ? '친구' : myNickname;
    for (final code in friendCodes) {
      final uid = state
          .where((f) => f.code == code && f.supabaseUid != null)
          .map((f) => f.supabaseUid!)
          .firstOrNull;
      if (uid == null) continue;
      Supabase.instance.client.functions.invoke(
        'send-fcm',
        body: {
          'target_uid': uid,
          'title': '핀에 태그됐어요',
          'body': '$displayName님이 "$pinTitle" 기억에 함께한 친구로 태그했어요',
          'data': {'type': 'pin_tag'},
        },
      ).ignore();
    }
  }

  Future<void> removeFriend(String code) async {
    state = state.where((f) => f.code != code).toList();
    await _persist();
  }

  Future<void> setIntimacy(String code, int level) async {
    state = [
      for (final f in state)
        if (f.code == code) f.copyWith(intimacyLevel: level.clamp(1, 5)) else f,
    ];
    await _persist();
  }

  bool get hasDemoFriends =>
      state.any((f) => f.supabaseUid == _kDemoUidJihu || f.supabaseUid == _kDemoUidSeoyeon);

  Future<void> addDemoFriends() async {
    final demoFriends = [
      Friend(code: 'DEMO01', name: '김지후', addedAt: DateTime(2026, 5, 1), supabaseUid: _kDemoUidJihu, intimacyLevel: 4),
      Friend(code: 'DEMO02', name: '이서연', addedAt: DateTime(2026, 5, 10), supabaseUid: _kDemoUidSeoyeon, intimacyLevel: 3),
    ];
    final existing = state.map((f) => f.code).toSet();
    final toAdd = demoFriends.where((f) => !existing.contains(f.code)).toList();
    if (toAdd.isEmpty) return;
    state = [...state, ...toAdd];
    await _persist();
  }

  Future<void> clearDemoFriends() async {
    state = state.where((f) => f.supabaseUid != _kDemoUidJihu && f.supabaseUid != _kDemoUidSeoyeon).toList();
    await _persist();
  }

  Future<void> _persist() async {
    await _box.put(_friendsKey, jsonEncode(state.map((f) => f.toJson()).toList()));
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, List<Friend>>(
  (ref) => FriendsNotifier(),
);

final myFriendCodeProvider = Provider<String>((ref) {
  final repo = ref.read(profileRepositoryProvider);
  return repo.getFriendCode();
});
