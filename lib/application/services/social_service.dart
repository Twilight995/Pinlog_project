import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/friends_provider.dart';
import '../../data/models/pin_model.dart';

final socialServiceProvider = Provider<SocialService>((ref) => SocialService());

// ─── FriendRequest 모델 ───────────────────────────────────────────────────────

class FriendRequest {
  final String id;
  final String fromUid;
  final String fromNickname;
  final String fromFriendCode;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.fromNickname,
    required this.fromFriendCode,
    required this.createdAt,
  });
}

// ─── SocialService ────────────────────────────────────────────────────────────

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

  /// 직접 friendship 삽입 (accept_friend_request RPC 외부에서도 사용 가능)
  Future<void> addFriendship(
    String targetUid,
    String targetNickname,
    String targetFriendCode,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    await _db.from('friendships').upsert({
      'user_uid': uid,
      'friend_uid': targetUid,
      'friend_code': targetFriendCode.toUpperCase(),
      'nickname': targetNickname,
    }, onConflict: 'user_uid,friend_uid');
  }

  Stream<List<Friend>> friendsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .from('friendships')
        .stream(primaryKey: ['user_uid', 'friend_uid'])
        .eq('user_uid', uid)
        .map((rows) => rows
            .map((row) => Friend(
                  code: row['friend_code'] as String? ?? '',
                  name: row['nickname'] as String? ?? '친구',
                  addedAt: row['added_at'] != null
                      ? DateTime.parse(row['added_at'] as String)
                      : DateTime.now(),
                  supabaseUid: row['friend_uid'] as String?,
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

  // ── Friend Requests ────────────────────────────────────────────────────────

  /// 친구 신청 전송. 에러 메시지 반환(null이면 성공).
  Future<String?> sendFriendRequest(
    String targetUid,
    String targetNickname,
    String targetFriendCode,
  ) async {
    final uid = _uid;
    if (uid == null) return '로그인이 필요해요.';
    if (uid == targetUid) return '본인에게 신청할 수 없어요.';

    // 이미 친구인지 확인
    final existing = await _db
        .from('friendships')
        .select('friend_uid')
        .eq('user_uid', uid)
        .eq('friend_uid', targetUid)
        .limit(1);
    if (existing.isNotEmpty) return '이미 친구예요.';

    // 이미 신청한 경우 확인
    final alreadySent = await _db
        .from('friend_requests')
        .select('id')
        .eq('from_uid', uid)
        .eq('to_uid', targetUid)
        .limit(1);
    if (alreadySent.isNotEmpty) return '이미 신청한 친구예요.';

    // 내 정보 조회 (from_nickname, from_friend_code 채우기)
    final myData = await _db
        .from('users')
        .select('nickname,friend_code')
        .eq('uid', uid)
        .maybeSingle();
    final myNickname = myData?['nickname'] as String? ?? '';
    final myCode = myData?['friend_code'] as String? ?? '';

    await _db.from('friend_requests').insert({
      'from_uid': uid,
      'to_uid': targetUid,
      'from_nickname': myNickname,
      'from_friend_code': myCode,
    });

    // FCM 알림 전송 (실패해도 무방)
    final displayName = myNickname.isNotEmpty ? myNickname : '누군가';
    _db.functions.invoke(
      'send-fcm',
      body: {
        'target_uid': targetUid,
        'title': '친구 신청이 왔어요',
        'body': '$displayName 님이 친구 신청을 보냈어요',
        'data': {'type': 'friend_request'},
      },
    ).ignore();

    return null;
  }

  /// 친구 신청 수락 (Supabase RPC 사용 — 양쪽 friendship 행을 서버에서 동시 삽입)
  Future<String?> acceptFriendRequest(
    String requestId,
    String fromUid,
    String fromNickname,
    String fromCode,
  ) async {
    try {
      await _db.rpc('accept_friend_request', params: {
        'p_request_id': requestId,
        'p_from_uid': fromUid,
        'p_from_nickname': fromNickname,
        'p_from_code': fromCode.toUpperCase(),
      });

      // 수락 사실을 신청자에게 FCM 알림
      final myData = await _db
          .from('users')
          .select('nickname')
          .eq('uid', _uid ?? '')
          .maybeSingle();
      final myName = myData?['nickname'] as String? ?? '누군가';
      _db.functions.invoke(
        'send-fcm',
        body: {
          'target_uid': fromUid,
          'title': '친구 신청이 수락됐어요',
          'body': '$myName 님이 친구 신청을 수락했어요',
          'data': {'type': 'friend_accepted'},
        },
      ).ignore();

      return null;
    } catch (_) {
      return '수락 중 오류가 발생했어요.';
    }
  }

  /// 친구 신청 거절
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.from('friend_requests').delete().eq('id', requestId);
  }

  /// 받은 대기 중인 친구 신청 스트림
  /// 친구의 공개 핀 조회 (전체 공개 + 친구 공개)
  Future<List<PinModel>> getFriendPublicPins(String friendUid) async {
    try {
      final rows = await _db
          .from('pins')
          .select()
          .eq('uid', friendUid)
          .inFilter('visibility', ['🌍 전체 공개', '👥 친구 공개'])
          .order('created_at', ascending: false);
      return rows.map(_pinFromRow).toList();
    } catch (_) {
      return [];
    }
  }

  PinModel _pinFromRow(Map<String, dynamic> r) => PinModel(
        id: r['id'] as String,
        title: r['title'] as String? ?? '',
        description: r['description'] as String? ?? '',
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
        emotion: r['emotion'] as String? ?? '좋아요',
        weather: r['weather'] as String? ?? '맑음',
        companions: (r['companions'] as List?)?.cast<String>() ?? [],
        intensityLevel: r['intensity_level'] as int? ?? 3,
        pinShape: r['pin_shape'] as String? ?? 'star',
        visibility: r['visibility'] as String? ?? '🌍 전체 공개',
        photoPaths: (r['photo_paths'] as List?)?.cast<String>() ?? [],
        countryCode: r['country_code'] as String? ?? '',
        taggedFriendCodes: (r['tagged_friend_codes'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  Stream<List<FriendRequest>> pendingRequestsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .eq('to_uid', uid)
        .map((rows) => rows
            .map((row) => FriendRequest(
                  id: row['id'] as String,
                  fromUid: row['from_uid'] as String? ?? '',
                  fromNickname: row['from_nickname'] as String? ?? '알 수 없음',
                  fromFriendCode: row['from_friend_code'] as String? ?? '',
                  createdAt: row['created_at'] != null
                      ? DateTime.parse(row['created_at'] as String)
                      : DateTime.now(),
                ))
            .toList());
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final friendsStreamProvider = StreamProvider<List<Friend>>((ref) {
  return ref.watch(socialServiceProvider).friendsStream();
});

final pendingRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  return ref.watch(socialServiceProvider).pendingRequestsStream();
});

final pendingRequestCountProvider = Provider<int>((ref) {
  return ref.watch(pendingRequestsProvider).valueOrNull?.length ?? 0;
});

final friendPinsProvider =
    FutureProvider.family<List<PinModel>, String>((ref, friendUid) {
  return ref.read(socialServiceProvider).getFriendPublicPins(friendUid);
});
