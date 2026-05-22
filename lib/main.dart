import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'core/secrets.dart';
import 'core/theme/app_theme.dart';
import 'data/models/pin_model.dart';
import 'data/repositories/pin_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'presentation/screens/main_shell.dart';

/// Mapbox 공개 access token.
///
/// 우선순위:
///   1) `--dart-define=MAPBOX_TOKEN=pk.xxx` 로 주입된 값
///   2) `lib/core/secrets.dart` 의 `Secrets.mapboxPublicToken` (기본값)
const _mapboxToken = String.fromEnvironment(
  'MAPBOX_TOKEN',
  defaultValue: Secrets.mapboxPublicToken,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PinRepository.init();
  await ProfileRepository.init();
  await _seedTestRouteIfNeeded();
  await _seedDemoCategoriesIfNeeded();

  // Mapbox SDK 초기화 — 토큰 설정
  if (_mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxToken);
  } else {
    debugPrint(
      '⚠️ MAPBOX_TOKEN 이 비어있습니다. '
      'flutter run --dart-define=MAPBOX_TOKEN=pk.xxxx 로 주입하세요.',
    );
  }

  runApp(const ProviderScope(child: PinlogApp()));
}

// 새 카테고리(cafe/drinking/shopping/drive/running) 데모 핀 (최초 1회만)
Future<void> _seedDemoCategoriesIfNeeded() async {
  const sentinel = 'demo_cafe_001';
  final repo = PinRepository();
  if (repo.getAll().any((p) => p.id == sentinel)) return;

  final now = DateTime.now();
  final seeds = <PinModel>[
    PinModel(
      id: 'demo_cafe_001',
      title: '성수동 블루보틀',
      description: '',
      latitude: 37.5447, longitude: 127.0557,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 5, pinShape: 'cafe',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now, countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_cafe_002', title: '연남동 작은 카페', description: '',
      latitude: 37.5654, longitude: 126.9255,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 4, pinShape: 'cafe',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 7)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_cafe_003', title: '망원동 골목 카페', description: '',
      latitude: 37.5560, longitude: 126.9015,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 3, pinShape: 'cafe',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 14)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_drinking_001', title: '광장시장 육회골목', description: '',
      latitude: 37.5703, longitude: 126.9999,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 5, pinShape: 'drinking',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 1)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_drinking_002', title: '을지로 노포', description: '',
      latitude: 37.5667, longitude: 126.9919,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 4, pinShape: 'drinking',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 4)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_shopping_001', title: '성수 콘크리트', description: '',
      latitude: 37.5447, longitude: 127.0560,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 4, pinShape: 'shopping',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 2)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_drive_001', title: '강변북로 야경', description: '',
      latitude: 37.5443, longitude: 127.0001,
      emotion: '좋아요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 5, pinShape: 'drive',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 3)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_running_001', title: '서울숲 산책로', description: '',
      latitude: 37.5443, longitude: 127.0374,
      emotion: '별로에요', weather: '☀️ 맑음', companions: const [],
      intensityLevel: 2, pinShape: 'running',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 5)), countryCode: 'KR',
    ),
  ];

  for (final pin in seeds) {
    await repo.save(pin);
  }
}

// 잠실→한강→뚝섬→광화문 테스트 경로 핀 (2026-04-28, 최초 1회만)
Future<void> _seedTestRouteIfNeeded() async {
  const sentinel = 'test_route_001';
  final repo = PinRepository();
  if (repo.getAll().any((p) => p.id == sentinel)) return;

  final pins = [
    PinModel(
      id: 'test_route_001',
      title: '잠실 롯데타워',
      description: '서울에서 가장 높은 빌딩, 전망대에서 도시 전경 감상',
      latitude: 37.5126,
      longitude: 127.1027,
      emotion: '좋아요',
      weather: '☀️ 맑음',
      companions: [],
      intensityLevel: 4,
      pinShape: 'star',
      visibility: 'public',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 10, 0),
      countryCode: 'KR',
    ),
    PinModel(
      id: 'test_route_002',
      title: '잠실 한강공원',
      description: '한강변 산책로, 봄날 치킨과 함께 강바람',
      latitude: 37.5181,
      longitude: 127.0830,
      emotion: '좋아요',
      weather: '☀️ 맑음',
      companions: [],
      intensityLevel: 3,
      pinShape: 'sprout',
      visibility: 'public',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 11, 30),
      countryCode: 'KR',
    ),
    PinModel(
      id: 'test_route_003',
      title: '뚝섬 한강공원',
      description: '자전거 타고 한강 따라 뚝섬까지, 봄 바람이 기가 막혀',
      latitude: 37.5307,
      longitude: 127.0672,
      emotion: '좋아요',
      weather: '☀️ 맑음',
      companions: [],
      intensityLevel: 4,
      pinShape: 'cherryBlossom',
      visibility: 'public',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 13, 0),
      countryCode: 'KR',
    ),
    PinModel(
      id: 'test_route_004',
      title: '성수동 카페거리',
      description: '힙한 성수동 카페, 오렌지 라떼와 감성 인테리어',
      latitude: 37.5440,
      longitude: 127.0560,
      emotion: '좋아요',
      weather: '☀️ 맑음',
      companions: [],
      intensityLevel: 3,
      pinShape: 'moon',
      visibility: 'public',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 14, 30),
      countryCode: 'KR',
    ),
    PinModel(
      id: 'test_route_005',
      title: '경복궁 돌담길',
      description: '조선의 정궁, 돌담길 따라 봄 산책',
      latitude: 37.5796,
      longitude: 126.9770,
      emotion: '좋아요',
      weather: '☀️ 맑음',
      companions: [],
      intensityLevel: 3,
      pinShape: 'cloud',
      visibility: 'public',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 16, 0),
      countryCode: 'KR',
    ),
    PinModel(
      id: 'test_route_006',
      title: '광화문광장',
      description: '이순신 장군 동상 앞 저녁 산책, 하루의 마무리',
      latitude: 37.5759,
      longitude: 126.9769,
      emotion: '좋아요',
      weather: '🌤️ 맑음',
      companions: [],
      intensityLevel: 4,
      pinShape: 'sun',
      visibility: 'public',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 17, 30),
      countryCode: 'KR',
    ),
  ];

  for (final pin in pins) {
    await repo.save(pin);
  }
}

class PinlogApp extends StatelessWidget {
  const PinlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinlog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}
