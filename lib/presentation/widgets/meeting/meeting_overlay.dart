import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../data/models/meeting.dart';

// ─── 전체 미팅 오버레이 ────────────────────────────────────────────────────────
// Map screen Stack에 Positioned.fill로 삽입.
// myScreenPos / friendScreenPos: mapboxMap.pixelForCoordinate()로 얻은 화면 좌표.

class MeetingMapOverlay extends StatelessWidget {
  final Offset myScreenPos;
  final Offset friendScreenPos;
  final Meeting meeting;
  final double? distanceMeters;
  final int? etaMinutes;

  const MeetingMapOverlay({
    super.key,
    required this.myScreenPos,
    required this.friendScreenPos,
    required this.meeting,
    this.distanceMeters,
    this.etaMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final mid = Offset(
      (myScreenPos.dx + friendScreenPos.dx) / 2,
      (myScreenPos.dy + friendScreenPos.dy) / 2,
    );

    return IgnorePointer(
      child: Stack(
        children: [
          // ── 네온 고무줄 선 ──────────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _RubberBandPainter(
                from: myScreenPos,
                to: friendScreenPos,
              ),
            ),
          ),

          // ── 중간 ETA 배지 ──────────────────────────────────────────────────
          Positioned(
            left: mid.dx - 80,
            top: mid.dy - 22,
            child: _EtaBadge(
              meeting: meeting,
              distanceMeters: distanceMeters,
              etaMinutes: etaMinutes,
            ),
          ),

          // ── 친구 아바타 (Liquid Glass) ─────────────────────────────────────
          Positioned(
            left: friendScreenPos.dx - 44,
            top: friendScreenPos.dy - 104,
            child: _LiquidGlassAvatar(
              nickname: meeting.friendNickname ?? '친구',
              avatarUrl: meeting.friendAvatarUrl,
            ),
          ),

          // ── 내 아바타 ───────────────────────────────────────────────────────
          Positioned(
            left: myScreenPos.dx - 24,
            top: myScreenPos.dy - 56,
            child: const _MyAvatarMarker(),
          ),
        ],
      ),
    );
  }
}

// ─── 네온 고무줄 선 Painter ────────────────────────────────────────────────────

class _RubberBandPainter extends CustomPainter {
  final Offset from;
  final Offset to;

  const _RubberBandPainter({required this.from, required this.to});

  @override
  void paint(Canvas canvas, Size size) {
    // 외부 글로우 (넓은 블러)
    canvas.drawLine(
      from, to,
      Paint()
        ..color = const Color(0xFFD946EF).withValues(alpha: 0.18)
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12),
    );
    // 중간 글로우
    canvas.drawLine(
      from, to,
      Paint()
        ..color = const Color(0xFFA78BFA).withValues(alpha: 0.45)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );
    // 코어 라인 (그라디언트)
    final shader = ui.Gradient.linear(
      from, to,
      [const Color(0xFFA78BFA), const Color(0xFFD946EF)],
    );
    canvas.drawLine(
      from, to,
      Paint()
        ..shader = shader
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RubberBandPainter old) =>
      old.from != from || old.to != to;
}

// ─── ETA 배지 ─────────────────────────────────────────────────────────────────

class _EtaBadge extends StatelessWidget {
  final Meeting meeting;
  final double? distanceMeters;
  final int? etaMinutes;

  const _EtaBadge({
    required this.meeting,
    this.distanceMeters,
    this.etaMinutes,
  });

  String get _distLabel {
    final d = distanceMeters;
    if (d == null) return '';
    if (d < 1000) return '${d.round()}m';
    return '${(d / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0D30).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD946EF).withValues(alpha: 0.30),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            meeting.transitSvgPath,
            width: 14,
            height: 14,
            colorFilter: const ColorFilter.mode(
              Color(0xFFC084FC),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 5),
          if (etaMinutes != null)
            Text(
              '도착 $etaMinutes분 전',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Pretendard',
              ),
            )
          else if (_distLabel.isNotEmpty)
            Text(
              _distLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Pretendard',
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Liquid Glass 친구 아바타 마커 ─────────────────────────────────────────────

class _LiquidGlassAvatar extends StatelessWidget {
  final String nickname;
  final String? avatarUrl;

  const _LiquidGlassAvatar({required this.nickname, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer purple glow ring
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD946EF).withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 88,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Profile photo
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14.5),
                        ),
                        child: avatarUrl != null
                            ? Image.network(
                                avatarUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, _, _) =>
                                    _placeholderPhoto(),
                              )
                            : _placeholderPhoto(),
                      ),
                    ),
                    // Nickname
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D30).withValues(alpha: 0.72),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14.5),
                        ),
                      ),
                      child: Text(
                        nickname,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Pointer dot
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 3),
          decoration: const BoxDecoration(
            color: Color(0xFFD946EF),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _placeholderPhoto() => Container(
        color: const Color(0xFF2D1B5E),
        child: const Icon(Icons.person_rounded, color: Colors.white38, size: 36),
      );
}

// ─── 내 아바타 마커 ────────────────────────────────────────────────────────────

class _MyAvatarMarker extends StatelessWidget {
  const _MyAvatarMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A0D30),
            border: Border.all(
              color: const Color(0xFFA78BFA),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.50),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white70,
            size: 26,
          ),
        ),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 3),
          decoration: const BoxDecoration(
            color: Color(0xFF8B5CF6),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
