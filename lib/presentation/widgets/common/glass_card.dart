import 'dart:ui';

import 'package:flutter/material.dart';

/// 글래스 카드 — 다층 디자인 시스템의 핵심 컨테이너.
///
/// 패턴:
/// - 흰색 미세 그라디언트 fill (상단 밝게 → 하단 옅게)
/// - BackdropFilter 블러로 뒷배경 픽업
/// - 흰 보더로 윤곽 정의
/// - 라운드 모서리
///
/// 사용:
/// ```dart
/// GlassCard(
///   radius: 28,
///   padding: const EdgeInsets.all(16),
///   child: ...,
/// );
/// ```
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;

  /// fill 그라디언트 강도 — `1.0` 기본 (`#33→#1F→#14`).
  /// 더 진하게(`1.4`) 또는 더 옅게(`0.6`).
  final double intensity;

  /// 보더 색 (기본: 흰색 25%).
  final Color? borderColor;

  /// `red`, `green` 같은 색조를 입힌 글래스 변형. null이면 중립(흰색).
  final Color? tint;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.blurSigma = 24,
    this.intensity = 1.0,
    this.borderColor,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint ?? Colors.white;
    final topA = (0.20 * intensity).clamp(0.0, 1.0);
    final midA = (0.12 * intensity).clamp(0.0, 1.0);
    final botA = (0.08 * intensity).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: topA),
                base.withValues(alpha: midA),
                base.withValues(alpha: botA),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 작은 원형 글래스 버튼 (chevron, more 등).
class GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final Color? iconColor;

  const GlassCircleButton({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 20,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.12),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
