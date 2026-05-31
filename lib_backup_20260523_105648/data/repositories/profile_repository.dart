import 'package:hive_flutter/hive_flutter.dart';

class ProfileRepository {
  static const _boxName = 'profile';
  static const _nicknameKey = 'nickname';
  static const _subtitleKey = 'subtitle';
  static const _photoPathKey = 'photoPath';
  static const _borderStyleKey = 'borderStyle';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  String getNickname() => _box.get(_nicknameKey, defaultValue: 'Pinlog 탐험가')!;
  String getSubtitle() => _box.get(_subtitleKey, defaultValue: '기억을 지도에 새기는 중')!;
  String? getPhotoPath() => _box.get(_photoPathKey);
  String getBorderStyle() => _box.get(_borderStyleKey, defaultValue: 'white')!;

  Future<void> setNickname(String value) => _box.put(_nicknameKey, value);
  Future<void> setSubtitle(String value) => _box.put(_subtitleKey, value);
  Future<void> setPhotoPath(String? value) =>
      value != null ? _box.put(_photoPathKey, value) : _box.delete(_photoPathKey);
  Future<void> setBorderStyle(String value) => _box.put(_borderStyleKey, value);
}
