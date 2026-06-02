import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pin_model.dart';

class SharedPinEntry {
  final PinModel pin;
  final String ownerUid;
  final String ownerNickname;

  const SharedPinEntry({
    required this.pin,
    required this.ownerUid,
    required this.ownerNickname,
  });
}

class SharedMapRepository {
  final _db = Supabase.instance.client;

  /// Returns public/friend-visible pins from the given friend UIDs.
  /// Gracefully returns empty if the `pins` table doesn't exist yet.
  Future<List<SharedPinEntry>> fetchFriendPins(List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    try {
      final rows = await _db
          .from('pins')
          .select('*, users!pins_uid_fkey(nickname)')
          .inFilter('uid', friendUids)
          .inFilter('visibility', ['🌐 전체 공개', '👥 친구 공개']);

      return rows.map((r) {
        final userRow = r['users'] as Map<String, dynamic>?;
        final nickname = userRow?['nickname'] as String? ?? '친구';
        return SharedPinEntry(
          ownerUid: r['uid'] as String,
          ownerNickname: nickname,
          pin: PinModel(
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
            visibility: r['visibility'] as String? ?? '🔒 나만 보기',
            photoPaths: (r['photo_paths'] as List?)?.cast<String>() ?? [],
            countryCode: r['country_code'] as String? ?? '',
            taggedFriendCodes: (r['tagged_friend_codes'] as List?)?.cast<String>() ?? [],
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      // pins table doesn't exist yet or query failed
      return [];
    }
  }

  /// My own public/friend pins for the shared map (always visible).
  Future<List<SharedPinEntry>> fetchMyPublicPins(String myUid) async {
    try {
      final rows = await _db
          .from('pins')
          .select()
          .eq('uid', myUid)
          .inFilter('visibility', ['🌐 전체 공개', '👥 친구 공개']);
      return rows.map((r) => SharedPinEntry(
            ownerUid: myUid,
            ownerNickname: '나',
            pin: PinModel(
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
              visibility: r['visibility'] as String? ?? '🔒 나만 보기',
              photoPaths: (r['photo_paths'] as List?)?.cast<String>() ?? [],
              countryCode: r['country_code'] as String? ?? '',
              taggedFriendCodes: (r['tagged_friend_codes'] as List?)?.cast<String>() ?? [],
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
          )).toList();
    } catch (_) {
      return [];
    }
  }
}
