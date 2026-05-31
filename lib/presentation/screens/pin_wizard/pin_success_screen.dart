import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/providers/pin_provider.dart';
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

  const PinSuccessScreen({
    super.key,
    required this.pinTitle,
    required this.categorySvgPath,
    required this.categoryName,
    this.locationLabel,
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
              // 구슬 + 물결 + 별 — pencil 픽셀 좌표 그대로
              _OrbStage(scale: scale),
              // 텍스트 + 버튼
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 28 * scale),
                  child: Column(
                    children: [
                      SizedBox(height: 430 * scale),
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

class _OrbStage extends StatelessWidget {
  final double scale;
  const _OrbStage({required this.scale});

  /// Pencil 좌표대로 Positioned 헬퍼.
  Widget _at({
    required double x,
    required double y,
    required Widget child,
  }) {
    return Positioned(
      left: x * scale,
      top: y * scale,
      child: child,
    );
  }

  Widget _radial({
    required double size,
    required List<Color> colors,
    required List<double> stops,
    double opacity = 1.0,
  }) {
    final s = size * scale;
    return Opacity(
      opacity: opacity,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            radius: 0.5,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }

  Widget _ovalGlow({
    required double width,
    required double height,
    required List<Color> colors,
    required List<double> stops,
    double opacity = 1.0,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width * scale,
        height: height * scale,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: RadialGradient(
            radius: 0.5,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }

  Widget _ripple({
    required double width,
    required double height,
    required double opacity,
    double thickness = 1.0,
  }) {
    return IgnorePointer(
      child: Container(
        width: width * scale,
        height: height * scale,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFA78BFA).withValues(alpha: opacity),
            width: thickness * scale,
          ),
        ),
      ),
    );
  }

  Widget _dot({required double size, required Color color, required double opacity}) {
    final s = size * scale;
    return IgnorePointer(
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.6),
              blurRadius: s * 1.2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 외곽 헤일로 (320×320 @ 55,50) ──
        _at(
          x: 55,
          y: 50,
          child: _radial(
            size: 320,
            colors: const [Color(0xFFA78BFA), Colors.black],
            stops: const [0.0, 0.45],
            opacity: 0.4,
          ),
        ),
        // ── 미드 헤일로 (240×240 @ 95,90) ──
        _at(
          x: 95,
          y: 90,
          child: _radial(
            size: 240,
            colors: const [Color(0xFFC7BFFF), Colors.black],
            stops: const [0.0, 0.5],
            opacity: 0.4,
          ),
        ),
        // ── 크리스탈 구슬 본체 (200×200 @ 115,130) ──
        _at(
          x: 115,
          y: 130,
          child: _radial(
            size: 200,
            colors: const [
              Color(0xFFF0F4FF),
              Color(0xFFA78BFA),
              Color(0xFF1E1640),
            ],
            stops: const [0.15, 0.65, 0.95],
            opacity: 0.95,
          ),
        ),
        // ── 내부 빛 (100×100 @ 165,180) ──
        _at(
          x: 165,
          y: 180,
          child: _radial(
            size: 100,
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFFC7BFFF),
              Color(0xFFA78BFA),
            ],
            stops: const [0.0, 0.6, 1.0],
            opacity: 0.85,
          ),
        ),
        // ── 글래스 하이라이트 (60×40 @ 140,150) ──
        _at(
          x: 140,
          y: 150,
          child: _ovalGlow(
            width: 60,
            height: 40,
            colors: const [Colors.white, Color(0x00FFFFFF)],
            stops: const [0.0, 1.0],
            opacity: 0.7,
          ),
        ),
        // ── 작은 흰 반짝 (14×14 @ 150,160) ──
        _at(
          x: 150,
          y: 160,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.95,
              child: Container(
                width: 14 * scale,
                height: 14 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 8 * scale,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── 하단 반사 (100×14 @ 165,310) ──
        _at(
          x: 165,
          y: 310,
          child: _ovalGlow(
            width: 100,
            height: 14,
            colors: const [Color(0xFFC7BFFF), Color(0x00A78BFA)],
            stops: const [0.0, 1.0],
            opacity: 0.4,
          ),
        ),
        // ── 물결 4개 (구슬 아래로 캐스케이드) ──
        _at(x: 115, y: 360, child: _ripple(width: 200, height: 50, opacity: 0.7, thickness: 1.5)),
        _at(x: 85, y: 380, child: _ripple(width: 260, height: 64, opacity: 0.45)),
        _at(x: 50, y: 404, child: _ripple(width: 330, height: 80, opacity: 0.28)),
        _at(x: 10, y: 430, child: _ripple(width: 410, height: 96, opacity: 0.16)),
        // ── 흰 별 6개 ──
        _at(x: 80, y: 160, child: _dot(size: 8, color: Colors.white, opacity: 0.9)),
        _at(x: 340, y: 200, child: _dot(size: 5, color: Colors.white, opacity: 0.7)),
        _at(x: 60, y: 340, child: _dot(size: 6, color: Colors.white, opacity: 0.85)),
        _at(x: 360, y: 380, child: _dot(size: 4, color: Colors.white, opacity: 0.6)),
        _at(x: 100, y: 240, child: _dot(size: 3, color: Colors.white, opacity: 0.55)),
        _at(x: 330, y: 300, child: _dot(size: 7, color: Colors.white, opacity: 0.8)),
        // ── 컬러 입자 6개 (라벤더 톤) ──
        _at(x: 90, y: 200, child: _dot(size: 4, color: const Color(0xFFC7BFFF), opacity: 0.85)),
        _at(x: 330, y: 160, child: _dot(size: 3, color: const Color(0xFFA78BFA), opacity: 0.75)),
        _at(x: 350, y: 280, child: _dot(size: 5, color: const Color(0xFFC7BFFF), opacity: 0.8)),
        _at(x: 70, y: 380, child: _dot(size: 3, color: const Color(0xFFA78BFA), opacity: 0.6)),
        _at(x: 300, y: 420, child: _dot(size: 4, color: const Color(0xFFC7BFFF), opacity: 0.7)),
        _at(x: 55, y: 260, child: _dot(size: 2, color: const Color(0xFFFFFAF0), opacity: 0.5)),
      ],
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
