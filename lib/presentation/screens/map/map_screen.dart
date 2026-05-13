import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/map/filter_sheet.dart';
import '../../widgets/map/pin_create_sheet.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ─── 클러스터 모델 ─────────────────────────────────────────────────────────────

class _Cluster {
  final List<PinModel> pins;
  final double lat;
  final double lng;
  const _Cluster({
    required this.pins,
    required this.lat,
    required this.lng,
  });
}

// 핀 카테고리 → 이모지
String _shapeEmoji(String shape) =>
    AppConstants.pinShapeEmojis[shape] ?? '📍';

// ─── 마커 비트맵 생성 (캐시됨) ────────────────────────────────────────────────

final _markerCache = <String, BitmapDescriptor>{};

Future<BitmapDescriptor> _buildMarkerBitmap({
  required bool isCluster,
  int count = 0,
  String emoji = '',
  required double pixelRatio,
}) async {
  final key = 'm_${isCluster}_${count}_${emoji}_${pixelRatio.toStringAsFixed(1)}';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  final logicalSize = isCluster ? 52.0 : 46.0;
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
      ..color = const Color(0x2A000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 6),
  );
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()..color = isCluster ? const Color(0xFF1C1C1E) : Colors.white,
  );
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = isCluster ? Colors.white.withAlpha(60) : const Color(0xFFD0D0D5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isCluster ? 2.5 : 1.5) * pixelRatio,
  );

  if (isCluster && count > 0) {
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
  final descriptor = BitmapDescriptor.bytes(bytes);
  _markerCache[key] = descriptor;
  return descriptor;
}

Future<BitmapDescriptor> _buildNumberedMarkerBitmap(
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
  final descriptor = BitmapDescriptor.bytes(bytes);
  _markerCache[key] = descriptor;
  return descriptor;
}

Future<BitmapDescriptor> _buildLocationBitmap(double pixelRatio) async {
  const key = 'location_marker';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

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
  final descriptor = BitmapDescriptor.bytes(bd!.buffer.asUint8List());
  _markerCache[key] = descriptor;
  return descriptor;
}

// ─── 다크 스타일 JSON ─────────────────────────────────────────────────────────

const _kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Marker? _locationMarker;

  // marker id → pinId (단일 핀) / center (클러스터)
  final Map<String, String> _pinIds = {};
  final Map<String, LatLng> _clusterCenters = {};

  double _zoom = 13.0;
  bool _showFilterSheet = false;
  bool _mapReady = false;

  Timer? _updateTimer;
  List<PinModel> _currentPins = [];

  // 경로 모드
  List<PinModel>? _routePins;
  String _routeDate = '';

  // 컨트롤 패널 펼침/접힘
  bool _controlsExpanded = true;
  bool get _routeMode => _routePins != null;

  static const _initialCamera = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 13.0,
  );

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── 클러스터 계산 ─────────────────────────────────────────────────────────

  List<_Cluster> _computeClusters(List<PinModel> pins, double zoom) {
    if (zoom >= 13) {
      return pins
          .map((p) => _Cluster(pins: [p], lat: p.latitude, lng: p.longitude))
          .toList();
    }

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

  Future<void> _updateMarkers(List<PinModel> pins) async {
    if (!_mapReady) return;

    _currentPins = pins;
    if (_routeMode) return;

    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    final clusters = _computeClusters(pins, _zoom);

    final descriptors = await Future.wait(
      clusters.map((c) => _buildMarkerBitmap(
            isCluster: c.pins.length > 1,
            count: c.pins.length,
            emoji: c.pins.length == 1 ? _shapeEmoji(c.pins.first.pinShape) : '',
            pixelRatio: pixelRatio,
          )),
    );

    if (!mounted) return;

    _pinIds.clear();
    _clusterCenters.clear();

    final newMarkers = <Marker>{};
    for (var i = 0; i < clusters.length; i++) {
      final c = clusters[i];
      final id = 'm_$i';
      if (c.pins.length == 1) {
        _pinIds[id] = c.pins.first.id;
      } else {
        _clusterCenters[id] = LatLng(c.lat, c.lng);
      }
      newMarkers.add(Marker(
        markerId: MarkerId(id),
        position: LatLng(c.lat, c.lng),
        icon: descriptors[i],
        anchor: const Offset(0.5, 0.5),
        onTap: () => _onMarkerTap(id),
      ));
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _onMarkerTap(String markerId) {
    final pinId = _pinIds[markerId];
    if (pinId != null) {
      HapticFeedback.lightImpact();
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
    final center = _clusterCenters[markerId];
    if (center != null) {
      HapticFeedback.lightImpact();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(center, _zoom + 2),
      );
    }
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

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15.0),
      );

      final pr = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;
      final dot = await _buildLocationBitmap(pr);
      if (!mounted) return;
      setState(() {
        _locationMarker = Marker(
          markerId: const MarkerId('current_location'),
          position: target,
          icon: dot,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 999,
        );
      });
    } catch (_) {}
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
    setState(() {
      _routePins = sorted;
      _routeDate = label;
    });
    await _drawRoute(sorted);
    if (sorted.isEmpty || _mapController == null) return;

    if (sorted.length == 1) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(sorted.first.latitude, sorted.first.longitude),
          _zoom < 12 ? 13.0 : _zoom,
        ),
      );
    } else {
      final lats = sorted.map((p) => p.latitude);
      final lngs = sorted.map((p) => p.longitude);
      final minLat = lats.reduce((a, b) => a < b ? a : b);
      final maxLat = lats.reduce((a, b) => a > b ? a : b);
      final minLng = lngs.reduce((a, b) => a < b ? a : b);
      final maxLng = lngs.reduce((a, b) => a > b ? a : b);

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80,
        ),
      );
    }
  }

  void _deactivateRoute() {
    setState(() {
      _routePins = null;
      _routeDate = '';
      _polylines = {};
    });
    _updateMarkers(ref.read(filteredPinsProvider));
  }

  Future<void> _drawRoute(List<PinModel> pins) async {
    if (!_mapReady) return;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    final style = ref.read(mapStyleProvider);
    final (lineColor, markerBg, markerText, markerBorder) = switch (style) {
      MapStyleOption.satellite => (
        Colors.white,
        Colors.white,
        const Color(0xFF1C1C1E),
        const Color(0xFF1C1C1E),
      ),
      MapStyleOption.dark => (
        AppColors.primary,
        AppColors.primary,
        Colors.white,
        Colors.white,
      ),
      MapStyleOption.outdoors => (
        const Color(0xFF1565C0),
        const Color(0xFF1565C0),
        Colors.white,
        Colors.white,
      ),
      MapStyleOption.light || MapStyleOption.streets => (
        AppColors.primaryDark,
        AppColors.primaryDark,
        Colors.white,
        Colors.white,
      ),
      _ => (
        AppColors.primaryDark,
        AppColors.primary,
        Colors.white,
        Colors.white,
      ),
    };

    if (pins.isEmpty) {
      setState(() {
        _markers = {};
        _polylines = {};
      });
      return;
    }

    final descriptors = await Future.wait(
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

    if (!mounted) return;

    _pinIds.clear();
    _clusterCenters.clear();

    final newMarkers = <Marker>{};
    for (var i = 0; i < pins.length; i++) {
      final id = 'route_$i';
      _pinIds[id] = pins[i].id;
      newMarkers.add(Marker(
        markerId: MarkerId(id),
        position: LatLng(pins[i].latitude, pins[i].longitude),
        icon: descriptors[i],
        anchor: const Offset(0.5, 0.5),
        onTap: () => _onMarkerTap(id),
      ));
    }

    final newPolylines = <Polyline>{};
    if (pins.length >= 2) {
      newPolylines.add(Polyline(
        polylineId: const PolylineId('route_line'),
        points: pins.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        color: lineColor,
        width: 5,
      ));
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });
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

  // ─── 지도 스타일 적용 ──────────────────────────────────────────────────────

  (MapType, String?) _styleFor(MapStyleOption style) {
    switch (style) {
      case MapStyleOption.satellite:
        return (MapType.hybrid, null);
      case MapStyleOption.outdoors:
        return (MapType.terrain, null);
      case MapStyleOption.dark:
        return (MapType.normal, _kDarkMapStyle);
      case MapStyleOption.standard:
      case MapStyleOption.light:
      case MapStyleOption.streets:
        return (MapType.normal, null);
    }
  }

  // ─── 지도 탭 핸들러 ──────────────────────────────────────────────────────

  void _onMapTap(LatLng pos) {
    if (_zoom < 4) return;
    showAppSheet<void>(
      context,
      builder: (_) => PinCreateSheet(
        location: ll.LatLng(pos.latitude, pos.longitude),
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

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    setState(() => _mapReady = true);
    final pins = ref.read(filteredPinsProvider);
    await _updateMarkers(pins);
  }

  // ─── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen(filteredPinsProvider, (_, pins) {
      _scheduleUpdate(pins);
    });

    ref.listen(triggerCreatePinProvider, (_, triggered) {
      if (triggered) {
        ref.read(triggerCreatePinProvider.notifier).state = false;
        _createPinAtCurrentLocation();
      }
    });

    final currentStyle = ref.watch(mapStyleProvider);
    final (mapType, styleJson) = _styleFor(currentStyle);

    final allMarkers = <Marker>{
      ..._markers,
      ?_locationMarker,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Google 지도 ─────────────────────────────────────────────────
            GoogleMap(
              initialCameraPosition: _initialCamera,
              mapType: mapType,
              style: styleJson,
              markers: allMarkers,
              polylines: _polylines,
              onMapCreated: _onMapCreated,
              onTap: _onMapTap,
              onCameraMove: (pos) {
                final newZoom = pos.zoom;
                if ((newZoom - _zoom).abs() > 0.15) {
                  _zoom = newZoom;
                  _scheduleUpdate(
                    _currentPins.isEmpty
                        ? ref.read(filteredPinsProvider)
                        : _currentPins,
                  );
                }
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),

            // ── 지도 컨트롤 ──────────────────────────────────────────────
            _MapControls(
              onLayerTap: () => _showLayerSheet(context, ref),
              onFilterTap: () => setState(() => _showFilterSheet = true),
              onPolylineTap: _onPolylineTap,
              routeActive: _routeMode,
              isExpanded: _controlsExpanded,
              onToggle: () =>
                  setState(() => _controlsExpanded = !_controlsExpanded),
            ),

            // ── 현재 위치 버튼 (우측 하단) ────────────────────────────────
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 10,
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

            // ── 경로 패널 ────────────────────────────────────────────────
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
  final VoidCallback onLayerTap;
  final VoidCallback onFilterTap;
  final VoidCallback onPolylineTap;
  final VoidCallback onToggle;
  final bool routeActive;
  final bool isExpanded;

  const _MapControls({
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
            // 경로 버튼
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

            // 필터 버튼
            GlassButton(icon: Icons.tune, onTap: onFilterTap, size: 44),
            const SizedBox(height: 10),

            // 토글 버튼
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

            // 펼침: 레이어
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

// ─── 경로 날짜 선택 시트 ──────────────────────────────────────────────────────

class _RouteDateSheet extends StatelessWidget {
  final List<PinModel> pins;
  final void Function(List<PinModel> pins, String label) onSelect;

  const _RouteDateSheet({required this.pins, required this.onSelect});

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
          Divider(height: 1, color: context.glassBorder),
          const SizedBox(height: 8),
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
