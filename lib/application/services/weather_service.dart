import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OpenWeatherMap 현재 날씨 → 앱 5개 옵션 매핑
/// 옵션: 맑음 / 비 / 흐림 / 눈 / 바람
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const _apiKey = '7e15ca6394eaa3694b639dbd4f7c4627';
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  /// 좌표 기반 날씨 자동 감지. 실패 시 null 반환 (UI에서 기본값 유지).
  Future<String?> fetchWeather(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lng&appid=$_apiKey&units=metric',
      );
      debugPrint('[Weather] fetching: $uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      debugPrint('[Weather] status=${res.statusCode} body=${res.body}');
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final main = (json['weather'] as List?)?.first['main'] as String? ?? '';
      final windSpeed = (json['wind']?['speed'] as num?)?.toDouble() ?? 0.0;
      final result = _map(main, windSpeed);
      debugPrint('[Weather] main=$main wind=$windSpeed → $result');
      return result;
    } catch (e) {
      debugPrint('[Weather] fetch error: $e');
      return null;
    }
  }

  // OpenWeatherMap main → 앱 옵션
  String _map(String main, double windSpeed) {
    switch (main.toLowerCase()) {
      case 'clear':
        // 맑아도 바람이 강하면 바람 우선
        if (windSpeed >= 8.0) return '바람';
        return '맑음';
      case 'rain':
      case 'drizzle':
      case 'thunderstorm':
        return '비';
      case 'snow':
        return '눈';
      case 'clouds':
        if (windSpeed >= 8.0) return '바람';
        return '흐림';
      default:
        // Mist, Fog, Haze, Smoke, Dust, Sand, Squall, Tornado 등
        if (windSpeed >= 8.0) return '바람';
        return '흐림';
    }
  }
}
