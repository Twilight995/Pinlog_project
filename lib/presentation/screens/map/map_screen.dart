import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings;

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/map/cluster_anim_overlay.dart';
import '../../widgets/map/filter_sheet.dart';
import '../../widgets/map/pin_create_sheet.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ─── 지구본 모드 상수 ──────────────────────────────────────────────────────────
const double _kGlobeEnterZoom = 4.5;
const double _kGlobeExitZoom = 5.8; // 히스테리시스 — 진입보다 높게 설정
const double _kGlobeTargetZoom = 1.5;

// ─── 클러스터 모델 ─────────────────────────────────────────────────────────────

class _Cluster {
  final List<PinModel> pins;
  final double lat;
  final double lng;
  final String? countryCode; // null = 일반 클러스터, non-null = 지구본 국가 클러스터
  const _Cluster({
    required this.pins,
    required this.lat,
    required this.lng,
    this.countryCode,
  });
}

// ISO 3166-1 alpha-2 → 국기 이모지
String _countryFlag(String code) {
  if (code.length != 2) return '🌍';
  final a = String.fromCharCode(code.codeUnitAt(0) - 0x41 + 0x1F1E6);
  final b = String.fromCharCode(code.codeUnitAt(1) - 0x41 + 0x1F1E6);
  return a + b;
}

// 핀 카테고리 → 이모지
String _shapeEmoji(String shape) =>
    AppConstants.pinShapeEmojis[shape] ?? '📍';

// ─── 마커 비트맵 생성 (캐시됨) ────────────────────────────────────────────────

final _markerCache = <String, Uint8List>{};

Future<Uint8List> _buildMarkerBitmap({
  required bool isCluster,
  int count = 0,
  String emoji = '',
  required double pixelRatio,
}) async {
  final key = '${isCluster}_${count}_${emoji}_${pixelRatio.toStringAsFixed(1)}';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  final logicalSize = isCluster ? 52.0 : 46.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pxSize / 2 - pixelRatio * 2;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));

  // 그림자
  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 2.5),
    r,
    Paint()
      ..color = const Color(0x2A000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 6),
  );
  // 본체
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()..color = isCluster ? const Color(0xFF1C1C1E) : Colors.white,
  );
  // 테두리
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = isCluster ? Colors.white.withAlpha(60) : const Color(0xFFD0D0D5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isCluster ? 2.5 : 1.5) * pixelRatio,
  );

  if (isCluster && count > 0) {
    // 클러스터: 숫자
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontWeight: ui.FontWeight.w800,
              fontSize: 13 * pixelRatio,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
          ..addText('$count');
    final para = pb.build()..layout(ui.ParagraphConstraints(width: pxSize));
    canvas.drawParagraph(
      para,
      Offset(cx - para.maxIntrinsicWidth / 2, cy - para.height / 2),
    );
  } else if (!isCluster && emoji.isNotEmpty) {
    // 단일 핀: 이모지
    final emojiPx = pxSize * 0.50;
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: emojiPx),
    )..addText(emoji);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: pxSize));
    canvas.drawParagraph(para, Offset(0, cy - para.height / 2));
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  _markerCache[key] = bytes;
  return bytes;
}

// 지구본 모드 국가 마커 (국기 이모지 + 카운트 뱃지)
Future<Uint8List> _buildCountryMarkerBitmap({
  required String countryCode,
  required int count,
  required double pixelRatio,
}) async {
  final flag = _countryFlag(countryCode);
  final key =
      'country_${countryCode}_${count}_${pixelRatio.toStringAsFixed(1)}';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  const logicalSize = 58.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pxSize / 2 - pixelRatio * 2;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));

  // 그림자
  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 3),
    r,
    Paint()
      ..color = const Color(0x35000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 7),
  );
  // 흰 배경
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);
  // 테두리
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = const Color(0x18000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = pixelRatio * 1.5,
  );

  // 국기 이모지
  final emojiPx = pxSize * 0.48;
  final pb = ui.ParagraphBuilder(
    ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: emojiPx),
  )..addText(flag);
  final para = pb.build()..layout(ui.ParagraphConstraints(width: pxSize));
  canvas.drawParagraph(para, Offset(0, cy - para.height / 2));

  // 카운트 뱃지 (2개 이상일 때)
  if (count > 1) {
    final badgeR = pixelRatio * 10;
    final badgeX = cx + r * 0.62;
    final badgeY = cy - r * 0.62;
    canvas.drawCircle(
      Offset(badgeX, badgeY),
      badgeR,
      Paint()..color = const Color(0xFF1C1C1E),
    );
    canvas.drawCircle(
      Offset(badgeX, badgeY),
      badgeR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = pixelRatio,
    );
    final cPb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontWeight: ui.FontWeight.w800,
              fontSize: badgeR * 1.15,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
          ..addText('$count');
    final cPara = cPb.build()
      ..layout(ui.ParagraphConstraints(width: badgeR * 2));
    canvas.drawParagraph(
      cPara,
      Offset(badgeX - badgeR, badgeY - cPara.height / 2),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  _markerCache[key] = bytes;
  return bytes;
}

Future<Uint8List> _buildNumberedMarkerBitmap(
  int number,
  double pixelRatio, {
  Color bgColor = AppColors.primary,
  Color textColor = Colors.white,
  Color borderColor = Colors.white,
}) async {
  final key =
      'num_${number}_${pixelRatio.toStringAsFixed(1)}_${bgColor.toARGB32()}';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  const logicalSize = 48.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pxSize / 2 - pixelRatio * 2;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));

  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 2.5),
    r,
    Paint()
      ..color = const Color(0x3A000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 5),
  );
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bgColor);
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = pixelRatio * 2,
  );
  final pb =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: TextAlign.center,
            fontWeight: ui.FontWeight.w800,
            fontSize: 13 * pixelRatio,
          ),
        )
        ..pushStyle(ui.TextStyle(color: ui.Color(textColor.toARGB32())))
        ..addText('$number');
  final para = pb.build()..layout(ui.ParagraphConstraints(width: pxSize));
  canvas.drawParagraph(
    para,
    Offset(cx - para.maxIntrinsicWidth / 2, cy - para.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  _markerCache[key] = bytes;
  return bytes;
}

Future<Uint8List> _buildLocationBitmap(double pixelRatio) async {
  const logicalSize = 26.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));

  canvas.drawCircle(
    Offset(cx, cy),
    pxSize * 0.46,
    Paint()
      ..color = const Color(0x40007AFF)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 4),
  );
  canvas.drawCircle(
    Offset(cx, cy),
    pxSize * 0.33,
    Paint()..color = const Color(0xFF007AFF),
  );
  canvas.drawCircle(
    Offset(cx, cy),
    pxSize * 0.33,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = pixelRatio * 2.5,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pinManager;
  PointAnnotationManager? _locationManager;
  PolylineAnnotationManager? _polylineManager;

  final Map<String, String> _pinAnnotationIds = {};
  final Map<String, (double, double)> _clusterIds = {};

  double _zoom = 13.0;
  double _cameraCenterLat = 37.5665;
  double _cameraCenterLng = 126.9780;
  bool _showFilterSheet = false;
  bool _mapReady = false;

  // 지구본 모드
  bool _isGlobeMode = false;
  bool _isGlobeTransitioning = false;
  bool _globePanelExpanded = false;

  Timer? _updateTimer;
  List<PinModel> _currentPins = [];
  Cancelable? _tapSubscription;

  // 클러스터 Nebulous 애니메이션
  List<ClusterItem> _animPrev = [];
  List<ClusterItem> _animNext = [];
  bool _showClusterAnim = false;

  // 경로 모드
  List<PinModel>? _routePins;
  String _routeDate = '';

  // 컨트롤 패널 펼침/접힘
  bool _controlsExpanded = true;
  bool get _routeMode => _routePins != null;

  @override
  void dispose() {
    _updateTimer?.cancel();
    _tapSubscription?.cancel();
    super.dispose();
  }

  // ─── 클러스터 계산 ─────────────────────────────────────────────────────────

  List<_Cluster> _computeClusters(List<PinModel> pins, double zoom) {
    // 지구본 줌: 국가별 클러스터
    if (zoom < _kGlobeEnterZoom) {
      final Map<String, List<PinModel>> byCountry = {};
      for (final p in pins) {
        final key = p.countryCode.isEmpty ? '_unknown' : p.countryCode;
        byCountry.putIfAbsent(key, () => []).add(p);
      }
      return byCountry.entries.map((e) {
        final cp = e.value;
        final lat = cp.fold(0.0, (s, p) => s + p.latitude) / cp.length;
        final lng = cp.fold(0.0, (s, p) => s + p.longitude) / cp.length;
        return _Cluster(pins: cp, lat: lat, lng: lng, countryCode: e.key);
      }).toList();
    }

    if (zoom >= 13) {
      return pins
          .map((p) => _Cluster(pins: [p], lat: p.latitude, lng: p.longitude))
          .toList();
    }

    // 반경 기반 클러스터링 — 그리드 경계 없이 가까운 핀끼리 일관되게 합침
    final radius = zoom >= 12
        ? 0.008
        : zoom >= 10
        ? 0.035
        : zoom >= 8
        ? 0.12
        : zoom >= 6
        ? 0.45
        : 1.8;

    final remaining = List<int>.generate(pins.length, (i) => i);
    final clusters = <_Cluster>[];

    while (remaining.isNotEmpty) {
      final seedIdx = remaining.removeAt(0);
      final group = [pins[seedIdx]];
      double cLat = pins[seedIdx].latitude;
      double cLng = pins[seedIdx].longitude;

      bool changed = true;
      while (changed) {
        changed = false;
        for (int i = remaining.length - 1; i >= 0; i--) {
          final p = pins[remaining[i]];
          final d = math.sqrt(
            math.pow(p.latitude - cLat, 2) + math.pow(p.longitude - cLng, 2),
          );
          if (d < radius) {
            group.add(p);
            remaining.removeAt(i);
            cLat = group.fold(0.0, (s, p) => s + p.latitude) / group.length;
            cLng = group.fold(0.0, (s, p) => s + p.longitude) / group.length;
            changed = true;
          }
        }
      }
      clusters.add(_Cluster(pins: group, lat: cLat, lng: cLng));
    }

    return clusters;
  }

  // ─── 마커 업데이트 ─────────────────────────────────────────────────────────

  List<_Cluster> _lastClusters = [];

  ClusterItem _toItem(_Cluster c) => ClusterItem(
    lat: c.lat,
    lng: c.lng,
    count: c.pins.length,
    emoji: c.pins.length == 1 ? _shapeEmoji(c.pins.first.pinShape) : '',
    countryFlag: c.countryCode != null
        ? (c.countryCode == '_unknown' ? '🌍' : _countryFlag(c.countryCode!))
        : null,
  );

  Future<void> _updateMarkers(List<PinModel> pins) async {
    if (!_mapReady || _pinManager == null) return;

    _currentPins = pins;
    if (_routeMode) return; // 경로 모드 중엔 마커 재렌더 스킵
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    final clusters = _computeClusters(pins, _zoom);

    // ── Nebulous 애니메이션 트리거 ──────────────────────────────────────────
    // 클러스터 수가 바뀐 경우에만 (줌 변화로 인한 merge/split)
    if (_lastClusters.isNotEmpty &&
        _lastClusters.length != clusters.length &&
        mounted &&
        !_isGlobeTransitioning) {
      setState(() {
        _animPrev = _lastClusters.map(_toItem).toList();
        _animNext = clusters.map(_toItem).toList();
        _showClusterAnim = true;
      });
    }
    _lastClusters = clusters;

    await _pinManager!.deleteAll();
    _pinAnnotationIds.clear();
    _clusterIds.clear();

    final images = await Future.wait(
      clusters.map((c) {
        if (c.countryCode != null) {
          // 지구본 모드: 국기 이모지 마커
          return _buildCountryMarkerBitmap(
            countryCode: c.countryCode == '_unknown' ? '' : c.countryCode!,
            count: c.pins.length,
            pixelRatio: pixelRatio,
          );
        }
        return _buildMarkerBitmap(
          isCluster: c.pins.length > 1,
          count: c.pins.length,
          emoji: c.pins.length == 1 ? _shapeEmoji(c.pins.first.pinShape) : '',
          pixelRatio: pixelRatio,
        );
      }),
    );

    if (!mounted) return;

    final options = List.generate(
      clusters.length,
      (i) => PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(clusters[i].lng, clusters[i].lat),
        ),
        image: images[i],
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
      ),
    );

    if (options.isEmpty) return;
    final created = await _pinManager!.createMulti(options);

    for (var i = 0; i < created.length; i++) {
      final annotation = created[i];
      if (annotation == null) continue;
      final id = annotation.id;
      final cluster = clusters[i];
      // 국가 클러스터는 항상 줌인 (지구본 모드에서 핀 상세 안 띄움)
      if (cluster.countryCode != null) {
        _clusterIds[id] = (cluster.lat, cluster.lng);
      } else if (cluster.pins.length == 1) {
        _pinAnnotationIds[id] = cluster.pins.first.id;
      } else {
        _clusterIds[id] = (cluster.lat, cluster.lng);
      }
    }

    await _polylineManager!.deleteAll();
  }

  void _scheduleUpdate(List<PinModel> pins) {
    _updateTimer?.cancel();
    _updateTimer = Timer(
      const Duration(milliseconds: 300),
      () => _updateMarkers(pins),
    );
  }

  // ─── 현재 위치 ────────────────────────────────────────────────────────────

  Future<void> _moveToCurrentLocation() async {
    HapticFeedback.lightImpact();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    if (_isGlobeMode) {
      // 지구본 모드: 마지막 알려진 위치로 즉시 전환 (GPS 대기 없음)
      final last = await Geolocator.getLastKnownPosition();
      await _exitGlobeMode(
        lat: last?.latitude ?? 37.5665,
        lng: last?.longitude ?? 126.9780,
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1200),
      );

      final pr = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;
      final dot = await _buildLocationBitmap(pr);
      await _locationManager?.deleteAll();
      await _locationManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(pos.longitude, pos.latitude)),
          image: dot,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (_) {}
  }

  // ─── 지구본 모드 ──────────────────────────────────────────────────────────

  Future<void> _enterGlobeMode() async {
    if (_isGlobeMode || _isGlobeTransitioning || _mapboxMap == null) return;
    // setState 없이 직접 설정 — 카메라 리스너에서만 사용
    _isGlobeTransitioning = true;

    HapticFeedback.mediumImpact();

    final state = await _mapboxMap!.getCameraState();
    // flyTo future가 애니메이션 완료 전에 resolve될 수 있으므로 await하지 않음
    _mapboxMap!.flyTo(
      CameraOptions(
        center: state.center,
        zoom: _kGlobeTargetZoom,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 2200),
    );

    // 애니메이션 실제 완료까지 대기 (duration + 200ms 여유)
    await Future.delayed(const Duration(milliseconds: 2400));

    if (mounted) {
      setState(() {
        _isGlobeMode = true;
        _isGlobeTransitioning = false;
        _globePanelExpanded = false;
      });
      _scheduleUpdate(ref.read(filteredPinsProvider));
    }
  }

  Future<void> _exitGlobeMode({double? lat, double? lng}) async {
    if (!_isGlobeMode || _isGlobeTransitioning || _mapboxMap == null) return;

    setState(() {
      _isGlobeMode = false;
      _isGlobeTransitioning = true;
    });

    HapticFeedback.mediumImpact();

    // flyTo future가 애니메이션 완료 전에 resolve될 수 있으므로 await하지 않음
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng ?? 126.9780, lat ?? 37.5665)),
        zoom: 11.0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 1400),
    );

    // 애니메이션 실제 완료까지 대기 (duration + 100ms 여유)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _isGlobeTransitioning = false);
      _scheduleUpdate(ref.read(filteredPinsProvider));
    }
  }

  // ─── 경로 모드 ────────────────────────────────────────────────────────────

  void _onPolylineTap() {
    if (_routeMode) {
      _deactivateRoute();
    } else {
      _showRouteDateSheet(context);
    }
  }

  void _showRouteDateSheet(BuildContext ctx) {
    final pins = ref.read(filteredPinsProvider);
    showAppSheet<void>(
      ctx,
      builder: (_) => _RouteDateSheet(
        pins: pins,
        onSelect: (datePins, label) {
          Navigator.of(ctx).pop();
          _activateRoute(datePins, label);
        },
      ),
    );
  }

  Future<void> _activateRoute(List<PinModel> pins, String label) async {
    final sorted = [...pins]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _lastClusters = []; // stale cluster animation 방지
    setState(() {
      _routePins = sorted;
      _routeDate = label;
    });
    await _drawRoute(sorted);
    if (sorted.isEmpty || _mapboxMap == null) return;

    if (sorted.length == 1) {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              sorted.first.longitude,
              sorted.first.latitude,
            ),
          ),
          zoom: _zoom < 12 ? 13.0 : _zoom,
        ),
        MapAnimationOptions(duration: 800),
      );
    } else {
      // 모든 핀이 화면에 들어오도록 bounds fit
      final lats = sorted.map((p) => p.latitude);
      final lngs = sorted.map((p) => p.longitude);
      final minLat = lats.reduce((a, b) => a < b ? a : b);
      final maxLat = lats.reduce((a, b) => a > b ? a : b);
      final minLng = lngs.reduce((a, b) => a < b ? a : b);
      final maxLng = lngs.reduce((a, b) => a > b ? a : b);

      try {
        final camera = await _mapboxMap!.cameraForCoordinateBounds(
          CoordinateBounds(
            southwest: Point(coordinates: Position(minLng, minLat)),
            northeast: Point(coordinates: Position(maxLng, maxLat)),
            infiniteBounds: false,
          ),
          MbxEdgeInsets(
            top: 100,
            left: 60,
            bottom: 360, // 경로 패널 + 네비 바 공간 확보
            right: 60,
          ),
          null,
          null,
          null,
          null,
        );
        await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1200));
      } catch (_) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                (minLng + maxLng) / 2,
                (minLat + maxLat) / 2,
              ),
            ),
            zoom: 11.0,
          ),
          MapAnimationOptions(duration: 1000),
        );
      }
    }
  }

  void _deactivateRoute() {
    _lastClusters = []; // stale cluster animation 방지
    setState(() {
      _routePins = null;
      _routeDate = '';
    });
    _updateMarkers(ref.read(filteredPinsProvider));
  }

  Future<void> _drawRoute(List<PinModel> pins) async {
    if (!_mapReady || _pinManager == null) return;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // 지도 테마별 경로 색상
    final style = ref.read(mapStyleProvider);
    final (lineColorInt, markerBg, markerText, markerBorder) = switch (style) {
      MapStyleOption.satellite => (
        const Color(0xFFFFFFFF).toARGB32(),
        Colors.white,
        const Color(0xFF1C1C1E),
        const Color(0xFF1C1C1E),
      ),
      MapStyleOption.dark => (
        AppColors.primary.toARGB32(),
        AppColors.primary,
        Colors.white,
        Colors.white,
      ),
      MapStyleOption.outdoors => (
        const Color(0xFF1565C0).toARGB32(),
        const Color(0xFF1565C0),
        Colors.white,
        Colors.white,
      ),
      MapStyleOption.light || MapStyleOption.streets => (
        AppColors.primaryDark.toARGB32(),
        AppColors.primaryDark,
        Colors.white,
        Colors.white,
      ),
      _ => (
        // standard
        AppColors.primaryDark.toARGB32(),
        AppColors.primary,
        Colors.white,
        Colors.white,
      ),
    };

    await _pinManager!.deleteAll();
    await _polylineManager!.deleteAll();
    _pinAnnotationIds.clear();
    _clusterIds.clear();

    if (pins.isEmpty) return;

    // 번호 마커 생성
    final images = await Future.wait(
      pins.asMap().entries.map(
        (e) => _buildNumberedMarkerBitmap(
          e.key + 1,
          pixelRatio,
          bgColor: markerBg,
          textColor: markerText,
          borderColor: markerBorder,
        ),
      ),
    );
    final pointOptions = pins
        .asMap()
        .entries
        .map(
          (e) => PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(e.value.longitude, e.value.latitude),
            ),
            image: images[e.key],
            iconSize: 1.0,
            iconAnchor: IconAnchor.CENTER,
          ),
        )
        .toList();
    final created = await _pinManager!.createMulti(pointOptions);
    for (var i = 0; i < created.length; i++) {
      if (created[i] != null) _pinAnnotationIds[created[i]!.id] = pins[i].id;
    }

    // 폴리라인 연결 (실선; 점선은 LineLayer Style API 필요)
    if (pins.length >= 2) {
      await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: pins
                .map((p) => Position(p.longitude, p.latitude))
                .toList(),
          ),
          lineColor: lineColorInt,
          lineWidth: 4.5,
          lineOpacity: 0.9,
        ),
      );
    }
  }

  // ─── + 버튼: 현재 위치에서 핀 생성 ────────────────────────────────────────

  Future<void> _createPinAtCurrentLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      showAppSheet<void>(
        context,
        builder: (sheetCtx) => PinCreateSheet(
          location: ll.LatLng(pos.latitude, pos.longitude),
          onClose: () => Navigator.of(sheetCtx).pop(),
          onSaved: () => Navigator.of(sheetCtx).pop(),
        ),
      );
    } catch (_) {}
  }

  // ─── 지도 스타일 변경 ──────────────────────────────────────────────────────

  Future<void> _applyMapStyle(MapStyleOption style) async {
    if (_mapboxMap == null) return;
    final uri = switch (style) {
      MapStyleOption.standard => MapboxStyles.STANDARD,
      MapStyleOption.satellite => MapboxStyles.SATELLITE_STREETS,
      MapStyleOption.outdoors => MapboxStyles.OUTDOORS,
      MapStyleOption.dark => MapboxStyles.DARK,
      MapStyleOption.light => 'mapbox://styles/mapbox/light-v11',
      MapStyleOption.streets => 'mapbox://styles/mapbox/streets-v12',
    };
    await _mapboxMap!.style.setStyleURI(uri);
    if (style == MapStyleOption.standard) {
      await _mapboxMap!.style.setProjection(
        StyleProjection(name: StyleProjectionName.globe),
      );
    }
  }

  // ─── 지도 탭 핸들러 ──────────────────────────────────────────────────────

  void _onMapTap(MapContentGestureContext ctx) {
    if (_mapboxMap == null || _isGlobeTransitioning) return;

    final lat = ctx.point.coordinates.lat.toDouble();
    final lng = ctx.point.coordinates.lng.toDouble();

    if (_isGlobeMode) {
      _exitGlobeMode(lat: lat, lng: lng);
      return;
    }

    if (_zoom < 4) return;

    showAppSheet<void>(
      context,
      builder: (_) => PinCreateSheet(
        location: ll.LatLng(lat, lng),
        onClose: () => Navigator.of(context).pop(),
        onSaved: () => Navigator.of(context).pop(),
      ),
    );
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

  // ─── 지도 생성 콜백 ───────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // 초기 카메라 위치 설정 (viewport prop 대신 여기서 한 번만)
    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(126.9780, 37.5665)),
        zoom: 13.0,
        pitch: 0,
        bearing: 0,
      ),
    );

    // 거리 스케일바 숨기기
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    await mapboxMap.style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );

    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _pinManager = await mapboxMap.annotations.createPointAnnotationManager();
    _locationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    _tapSubscription = _pinManager!.tapEvents(
      onTap: (annotation) {
        final pinId = _pinAnnotationIds[annotation.id];
        if (pinId != null) {
          if (_isGlobeMode || _isGlobeTransitioning) return;
          HapticFeedback.lightImpact();
          // showGeneralDialog로 슬라이드+페이드 팝업
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: '',
            barrierColor: Colors.black.withValues(alpha: 0.18),
            transitionDuration: const Duration(milliseconds: 380),
            pageBuilder: (ctx, _, _) => Stack(
              children: [
                PinDetailSheet(
                  pinId: pinId,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            transitionBuilder: (_, anim, _, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                    ),
                child: child,
              ),
            ),
          );
          return;
        }
        final center = _clusterIds[annotation.id];
        if (center != null) {
          HapticFeedback.lightImpact();
          if (_isGlobeMode) {
            _exitGlobeMode(lat: center.$1, lng: center.$2);
            return;
          }
          _mapboxMap?.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(center.$2, center.$1)),
              zoom: _zoom + 2,
            ),
            MapAnimationOptions(duration: 500),
          );
        }
      },
    );

    setState(() => _mapReady = true);

    final pins = ref.read(filteredPinsProvider);
    await _updateMarkers(pins);
  }

  // ─── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allPins = ref.watch(pinsProvider);

    ref.listen(filteredPinsProvider, (_, pins) {
      _scheduleUpdate(pins);
    });

    ref.listen(triggerCreatePinProvider, (_, triggered) {
      if (triggered) {
        ref.read(triggerCreatePinProvider.notifier).state = false;
        _createPinAtCurrentLocation();
      }
    });

    ref.listen(mapStyleProvider, (prev, next) {
      if (prev != next) _applyMapStyle(next);
    });

    final currentStyle = ref.watch(mapStyleProvider);
    final styleUri = switch (currentStyle) {
      MapStyleOption.standard => MapboxStyles.STANDARD,
      MapStyleOption.satellite => MapboxStyles.SATELLITE_STREETS,
      MapStyleOption.outdoors => MapboxStyles.OUTDOORS,
      MapStyleOption.dark => MapboxStyles.DARK,
      MapStyleOption.light => 'mapbox://styles/mapbox/light-v11',
      MapStyleOption.streets => 'mapbox://styles/mapbox/streets-v12',
    };

    final bool controlsVisible = !_isGlobeMode && !_isGlobeTransitioning;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_isGlobeMode || _isGlobeTransitioning)
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Mapbox 지도 ───────────────────────────────────────────────
            MapWidget(
              styleUri: styleUri,
              onMapCreated: _onMapCreated,
              onCameraChangeListener: (data) {
                final newZoom = data.cameraState.zoom;
                // 카메라 센터 추적 (Nebulous 오버레이 Mercator 투영용)
                final center = data.cameraState.center.coordinates;
                _cameraCenterLat = center.lat.toDouble();
                _cameraCenterLng = center.lng.toDouble();
                // 전환 중엔 setState·마커 업데이트 없이 zoom 값만 갱신
                if (_isGlobeTransitioning) {
                  _zoom = newZoom;
                  return;
                }
                if ((newZoom - _zoom).abs() > 0.15) {
                  setState(() => _zoom = newZoom);
                  _scheduleUpdate(
                    _currentPins.isEmpty
                        ? ref.read(filteredPinsProvider)
                        : _currentPins,
                  );
                }
                // 줌 기반 지구본 모드 자동 전환
                if (!_isGlobeMode && newZoom < _kGlobeEnterZoom) {
                  _enterGlobeMode();
                } else if (_isGlobeMode && newZoom > _kGlobeExitZoom) {
                  setState(() => _isGlobeMode = false);
                }
              },
              onTapListener: _onMapTap, // ignore: deprecated_member_use
            ),

            // ── 일반 지도 컨트롤 ─────────────────────────────────────────
            AnimatedOpacity(
              opacity: controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 280),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: _MapControls(
                  onGlobeTap: _enterGlobeMode,
                  onLayerTap: () => _showLayerSheet(context, ref),
                  onFilterTap: () => setState(() => _showFilterSheet = true),
                  onPolylineTap: _onPolylineTap,
                  routeActive: _routeMode,
                  isExpanded: _controlsExpanded,
                  onToggle: () =>
                      setState(() => _controlsExpanded = !_controlsExpanded),
                ),
              ),
            ),

            // ── 현재 위치 버튼 (우측 하단) ───────────────────────────────
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 10,
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 280),
                child: IgnorePointer(
                  ignoring: !controlsVisible,
                  child: GestureDetector(
                    onTap: _moveToCurrentLocation,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 22,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 지구본 모드: 하단 패널 ────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_isGlobeMode,
                child: AnimatedOpacity(
                  opacity: _isGlobeMode ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: _GlobeBottomPanel(
                    pinCount: allPins.length,
                    isExpanded: _globePanelExpanded,
                    onExitGlobeMode: _exitGlobeMode,
                    onGoToCurrentLocation: _moveToCurrentLocation,
                    onToggle: () => setState(
                      () => _globePanelExpanded = !_globePanelExpanded,
                    ),
                  ),
                ),
              ),
            ),

            // ── Nebulous 클러스터 애니메이션 오버레이 ──────────────────────
            if (_showClusterAnim)
              Positioned.fill(
                child: ClusterAnimOverlay(
                  prevItems: _animPrev,
                  nextItems: _animNext,
                  zoom: _zoom,
                  centerLat: _cameraCenterLat,
                  centerLng: _cameraCenterLng,
                  onDone: () {
                    if (mounted) setState(() => _showClusterAnim = false);
                  },
                ),
              ),

            // ── 경로 패널 (플로팅 카드, 네비게이션 바 위에 위치) ──────────
            if (_routeMode)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: _RoutePanel(
                  pins: _routePins!,
                  dateLabel: _routeDate,
                  onClose: _deactivateRoute,
                  onSave: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('동선이 저장되었어요 ✨'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      duration: const Duration(seconds: 2),
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

class _MapControls extends StatelessWidget {
  final VoidCallback onGlobeTap;
  final VoidCallback onLayerTap;
  final VoidCallback onFilterTap;
  final VoidCallback onPolylineTap;
  final VoidCallback onToggle;
  final bool routeActive;
  final bool isExpanded;

  const _MapControls({
    required this.onGlobeTap,
    required this.onLayerTap,
    required this.onFilterTap,
    required this.onPolylineTap,
    required this.onToggle,
    this.routeActive = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 항상 보이는 버튼: 경로 ─────────────────────────────────
            GestureDetector(
              onTap: onPolylineTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: routeActive
                          ? AppColors.primary
                          : context.glassBtnBg,
                      shape: BoxShape.circle,
                      border: routeActive
                          ? null
                          : Border.all(color: context.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: routeActive
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: routeActive ? 14 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      routeActive ? Icons.close_rounded : Icons.route_rounded,
                      size: 20,
                      color: routeActive ? Colors.white : context.labelColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── 항상 보이는 버튼: 필터 ─────────────────────────────────
            GlassButton(icon: Icons.tune, onTap: onFilterTap, size: 44),
            const SizedBox(height: 10),

            // ── 토글 버튼 ───────────────────────────────────────────────
            GestureDetector(
              onTap: onToggle,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.glassBtnBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: context.labelColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 슬라이드 펼침: 지구본 + 지도 테마 ─────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                opacity: isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: isExpanded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          GlassButton(
                            icon: Icons.public_rounded,
                            onTap: onGlobeTap,
                            size: 44,
                          ),
                          const SizedBox(height: 10),
                          GlassButton(
                            icon: Icons.layers_outlined,
                            onTap: onLayerTap,
                            size: 44,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 지구본 모드 하단 패널 (슬라이드로 펼치기) ──────────────────────────────

class _GlobeBottomPanel extends StatelessWidget {
  final int pinCount;
  final bool isExpanded;
  final VoidCallback onExitGlobeMode;
  final VoidCallback onGoToCurrentLocation;
  final VoidCallback onToggle;

  const _GlobeBottomPanel({
    required this.pinCount,
    required this.isExpanded,
    required this.onExitGlobeMode,
    required this.onGoToCurrentLocation,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200 && !isExpanded) onToggle(); // 위로 스와이프 → 펼침
        if (v > 200 && isExpanded) onToggle(); // 아래로 스와이프 → 접음
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF080816).withValues(alpha: 0.88),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset + 24),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 드래그 핸들
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ── 펼쳐졌을 때만 보이는 내용 ──
                  if (isExpanded) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: const Center(
                            child: Text('📍', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pinCount개의 기억',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '지도 위에 새겨진 당신의 이야기',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ] else
                    const SizedBox(height: 12),

                  // ── 버튼 행 (항상 표시) ──
                  Row(
                    children: [
                      _GlobePanelButton(
                        icon: Icons.my_location_rounded,
                        label: '현재 위치',
                        onTap: onGoToCurrentLocation,
                        isPrimary: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GlobePanelButton(
                          icon: Icons.map_rounded,
                          label: '지도 보기',
                          onTap: onExitGlobeMode,
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),

                  // ── 힌트 (펼쳤을 때만) ──
                  if (isExpanded) ...[
                    const SizedBox(height: 14),
                    Text(
                      '탭해서 확대  ·  핀치로 탐색',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 지구본 패널 버튼 ─────────────────────────────────────────────────────────

class _GlobePanelButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _GlobePanelButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  State<_GlobePanelButton> createState() => _GlobePanelButtonState();
}

class _GlobePanelButtonState extends State<_GlobePanelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isPrimary
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isPrimary ? AppColors.dark : Colors.white,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isPrimary ? AppColors.dark : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 경로 날짜 선택 시트 ──────────────────────────────────────────────────────

class _RouteDateSheet extends StatelessWidget {
  final List<PinModel> pins;
  final void Function(List<PinModel> pins, String label) onSelect;

  const _RouteDateSheet({required this.pins, required this.onSelect});

  // 날짜별 그루핑 (최신순)
  List<(String key, String label, List<PinModel> datePins)> _grouped() {
    final Map<String, List<PinModel>> byDate = {};
    for (final p in pins) {
      final k =
          '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(k, () => []).add(p);
    }
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return byDate.entries.map((e) {
      final d = DateTime.parse(e.key);
      final label = '${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
      return (e.key, label, e.value);
    }).toList()..sort((a, b) => b.$1.compareTo(a.$1));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: context.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '날짜별 경로 보기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.labelColor,
                  ),
                ),
                const Spacer(),
                Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
          const Divider(height: 1),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '핀이 없어요',
                style: TextStyle(color: context.subLabelColor),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (context, i) {
                  final (_, label, datePins) = groups[i];
                  final sorted = [...datePins]
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  return GestureDetector(
                    onTap: () => onSelect(sorted, label),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.labelColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${datePins.length}개',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.subLabelColor,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: bottomInset + 8),
        ],
      ),
    );
  }
}

// ─── 경로 플로팅 카드 ─────────────────────────────────────────────────────────

class _RoutePanel extends StatelessWidget {
  final List<PinModel> pins;
  final String dateLabel;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const _RoutePanel({
    required this.pins,
    required this.dateLabel,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 날짜 + 핀 수 + 닫기
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.labelColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${pins.length}개 장소',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.subLabelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: context.subLabelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 구분선
          Divider(height: 1, color: context.glassBorder),
          const SizedBox(height: 8),

          // 핀 목록 (최대 4줄, 스크롤 가능)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: pins.length,
              itemBuilder: (context, i) {
                final pin = pins[i];
                final isLast = i == pins.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                  child: Row(
                    children: [
                      // 번호 + 연결선
                      SizedBox(
                        width: 22,
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pin.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.labelColor,
                          ),
                        ),
                      ),
                      Text(
                        '${pin.createdAt.hour.toString().padLeft(2, '0')}:${pin.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.subLabelColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 저장 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '이 동선 저장하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    (
      MapStyleOption.standard,
      '기본',
      '표준 지도',
      [Color(0xFFE8E0D4), Color(0xFFD4C9A8)],
      Color(0xFF2A7A4F),
    ),
    (
      MapStyleOption.dark,
      '다크',
      '야간 모드',
      [Color(0xFF1C1C2E), Color(0xFF0D0D1A)],
      Color(0xFF8B5CF6),
    ),
    (
      MapStyleOption.satellite,
      '위성',
      '항공 사진',
      [Color(0xFF1A3A2A), Color(0xFF0D2010)],
      Color(0xFF4ADE80),
    ),
    (
      MapStyleOption.outdoors,
      '야외',
      '등산·하이킹',
      [Color(0xFF8DC26A), Color(0xFF3A7A30)],
      Color(0xFFFFFFFF),
    ),
    (
      MapStyleOption.light,
      '라이트',
      '밝은 모드',
      [Color(0xFFF8F5EE), Color(0xFFE8E0D0)],
      Color(0xFF374151),
    ),
    (
      MapStyleOption.streets,
      '스트리트',
      '도로 중심',
      [Color(0xFFF5F0E8), Color(0xFFD9C9A0)],
      Color(0xFF1565C0),
    ),
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
                      color: isActive
                          ? AppColors.primary
                          : context.glassBorder,
                      width: isActive ? 2.5 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
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
                        // 그라디언트 배경
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
                        // 미니 도로 장식 (격자 패턴 느낌)
                        Positioned(
                          bottom: 28,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Container(height: 1.5, color: accentColor.withValues(alpha: 0.35)),
                              const SizedBox(height: 10),
                              Container(height: 1, color: accentColor.withValues(alpha: 0.2)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          bottom: 28,
                          left: 30,
                          child: Container(width: 1.5, color: accentColor.withValues(alpha: 0.2)),
                        ),
                        // 텍스트 영역
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
                        // 활성 체크
                        if (isActive)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.5),
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
