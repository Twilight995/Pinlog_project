import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/pin_model.dart';

const _kSyncEnabledKey = 'cloud_sync_enabled';
const _kLastSyncKey = 'cloud_sync_last_at';

/// Supabase `pins` table schema (run once in Supabase SQL editor):
///
/// ```sql
/// CREATE TABLE pins (
///   id TEXT PRIMARY KEY,
///   uid UUID NOT NULL,
///   title TEXT,
///   description TEXT,
///   latitude DOUBLE PRECISION NOT NULL,
///   longitude DOUBLE PRECISION NOT NULL,
///   emotion TEXT,
///   weather TEXT,
///   companions TEXT[],
///   intensity_level INT DEFAULT 3,
///   pin_shape TEXT DEFAULT 'star',
///   visibility TEXT DEFAULT '🔒 나만 보기',
///   photo_paths TEXT[],
///   country_code TEXT DEFAULT '',
///   tagged_friend_codes TEXT[] DEFAULT '{}',
///   created_at TIMESTAMPTZ NOT NULL,
///   updated_at TIMESTAMPTZ DEFAULT NOW()
/// );
/// ALTER TABLE pins ENABLE ROW LEVEL SECURITY;
/// CREATE POLICY "own pins" ON pins USING (auth.uid() = uid);
/// ```
class PinSyncService {
  PinSyncService._();
  static final PinSyncService instance = PinSyncService._();

  final _db = Supabase.instance.client;
  Box<dynamic> get _settings => Hive.box<dynamic>('settings');

  bool get isEnabled =>
      _settings.get(_kSyncEnabledKey, defaultValue: false) as bool;

  Future<void> setEnabled(bool v) => _settings.put(_kSyncEnabledKey, v);

  DateTime? get lastSyncAt {
    final s = _settings.get(_kLastSyncKey) as String?;
    return s == null ? null : DateTime.tryParse(s);
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> uploadAll(List<PinModel> pins) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = pins.map((p) => _toRow(p, uid)).toList();
      await _db.from('pins').upsert(rows, onConflict: 'id');
      // 동기화 OFF 중 로컬에서 삭제된 핀을 서버에서도 제거
      final serverRows = await _db.from('pins').select('id').eq('uid', uid);
      final localIds = pins.map((p) => p.id).toSet();
      for (final row in serverRows) {
        final serverId = row['id'] as String;
        if (!localIds.contains(serverId)) {
          await _db.from('pins').delete().eq('id', serverId);
        }
      }
      await _settings.put(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[PinSync] upload error: $e');
    }
  }

  Future<void> uploadPin(PinModel pin) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null || !isEnabled) return;
    try {
      await _db.from('pins').upsert(_toRow(pin, uid), onConflict: 'id');
    } catch (e) {
      debugPrint('[PinSync] uploadPin error: $e');
    }
  }

  Future<void> deletePin(String id) async {
    if (!isEnabled) return;
    try {
      await _db.from('pins').delete().eq('id', id);
    } catch (e) {
      debugPrint('[PinSync] deletePin error: $e');
    }
  }

  // ── Download ───────────────────────────────────────────────────────────────

  Future<List<PinModel>> downloadAll() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _db.from('pins').select().eq('uid', uid);
      return rows.map(_fromRow).toList();
    } catch (e) {
      debugPrint('[PinSync] download error: $e');
      return [];
    }
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(PinModel p, String uid) => {
        'id': p.id,
        'uid': uid,
        'title': p.title,
        'description': p.description,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'emotion': p.emotion,
        'weather': p.weather,
        'companions': p.companions,
        'intensity_level': p.intensityLevel,
        'pin_shape': p.pinShape,
        'visibility': p.visibility,
        // 로컬 파일 경로('/'로 시작)는 다른 기기에서 깨지므로 클라우드 URL만 동기화
        'photo_paths': p.photoPaths.where((path) => !path.startsWith('/')).toList(),
        'country_code': p.countryCode,
        'tagged_friend_codes': p.taggedFriendCodes,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  PinModel _fromRow(Map<String, dynamic> r) => PinModel(
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
      );
}
