import 'package:flutter/material.dart';

/// 도감 탭 전용 글로우 배경 — 펜 디자인 v1 (`o0gAK Glow BG`).
///
/// 3겹 라디얼:
/// - Apricot Back: `#F5C088` 우상단 (소형)
/// - Grape A: `#6B2840` 좌상단 (대형)
/// - Grape B: `#4A1F45` 중앙 (대형)
class DogamGlowBackground extends StatelessWidget {
  const DogamGlowBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          // Apricot — 우상단
          // 펜 위치 (40, 30), size 500×500, on 430×932 screen
          // → align (40+250)/430*2-1 = 0.35, (30+250)/932*2-1 = -0.40
          // radius ≈ 500/932 ≈ 0.54
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.35, -0.40),
                radius: 0.60,
                colors: [
                  Color(0xFFF5C088),
                  Color(0x00F5C088),
                ],
                stops: [0.0, 0.55],
              ),
            ),
          ),
          // Grape A — 큰 좌상단 부근
          // 펜 위치 (-710, -360), size 1200, center at (-110, 240)
          // → align (-110)/430*2-1 = -1.51 (off canvas)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.51, -0.49),
                radius: 1.4,
                colors: [
                  Color(0xFF6B2840),
                  Color(0x006B2840),
                ],
                stops: [0.0, 0.6],
              ),
            ),
          ),
          // Grape B — 큰 중하단
          // 펜 위치 (-280, -360), size 1200, center at (320, 240) — 우측 중상단
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.49, -0.49),
                radius: 1.4,
                colors: [
                  Color(0xFF4A1F45),
                  Color(0x004A1F45),
                ],
                stops: [0.0, 0.6],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
