import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class PinSuccessScreen extends ConsumerStatefulWidget {
  final String pinTitle;
  final String? locationLabel;
  final String categorySvgPath;
  final String categoryName;
  final String? emotion;
  final String? countryCode;

  const PinSuccessScreen({
    super.key,
    required this.pinTitle,
    required this.categorySvgPath,
    required this.categoryName,
    this.locationLabel,
    this.emotion,
    this.countryCode,
  });

  @override
  ConsumerState<PinSuccessScreen> createState() => _PinSuccessScreenState();
}

class _PinSuccessScreenState extends ConsumerState<PinSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── 핀 성장 (0%–58%) ─────────────────────────────────────────────────────
  late final Animation<double> _pinScale;
  late final Animation<double> _pinRise; // y offset: 55 → 0

  // ── 지면 파장 (0%–52%) ───────────────────────────────────────────────────
  late final Animation<double> _rings;

  // ── 씨앗 파티클 (28%–72%) ────────────────────────────────────────────────
  late final Animation<double> _sparks;

  // ── 정보 텍스트 등장 (60%–84%) ───────────────────────────────────────────
  late final Animation<double> _infoFade;
  late final Animation<double> _infoRise; // y offset: 20 → 0

  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pinScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.58, curve: Curves.easeOutBack),
      ),
    );
    _pinRise = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _rings = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.52, curve: Curves.easeOut),
    );
    _sparks = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.28, 0.72, curve: Curves.easeOut),
    );
    _infoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.60, 0.84, curve: Curves.easeOut),
    );
    _infoRise = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.60, 0.84, curve: Curves.easeOutCubic),
      ),
    );

    // 핀이 자리 잡는 순간 촉각 피드백
    _ctrl.addListener(() {
      if (!_hapticFired && _ctrl.value >= 0.58) {
        _hapticFired = true;
        HapticFeedback.lightImpact();
      }
    });

    HapticFeedback.mediumImpact();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _back(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _createAnother(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    Future.microtask(() {
      ref.read(triggerCreatePinProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.primaryColor;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C10),
        body: Stack(
          children: [
            // ── 지도 배경 ───────────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _MapBackgroundPainter(accent: accent),
              ),
            ),
            // ── 하단 페이드 오버레이 ────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 320,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE5080C10)],
                    stops: [0.0, 0.55],
                  ),
                ),
              ),
            ),

            // ── 본문 ────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 지도 영역 (핀이 자라나는 공간)
                    Expanded(
                      flex: 52,
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, _) => Stack(
                          alignment: Alignment.center,
                          children: [
                            // 파장 링
                            _RingWaves(
                              accent: accent,
                              progress: _rings.value,
                            ),
                            // 씨앗 파티클
                            _SparkleParticles(
                              accent: accent,
                              progress: _sparks.value,
                            ),
                            // 성장하는 핀
                            Transform.translate(
                              offset: Offset(0, _pinRise.value),
                              child: Transform.scale(
                                scale: _pinScale.value,
                                child: _PinMarker(
                                  accent: accent,
                                  svgPath: widget.categorySvgPath,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 정보 영역
                    Expanded(
                      flex: 48,
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, _) => Opacity(
                          opacity: _infoFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _infoRise.value),
                            child: _InfoContent(
                              accent: accent,
                              categoryName: widget.categoryName,
                              locationLabel: widget.locationLabel,
                              svgPath: widget.categorySvgPath,
                              pinTitle: widget.pinTitle,
                              emotion: widget.emotion,
                              countryCode: widget.countryCode,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 지도에서 보기 버튼
                    _PrimaryButton(
                      accent: accent,
                      onTap: () => _back(context),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _createAnother(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '또 다른 기억 심기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.35),
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 지도 배경 ──────────────────────────────────────────────────────────────────

class _MapBackgroundPainter extends CustomPainter {
  final Color accent;
  const _MapBackgroundPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);

    // 블록 (건물/구역)
    final blockPaint = Paint()
      ..color = const Color(0xFF111820)
      ..style = PaintingStyle.fill;

    final blockRects = [
      Rect.fromLTWH(size.width * 0.05, size.height * 0.08, size.width * 0.22, size.height * 0.14),
      Rect.fromLTWH(size.width * 0.32, size.height * 0.06, size.width * 0.18, size.height * 0.10),
      Rect.fromLTWH(size.width * 0.62, size.height * 0.10, size.width * 0.30, size.height * 0.16),
      Rect.fromLTWH(size.width * 0.10, size.height * 0.30, size.width * 0.15, size.height * 0.20),
      Rect.fromLTWH(size.width * 0.70, size.height * 0.34, size.width * 0.24, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.05, size.height * 0.58, size.width * 0.28, size.height * 0.12),
      Rect.fromLTWH(size.width * 0.60, size.height * 0.60, size.width * 0.32, size.height * 0.14),
    ];
    for (final r in blockRects) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), blockPaint);
    }

    // 도로
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.038)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    void line(Offset a, Offset b) => canvas.drawLine(a, b, roadPaint);

    // 수직 도로
    line(Offset(size.width * 0.30, 0), Offset(size.width * 0.30, size.height));
    line(Offset(size.width * 0.60, 0), Offset(size.width * 0.60, size.height));
    line(Offset(size.width * 0.78, 0), Offset(size.width * 0.78, size.height));
    // 수평 도로
    line(Offset(0, size.height * 0.26), Offset(size.width, size.height * 0.26));
    line(Offset(0, size.height * 0.54), Offset(size.width, size.height * 0.54));
    line(Offset(0, size.height * 0.72), Offset(size.width, size.height * 0.72));
    // 대각 도로
    roadPaint.strokeWidth = 0.8;
    final path = Path()
      ..moveTo(0, size.height * 0.40)
      ..cubicTo(
        size.width * 0.25, size.height * 0.40,
        size.width * 0.55, size.height * 0.34,
        size.width, size.height * 0.38,
      );
    canvas.drawPath(path, roadPaint);

    // 다른 핀들 (희미하게)
    final pinPaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final pinPositions = [
      Offset(size.width * 0.15, size.height * 0.18),
      Offset(size.width * 0.72, size.height * 0.15),
      Offset(size.width * 0.08, size.height * 0.44),
      Offset(size.width * 0.84, size.height * 0.42),
      Offset(size.width * 0.20, size.height * 0.65),
      Offset(size.width * 0.88, size.height * 0.24),
    ];
    for (int i = 0; i < pinPositions.length; i++) {
      final pos = pinPositions[i];
      final r = 3.5 + rng.nextDouble() * 2;
      canvas.drawCircle(pos, r, pinPaint..color = accent.withValues(alpha: 0.10 + rng.nextDouble() * 0.12));
    }
  }

  @override
  bool shouldRepaint(_MapBackgroundPainter old) => old.accent != accent;
}

// ─── 파장 링 ────────────────────────────────────────────────────────────────────

class _RingWaves extends StatelessWidget {
  final Color accent;
  final double progress; // 0 → 1

  const _RingWaves({required this.accent, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _RingPainter(accent: accent, progress: progress),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color accent;
  final double progress;
  const _RingPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    // 3개 링, 각각 약간의 지연 효과
    for (int i = 0; i < 3; i++) {
      final delayed = ((progress - i * 0.12).clamp(0.0, 1.0));
      if (delayed <= 0) continue;
      final radius = delayed * (60.0 + i * 18.0);
      final opacity = (1 - delayed) * (0.55 - i * 0.12);
      if (opacity <= 0) continue;
      paint
        ..color = accent.withValues(alpha: opacity)
        ..strokeWidth = 1.2 - i * 0.25;
      canvas.drawCircle(center, radius, paint);
    }

    // 중심 점 (씨앗)
    if (progress < 0.8) {
      final dotOpacity = (1 - progress / 0.8).clamp(0.0, 1.0) * 0.6;
      canvas.drawCircle(
        center,
        3.5,
        Paint()..color = accent.withValues(alpha: dotOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent;
}

// ─── 씨앗 파티클 ────────────────────────────────────────────────────────────────

class _SparkleParticles extends StatelessWidget {
  final Color accent;
  final double progress;
  const _SparkleParticles({required this.accent, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(180, 180),
      painter: _SparklePainter(accent: accent, progress: progress),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color accent;
  final double progress;
  const _SparklePainter({required this.accent, required this.progress});

  // 파티클 방향 (normalized) — 새싹이 퍼지는 방향 (위쪽 집중)
  static const _dirs = [
    Offset(-0.90, -1.10), Offset(0, -1.40), Offset(0.90, -1.10),
    Offset(-1.30, -0.50), Offset(1.30, -0.50),
    Offset(-0.70,  0.60), Offset(0.70,  0.60),
    Offset(-1.10, -1.40), Offset(1.10, -1.40),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    const maxDist = 62.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _dirs.length; i++) {
      final dist = progress * maxDist;
      final pos = center + Offset(_dirs[i].dx * dist, _dirs[i].dy * dist);
      final opacity = (1 - progress) * 0.70;
      final r = (3.2 - progress * 2.4).clamp(0.4, 3.2);
      if (opacity < 0.04) continue;
      // 짝수 파티클은 흰색, 홀수는 accent
      paint.color = (i % 2 == 0 ? accent : Colors.white).withValues(alpha: opacity);
      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.progress != progress || old.accent != accent;
}

// ─── 핀 마커 ────────────────────────────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  final Color accent;
  final String svgPath;
  const _PinMarker({required this.accent, required this.svgPath});

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    final lighter = Color.lerp(accent, Colors.white, 0.32)!;
    final darker  = Color.lerp(accent, Colors.black, 0.08)!;
    final body    = HSLColor.fromColor(accent)
        .withLightness(0.11)
        .withSaturation(
            (HSLColor.fromColor(accent).saturation * 0.50).clamp(0.0, 1.0))
        .toColor();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 글로우
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.50),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          // 그라디언트 테두리
          ShaderMask(
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [lighter, darker],
            ).createShader(r),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          // 바디
          Container(
            width: size - 5,
            height: size - 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: body),
          ),
          // 스펙큘러
          Positioned(
            top: size * 0.16,
            left: size * 0.30,
            child: Container(
              width: size * 0.34,
              height: size * 0.13,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          // 아이콘
          if (svgPath.isNotEmpty)
            SvgPicture.asset(
              svgPath,
              width: size * 0.50,
              height: size * 0.50,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          // 체크 배지
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                border: Border.all(
                  color: const Color(0xFF080C10),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 정보 컨텐츠 ────────────────────────────────────────────────────────────────

class _InfoContent extends StatelessWidget {
  final Color accent;
  final String categoryName;
  final String? locationLabel;
  final String svgPath;
  final String pinTitle;
  final String? emotion;
  final String? countryCode;

  const _InfoContent({
    required this.accent,
    required this.categoryName,
    required this.locationLabel,
    required this.svgPath,
    required this.pinTitle,
    required this.emotion,
    required this.countryCode,
  });

  @override
  Widget build(BuildContext context) {
    final loc = locationLabel?.trim();
    final label = (loc != null && loc.isNotEmpty)
        ? '$loc · $categoryName'
        : categoryName;
    final emotionSvg = AppConstants.emotionSvgPath(emotion);
    final flagSvg = (countryCode != null && countryCode != 'KR')
        ? AppConstants.flagSvgPath(countryCode)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 메인 타이틀
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.20,
              fontFamily: AppTokens.fontDisplay,
              letterSpacing: -0.5,
            ),
            children: const [
              TextSpan(text: '기억이\n'),
              TextSpan(
                text: '심어졌어요',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 위치 + 카테고리 칩
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, size: 12, color: accent),
              const SizedBox(width: 5),
              if (svgPath.isNotEmpty) ...[
                SvgPicture.asset(
                  svgPath,
                  width: 12,
                  height: 12,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.70),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.80),
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              // 감정 / 국기 인라인
              if (emotionSvg != null) ...[
                const SizedBox(width: 6),
                Container(width: 1, height: 10, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(width: 6),
                SvgPicture.asset(
                  emotionSvg,
                  width: 12,
                  height: 12,
                  colorFilter: ColorFilter.mode(
                    accent.withValues(alpha: 0.85),
                    BlendMode.srcIn,
                  ),
                ),
              ],
              if (flagSvg != null) ...[
                const SizedBox(width: 6),
                SvgPicture.asset(flagSvg, width: 16, height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 핀 제목
        Text(
          '"$pinTitle"',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.42),
            fontFamily: AppTokens.fontDisplay,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── 버튼 ───────────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _PrimaryButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.90),
            ),
            const SizedBox(width: 8),
            const Text(
              '지도에서 보기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: AppTokens.fontDisplay,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
