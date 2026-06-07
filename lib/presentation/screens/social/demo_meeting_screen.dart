import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../application/providers/meeting_provider.dart';
import '../../../application/providers/pin_provider.dart'
    show mapStyleProvider, MapStyleOption;
import '../../../core/theme/app_theme.dart';
import '../../widgets/meeting/meeting_bottom_sheet.dart';
import '../../widgets/meeting/meeting_overlay.dart';

// 지도 초기 카메라 (데모 미팅 중간 지점)
const _kCenterLng = 126.9700;
const _kCenterLat = 37.5530;

class DemoMeetingScreen extends ConsumerStatefulWidget {
  const DemoMeetingScreen({super.key});

  @override
  ConsumerState<DemoMeetingScreen> createState() => _DemoMeetingScreenState();
}

class _DemoMeetingScreenState extends ConsumerState<DemoMeetingScreen> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  Offset _myScreenPos = Offset.zero;
  Offset _friendScreenPos = Offset.zero;
  Timer? _posTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(meetingProvider);
      if (current.activeMeeting == null) {
        ref.read(meetingProvider.notifier).injectDemoMeeting();
      }
    });
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    final current = ref.read(meetingProvider);
    if (current.activeMeeting?.id.startsWith('demo_') == true) {
      ref.read(meetingProvider.notifier).clearDemoMeeting();
    }
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.location.updateSettings(LocationComponentSettings(enabled: false));
    if (mounted) setState(() => _mapReady = true);
    _schedulePositionUpdate();
  }

  void _schedulePositionUpdate() {
    _posTimer?.cancel();
    _posTimer = Timer(const Duration(milliseconds: 60), _updateScreenPositions);
  }

  Future<void> _updateScreenPositions() async {
    final map = _mapboxMap;
    if (map == null) return;
    final ms = ref.read(meetingProvider);
    final meeting = ms.activeMeeting;
    if (meeting == null) return;

    final myLat = ms.myLat ?? 37.5573;
    final myLng = ms.myLng ?? 126.9245;
    final friendLat = ms.friendLat ?? 37.5756;
    final friendLng = ms.friendLng ?? 127.0480;

    final mySc = await map.pixelForCoordinate(
        Point(coordinates: Position(myLng, myLat)));
    final friendSc = await map.pixelForCoordinate(
        Point(coordinates: Position(friendLng, friendLat)));

    if (mounted) {
      setState(() {
        _myScreenPos = Offset(mySc.x, mySc.y);
        _friendScreenPos = Offset(friendSc.x, friendSc.y);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingState = ref.watch(meetingProvider);
    final meeting = meetingState.activeMeeting;
    final currentStyle = ref.watch(mapStyleProvider);
    final isDark = currentStyle == MapStyleOption.dark ||
        (currentStyle == MapStyleOption.auto &&
            Theme.of(context).brightness == Brightness.dark);
    final styleUri = isDark ? MapboxStyles.DARK : MapboxStyles.STANDARD;

    final topPad = MediaQuery.of(context).padding.top;
    final primary = context.primaryColor;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // ── 실제 Mapbox 지도 ────────────────────────────────────────
          MapWidget(
            styleUri: styleUri,
            viewport: CameraViewportState(
              center: Point(coordinates: Position(_kCenterLng, _kCenterLat)),
              zoom: 12.5,
              pitch: 35,
              bearing: 0,
            ),
            onMapCreated: _onMapCreated,
            onCameraChangeListener: (_) {
              if (_mapReady) _schedulePositionUpdate();
            },
          ),

          // ── 미팅 오버레이 ────────────────────────────────────────────
          if (_mapReady && meeting != null)
            Positioned.fill(
              child: IgnorePointer(
                child: MeetingMapOverlay(
                  myScreenPos: _myScreenPos,
                  friendScreenPos: _friendScreenPos,
                  meeting: meeting,
                  distanceMeters: meetingState.distanceMeters ?? 4800,
                  etaSeconds: meetingState.etaSeconds,
                ),
              ),
            ),

          // ── 뒤로가기 버튼 ───────────────────────────────────────────
          Positioned(
            top: topPad.clamp(0.0, 62.0) + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.cardBg.withValues(alpha: 0.88),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: context.labelColor,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 상단 약속 상태 배너 ─────────────────────────────────────
          if (meeting != null)
            Positioned(
              top: topPad.clamp(0.0, 62.0) + 8,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: context.cardBg.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.18),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${meeting.friendNickname ?? "친구"} 님과 약속 진행 중',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.labelColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── 하단 미팅 시트 ───────────────────────────────────────────
          if (meeting != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              left: 0,
              right: 0,
              child: const MeetingBottomSheet(),
            ),

          // ── 로딩 상태 ────────────────────────────────────────────────
          if (!_mapReady || meeting == null)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.cardBg.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '지도 불러오는 중...',
                            style: TextStyle(
                              color: context.subLabelColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
