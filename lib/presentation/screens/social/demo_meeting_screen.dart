import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../application/providers/meeting_provider.dart';
import '../../../application/providers/pin_provider.dart'
    show mapStyleProvider, MapStyleOption;
import '../../../core/theme/app_theme.dart';
import '../../widgets/meeting/meeting_bottom_sheet.dart';
import '../../widgets/meeting/meeting_overlay.dart';

// 지도 카메라
const _kCenterLng = 126.9700;
const _kCenterLat = 37.5530;

class DemoMeetingScreen extends ConsumerStatefulWidget {
  const DemoMeetingScreen({super.key});

  @override
  ConsumerState<DemoMeetingScreen> createState() => _DemoMeetingScreenState();
}

class _DemoMeetingScreenState extends ConsumerState<DemoMeetingScreen> {
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    // demo meeting이 없으면 진입 즉시 주입
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(meetingProvider);
      if (current.activeMeeting == null) {
        ref.read(meetingProvider.notifier).injectDemoMeeting();
      }
    });
  }

  @override
  void dispose() {
    // 데모 종료 시 state 정리
    final current = ref.read(meetingProvider);
    if (current.activeMeeting?.id.startsWith('demo_') == true) {
      ref.read(meetingProvider.notifier).clearDemoMeeting();
    }
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.location
        .updateSettings(LocationComponentSettings(enabled: false));
    if (mounted) setState(() => _mapReady = true);
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

    final sz = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    // 고정 화면 좌표 — Mapbox 배경 위에 오버레이 (비율 기반)
    final myPos = Offset(sz.width * 0.26, sz.height * 0.56);
    final friendPos = Offset(sz.width * 0.72, sz.height * 0.25);

    return Scaffold(
      backgroundColor: const Color(0xFF050B1A),
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
          ),

          // ── 미팅 오버레이 (지도 로드 + meeting 준비 시) ─────────────
          if (_mapReady && meeting != null)
            Positioned.fill(
              child: IgnorePointer(
                child: MeetingMapOverlay(
                  myScreenPos: myPos,
                  friendScreenPos: friendPos,
                  meeting: meeting,
                  distanceMeters: meetingState.distanceMeters ?? 4800,
                  etaSeconds: meetingState.etaSeconds,
                ),
              ),
            ),

          // ── 목적지 마커 ─────────────────────────────────────────────
          if (_mapReady && meeting != null)
            Positioned(
              left: sz.width * 0.45,
              top: sz.height * 0.48,
              child: _DestinationMarker(name: meeting.targetName ?? '목적지'),
            ),

          // ── 뒤로가기 ────────────────────────────────────────────────
          Positioned(
            top: topPad.clamp(0.0, 62.0) + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF12082A).withValues(alpha: 0.90),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ── 상단 약속 뱃지 ───────────────────────────────────────────
          if (meeting != null)
            Positioned(
              top: topPad.clamp(0.0, 62.0) + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12082A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          const Color(0xFFA78BFA).withValues(alpha: 0.40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF8B5CF6).withValues(alpha: 0.25),
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
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${meeting.friendNickname ?? "친구"} 님과 약속 진행 중',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 하단 미팅 시트 ───────────────────────────────────────────
          if (meeting != null)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: MeetingBottomSheet(),
            ),

          // ── 로딩 상태 ────────────────────────────────────────────────
          if (!_mapReady || meeting == null)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF12082A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA78BFA)
                          .withValues(alpha: 0.30),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '지도 불러오는 중...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 목적지 마커 ──────────────────────────────────────────────────────────────

class _DestinationMarker extends StatelessWidget {
  final String name;
  const _DestinationMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0820).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 2,
          height: 10,
          color: const Color(0xFFF59E0B).withValues(alpha: 0.60),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFF59E0B),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
