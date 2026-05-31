import 'package:flutter/material.dart';

/// 카드 내부 장식용 라디얼 글로우 블롭.
///
/// 중심에서 [color]가 [opacity] 강도로 시작해 가장자리에서 투명으로 페이드.
/// `ClipRRect` 안에 `Positioned`로 배치해 카드 모서리에 빼꼼 보이게 사용.
class Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const Blob({
    super.key,
    required this.size,
    required this.color,
    this.opacity = 0.55,
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
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
