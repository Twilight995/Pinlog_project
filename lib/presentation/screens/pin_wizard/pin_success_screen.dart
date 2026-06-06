import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

/// 핀 생성 성공 모먼트.
///
/// Pencil 디자인 `Qsw0P`(430×932)를 픽셀 단위로 재현.
/// 화면 폭이 430과 다르면 모든 좌표/크기에 `scale = width / 430` 비례 적용.
class PinSuccessScreen extends ConsumerWidget {
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

  void _back(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _createAnother(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    Future.microtask(() {
      ref.read(triggerCreatePinProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final scale = w / 430.0; // pencil 디자인 기준 폭
          return Stack(
            children: [
              // 배경 글로우 2개 (sBg1 라벤더 상단 + sBg2 살구 하단)
              _BgGlow(
                left: -200 * scale,
                top: -200 * scale,
                size: 830 * scale,
                color: const Color(0xFFA78BFA),
                opacity: 0.2,
                colorStop: 0.55,
              ),
              _BgGlow(
                left: -150 * scale,
                top: 400 * scale,
                size: 730 * scale,
                color: const Color(0xFFFFC093),
                opacity: 0.16,
                colorStop: 0.55,
              ),
              // 핀 아이콘 + 감정 + 국기 비주얼
              _PinMemoryVisual(
                scale: scale,
                categorySvgPath: categorySvgPath,
                emotion: emotion,
                countryCode: countryCode,
              ),
              // 텍스트 + 버튼
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 28 * scale),
                  child: Column(
                    children: [
                      SizedBox(height: 390 * scale),
                      const Text(
                        '기억이',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.05,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                      const Text(
                        '심어졌어요',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                          height: 1.05,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ContextChip(
                        locationLabel: locationLabel,
                        svgPath: categorySvgPath,
                        categoryName: categoryName,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '"$pinTitle"',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppOverlays.w67,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                      const Spacer(),
                      _PrimaryButton(onTap: () => _back(context)),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _createAnother(context, ref),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '또 다른 기억 심기',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppOverlays.w67,
                                  fontFamily: AppTokens.fontBody,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: AppOverlays.w67,
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
          );
        },
      ),
    );
  }
}

// ─── 배경 글로우 ────────────────────────────────────────────────────────

class _BgGlow extends StatelessWidget {
  final double left;
  final double top;
  final double size;
  final Color color;
  final double opacity;
  final double colorStop;

  const _BgGlow({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
    required this.opacity,
    required this.colorStop,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                radius: 0.5,
                colors: [color, Colors.black],
                stops: [0.0, colorStop],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 구슬 + 물결 + 별 ─────────────────────────────────────────────────
// Pencil x/y 좌표 그대로 + scale 적용.

// ─── 핀 메모리 비주얼 (핀 마커 + 감정 + 국기) ────────────────────────────────

class _PinMemoryVisual extends StatelessWidget {
  final double scale;
  final String categorySvgPath;
  final String? emotion;
  final String? countryCode;

  const _PinMemoryVisual({
    required this.scale,
    required this.categorySvgPath,
    required this.emotion,
    required this.countryCode,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.primaryColor;
    final lighter = Color.lerp(accent, Colors.white, 0.40)!;
    final darker = Color.lerp(accent, Colors.black, 0.10)!;
    final bodyColor = HSLColor.fromColor(accent)
        .withLightness(0.12)
        .withSaturation((HSLColor.fromColor(accent).saturation * 0.55).clamp(0.0, 1.0))
        .toColor();

    final emotionSvg = AppConstants.emotionSvgPath(emotion);
    final flagSvg = (countryCode != null && countryCode != 'KR')
        ? AppConstants.flagSvgPath(countryCode)
        : null;

    // 물결 ripple 렌더 헬퍼 — 핀 바텀(65+110=175pt) 아래부터 시작
    Widget ripple(double w, double h, double opacity) => Container(
          width: w * scale,
          height: h * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withValues(alpha: opacity),
              width: 1.0 * scale,
            ),
          ),
        );

    // 별 dot 렌더 헬퍼
    Widget dot(double size, Color color, double opacity) {
      final s = size * scale;
      return Container(
        width: s, height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
          boxShadow: [BoxShadow(color: color.withValues(alpha: opacity * 0.4), blurRadius: s * 1.5)],
        ),
      );
    }

    // 서브 아이콘 카드 (감정/국기) — 핀 옆, 겹치지 않게
    Widget iconCard({required Widget child}) => Container(
          width: 52 * scale,
          height: 52 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 16 * scale)],
          ),
          child: Center(child: child),
        );

    // 핀 마커 크기: 110pt
    final pinSize = 110.0 * scale;
    final pinR = pinSize / 2;
    // 핀 top: 노치/Dynamic Island 아래 충분한 여백 확보 (90pt)
    const pinTop = 90.0;
    // 아이콘 카드 위치 (design-space 기준, 430px 폭)
    // 핀 중심 y = 90+55 = 145, 카드 높이=52 → top = 145-26 = 119
    // 핀 중심 x=215, 반지름=55, 카드폭=52, 간격=10 → left/right = 98
    final iconCardTop = 119.0 * scale;
    const iconCardHOffset = 98.0; // design-space left/right

    return SizedBox(
      width: double.infinity,
      height: 370 * scale,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 배경 글로우
          Positioned(
            top: 40 * scale,
            child: Container(
              width: 240 * scale, height: 240 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withValues(alpha: 0.28), Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // 물결 — 핀 바텀(90+110=200pt) 아래부터 펼쳐짐
          Positioned(top: 207 * scale, child: ripple(180, 44, 0.50)),
          Positioned(top: 225 * scale, child: ripple(240, 58, 0.30)),
          Positioned(top: 247 * scale, child: ripple(310, 72, 0.16)),
          Positioned(top: 269 * scale, child: ripple(380, 86, 0.08)),
          // 별 파티클 (핀 주변)
          Positioned(top: 60 * scale,  left: 45 * scale,  child: dot(6, Colors.white, 0.80)),
          Positioned(top: 75 * scale,  right: 50 * scale, child: dot(4, Colors.white, 0.60)),
          Positioned(top: 220 * scale, left: 35 * scale,  child: dot(4, Colors.white, 0.45)),
          Positioned(top: 185 * scale, right: 30 * scale, child: dot(5, Colors.white, 0.70)),
          Positioned(top: 125 * scale, left: 28 * scale,  child: dot(3, accent, 0.75)),
          Positioned(top: 110 * scale, right: 25 * scale, child: dot(3, accent, 0.65)),
          // ── 중앙 핀 마커 ──
          Positioned(
            top: pinTop * scale,
            child: SizedBox(
              width: pinSize, height: pinSize,
              child: Stack(alignment: Alignment.center, children: [
                // 글로우
                Container(
                  width: pinSize, height: pinSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.55), blurRadius: 36 * scale, spreadRadius: 2 * scale),
                    ],
                  ),
                ),
                // 그라디언트 테두리
                ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [lighter, darker],
                  ).createShader(r),
                  child: Container(
                    width: pinSize, height: pinSize,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
                // 바디
                Container(
                  width: pinSize - 6 * scale, height: pinSize - 6 * scale,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: bodyColor),
                ),
                // 상단 하이라이트
                Positioned(
                  top: pinR * 0.20, left: pinR * 0.58,
                  child: Container(
                    width: pinR * 0.70, height: pinR * 0.34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                // 핀 SVG 아이콘
                if (categorySvgPath.isNotEmpty)
                  SvgPicture.asset(
                    categorySvgPath,
                    width: pinR * 1.15,
                    height: pinR * 1.15,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
              ]),
            ),
          ),
          // ── 감정 아이콘 (좌측, 핀 중앙 수평) ──
          if (emotionSvg != null)
            Positioned(
              top: iconCardTop,
              left: iconCardHOffset * scale,
              child: iconCard(
                child: SvgPicture.asset(
                  emotionSvg,
                  width: 24 * scale, height: 24 * scale,
                  colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                ),
              ),
            ),
          // ── 국기 (우측, 해외일 때만) ──
          if (flagSvg != null)
            Positioned(
              top: iconCardTop,
              right: iconCardHOffset * scale,
              child: iconCard(
                child: SvgPicture.asset(
                  flagSvg,
                  width: 28 * scale, height: 28 * scale,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 컨텍스트 칩 ────────────────────────────────────────────────────────

class _ContextChip extends StatelessWidget {
  final String? locationLabel;
  final String svgPath;
  final String categoryName;

  const _ContextChip({
    required this.locationLabel,
    required this.svgPath,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final loc = locationLabel?.trim();
    final label = (loc != null && loc.isNotEmpty)
        ? '$loc · $categoryName'
        : categoryName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppOverlays.w08,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 12,
            color: Color(0xFFA78BFA),
          ),
          const SizedBox(width: 6),
          if (svgPath.isNotEmpty) ...[
            SvgPicture.asset(
              svgPath,
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(AppOverlays.w80, BlendMode.srcIn),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppOverlays.w80,
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 주 액션 버튼 ───────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.map_rounded, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              '지도에서 보기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: AppTokens.fontDisplay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
