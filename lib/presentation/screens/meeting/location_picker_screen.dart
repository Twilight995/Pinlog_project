import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/theme/app_theme.dart';

// 선택 결과
class LocationPickResult {
  final double lat;
  final double lng;
  final String name;
  const LocationPickResult({
    required this.lat,
    required this.lng,
    required this.name,
  });
}

class LocationPickerScreen extends StatefulWidget {
  /// 이전에 선택된 위치 (편집 시 초기값)
  final LocationPickResult? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapboxMap? _mapboxMap;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // _viewport*: MapWidget 선언 위치 (초기값 고정 — 재선언 시 카메라 충돌 방지)
  late double _viewportLat;
  late double _viewportLng;
  // _center*: 현재 카메라 중심 (UI 표시 및 confirm 용, setState 없이 직접 업데이트)
  double _centerLat = 37.5665;
  double _centerLng = 126.9780;
  String _placeName = '위치를 선택하세요';
  bool _isSearching = false;
  bool _isReverseGeocoding = false;
  Timer? _rgTimer;
  Timer? _searchDebounce;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _viewportLat = widget.initial?.lat ?? 37.5665;
    _viewportLng = widget.initial?.lng ?? 126.9780;
    _centerLat = _viewportLat;
    _centerLng = _viewportLng;
    if (widget.initial != null) {
      _placeName = widget.initial!.name;
    }
  }

  @override
  void dispose() {
    _rgTimer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Mapbox 초기화 ──────────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.location.updateSettings(LocationComponentSettings(enabled: false));
    // 초기 위치 역지오코딩
    _scheduleReverseGeocode(_centerLat, _centerLng);
  }

  // ─── 카메라 이동 → 중심 좌표 업데이트 ────────────────────────────────────────
  // setState 없이 필드 직접 업데이트 → MapWidget viewport 재선언 없음 → 제스처 충돌 방지

  void _onCameraChange(CameraChangedEventData data) {
    final lat = data.cameraState.center.coordinates.lat.toDouble();
    final lng = data.cameraState.center.coordinates.lng.toDouble();
    if ((lat - _centerLat).abs() > 0.000001 ||
        (lng - _centerLng).abs() > 0.000001) {
      _centerLat = lat;
      _centerLng = lng;
      _scheduleReverseGeocode(lat, lng);
    }
  }

  // ─── 역지오코딩 (500ms 디바운스) ────────────────────────────────────────────

  void _scheduleReverseGeocode(double lat, double lng) {
    _rgTimer?.cancel();
    _rgTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isReverseGeocoding = true);
      try {
        final marks = await placemarkFromCoordinates(lat, lng);
        if (!mounted) return;
        if (marks.isNotEmpty) {
          final p = marks.first;
          // 유효한 첫 번째 이름 사용 (상세 → 광역 순)
          final candidates = [
            if (p.name != null && p.name!.isNotEmpty && p.name != p.street)
              p.name,
            p.thoroughfare,
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
          ].whereType<String>().where((s) => s.isNotEmpty).toList();
          setState(() => _placeName =
              candidates.isNotEmpty ? candidates.first : '선택한 위치');
        } else {
          setState(() => _placeName = '선택한 위치');
        }
      } catch (_) {
        if (mounted) setState(() => _placeName = '선택한 위치');
      } finally {
        if (mounted) setState(() => _isReverseGeocoding = false);
      }
    });
  }

  // ─── 장소 검색 ──────────────────────────────────────────────────────────────

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    setState(() { _isSearching = true; _searchError = null; });
    try {
      final locations = await locationFromAddress(query)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final lat = loc.latitude;
        final lng = loc.longitude;
        // 한국 범위 검증
        if (lat < 33.0 || lat > 39.0 || lng < 124.0 || lng > 132.0) {
          setState(() => _searchError = '국내 장소만 검색할 수 있어요.');
          return;
        }
        await _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: 16.0,
          ),
          MapAnimationOptions(duration: 900, startDelay: 0),
        );
        _centerLat = lat;
        _centerLng = lng;
        setState(() {
          _viewportLat = lat;
          _viewportLng = lng;
          _placeName = query;
        });
        _searchCtrl.clear();
      } else {
        setState(() => _searchError = '"$query" 위치를 찾을 수 없어요.');
      }
    } on TimeoutException {
      if (mounted) setState(() => _searchError = '검색 시간이 초과됐어요. 다시 시도해주세요.');
    } catch (_) {
      if (mounted) setState(() => _searchError = '검색 중 오류가 발생했어요.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      LocationPickResult(lat: _centerLat, lng: _centerLng, name: _placeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final primary = context.primaryColor;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // ── 지도 ────────────────────────────────────────────────────
          MapWidget(
            styleUri: Theme.of(context).brightness == Brightness.dark
                ? MapboxStyles.DARK
                : MapboxStyles.STANDARD,
            viewport: CameraViewportState(
              center: Point(
                  coordinates: Position(_viewportLng, _viewportLat)),
              zoom: 15.0,
              pitch: 0,
              bearing: 0,
            ),
            onMapCreated: _onMapCreated,
            onCameraChangeListener: _onCameraChange,
          ),

          // ── 중심 십자선 ─────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: primary,
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 20,
                  color: primary,
                ),
              ],
            ),
          ),

          // ── 상단 검색바 + 뒤로가기 ─────────────────────────────────
          Positioned(
            top: topPad + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // 뒤로가기
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.cardBg.withValues(alpha: 0.90),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: context.glassBorder, width: 1),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 17, color: context.labelColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 검색창
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.cardBg.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _focusNode.hasFocus
                                  ? primary.withValues(alpha: 0.50)
                                  : context.glassBorder,
                              width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search_rounded,
                                size: 18, color: context.subLabelColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _focusNode,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.labelColor,
                                  fontFamily: 'Pretendard',
                                ),
                                decoration: InputDecoration(
                                  hintText: '장소 검색 (예: 강남역 2번 출구)',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: context.subLabelColor,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: _search,
                              ),
                            ),
                            if (_isSearching)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: primary),
                                ),
                              )
                            else if (_searchCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchError = null);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Icon(Icons.close_rounded,
                                      size: 17, color: context.subLabelColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 검색 오류 ────────────────────────────────────────────────
          if (_searchError != null)
            Positioned(
              top: topPad + 60,
              left: 62,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.30)),
                ),
                child: Text(
                  _searchError!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF3B30),
                  ),
                ),
              ),
            ),

          // ── 하단 확인 바 ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      20, 16, 20, bottomPad.clamp(12.0, 40.0) + 12),
                  decoration: BoxDecoration(
                    color: context.cardBg.withValues(alpha: 0.94),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                          color: context.glassBorder, width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              size: 16, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            '선택된 위치',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.subLabelColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (_isReverseGeocoding) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: primary),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _placeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.labelColor,
                          fontFamily: 'Pretendard',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _placeName == '위치를 선택하세요' ||
                                  _placeName == '위치 확인 중...'
                              ? null
                              : _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: context.onPrimaryColor,
                            disabledBackgroundColor:
                                primary.withValues(alpha: 0.40),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            '이 위치로 선택',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
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
