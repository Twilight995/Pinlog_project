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
  await _seedClusterDemoIfNeeded();

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

// 클러스터링 데모용 핀 대량 시드 (서울 인기 지역 밀집 + 외곽 분산, 최초 1회만)
Future<void> _seedClusterDemoIfNeeded() async {
  const sentinel = 'demo_cluster_001';
  final repo = PinRepository();
  if (repo.getAll().any((p) => p.id == sentinel)) return;

  final now = DateTime.now();
  // (lat, lng, title, shape, intensity, emotion, daysAgo, companions)
  final raw = <List<Object>>[
    // ── 강남역 밀집 (8개) ─────────────────────────────────
    [37.4979, 127.0276, '강남역 식스슈가', 'cafe', 4, '좋아요', 1, <String>[]],
    [37.4985, 127.0290, '강남 교보문고', 'reading', 3, '좋아요', 5, <String>['지윤']],
    [37.4970, 127.0260, '강남 더현대', 'shopping', 5, '좋아요', 2, <String>['수현', '민호']],
    [37.4992, 127.0282, '강남 노포 갈비', 'drinking', 4, '좋아요', 8, <String>['민호']],
    [37.4965, 127.0298, '강남 PC방', 'game', 2, '별로에요', 12, <String>[]],
    [37.5002, 127.0271, '강남 헬스장', 'gym', 3, '좋아요', 3, <String>[]],
    [37.4977, 127.0312, '강남 디지털 매장', 'tech', 4, '좋아요', 9, <String>['수현']],
    [37.4988, 127.0245, '강남 인강 카페', 'selfdev', 4, '좋아요', 6, <String>[]],

    // ── 홍대 밀집 (7개) ───────────────────────────────────
    [37.5563, 126.9220, '홍대 정문 카페', 'cafe', 5, '좋아요', 4, <String>['지윤']],
    [37.5550, 126.9234, '홍대 클럽거리', 'drinking', 5, '좋아요', 1, <String>['수현', '민호', '지윤']],
    [37.5572, 126.9209, '홍대 라이브홀', 'drinking', 4, '좋아요', 11, <String>['민호']],
    [37.5558, 126.9241, '홍대 보드게임 카페', 'game', 3, '좋아요', 7, <String>['수현']],
    [37.5546, 126.9195, '홍대 헬스장', 'gym', 2, '별로에요', 15, <String>[]],
    [37.5580, 126.9225, '홍대 옷가게 골목', 'shopping', 3, '좋아요', 2, <String>[]],
    [37.5565, 126.9252, '홍대 농구장', 'basketball', 4, '좋아요', 5, <String>['민호']],

    // ── 성수동 밀집 (6개) ─────────────────────────────────
    [37.5435, 127.0540, '성수 카페골목', 'cafe', 4, '좋아요', 10, <String>['지윤']],
    [37.5458, 127.0571, '성수 편집샵', 'shopping', 5, '좋아요', 3, <String>['수현']],
    [37.5447, 127.0590, '성수 와인바', 'drinking', 4, '좋아요', 6, <String>['민호', '지윤']],
    [37.5421, 127.0552, '서울숲 러닝', 'running', 5, '좋아요', 1, <String>[]],
    [37.5440, 127.0525, '성수 가죽공방', 'selfdev', 3, '좋아요', 13, <String>[]],
    [37.5462, 127.0548, '성수 자전거 샵', 'tech', 4, '좋아요', 8, <String>[]],

    // ── 이태원 (5개) ─────────────────────────────────────
    [37.5340, 126.9947, '이태원 펍', 'drinking', 5, '좋아요', 2, <String>['민호', '수현']],
    [37.5355, 126.9962, '이태원 케밥', 'drinking', 3, '좋아요', 9, <String>[]],
    [37.5328, 126.9931, '이태원 빈티지샵', 'shopping', 4, '좋아요', 14, <String>['지윤']],
    [37.5347, 126.9978, '이태원 헬스장', 'gym', 3, '좋아요', 4, <String>[]],
    [37.5362, 126.9920, '이태원 루프탑 카페', 'cafe', 5, '좋아요', 7, <String>['수현']],

    // ── 명동/종로 (5개) ──────────────────────────────────
    [37.5636, 126.9826, '명동 거리', 'shopping', 3, '좋아요', 11, <String>[]],
    [37.5651, 126.9810, '명동 코인노래방', 'game', 4, '좋아요', 6, <String>['민호']],
    [37.5705, 126.9920, '광화문 교보문고', 'reading', 5, '좋아요', 16, <String>[]],
    [37.5683, 126.9853, '청계천 산책', 'running', 2, '별로에요', 20, <String>[]],
    [37.5719, 126.9876, '종로 자기개발 모임', 'selfdev', 4, '좋아요', 8, <String>['지윤', '수현']],

    // ── 잠실/송파 (4개) ──────────────────────────────────
    [37.5130, 127.1015, '잠실 롯데몰', 'shopping', 4, '좋아요', 5, <String>['민호']],
    [37.5145, 127.1052, '잠실 야구장', 'soccer', 5, '좋아요', 3, <String>['수현', '민호']],
    [37.5165, 127.0986, '잠실 카페', 'cafe', 3, '좋아요', 10, <String>[]],
    [37.5188, 127.0830, '잠실 한강 자전거', 'drive', 4, '좋아요', 1, <String>[]],

    // ── 서울 외곽/분산 (6개) ─────────────────────────────
    [37.6584, 127.0610, '북한산 등반', 'running', 5, '좋아요', 25, <String>['민호']],
    [37.4836, 126.9788, '관악산 산책', 'running', 4, '좋아요', 30, <String>[]],
    [37.6536, 126.8350, '김포 드라이브', 'drive', 5, '좋아요', 18, <String>['지윤', '수현']],
    [37.4451, 127.1389, '판교 IT밋업', 'selfdev', 4, '좋아요', 12, <String>['민호']],
    [37.7404, 127.0470, '의정부 카페', 'cafe', 3, '좋아요', 22, <String>[]],
    [37.4564, 126.7052, '인천 차이나타운', 'drinking', 4, '좋아요', 17, <String>['수현']],

    // ── 타 도시 (3개) ────────────────────────────────────
    [35.1796, 129.0756, '부산 광안리', 'drive', 5, '좋아요', 40, <String>['민호', '수현']],
    [35.1604, 129.1635, '부산 해운대 러닝', 'running', 5, '좋아요', 41, <String>[]],
    [33.4996, 126.5312, '제주 카페투어', 'cafe', 5, '좋아요', 55, <String>['지윤']],
  ];

  for (var i = 0; i < raw.length; i++) {
    final r = raw[i];
    final pin = PinModel(
      id: 'demo_cluster_${(i + 1).toString().padLeft(3, '0')}',
      title: r[2] as String,
      description: '',
      latitude: r[0] as double,
      longitude: r[1] as double,
      emotion: r[5] as String,
      weather: '☀️ 맑음',
      companions: List<String>.from(r[7] as List),
      intensityLevel: r[4] as int,
      pinShape: r[3] as String,
      visibility: '🌐 전체 공개',
      photoPaths: const [],
      createdAt: now.subtract(Duration(days: r[6] as int)),
      countryCode: 'KR',
    );
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
