import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 다크 글래스 바텀시트 — 핀로그 표준 시트.
///
/// 레이어 구조 (아래 → 위):
/// 1. **BackdropFilter blur** (지도 등 뒷배경을 흐림)
/// 2. **다크 스크림** (40~55% 검정) — 흰 텍스트 가독성 확보
/// 3. **흰 글래스 그라디언트** (10~20%) — 글래스 톤 정체성
/// 4. 컨텐츠 (드래그 핸들 + 헤더 + child)
///
/// `showModalBottomSheet`와 함께 사용:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: Colors.transparent,
///   isScrollControlled: true,
///   builder: (_) => GlassBottomSheet(
///     title: '맞춤 지도 뷰',
///     subtitle: '어떤 순간을 다시 떠올려볼까요',
///     headerIcon: Icons.tune_rounded,
///     child: ...,
///   ),
/// );
/// ```
class GlassBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? headerIcon;
  final Widget child;

  /// 블러 강도 — 기본 30. 0이면 블러 없음(스크림만).
  final double blurSigma;

  /// 다크 스크림 알파 — 기본 0.55 (가독성 우선).
  final double scrimAlpha;

  /// 흰 글래스 오버레이 알파 — 기본 0.10.
  final double glassAlpha;

  const GlassBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.headerIcon,
    required this.child,
    this.blurSigma = 30,
    this.scrimAlpha = 0.55,
    this.glassAlpha = 0.10,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        children: [
          // 1) 블러 + 스크림 — 뒷배경 흐림 + 어둡게
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                color: Colors.black.withValues(alpha: scrimAlpha),
              ),
            ),
          ),
          // 2) 흰 글래스 톤 (살짝)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: glassAlpha + 0.05),
                    Colors.white.withValues(alpha: glassAlpha),
                    Colors.white.withValues(alpha: glassAlpha - 0.04),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 3) 상단 보더 (희미한 흰 라인)
          Positioned(
            top: 0, left: 0, right: 0, height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 4) 컨텐츠
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 드래그 핸들
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 헤더 (옵션)
                if (title != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Row(
                      children: [
                        if (headerIcon != null) ...[
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFFA78BFA),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(headerIcon, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            title!,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                            height: 1.4,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                ],
                // child
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + safeBottom),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
