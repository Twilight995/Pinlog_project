import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';

/// 위자드 Step 3 — 동행자.
///
/// "누구와 / 함께였나요?" — 입력 + 추가 버튼 + 칩 목록.
/// 옵션 단계이므로 "혼자였어요" 스킵 가능.
class StepCompanions extends StatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// 부모 setState 트리거.
  final VoidCallback onChange;

  const StepCompanions({
    super.key,
    required this.data,
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onChange,
  });

  @override
  State<StepCompanions> createState() => _StepCompanionsState();
}

class _StepCompanionsState extends State<StepCompanions> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  /// 동행자 아바타 그라디언트 색 (이름 해시로 결정).
  static const _avatarPalettes = <List<Color>>[
    [Color(0xFFFFE9A8), Color(0xFFF2A66B)], // 옐로우→피치
    [Color(0xFFBFEFE4), Color(0xFF5BB89E)], // 민트
    [Color(0xFFF5C9E0), Color(0xFFD89BC4)], // 핑크
    [Color(0xFFC7BFFF), Color(0xFF9D8BE0)], // 라벤더
    [Color(0xFFBFDBFE), Color(0xFF93C5FD)], // 블루
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (widget.data.companions.contains(text)) {
      _ctrl.clear();
      return;
    }
    widget.data.companions = [...widget.data.companions, text];
    _ctrl.clear();
    widget.onChange();
    setState(() {});
    _focus.requestFocus();
  }

  void _remove(String name) {
    widget.data.companions =
        widget.data.companions.where((c) => c != name).toList();
    widget.onChange();
    setState(() {});
  }

  List<Color> _paletteFor(String name) {
    final i = name.hashCode.abs() % _avatarPalettes.length;
    return _avatarPalettes[i];
  }

  @override
  Widget build(BuildContext context) {
    final hasCompanions = widget.data.companions.isNotEmpty;
    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP 3 OF 4',
      questionTop: '누구와',
      questionBottom: '함께였나요?',
      subtitle: '혼자라면 건너뛰어도 좋아요',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
        skipLabel: hasCompanions ? null : '혼자였어요',
        onSkip: hasCompanions ? null : widget.onSkip,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 입력 + 추가 버튼
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppOverlays.w06,
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onSubmitted: (_) => _add(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontFamily: AppTokens.fontBody,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '이름 입력 후 추가',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppOverlays.w33,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _add,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: TabTheme.map.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (hasCompanions) ...[
            const SizedBox(height: 24),
            const Text(
              '함께한 사람',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.3,
                fontFamily: AppTokens.fontBody,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.data.companions
                  .map((name) => _CompanionChip(
                        name: name,
                        gradient: _paletteFor(name),
                        onRemove: () => _remove(name),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanionChip extends StatelessWidget {
  final String name;
  final List<Color> gradient;
  final VoidCallback onRemove;

  const _CompanionChip({
    required this.name,
    required this.gradient,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppOverlays.w08,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 그라디언트 아바타
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: AppOverlays.w50,
            ),
          ),
        ],
      ),
    );
  }
}
