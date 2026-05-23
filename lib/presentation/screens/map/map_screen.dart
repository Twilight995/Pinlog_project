import 'dart:convert';
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
import '../../widgets/common/glass_bottom_sheet.dart';
import '../../widgets/map/filter_sheet.dart';
import '../pin_detail/pin_detail_screen.dart';
import '../pin_wizard/pin_wizard_screen.dart';

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;

  /// GeoJsonSource + 레이어 추가가 끝났는지.
  bool _layersReady = false;

  /// 이미 등록된 카테고리 아이콘 (shape 키).
  final Set<String> _iconsRegistered = {};

  // (이전: _showFilterSheet 플래그 — 이제 showModalBottomSheet 사용)

  /// 3D 지구본 투영 활성 여부.
  bool _isGlobeView = false;

  // ─── 클러스터링 소스/레이어 ID ────────────────────────────────────────────
  static const _pinSourceId = 'pinlog-pins';
  static const _clusterHaloOuterLayerId = 'pinlog-cluster-halo-outer';
  static const _clusterHaloLayerId = 'pinlog-cluster-halo';
  static const _clusterCoreLayerId = 'pinlog-cluster-core';
  static const _clusterCoreInnerLayerId = 'pinlog-cluster-core-inner';
  static const _clusterCountLayerId = 'pinlog-cluster-count';
  static const _unclusteredLayerId = 'pinlog-unclustered';

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

    // 스타일 변경으로 MapWidget이 재생성되면 상태 리셋 (새 스타일은 source/layer 없음)
    _layersReady = false;
    _iconsRegistered.clear();

    // 기본 UI 정리 — 컴퍼스/스케일바 숨김
    await controller.compass.updateSettings(CompassSettings(enabled: false));
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.attribution.updateSettings(
      AttributionSettings(position: OrnamentPosition.BOTTOM_LEFT, marginBottom: 100),
    );
  }

  /// 스타일이 완전히 로드된 후 트리거 — 클러스터링 셋업.
  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (_mapboxMap == null) return;
    try {
      await _setupClustering();
      await _refreshPinSource();
    } catch (e, st) {
      debugPrint('🛑 clustering setup failed: $e\n$st');
    }
  }

  /// 카테고리별 마커 이미지 캐시 (shape + pixelRatio → bytes).
  final Map<String, Uint8List> _markerCache = {};

  // ─── 클러스터링 셋업 ──────────────────────────────────────────────────────

  /// 스타일에 GeoJsonSource + 4개 레이어(헤일로/코어/카운트/개별 핀)를 추가.
  /// 한 번만 실행되도록 `_layersReady` 가드.
  Future<void> _setupClustering() async {
    if (_layersReady || _mapboxMap == null) return;
    final style = _mapboxMap!.style;
    debugPrint('🟢 clustering setup start');

    // 1) 카테고리별 아이콘 등록 (개별 핀 SymbolLayer가 shape 이름으로 참조)
    try {
      await _registerPinIcons();
      debugPrint('🟢 ${_iconsRegistered.length} icons registered');
    } catch (e) {
      debugPrint('🛑 icon registration failed: $e');
    }

    // 2) GeoJsonSource (클러스터 활성)
    await style.addSource(GeoJsonSource(
      id: _pinSourceId,
      data: _emptyGeoJson,
      cluster: true,
      clusterRadius: 50,
      clusterMaxZoom: 14,
    ));
    debugPrint('🟢 source added');

    // 3a) 외곽 헤일로 — 가장 흐릿한 큰 글로우 (펜의 0.6~1.0 위치)
    // 펜 size × 1.3, 매우 흐림, 옅은 알파
    await style.addLayer(CircleLayer(
      id: _clusterHaloOuterLayerId,
      sourceId: _pinSourceId,
      filter: ['has', 'point_count'],
      circleColorExpression: [
        'step', ['get', 'point_count'],
        '#D9CEFA', 10, '#C7BFFF', 50, '#9D8BE0',
      ],
      circleRadiusExpression: [
        'step', ['get', 'point_count'],
        44, 10, 56, 50, 70,
      ],
      circleBlur: 1.0,
      circleOpacity: 0.30,
    ));

    // 3b) 내부 헤일로 — 더 또렷한 글로우 (펜의 0~0.35 위치)
    // 펜 size 그대로, 중간 blur, 강한 알파
    await style.addLayer(CircleLayer(
      id: _clusterHaloLayerId,
      sourceId: _pinSourceId,
      filter: ['has', 'point_count'],
      circleColorExpression: [
        'step', ['get', 'point_count'],
        '#D9CEFA', 10, '#C7BFFF', 50, '#9D8BE0',
      ],
      circleRadiusExpression: [
        'step', ['get', 'point_count'],
        32, 10, 41, 50, 52,
      ],
      circleBlur: 0.7,
      circleOpacity: 0.55,
    ));

    // 4a) 코어 — 진한 라벤더 (펜 core 그라디언트 끝 색)
    await style.addLayer(CircleLayer(
      id: _clusterCoreLayerId,
      sourceId: _pinSourceId,
      filter: ['has', 'point_count'],
      circleColorExpression: [
        'step', ['get', 'point_count'],
        '#C7BFFF', 10, '#9D8BE0', 50, '#8B7BC9',
      ],
      circleRadiusExpression: [
        'step', ['get', 'point_count'],
        19, 10, 25, 50, 32,
      ],
      circleBlur: 0.2,
      circleOpacity: 0.95,
    ));

    // 4b) 코어 하이라이트 — 가운데 옅은 흰빛 (펜 core 그라디언트 시작 색)
    // 살짝 작은 원 + 옅은 흰 알파로 입체감
    await style.addLayer(CircleLayer(
      id: _clusterCoreInnerLayerId,
      sourceId: _pinSourceId,
      filter: ['has', 'point_count'],
      circleColor: 0xFFFFFFFF,
      circleRadiusExpression: [
        'step', ['get', 'point_count'],
        11, 10, 14, 50, 18,
      ],
      circleBlur: 0.6,
      circleOpacity: 0.55,
      circleTranslate: [-3.0, -3.0],
    ));

    // 5) 클러스터 카운트 텍스트
    await style.addLayer(SymbolLayer(
      id: _clusterCountLayerId,
      sourceId: _pinSourceId,
      filter: ['has', 'point_count'],
      textFieldExpression: ['get', 'point_count_abbreviated'],
      textSize: 14,
      textColor: 0xFFFFFFFF,
      textHaloColor: 0x66000000,
      textHaloWidth: 1,
      textFont: ['Open Sans Bold'],
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ));

    // 6) 개별 핀 (클러스터링되지 않은 점)
    await style.addLayer(SymbolLayer(
      id: _unclusteredLayerId,
      sourceId: _pinSourceId,
      filter: ['!', ['has', 'point_count']],
      iconImageExpression: ['get', 'shape'],
      iconSize: 1.0,
      iconAnchor: IconAnchor.BOTTOM,
      iconAllowOverlap: true,
    ));

    _layersReady = true;
    debugPrint('🟢 clustering setup complete (4 layers added)');
  }

  /// 카테고리별 아이콘 이미지를 스타일에 등록.
  /// SymbolLayer에서 `iconImage: ['get', 'shape']` 식으로 참조.
  ///
  /// `MbxImage.data` 는 PNG 바이트를 그대로 전달 (네이티브가 디코드).
  /// raw RGBA로 변환하면 채널 에러 발생.
  Future<void> _registerPinIcons() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    // _buildPinIconBytes 와 같은 로직 — 38 logical * pixelRatio
    final pxSize = (38.0 * pixelRatio).round();

    for (final shape in AppConstants.pinShapes) {
      if (_iconsRegistered.contains(shape)) continue;
      final emoji = AppConstants.pinShapeEmojis[shape] ?? '📍';
      final pngBytes = await _buildPinIconBytes(
        shape: shape,
        emoji: emoji,
        pixelRatio: pixelRatio,
      );
      await style.addStyleImage(
        shape,
        pixelRatio,
        MbxImage(width: pxSize, height: pxSize, data: pngBytes),
        false,
        [],
        [],
        null,
      );
      _iconsRegistered.add(shape);
    }
  }

  /// 빈 FeatureCollection (초기 source data).
  static const _emptyGeoJson =
      '{"type":"FeatureCollection","features":[]}';

  /// 필터된 핀들로 GeoJsonSource 데이터 업데이트.
  Future<void> _refreshPinSource() async {
    if (_mapboxMap == null || !_layersReady) {
      debugPrint('⚠️ refreshPinSource skipped (layersReady=$_layersReady)');
      return;
    }
    final pins = ref.read(filteredPinsProvider);

    final features = pins
        .map((pin) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [pin.longitude, pin.latitude],
              },
              'properties': {
                'pinId': pin.id,
                'shape': pin.pinShape,
              },
            })
        .toList();
    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    try {
      await _mapboxMap!.style.setStyleSourceProperty(
        _pinSourceId,
        'data',
        geoJson,
      );
      debugPrint('🟢 source data updated (${pins.length} pins)');
    } catch (e) {
      debugPrint('🛑 source data update failed: $e');
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

  /// 핀 상세 화면 진입 (공통 트랜지션).
  void _openPinDetail(String pinId) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => PinDetailScreen(pinId: pinId),
      transitionsBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    ));
  }

  /// 지도 탭 핸들러.
  /// 우선순위: 클러스터(줌인) → 개별 핀(상세) → 빈 곳(위자드).
  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    if (_mapboxMap == null) return;

    // 1) 탭한 지점의 렌더된 피쳐 쿼리 (클러스터 코어 + 개별 핀 레이어 대상)
    try {
      final screenCoord = ctx.touchPosition;
      final features = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        RenderedQueryOptions(
          layerIds: [_clusterCoreLayerId, _unclusteredLayerId],
        ),
      );

      if (features.isNotEmpty) {
        final feature = features.first;
        if (feature == null) return;
        final qFeature = feature.queriedFeature.feature;
        final props = (qFeature['properties'] as Map?) ?? const {};

        // 클러스터 — 줌인
        if (props.containsKey('point_count')) {
          final geometry = qFeature['geometry'] as Map?;
          final coords = geometry?['coordinates'] as List?;
          if (coords != null && coords.length >= 2) {
            HapticFeedback.lightImpact();
            final camState = await _mapboxMap!.getCameraState();
            final targetZoom = (camState.zoom + 2).clamp(1.0, 22.0);
            await _mapboxMap!.flyTo(
              CameraOptions(
                center: Point(
                  coordinates: Position(
                    (coords[0] as num).toDouble(),
                    (coords[1] as num).toDouble(),
                  ),
                ),
                zoom: targetZoom,
              ),
              MapAnimationOptions(duration: 600),
            );
          }
          return;
        }

        // 개별 핀 — 상세 진입
        final pinId = props['pinId'] as String?;
        if (pinId != null && pinId.isNotEmpty) {
          _openPinDetail(pinId);
          return;
        }
      }
    } catch (_) {
      // 쿼리 실패 시 빈 곳 탭과 동일 처리로 fallthrough
    }

    // 2) 빈 곳 → 핀 생성 위자드
    final lat = ctx.point.coordinates.lat;
    final lng = ctx.point.coordinates.lng;
    if (!mounted) return;
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
    // 핀 필터 변경 시 GeoJsonSource 데이터 갱신
    ref.listen(filteredPinsProvider, (_, _) {
      _refreshPinSource();
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
              onStyleLoadedListener: _onStyleLoaded,
              // ignore: deprecated_member_use
              onTapListener: _onMapTap,
            ),

            // ── 지도 컨트롤 ──────────────────────────────────────────────
            _MapControls(
              onRouteTap: () {
                // TODO: 경로 모드 Mapbox 재구현 예정
              },
              onFilterTap: () => FilterSheet.show(context),
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

  static const _options = <(MapStyleOption, String, IconData)>[
    (MapStyleOption.standard, '스탠다드', Icons.map_outlined),
    (MapStyleOption.streets, '스트리트', Icons.navigation_outlined),
    (MapStyleOption.light, '라이트', Icons.wb_sunny_outlined),
    (MapStyleOption.dark, '다크', Icons.nightlight_outlined),
    (MapStyleOption.satellite, '위성', Icons.satellite_alt_outlined),
    (MapStyleOption.outdoors, '아웃도어', Icons.terrain_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassBottomSheet(
      headerIcon: Icons.layers_rounded,
      title: '지도 스타일',
      subtitle: '오늘 어떤 풍경에 기억을 담아볼까요',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((opt) {
          final (style, name, icon) = opt;
          final isActive = current == style;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GlassStyleRow(
              label: name,
              icon: icon,
              isActive: isActive,
              onTap: () => onSelect(style),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 지도 스타일 선택 행 — 글래스 톤 통일.
class _GlassStyleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassStyleRow({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final topA = isActive ? 0.65 : 0.15;
    final midA = isActive ? 0.50 : 0.10;
    final botA = isActive ? 0.35 : 0.07;
    final borderA = isActive ? 0.85 : 0.20;
    final borderW = isActive ? 1.5 : 1.0;
    final blur = isActive ? 36.0 : 20.0;
    final iconBoxA = isActive ? 0.40 : 0.10;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 56,
            padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: topA),
                  Colors.white.withValues(alpha: midA),
                  Colors.white.withValues(alpha: botA),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderA),
                width: borderW,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: iconBoxA),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                      color: Colors.white,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ),
                if (isActive)
                  const Icon(Icons.check_rounded, size: 20, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
