import 'package:shared_preferences/shared_preferences.dart';

/// 마지막 지도 카메라 위치를 SharedPreferences에 저장/복원.
class CameraPrefs {
  static const _kLat  = 'camera_lat';
  static const _kLng  = 'camera_lng';
  static const _kZoom = 'camera_zoom';

  static Future<void> save({
    required double lat,
    required double lng,
    required double zoom,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat,  lat);
    await prefs.setDouble(_kLng,  lng);
    await prefs.setDouble(_kZoom, zoom);
  }

  /// 저장된 값 반환. 없으면 대한민국 중심 기본값.
  static Future<({double lat, double lng, double zoom})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat  = prefs.getDouble(_kLat)  ?? 36.5;
    final lng  = prefs.getDouble(_kLng)  ?? 127.5;
    final zoom = prefs.getDouble(_kZoom) ?? 6.5;
    return (lat: lat, lng: lng, zoom: zoom);
  }
}
