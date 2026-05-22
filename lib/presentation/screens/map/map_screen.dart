import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Mapbox와 이름 충돌(Position / LocationSettings)을 피하려고 prefix 사용
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../widgets/cosmic/category_palette.dart';
import '../../widgets/map/filter_sheet.dart';
import '../../widgets/map/pin_detail_sheet.dart';
import '../pin_wizard/pin_wizard_screen.dart';

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annoManager;

  /// 마커 ID → 핀 ID
  final Map<String, String> _pinByMarker = {};

  bool _showFilterSheet = false;

  /// 3D 지구본 투영 활성 여부.
  bool _isGlobeView = false;

  // Mapbox `Point`/`Position`은 const 생성자가 없어 정적 getter로 노출.
  static Point get _initialCenter =>
      Point(coordinates: Position(126.9780, 37.5665));
  static const _initialZoom = 13.0;

  /// Mapbox Standard 통합 스타일. globe projection과 호환성이 가장 좋음.
  static const _standardStyleUri = 'mapbox://styles/mapbox/standard';
  static const _standardSatelliteUri =
      'mapbox://styles/mapbox/standard-satellite';

  String _styleUriFor(MapStyleOption style) {
    switch (style) {
      case MapStyleOption.standard:
      case MapStyleOption.streets:
      case MapStyleOption.light:
        return _standardStyleUri;
      case MapStyleOption.dark:
        return MapboxStyles.DARK;
      case MapStyleOption.satellite:
        return _standardSatelliteUri;
      case MapStyleOption.outdoors:
        return MapboxStyles.OUTDOORS;
    }
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;

    // 기본 UI 정리 — 컴퍼스/스케일바 숨김
    await controller.compass.updateSettings(CompassSettings(enabled: false));
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.attribution.updateSettings(
      AttributionSettings(position: OrnamentPosition.BOTTOM_LEFT, marginBottom: 100),
    );

    // 핀 마커용 어노테이션 매니저
    _annoManager = await controller.annotations.createPointAnnotationManager();
    _annoManager?.tapEvents(onTap: _onMarkerTap);

    // 현재 필터된 핀들로 마커 갱신
    await _refreshMarkers();
  }

  /// 카테고리별 마커 이미지 캐시 (shape + pixelRatio → bytes).
  final Map<String, Uint8List> _markerCache = {};

  Future<void> _refreshMarkers() async {
    if (_annoManager == null) return;
    final pins = ref.read(filteredPinsProvider);

    await _annoManager!.deleteAll();
    _pinByMarker.clear();

    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    for (final pin in pins) {
      final emoji = AppConstants.pinShapeEmojis[pin.pinShape] ?? '📍';
      final iconBytes = await _buildPinIconBytes(
        shape: pin.pinShape,
        emoji: emoji,
        pixelRatio: pixelRatio,
      );
      final ann = await _annoManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(pin.longitude, pin.latitude)),
        image: iconBytes,
        iconSize: 1.0,
        iconAnchor: IconAnchor.BOTTOM,
      ));
      _pinByMarker[ann.id] = pin.id;
    }
  }

  /// 카테고리별 마커 아이콘 — 흰 원 + 카테고리 컬러 보더 + 이모지.
  Future<Uint8List> _buildPinIconBytes({
    required String shape,
    required String emoji,
    required double pixelRatio,
  }) async {
    final key = '${shape}_${pixelRatio.toStringAsFixed(1)}';
    final cached = _markerCache[key];
    if (cached != null) return cached;

    final palette = CategoryPalette.forShape(shape);
    const logicalSize = 38.0;
    final pxSize = (logicalSize * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final cx = pxSize / 2.0;
    final cy = pxSize / 2.0;
    final r = pxSize / 2.0 - pixelRatio * 2;

    // 그림자
    canvas.drawCircle(
      ui.Offset(cx, cy + pixelRatio * 2),
      r,
      ui.Paint()
        ..color = const ui.Color(0x40000000)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 4),
    );
    // 흰 원
    canvas.drawCircle(
      ui.Offset(cx, cy),
      r,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    // 카테고리 컬러 보더
    canvas.drawCircle(
      ui.Offset(cx, cy),
      r,
      ui.Paint()
        ..color = palette.accent
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = pixelRatio * 2.5,
    );
    // 이모지 — 중앙 정렬
    final emojiPx = pxSize * 0.55;
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: emojiPx),
    )..addText(emoji);
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: pxSize.toDouble()));
    canvas.drawParagraph(
      para,
      ui.Offset(0, cy - para.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxSize, pxSize);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = bd!.buffer.asUint8List();
    _markerCache[key] = bytes;
    return bytes;
  }

  void _onMarkerTap(PointAnnotation annotation) {
    final pinId = _pinByMarker[annotation.id];
    if (pinId == null) return;
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          PinDetailSheet(pinId: pinId, onClose: () => Navigator.of(ctx).pop()),
        ],
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  void _onMapTap(MapContentGestureContext ctx) {
    final lat = ctx.point.coordinates.lat;
    final lng = ctx.point.coordinates.lng;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinWizardScreen(
        location: ll.LatLng(lat.toDouble(), lng.toDouble()),
      ),
    ));
  }

  // ─── 현재 위치 ────────────────────────────────────────────────────────────

  Future<void> _moveToCurrentLocation() async {
    HapticFeedback.lightImpact();
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      return;
    }
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 800),
      );
    } catch (_) {}
  }

  // ─── 지구본 토글 ──────────────────────────────────────────────────────────

  Future<void> _toggleGlobe() async {
    HapticFeedback.lightImpact();
    final next = !_isGlobeView;
    setState(() => _isGlobeView = next);

    final map = _mapboxMap;
    if (map == null) return;

    if (next) {
      // ── ON 전환: 투영 먼저 → 부드럽게 줌 아웃 ──
      //   현재 줌이 깊어 globe·mercator 시각 차이 거의 없음 → 투영 전환 무감각.
      //   그 후 줌 아웃하면서 둥근 지구가 자연스레 드러남.
      try {
        await map.style.setProjection(
          StyleProjection(name: StyleProjectionName.globe),
        );
      } catch (e) {
        debugPrint('🛑 setProjection(globe) failed: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      try {
        await map.flyTo(
          CameraOptions(center: _initialCenter, zoom: 1.0),
          MapAnimationOptions(duration: 1600),
        );
      } catch (e) {
        debugPrint('🛑 flyTo(zoom-out) failed: $e');
      }
    } else {
      // ── OFF 전환: 줌 인 + 중간 시점에 투영 전환 (한 모션 안에 녹임) ──
      //   flyTo를 await 없이 시작 → 진행 도중(zoom ≈ 6) 조용히 mercator로 swap
      //   → 사용자는 끊김 없는 한 번의 줌 인 애니메이션으로 체감.
      const totalMs = 1800;
      const swapAtMs = 1100; // 줌 6 부근에서 swap

      final flyFuture = map
          .flyTo(
            CameraOptions(center: _initialCenter, zoom: _initialZoom),
            MapAnimationOptions(duration: totalMs),
          )
          .catchError((e) => debugPrint('🛑 flyTo(zoom-in) failed: $e'));

      await Future.delayed(const Duration(milliseconds: swapAtMs));
      if (!mounted) return;
      try {
        await map.style.setProjection(
          StyleProjection(name: StyleProjectionName.mercator),
        );
      } catch (e) {
        debugPrint('🛑 setProjection(mercator) failed: $e');
      }
      await flyFuture;
    }
  }

  // ─── + 버튼: 현재 위치에서 핀 생성 ────────────────────────────────────────

  Future<void> _createPinAtCurrentLocation() async {
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      _openWizardWith(_initialLatLng());
      return;
    }
    try {
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null) {
        _openWizardWith(ll.LatLng(last.latitude, last.longitude));
        return;
      }
    } catch (_) {}
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 2),
        ),
      );
      _openWizardWith(ll.LatLng(pos.latitude, pos.longitude));
      return;
    } catch (_) {}
    _openWizardWith(_initialLatLng());
  }

  ll.LatLng _initialLatLng() {
    final c = _initialCenter.coordinates;
    return ll.LatLng(c.lat.toDouble(), c.lng.toDouble());
  }

  void _openWizardWith(ll.LatLng target) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinWizardScreen(location: target),
    ));
  }

  // ─── 레이어 시트 ──────────────────────────────────────────────────────────

  void _showLayerSheet(BuildContext ctx, WidgetRef ref) {
    showAppSheet<void>(
      ctx,
      builder: (_) => _LayerSheet(
        current: ref.read(mapStyleProvider),
        onSelect: (style) {
          ref.read(mapStyleProvider.notifier).state = style;
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  // ─── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 핀 필터 변경 시 마커 갱신
    ref.listen(filteredPinsProvider, (_, _) {
      _refreshMarkers();
    });

    // + 버튼 트리거
    ref.listen(triggerCreatePinProvider, (_, triggered) {
      if (triggered) {
        ref.read(triggerCreatePinProvider.notifier).state = false;
        _createPinAtCurrentLocation();
      }
    });

    final currentStyle = ref.watch(mapStyleProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Mapbox 지도 ─────────────────────────────────────────────────
            MapWidget(
              key: ValueKey('map-$currentStyle'),
              // ignore: deprecated_member_use
              cameraOptions: CameraOptions(
                center: _initialCenter,
                zoom: _initialZoom,
              ),
              styleUri: _styleUriFor(currentStyle),
              onMapCreated: _onMapCreated,
              // ignore: deprecated_member_use
              onTapListener: _onMapTap,
            ),

            // ── 지도 컨트롤 ──────────────────────────────────────────────
            _MapControls(
              onRouteTap: () {
                // TODO: 경로 모드 Mapbox 재구현 예정
              },
              onFilterTap: () => setState(() => _showFilterSheet = true),
              onGlobeTap: _toggleGlobe,
              onLayerTap: () => _showLayerSheet(context, ref),
              isGlobeView: _isGlobeView,
            ),

            // ── 현재 위치 버튼 (우측 하단) ────────────────────────────────
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 110,
              child: GestureDetector(
                onTap: _moveToCurrentLocation,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [TabTheme.map.bgStart, TabTheme.map.bgEnd],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: TabTheme.map.accent, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 22,
                    color: TabTheme.map.deep,
                  ),
                ),
              ),
            ),

            // ── 필터 ─────────────────────────────────────────────────────
            if (_showFilterSheet)
              FilterSheet(
                onClose: () => setState(() => _showFilterSheet = false),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 지도 컨트롤 ──────────────────────────────────────────────────────────────
//
// 글래스 필 컨테이너 한 개 안에 4개 버튼(경로 / 필터 / 지구본 / 레이어) 통합.
// 활성 버튼은 흰→연한 그린 그라디언트 + 그린 보더, 비활성은 투명.

class _MapControls extends StatelessWidget {
  final VoidCallback onRouteTap;
  final VoidCallback onFilterTap;
  final VoidCallback onGlobeTap;
  final VoidCallback onLayerTap;
  final bool isGlobeView;

  const _MapControls({
    required this.onRouteTap,
    required this.onFilterTap,
    required this.onGlobeTap,
    required this.onLayerTap,
    required this.isGlobeView,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 56,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillButton(
                    icon: Icons.route_rounded,
                    isActive: false,
                    onTap: onRouteTap,
                  ),
                  _PillButton(
                    icon: Icons.tune_rounded,
                    isActive: false,
                    onTap: onFilterTap,
                  ),
                  _PillButton(
                    icon: isGlobeView
                        ? Icons.public_rounded
                        : Icons.public_off_rounded,
                    isActive: isGlobeView,
                    onTap: onGlobeTap,
                  ),
                  _PillButton(
                    icon: Icons.layers_outlined,
                    isActive: false,
                    onTap: onLayerTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 글래스 필 안의 개별 버튼.
/// 활성 시 흰→연한 그린 그라디언트 + 그린 보더,
/// 비활성 시 투명 + muted 흰 아이콘.
class _PillButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [TabTheme.map.bgStart, TabTheme.map.bgEnd],
                )
              : null,
          shape: BoxShape.circle,
          border: isActive
              ? Border.all(color: TabTheme.map.accent, width: 1)
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive
              ? TabTheme.map.deep
              : AppColors.textOnPastel.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ─── 지도 레이어 선택 시트 ────────────────────────────────────────────────────

class _LayerSheet extends StatelessWidget {
  final MapStyleOption current;
  final void Function(MapStyleOption) onSelect;

  const _LayerSheet({required this.current, required this.onSelect});

  static const _options = [
    (MapStyleOption.standard, '기본', '표준 지도', [Color(0xFFE8E0D4), Color(0xFFD4C9A8)], Color(0xFF2A7A4F)),
    (MapStyleOption.dark, '다크', '야간 모드', [Color(0xFF1C1C2E), Color(0xFF0D0D1A)], Color(0xFF8B5CF6)),
    (MapStyleOption.satellite, '위성', '항공 사진', [Color(0xFF1A3A2A), Color(0xFF0D2010)], Color(0xFF4ADE80)),
    (MapStyleOption.outdoors, '야외', '등산·하이킹', [Color(0xFF8DC26A), Color(0xFF3A7A30)], Color(0xFFFFFFFF)),
    (MapStyleOption.light, '라이트', '밝은 모드', [Color(0xFFF8F5EE), Color(0xFFE8E0D0)], Color(0xFF374151)),
    (MapStyleOption.streets, '스트리트', '도로 중심', [Color(0xFFF5F0E8), Color(0xFFD9C9A0)], Color(0xFF1565C0)),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: context.handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '지도 스타일',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.labelColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '마음에 드는 스타일을 선택하세요',
              style: TextStyle(fontSize: 13, color: context.subLabelColor),
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: _options.map((opt) {
              final (style, name, desc, bgColors, accentColor) = opt;
              final isActive = current == style;
              return GestureDetector(
                onTap: () => onSelect(style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive ? TabTheme.map.accent : context.glassBorder,
                      width: isActive ? 2.5 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: TabTheme.map.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: bgColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  bgColors.last.withValues(alpha: 0.0),
                                  bgColors.last.withValues(alpha: 0.95),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: accentColor.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isActive)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: TabTheme.map.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: TabTheme.map.accent.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
