import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../application/providers/pin_provider.dart';
import '../common/glass_sheet.dart';

class FilterSheet extends ConsumerWidget {
  final VoidCallback onClose;

  const FilterSheet({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);

    return GlassSheet(
      height: 420,
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: context.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text('핀 필터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('원하는 기억만 쏙쏙 골라보세요.', style: TextStyle(fontSize: 14, color: AppColors.greyLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),

          // 반응 필터
          const Text('반응으로 찾기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: '전체 보기', isActive: filter.emotion == 'all', onTap: () => ref.read(filterProvider.notifier).setEmotion('all')),
              ...AppConstants.emotions.map((e) => _FilterChip(
                label: e,
                isActive: filter.emotion == e,
                isEmotion: true,
                onTap: () => ref.read(filterProvider.notifier).setEmotion(e),
              )),
            ],
          ),
          const SizedBox(height: 20),

          // 공개 범위 필터
          const Text('공개 범위로 찾기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(label: '전체 보기', isActive: filter.visibility == 'all', onTap: () => ref.read(filterProvider.notifier).setVisibility('all')),
              ...AppConstants.visibilities.map((v) => _FilterChip(
                label: v,
                isActive: filter.visibility == v,
                onTap: () => ref.read(filterProvider.notifier).setVisibility(v),
              )),
            ],
          ),
          const SizedBox(height: 24),

          // 적용 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.themePreset.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: const Text('적용하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isEmotion;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isActive, required this.onTap, this.isEmotion = false});

  static const _visibilityIcons = {
    '🌐 전체 공개': (Icons.public_rounded, '전체 공개'),
    '👥 친구 공개': (Icons.people_outline_rounded, '친구 공개'),
    '🔒 나만 보기': (Icons.lock_outline_rounded, '나만 보기'),
  };

  @override
  Widget build(BuildContext context) {
    final visInfo = _visibilityIcons[label];
    final chipColor = isActive ? context.themePreset.onPrimary : AppColors.greyLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? context.primaryColor : context.chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? context.primaryColor : context.chipBorder,
          ),
        ),
        child: visInfo != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(visInfo.$1, size: 13, color: chipColor),
                  const SizedBox(width: 4),
                  Text(
                    visInfo.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: chipColor,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: chipColor,
                ),
              ),
      ),
    );
  }
}
