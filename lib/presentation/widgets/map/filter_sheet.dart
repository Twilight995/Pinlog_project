import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../common/glass_bottom_sheet.dart';

/// 지도 필터 — 반응 + 공개 범위로 핀 고르기.
///
/// 표준 글래스 바텀시트 패턴 사용 (블러 + 다크 스크림 + 흰 글래스).
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  /// 호출 헬퍼.
  static Future<void> show(BuildContext context) {
    return showAppSheet<void>(
      context,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);

    return GlassBottomSheet(
      headerIcon: Icons.tune_rounded,
      title: '맞춤 지도 뷰',
      subtitle: '어떤 순간을 다시 떠올려볼까요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SectionLabel('반응으로 찾기'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassChip(
                label: '전체',
                isActive: filter.emotion == 'all',
                onTap: () =>
                    ref.read(filterProvider.notifier).setEmotion('all'),
              ),
              ...AppConstants.emotions.map((e) => _GlassChip(
                    label: e,
                    isActive: filter.emotion == e,
                    onTap: () =>
                        ref.read(filterProvider.notifier).setEmotion(e),
                  )),
            ],
          ),
          const SizedBox(height: 22),

          const _SectionLabel('공개 범위로 찾기'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassChip(
                label: '전체',
                isActive: filter.visibility == 'all',
                onTap: () =>
                    ref.read(filterProvider.notifier).setVisibility('all'),
              ),
              ...AppConstants.visibilities.map((v) => _GlassChip(
                    label: v,
                    isActive: filter.visibility == v,
                    onTap: () =>
                        ref.read(filterProvider.notifier).setVisibility(v),
                  )),
            ],
          ),
          const SizedBox(height: 24),

          // 적용하기 CTA
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: const Text(
                '적용하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A0F3D),
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.textMuted,
        fontFamily: AppTokens.fontBody,
      ),
    );
  }
}

/// 글래스 톤 필터 칩 — 활성/비활성 같은 계열, 농도 차이.
class _GlassChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final topA = isActive ? 0.70 : 0.18;
    final midA = isActive ? 0.50 : 0.12;
    final botA = isActive ? 0.35 : 0.08;
    final borderA = isActive ? 0.85 : 0.20;
    final borderW = isActive ? 1.5 : 1.0;
    final blur = isActive ? 36.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: topA),
                  Colors.white.withValues(alpha: midA),
                  Colors.white.withValues(alpha: botA),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderA),
                width: borderW,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                color: Colors.white,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
