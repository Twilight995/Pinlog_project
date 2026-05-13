import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'data/models/pin_model.dart';
import 'data/repositories/pin_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'presentation/screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PinRepository.init();
  await ProfileRepository.init();
  await _seedTestRouteIfNeeded();

  runApp(const ProviderScope(child: PinlogApp()));
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
