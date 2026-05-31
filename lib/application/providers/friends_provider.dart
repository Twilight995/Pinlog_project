import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'profile_provider.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class Friend {
  final String code;
  final String name;
  final DateTime addedAt;
  final String? firestoreUid;
  /// 1~5 친밀도 단계 (별 개수로 표시)
  final int intimacyLevel;

  const Friend({
    required this.code,
    required this.name,
    required this.addedAt,
    this.firestoreUid,
    this.intimacyLevel = 1,
  });

  Friend copyWith({
    String? code,
    String? name,
    DateTime? addedAt,
    String? firestoreUid,
    int? intimacyLevel,
  }) =>
      Friend(
        code: code ?? this.code,
        name: name ?? this.name,
        addedAt: addedAt ?? this.addedAt,
        firestoreUid: firestoreUid ?? this.firestoreUid,
        intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'addedAt': addedAt.toIso8601String(),
        if (firestoreUid != null) 'firestoreUid': firestoreUid,
        'intimacyLevel': intimacyLevel,
      };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        code: json['code'] as String,
        name: json['name'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        firestoreUid: json['firestoreUid'] as String?,
        intimacyLevel: (json['intimacyLevel'] as int?) ?? 1,
      );
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

  Future<void> addFriend(String code, String name, {String? uid}) async {
    final normalized = code.toUpperCase().trim();
    if (state.any((f) => f.code == normalized)) return;
    state = [
      ...state,
      Friend(
        code: normalized,
        name: name.trim(),
        addedAt: DateTime.now(),
        firestoreUid: uid,
      ),
    ];
    await _persist();
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
