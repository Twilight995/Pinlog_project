import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/camera_prefs.dart';
import '../auth/sign_in_screen.dart';
import '../main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  double _bearing = 0.0;
  Timer? _rotationTimer;
  bool _navigated = false;
  bool _mapReady = false;

  late final AnimationController _contentCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // 지도가 늦게 준비될 경우 fallback — 2.5초 뒤엔 콘텐츠 강제 표시
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_contentCtrl.isCompleted) _contentCtrl.forward();
    });

    // 총 스플래시 시간 — 줌인 시작은 _navigateOut 내부에서 처리
    Future.delayed(const Duration(milliseconds: 3800), _navigateOut);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // 지구본 초기 카메라 (아시아 태평양 중심, 살짝 기울임)
    await map.setCamera(CameraOptions(
      center: Point(coordinates: Position(130.0, 30.0)),
      zoom: 1.5,
      pitch: 20,
      bearing: 0,
    ));

    await map.style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );

    // 불필요한 UI 요소 제거
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    try {
      await map.compass.updateSettings(CompassSettings(enabled: false));
    } catch (_) {}
    try {
      await map.attribution
          .updateSettings(AttributionSettings(enabled: false));
    } catch (_) {}
    try {
      await map.logo.updateSettings(LogoSettings(enabled: false));
    } catch (_) {}

    // 스플래시에서는 제스처 전부 비활성화
    try {
      await map.gestures.updateSettings(GesturesSettings(
        scrollEnabled: false,
        rotateEnabled: false,
        pitchEnabled: false,
        doubleTapToZoomInEnabled: false,
        doubleTouchToZoomOutEnabled: false,
        quickZoomEnabled: false,
      ));
    } catch (_) {}

    if (!mounted) return;
    setState(() => _mapReady = true);
    _contentCtrl.forward();
    _startAutoRotation();
  }

  void _startAutoRotation() {
    _rotationTimer?.cancel();
    // 16ms마다 0.12° → 약 7.5°/초 자동 회전
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_mapboxMap == null || !mounted) return;
      _bearing = (_bearing + 0.12) % 360;
      _mapboxMap!.setCamera(CameraOptions(bearing: _bearing));
    });
  }

  // 지구본 줌인 → 마지막 위치로 날아가며 앱 크로스페이드 (플래시 없음)
  Future<void> _navigateOut() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    _rotationTimer?.cancel();

    // 저장된 마지막 카메라 위치 로드 (없으면 한반도 중심 기본값)
    final cam = await CameraPrefs.load();
    if (!mounted) return;

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(cam.lng, cam.lat)),
        zoom: cam.zoom,
        pitch: 0,
        bearing: _bearing,
      ),
      MapAnimationOptions(duration: 1400),
    );

    // flyTo 진행 중(700ms 시점)에 앱 화면이 서서히 크로스페이드
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    final storedMode = Hive.box<dynamic>('settings').get('auth_mode') as String?;
    final isAuthenticated = session != null || storedMode == 'demo';
    final dest = isAuthenticated ? const MainShell() : const SignInScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, _, _) => dest,
        transitionsBuilder: (ctx, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 1100),
      ),
    );
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _contentCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Mapbox 지구본 ────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _mapReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 700),
            child: MapWidget(
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: _onMapCreated,
            ),
          ),

          // ── 우주 분위기 — 가장자리 어둡게, 상단 더 진하게 ────────────────
          IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Color(0xBB050B1A),
                  ],
                  stops: [0.42, 1.0],
                ),
              ),
            ),
          ),

          // ── 상단 그라디언트 (지구본과 하늘의 경계) ──────────────────────
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF050B1A), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          // ── PINLOG 워드마크 + 태그라인 (상단) ──────────────────────────────
          FadeTransition(
            opacity: _contentCtrl,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                    height: MediaQuery.of(context).padding.top.clamp(0.0, 60.0) + 28),
                Text(
                  '나만의 발자국을 지도 위에 새기다',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.50),
                    letterSpacing: -0.2,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 8),
                // shimmer PINLOG
                AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (context, _) => ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.65),
                        Colors.white,
                        Colors.white.withValues(alpha: 0.65),
                      ],
                      stops: [
                        (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                        _shimmerCtrl.value,
                        (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'PINLOG',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 10,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
