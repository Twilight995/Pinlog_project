import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class ProfileRepository {
  static const _boxName = 'profile';
  static const _nicknameKey = 'nickname';
  static const _subtitleKey = 'subtitle';
  static const _photoPathKey = 'photoPath';
  static const _borderStyleKey = 'borderStyle';
  static const _friendCodeKey = 'friendCode';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  String getNickname() => _box.get(_nicknameKey, defaultValue: 'Pinlog 탐험가')!;
  String getSubtitle() => _box.get(_subtitleKey, defaultValue: '기억을 지도에 새기는 중')!;
  String? getPhotoPath() {
    final path = _box.get(_photoPathKey);
    if (path == null) return null;
    // 앱 재설치 시 컨테이너 경로가 바뀌어 파일이 사라질 수 있음 → 자동 정리
    if (!File(path).existsSync()) {
      _box.delete(_photoPathKey);
      return null;
    }
    return path;
  }
  String getBorderStyle() => _box.get(_borderStyleKey, defaultValue: 'white')!;

  String getFriendCode() {
    String? code = _box.get(_friendCodeKey);
    if (code == null || code.isEmpty) {
      final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
      code = raw.substring(0, 6);
      _box.put(_friendCodeKey, code);
    }
    return code;
  }

  Future<void> setNickname(String value) => _box.put(_nicknameKey, value);
  Future<void> setSubtitle(String value) => _box.put(_subtitleKey, value);
  Future<void> setPhotoPath(String? value) =>
      value != null ? _box.put(_photoPathKey, value) : _box.delete(_photoPathKey);
  Future<void> setBorderStyle(String value) => _box.put(_borderStyleKey, value);
  Future<void> setFriendCode(String code) => _box.put(_friendCodeKey, code);

  Future<void> clearAll() async {
    await _box.clear();
  }
}
