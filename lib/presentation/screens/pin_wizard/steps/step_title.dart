import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';

/// 위자드 Step 2 — 제목.
///
/// "이 순간을 / 한 줄로 적는다면?" — 큰 입력 카드 + 글자 수 카운터 + 예시 칩.
/// 제목은 필수이므로 건너뛰기 없음.
class StepTitle extends StatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// 부모 setState 트리거.
  final VoidCallback onChange;

  const StepTitle({
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
  State<StepTitle> createState() => _StepTitleState();
}

class _StepTitleState extends State<StepTitle> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  static const _maxLength = 40;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.data.title);
    _focus = FocusNode();
    _ctrl.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChange() {
    widget.data.title = _ctrl.text;
    widget.onChange();
    setState(() {});
  }

  void _applyExample(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final length = _ctrl.text.length;
    final valid = _ctrl.text.trim().isNotEmpty;

    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP 2 OF 4',
      questionTop: '이 순간을',
      questionBottom: '한 줄로 적는다면?',
      subtitle: '나중에 돌아봤을 때 떠오를 한 마디',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
        primaryEnabled: valid,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 큰 입력 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppOverlays.w06,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: TabTheme.map.accent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  maxLines: 2,
                  minLines: 1,
                  maxLength: _maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: AppTokens.fontDisplay,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: '예: 성수동에서 처음 마신 커피',
                    hintStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppOverlays.w25,
                      fontFamily: AppTokens.fontDisplay,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$length / $_maxLength',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // 예시 칩
          const Text(
            '이런 식으로 적어보세요',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: const [
              _ExampleChip(text: '노을 보러 간 한강'),
              _ExampleChip(text: '두 시간 줄 선 빵집'),
              _ExampleChip(text: '엄마랑 걸은 산책길'),
            ].map((c) => GestureDetector(
                  onTap: () => _applyExample(c.text),
                  child: c,
                ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String text;
  const _ExampleChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppOverlays.w06,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: AppOverlays.w12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppOverlays.w67,
          fontFamily: AppTokens.fontBody,
        ),
      ),
    );
  }
}
