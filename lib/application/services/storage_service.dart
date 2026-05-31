import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Storage 업로드 헬퍼.
///
/// Supabase 대시보드에서 아래 버킷을 미리 생성해야 함:
///   - avatars      (public, 10 MB limit)
///   - pin-photos   (public, 50 MB limit)
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── 프로필 사진 ───────────────────────────────────────────────────────────────

  /// 로컬 파일을 Supabase Storage `avatars/{uid}.jpg`에 업로드하고 공개 URL 반환.
  /// 실패 시 null 반환 (로컬 저장은 계속 동작).
  Future<String?> uploadProfilePhoto(File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final bytes = await file.readAsBytes();
      final path = '$uid.jpg';
      await _client.storage
          .from('avatars')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ));
      final url = _client.storage.from('avatars').getPublicUrl(path);
      // cache-bust: 버전 쿼리 파라미터로 새 이미지 강제 로드
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('[Storage] uploadProfilePhoto error: $e');
      return null;
    }
  }

  /// Supabase `users` 테이블 `avatar_url` 컬럼 업데이트.
  Future<void> updateAvatarUrl(String url) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('users').update({'avatar_url': url}).eq('uid', uid);
    } catch (e) {
      debugPrint('[Storage] updateAvatarUrl error: $e');
    }
  }

  // ── 핀 사진 ──────────────────────────────────────────────────────────────────

  /// 핀의 로컬 사진 경로 목록을 업로드하고 공개 URL 목록 반환.
  /// 이미 URL인 경로는 그대로 유지. 실패한 항목은 로컬 경로 제거(동기화 불가).
  Future<List<String>> uploadPinPhotos(
      String pinId, List<String> localPaths) async {
    final uid = _uid;
    if (uid == null) return [];
    final urls = <String>[];
    for (int i = 0; i < localPaths.length; i++) {
      final path = localPaths[i];
      // 이미 클라우드 URL이면 스킵
      if (path.startsWith('http')) {
        urls.add(path);
        continue;
      }
      try {
        final file = File(path);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final storagePath = '$uid/${pinId}_$i.jpg';
        await _client.storage
            .from('pin-photos')
            .uploadBinary(storagePath, bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ));
        final url =
            _client.storage.from('pin-photos').getPublicUrl(storagePath);
        urls.add(url);
      } catch (e) {
        debugPrint('[Storage] uploadPinPhoto[$i] error: $e');
        // 업로드 실패한 사진은 목록에서 제외 (로컬 경로는 다른 기기에서 깨짐)
      }
    }
    return urls;
  }
}
