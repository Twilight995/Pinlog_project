import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/providers/theme_provider.dart';
import 'application/services/fcm_service.dart';
import 'application/services/notification_service.dart';
import 'core/firebase_options.dart';
import 'core/secrets.dart';
import 'core/theme/app_theme.dart';
import 'data/models/pin_model.dart';
import 'data/repositories/pin_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'presentation/screens/auth/sign_in_screen.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/screens/splash/splash_screen.dart';

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

  // 이전 세션의 만료된 PKCE 코드가 앱 시작 시 재생되어 발생하는 예외를 무시.
  // supabase_flutter 는 deep link 를 정상 처리하므로 이 예외는 무해한 노이즈.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      // 만료된 PKCE 코드 재생으로 인한 무해한 예외만 무시
      if (msg.contains('pkce') ||
          msg.contains('code verifier') ||
          msg.contains('invalid_grant') ||
          msg.contains('expired')) {
        return true;
      }
      return false;
    }
    return false;
  };

  // Hot restart 시 네이티브 채널 미준비 → 예외를 삼켜서 앱 계속 실행
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // detectSessionInUri: false — supabase_flutter 자체 딥링크 처리 비활성화.
  // app_links v7 이 FlutterImplicitEngineDelegate 에서 미등록되어 캐시된 URL 을
  // 앱 시작마다 재처리하면서 만료된 PKCE 코드로 크래시가 발생하는 것을 방지.
  // OAuth 콜백은 PinlogDeepLinkChannel (SceneDelegate → AppDelegate → Dart) 로 직접 처리.
  await Supabase.initialize(
    url: Secrets.supabaseUrl,
    anonKey: Secrets.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUri: false,
    ),
  );

  await Hive.initFlutter();
  await Hive.openBox<dynamic>('settings');
  await PinRepository.init();
  await ProfileRepository.init();
  if (kDebugMode) {
    await _seedTestRouteIfNeeded();
    await _seedDemoCategoriesIfNeeded();
  }
  await _removeLegacySeedPinsIfNeeded();
  await _migrateLandmarkPhotosIfNeeded();
  await _migratePinPhotosV2IfNeeded();
  await _migratePinPhotosV3IfNeeded();
  await _migratePinPhotosV4IfNeeded();
  // Note: createOrUpdateUser intentionally NOT called here.
  // Calling it at startup would create a users row with default values,
  // which causes _checkIsNewUser() to skip onboarding for new accounts.

  // FCM 알림 초기화
  try { await FCMService.instance.init(); } catch (_) {}

  // 로컬 푸시 알림 초기화
  try { await NotificationService.instance.init(); } catch (_) {}

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: '36e9bdb04487ae3ee8fa088e2b627ee4');

  // Mapbox SDK 초기화 — 토큰 + 전역 언어 설정
  if (_mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxToken);
  } else {
    debugPrint(
      '⚠️ MAPBOX_TOKEN 이 비어있습니다. '
      'flutter run --dart-define=MAPBOX_TOKEN=pk.xxxx 로 주입하세요.',
    );
  }
  // 지도 레이블 언어를 한국어로 고정 (맵 인스턴스 생성 전에 설정해야 적용됨)
  MapboxMapsOptions.setLanguage('ko');

  // 스플래시 오버레이 아래에 올바른 화면을 미리 준비하기 위해 앱 시작 전 auth 확인
  final session = Supabase.instance.client.auth.currentSession;
  final storedMode = Hive.box<dynamic>('settings').get('auth_mode') as String?;
  final isAuthenticated = session != null || storedMode == 'demo';

  runApp(ProviderScope(child: PinlogApp(isAuthenticated: isAuthenticated)));
}

// 새 카테고리(cafe/drinking/shopping/drive/running) 데모 핀 (최초 1회만)
Future<void> _seedDemoCategoriesIfNeeded() async {
  const settingsKey = 'seed_demo_categories_v1';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  final repo = PinRepository();
  final now = DateTime.now();
  final seeds = <PinModel>[
    PinModel(
      id: 'demo_cafe_001',
      title: '성수동 블루보틀',
      description: '',
      latitude: 37.5447, longitude: 127.0557,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 5, pinShape: 'cafe',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now, countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_cafe_002', title: '연남동 작은 카페', description: '',
      latitude: 37.5654, longitude: 126.9255,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 4, pinShape: 'cafe',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 7)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_cafe_003', title: '망원동 골목 카페', description: '',
      latitude: 37.5560, longitude: 126.9015,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 3, pinShape: 'cafe',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 14)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_drinking_001', title: '광장시장 육회골목', description: '',
      latitude: 37.5703, longitude: 126.9999,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 5, pinShape: 'drinking',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 1)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_drinking_002', title: '을지로 노포', description: '',
      latitude: 37.5667, longitude: 126.9919,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 4, pinShape: 'drinking',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 4)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_shopping_001', title: '성수 콘크리트', description: '',
      latitude: 37.5447, longitude: 127.0560,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 4, pinShape: 'shopping',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 2)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_drive_001', title: '강변북로 야경', description: '',
      latitude: 37.5443, longitude: 127.0001,
      emotion: '좋아요', weather: '맑음', companions: const [],
      intensityLevel: 5, pinShape: 'drive',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 3)), countryCode: 'KR',
    ),
    PinModel(
      id: 'demo_running_001', title: '서울숲 산책로', description: '',
      latitude: 37.5443, longitude: 127.0374,
      emotion: '별로에요', weather: '맑음', companions: const [],
      intensityLevel: 2, pinShape: 'running',
      visibility: '🌐 전체 공개', photoPaths: const [],
      createdAt: now.subtract(const Duration(days: 5)), countryCode: 'KR',
    ),
  ];

  for (final pin in seeds) {
    await repo.save(pin);
  }
  await box.put(settingsKey, true);
}

// 잠실→한강→뚝섬→광화문 테스트 경로 핀 (2026-04-28, 최초 1회만)
Future<void> _seedTestRouteIfNeeded() async {
  const settingsKey = 'seed_test_route_v1';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  final repo = PinRepository();
  final pins = [
    PinModel(
      id: 'test_route_001',
      title: '잠실 롯데타워',
      description: '서울에서 가장 높은 빌딩, 전망대에서 도시 전경 감상',
      latitude: 37.5126,
      longitude: 127.1027,
      emotion: '좋아요',
      weather: '맑음',
      companions: [],
      intensityLevel: 4,
      pinShape: 'star',
      visibility: '🌐 전체 공개',
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
      weather: '맑음',
      companions: [],
      intensityLevel: 3,
      pinShape: 'sprout',
      visibility: '🌐 전체 공개',
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
      weather: '맑음',
      companions: [],
      intensityLevel: 4,
      pinShape: 'cherryBlossom',
      visibility: '🌐 전체 공개',
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
      weather: '맑음',
      companions: [],
      intensityLevel: 3,
      pinShape: 'moon',
      visibility: '🌐 전체 공개',
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
      weather: '맑음',
      companions: [],
      intensityLevel: 3,
      pinShape: 'cloud',
      visibility: '🌐 전체 공개',
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
      weather: '맑음',
      companions: [],
      intensityLevel: 4,
      pinShape: 'sun',
      visibility: '🌐 전체 공개',
      photoPaths: [],
      createdAt: DateTime(2026, 4, 28, 17, 30),
      countryCode: 'KR',
    ),
  ];

  for (final pin in pins) {
    await repo.save(pin);
  }
  await box.put(settingsKey, true);
}

// seed-1..6 하드코딩 가짜 핀 제거 — uid 없이 심어진 핀이 계정 간 노출되던 버그 수정
Future<void> _removeLegacySeedPinsIfNeeded() async {
  const settingsKey = 'remove_seed_pins_v1';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  const legacyIds = ['seed-1', 'seed-2', 'seed-3', 'seed-4', 'seed-5', 'seed-6'];
  final repo = PinRepository();
  for (final id in legacyIds) {
    await repo.delete(id);
  }

  // 서버에도 혹시 업로드된 경우 동시 정리
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid != null) {
    try {
      await Supabase.instance.client
          .from('pins')
          .delete()
          .inFilter('id', legacyIds)
          .eq('uid', uid);
    } catch (_) {}
  }

  await box.put(settingsKey, true);
}

// 랜드마크 데모 핀에 번들 사진 할당 (최초 1회만)
Future<void> _migrateLandmarkPhotosIfNeeded() async {
  const settingsKey = 'landmark_photos_v1';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  final repo = PinRepository();
  const assignments = {
    'test_route_005': 'asset:lib/img/Kyeonbookgoung.jpeg',  // 경복궁
    'test_route_006': 'asset:lib/img/GwangWhamoon.jpeg',    // 광화문
    'seed-6':         'asset:lib/img/Bookchone koreanvillage.webp', // 북촌
  };

  for (final entry in assignments.entries) {
    final pin = repo.getById(entry.key);
    if (pin != null && pin.photoPaths.isEmpty) {
      await repo.save(pin.copyWith(photoPaths: [entry.value]));
    }
  }
  await box.put(settingsKey, true);
}

// 신규 핀 사진 일괄 할당 (최초 1회만)
Future<void> _migratePinPhotosV2IfNeeded() async {
  const settingsKey = 'pin_photos_v2';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  final repo = PinRepository();
  const assignments = {
    'test_route_001': 'asset:lib/img/잠실 롯데타워.png',
    'test_route_002': 'asset:lib/img/잠실 한강공원 .jpg',
    'test_route_003': 'asset:lib/img/뚝섬 한강공원.png',
    'test_route_004': 'asset:lib/img/성수동 카페거리.png',
    'demo_drive_001': 'asset:lib/img/강변북로 야경.png',
    'demo_running_001': 'asset:lib/img/서울숲 산책로.png',
    'demo_drinking_001': 'asset:lib/img/광장시장 육회골목.png',
    'demo_drinking_002': 'asset:lib/img/을지로 노포.png',
    'demo_shopping_001': 'asset:lib/img/성수 콘크리트.png',
  };

  for (final entry in assignments.entries) {
    final pin = repo.getById(entry.key);
    if (pin != null && pin.photoPaths.isEmpty) {
      await repo.save(pin.copyWith(photoPaths: [entry.value]));
    }
  }
  await box.put(settingsKey, true);
}

// 나머지 핀 사진 일괄 할당 (최초 1회만)
Future<void> _migratePinPhotosV3IfNeeded() async {
  const settingsKey = 'pin_photos_v3';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  final repo = PinRepository();
  const assignments = {
    'seed-1': 'asset:lib/img/홍대 연남동 골목 카페.png',
    'seed-2': 'asset:lib/img/이태원 경리단길 야경.jpeg',
    'seed-3': 'asset:lib/img/강남 코엑스 별마당 도서관.png',
    'seed-4': 'asset:lib/img/한강 뚝섬 유원지.jpeg',
    'seed-5': 'asset:lib/img/성수동 팝업 스토어.png',
    'demo_cafe_001': 'asset:lib/img/성수동 블루보틀.png',
    'demo_cafe_002': 'asset:lib/img/연남동 작은 카페.png',
  };

  for (final entry in assignments.entries) {
    final pin = repo.getById(entry.key);
    if (pin != null && pin.photoPaths.isEmpty) {
      await repo.save(pin.copyWith(photoPaths: [entry.value]));
    }
  }
  await box.put(settingsKey, true);
}

// 망원동 골목 카페 사진 할당 (최초 1회만)
Future<void> _migratePinPhotosV4IfNeeded() async {
  const settingsKey = 'pin_photos_v4';
  final box = Hive.box<dynamic>('settings');
  if (box.get(settingsKey) == true) return;

  final repo = PinRepository();
  const assignments = {
    'demo_cafe_003': 'asset:lib/img/망원동 골목 카페.png',
  };

  for (final entry in assignments.entries) {
    final pin = repo.getById(entry.key);
    if (pin != null && pin.photoPaths.isEmpty) {
      await repo.save(pin.copyWith(photoPaths: [entry.value]));
    }
  }
  await box.put(settingsKey, true);
}

/// 앱 전역에서 FCM 알림 오버레이 & 화면 이동에 사용하는 NavigatorKey
final GlobalKey<NavigatorState> pinlogNavigatorKey = GlobalKey<NavigatorState>();

class PinlogApp extends ConsumerWidget {
  final bool isAuthenticated;
  const PinlogApp({required this.isAuthenticated, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(themePresetProvider);
    return AppThemeScope(
      preset: preset,
      child: MaterialApp(
        title: 'Pinlog',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        navigatorKey: pinlogNavigatorKey,
        home: _AppEntry(isAuthenticated: isAuthenticated),
        builder: (ctx, child) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: isDark
                ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
                : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
            child: child!,
          );
        },
      ),
    );
  }
}

/// 앱 루트 엔트리 — 베이스 화면(MainShell 또는 SignInScreen) 위에
/// SplashScreen 오버레이를 얹는다. 스플래시가 끝나면 오버레이를
/// 600ms 페이드아웃해서 제거 — 베이스 지도는 이미 로딩 완료 상태.
class _AppEntry extends StatefulWidget {
  final bool isAuthenticated;
  const _AppEntry({required this.isAuthenticated});

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashFading = false;
  bool _splashGone = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 베이스 화면은 앱 시작과 동시에 로딩 시작 — 스플래시 뒤에서 준비됨
        widget.isAuthenticated ? const MainShell() : const SignInScreen(),

        if (!_splashGone)
          IgnorePointer(
            ignoring: _splashFading,
            child: AnimatedOpacity(
              opacity: _splashFading ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              onEnd: () {
                if (_splashFading && mounted) {
                  setState(() => _splashGone = true);
                }
              },
              child: SplashScreen(
                isAuthenticated: widget.isAuthenticated,
                onDone: () {
                  if (mounted) setState(() => _splashFading = true);
                },
              ),
            ),
          ),
      ],
    );
  }
}
