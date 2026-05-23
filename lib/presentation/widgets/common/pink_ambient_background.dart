import 'package:flutter/material.dart';

/// 핀로그 표준 배경 — 검은 베이스 + 핑크 광원 2개 (대각선 반대).
///
/// CLAUDE.md 의 "표준 배경 패턴" 그대로 Flutter로 옮긴 것.
/// 광원 위치/사이즈/색/알파 모두 펜 디자인과 동일.
///
/// 사용:
/// ```dart
/// Stack([
///   const Positioned.fill(child: PinkAmbientBackground()),
///   ...컨텐츠
/// ])
/// ```
class PinkAmbientBackground extends StatelessWidget {
  const PinkAmbientBackground({super.key});

  // 광원 색 — R 유지하고 G/B만 점진적으로 늘려 핑크 톤 유지
  static const _stops = <double>[0.0, 0.1, 0.22, 0.38, 0.54, 0.7, 0.85, 0.95, 1.0];
  static const _colors = <Color>[
    Color(0x4DFF80B0), // 30% 강한 핑크
    Color(0x40FF80B0), // 25% (plateau — hotspot 방지)
    Color(0x33FF8FB8), // 20%
    Color(0x24FFA0C2), // 14%
    Color(0x18FFB0CC), // 9%
    Color(0x0EFFC0D6), // 5%
    Color(0x06FFD0E0), // 2%
    Color(0x01FFD0E0), // 0.4%
    Color(0x00FFD0E0), // 0%
  ];

  @override
  Widget build(BuildContext context) {
    return const _PinkAmbientPainter();
  }
}

class _PinkAmbientPainter extends StatelessWidget {
  const _PinkAmbientPainter();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 베이스 다크
        const ColoredBox(color: Color(0xFF0A0612)),
        // 2. 광원 1 — 왼쪽 위 (꼭짓점 안쪽으로 살짝)
        // 펜 (0.25, 0.32) → Flutter alignment (-0.5, -0.36)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.5, -0.36),
              radius: 1.0,
              colors: PinkAmbientBackground._colors,
              stops: PinkAmbientBackground._stops,
            ),
          ),
        ),
        // 3. 광원 2 — 오른쪽 아래 (대각선 반대)
        // 펜 (0.75, 0.78) → Flutter alignment (0.5, 0.56)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5, 0.56),
              radius: 1.0,
              colors: PinkAmbientBackground._colors,
              stops: PinkAmbientBackground._stops,
            ),
          ),
        ),
      ],
    );
  }
}
