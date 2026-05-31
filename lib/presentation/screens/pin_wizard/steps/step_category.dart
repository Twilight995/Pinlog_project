import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';
import '../wizard_style.dart';

/// 위자드 Step 2 — 카테고리 선택.
///
/// 어떤 종류의 순간인지 카테고리를 먼저 고르면 다음 단계(Step 3)에서
/// 카테고리에 맞는 AI 제목 제안이 나타남.
class StepCategory extends StatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onChange;

  const StepCategory({
    super.key,
    required this.data,
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onChange,
  });

  @override
  State<StepCategory> createState() => _StepCategoryState();
}

class _StepCategoryState extends State<StepCategory> {
  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP ${widget.currentStep + 1} OF ${widget.totalSteps}',
      questionTop: '어떤 종류의',
      questionBottom: '순간인가요?',
      subtitle: '카테고리를 먼저 고르면 제목을 추천해 드려요',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
        primaryEnabled: true,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _CategoryGrid(
          selected: widget.data.pinShape,
          onSelect: (shape) {
            HapticFeedback.selectionClick();
            widget.data.pinShape = shape;
            widget.onChange();
            setState(() {});
          },
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    final accent = context.primaryColor;
    final shapes = AppConstants.pinShapes;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: shapes.length,
      itemBuilder: (_, i) {
        final shape = shapes[i];
        final isSelected = shape == selected;
        final svgPath = AppConstants.pinShapeSvgs[shape] ?? '';
        final label = AppConstants.pinShapeNames[shape] ?? shape;

        return GestureDetector(
          onTap: () => onSelect(shape),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.12)
                  : ws.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.7)
                    : ws.surfaceBorder,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  svgPath.isNotEmpty ? svgPath : 'lib/img/place/map-pin.svg',
                  width: 28,
                  height: 28,
                  colorFilter: ColorFilter.mode(
                    isSelected ? accent : ws.onSurface.withValues(alpha: 0.55),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? accent
                        : ws.onSurface.withValues(alpha: 0.6),
                    fontFamily: AppTokens.fontBody,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
