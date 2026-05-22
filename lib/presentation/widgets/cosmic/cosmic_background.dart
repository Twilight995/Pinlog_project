import 'package:flutter/material.dart';

/// 코스믹 배경 — 검정 베이스에 따뜻한 와인 글로우 + 차가운 보라 글로우가
/// 좌상단에서 만나 부드럽게 번지고, 좌하단에서 살구색이 빼꼼 보이는 무드.
///
/// 펜슬 디자인의 "포도 + 살구 + 차가운 와인" 글로우 조합 그대로 구현.
/// 단일 인스턴스로 MainShell에서 사용하면 전 화면 공유 + 성능 최적.
class CosmicBackground extends StatelessWidget {
  const CosmicBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              // 메인 와인색 글로우 (좌상단)
              Positioned(
                left: -590,
                top: -430,
                child: _Glow(
                  size: 1400,
                  color: Color(0xFF5C4458),
                  opacity: 0.5,
                ),
              ),
              // 차가운 보라 보조 글로우
              Positioned(
                left: -280,
                top: -360,
                child: _Glow(
                  size: 1200,
                  color: Color(0xFF3A2D70),
                  opacity: 0.6,
                ),
              ),
              // 살구색 좌하단 빼꼼 (포도 좌하단으로 살짝 드러남)
              Positioned(
                left: -150,
                top: 230,
                child: _Glow(
                  size: 400,
                  color: Color(0xFFE07A4A),
                  opacity: 0.5,
                ),
              ),
            ],
          ),
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
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            radius: 0.5,
            colors: [
              color.withValues(alpha: opacity),
              const Color(0x00000000),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
