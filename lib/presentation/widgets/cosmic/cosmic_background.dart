import 'package:flutter/material.dart';

/// 코스믹 배경 — 검정 베이스에 따뜻한 살구색 + 보라 글로우가
/// 한 곳에서 만나 부드럽게 번지는 무드.
///
/// 사용:
/// ```dart
/// Scaffold(
///   body: Stack(children: [
///     const CosmicBackground(),
///     // 실제 화면 컨텐츠
///   ]),
/// )
/// ```
class CosmicBackground extends StatelessWidget {
  /// 상단 글로우 강도(0~1).
  final double intensity;

  /// 살구색 좌하단 빼꼼 효과 활성 여부.
  final bool showApricot;

  const CosmicBackground({
    super.key,
    this.intensity = 1.0,
    this.showApricot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            // 메인 와인색 글로우 (좌상단에서 번짐)
            Positioned(
              left: -590,
              top: -430,
              child: _Glow(
                size: 1400,
                color: const Color(0xFF5C4458),
                opacity: 0.5 * intensity,
              ),
            ),
            // 차가운 보라 보조 글로우
            Positioned(
              left: -280,
              top: -360,
              child: _Glow(
                size: 1200,
                color: const Color(0xFF3A2D70),
                opacity: 0.6 * intensity,
              ),
            ),
            // 살구색 좌하단 (포도 좌하단으로 빼꼼)
            if (showApricot)
              Positioned(
                left: -150,
                top: 230,
                child: _Glow(
                  size: 400,
                  color: const Color(0xFFE07A4A),
                  opacity: 0.5 * intensity,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Glow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            radius: 0.5,
            colors: [
              color.withValues(alpha: opacity),
              Colors.black.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
