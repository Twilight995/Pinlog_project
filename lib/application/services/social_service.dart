import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/friends_provider.dart';

final socialServiceProvider = Provider<SocialService>((ref) => SocialService());

class SocialService {
  final SupabaseClient _db = Supabase.instance.client;

  String? get _uid => _db.auth.currentUser?.id;

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<void> createOrUpdateUser({
    required String friendCode,
    required String nickname,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _db.from('users').upsert({
      'uid': uid,
      'friend_code': friendCode.toUpperCase(),
      'nickname': nickname,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'uid');
  }

  Future<Map<String, dynamic>?> getUserByCode(String code) async {
    final data = await _db
        .from('users')
        .select()
        .eq('friend_code', code.toUpperCase())
        .limit(1);
    if (data.isEmpty) return null;
    return data.first;
  }

  // ── Friends ────────────────────────────────────────────────────────────────

  Future<void> addFriendship(
    String targetUid,
    String targetNickname,
    String targetFriendCode,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final meData = await _db.from('users').select().eq('uid', uid).limit(1);
    final myNickname = meData.isNotEmpty
        ? (meData.first['nickname'] as String? ?? 'Pinlog 탐험가')
        : 'Pinlog 탐험가';

    await _db.from('friendships').upsert([
      {
        'user_uid': uid,
        'friend_uid': targetUid,
        'friend_code': targetFriendCode.toUpperCase(),
        'nickname': targetNickname,
      },
      {
        'user_uid': targetUid,
        'friend_uid': uid,
        'friend_code': null,
        'nickname': myNickname,
      },
    ], onConflict: 'user_uid,friend_uid');
  }

  Stream<List<Friend>> friendsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .from('friendships')
        .stream(primaryKey: ['id'])
        .eq('user_uid', uid)
        .map((rows) => rows
            .map((row) => Friend(
                  code: row['friend_code'] as String? ?? '',
                  name: row['nickname'] as String? ?? '친구',
                  addedAt: row['added_at'] != null
                      ? DateTime.parse(row['added_at'] as String)
                      : DateTime.now(),
                  firestoreUid: row['friend_uid'] as String?,
                ))
            .toList());
  }

  Future<void> removeFriend(String targetUid) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('friendships')
        .delete()
        .eq('user_uid', uid)
        .eq('friend_uid', targetUid);
  }
}

final friendsStreamProvider = StreamProvider<List<Friend>>((ref) {
  return ref.watch(socialServiceProvider).friendsStream();
});
