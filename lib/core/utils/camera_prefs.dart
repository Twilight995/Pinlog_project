import 'package:shared_preferences/shared_preferences.dart';

/// 마지막 지도 카메라 위치를 SharedPreferences에 저장/복원.
class CameraPrefs {
  static const _kLat     = 'camera_lat';
  static const _kLng     = 'camera_lng';
  static const _kZoom    = 'camera_zoom';
  static const _kVersion = 'camera_version';

  // 버전을 올리면 모든 기기에서 저장값이 한국 기본값으로 한 번 초기화됨
  static const _kCurrentVersion = 3;

  static const _kDefaultLat  = 36.5;
  static const _kDefaultLng  = 127.5;
  static const _kDefaultZoom = 6.5;

  static Future<void> save({
    required double lat,
    required double lng,
    required double zoom,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVersion, _kCurrentVersion);
    await prefs.setDouble(_kLat,  lat);
    await prefs.setDouble(_kLng,  lng);
    await prefs.setDouble(_kZoom, zoom);
  }

  /// 저장된 값 반환.
  /// - 버전이 낮으면 (버그로 오염된 이전 데이터) 한국 기본값 반환 후 버전 갱신
  /// - 저장된 줌이 5.0 미만이면 (지구본 모드에서 잘못 저장된 값) 기본값 반환
  static Future<({double lat, double lng, double zoom})> load() async {
    final prefs = await SharedPreferences.getInstance();

    final version = prefs.getInt(_kVersion) ?? 0;
    if (version < _kCurrentVersion) {
      // stale 좌표 전부 기본값으로 덮어쓰기 — 이후 호출도 기본값을 읽도록
      await prefs.setDouble(_kLat, _kDefaultLat);
      await prefs.setDouble(_kLng, _kDefaultLng);
      await prefs.setDouble(_kZoom, _kDefaultZoom);
      await prefs.setInt(_kVersion, _kCurrentVersion);
      return (lat: _kDefaultLat, lng: _kDefaultLng, zoom: _kDefaultZoom);
    }

    final zoom = prefs.getDouble(_kZoom) ?? _kDefaultZoom;
    if (zoom < 5.0) {
      return (lat: _kDefaultLat, lng: _kDefaultLng, zoom: _kDefaultZoom);
    }

    final lat = prefs.getDouble(_kLat) ?? _kDefaultLat;
    final lng = prefs.getDouble(_kLng) ?? _kDefaultLng;
    return (lat: lat, lng: lng, zoom: zoom);
  }
}
