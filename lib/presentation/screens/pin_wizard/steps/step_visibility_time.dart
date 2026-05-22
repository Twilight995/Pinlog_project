import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';

/// 위자드 Step 4 — 공개 범위 + 시간 (마지막).
///
/// 큰 옵션 카드 3개로 공개 범위 선택, 하단 날짜/시간 행, "기록 심기" CTA.
class StepVisibilityTime extends StatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onSave;

  /// 부모 setState 트리거.
  final VoidCallback onChange;

  const StepVisibilityTime({
    super.key,
    required this.data,
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
    required this.onSave,
    required this.onChange,
  });

  @override
  State<StepVisibilityTime> createState() => _StepVisibilityTimeState();
}

class _StepVisibilityTimeState extends State<StepVisibilityTime> {
  /// 공개 범위 표시용 메타 (이모지 + 제목 + 설명) — 토큰 키 자체는
  /// AppConstants.visibilities를 신뢰.
  static const _visibilityMeta = <String, ({String emoji, String title, String desc})>{
    '🌐 전체 공개': (emoji: '🌐', title: '전체 공개', desc: '누구나 이 핀을 볼 수 있어요'),
    '👥 친구 공개': (emoji: '👥', title: '친구 공개', desc: '팔로우한 사람만 볼 수 있어요'),
    '🔒 나만 보기': (emoji: '🔒', title: '나만 보기', desc: '오직 나만 볼 수 있는 비밀 기억'),
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.data.createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: TabTheme.map.accent,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      widget.data.createdAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        widget.data.createdAt.hour,
        widget.data.createdAt.minute,
      );
      widget.onChange();
      setState(() {});
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.data.createdAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: TabTheme.map.accent,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      widget.data.createdAt = DateTime(
        widget.data.createdAt.year,
        widget.data.createdAt.month,
        widget.data.createdAt.day,
        picked.hour,
        picked.minute,
      );
      widget.onChange();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = widget.data.createdAt;
    final dateText =
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    final timeText =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP 4 OF 4',
      questionTop: '이 기억은',
      questionBottom: '누구에게 보일까요?',
      subtitle: '마지막으로 시간도 한 번 확인해주세요',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '기록 심기',
        primaryIcon: Icons.check_rounded,
        onPrimary: widget.onSave,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 공개 범위 옵션 3개
            ...AppConstants.visibilities.map((opt) {
              final meta = _visibilityMeta[opt];
              if (meta == null) return const SizedBox.shrink();
              final isActive = widget.data.visibility == opt;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VisibilityOption(
                  emoji: meta.emoji,
                  title: meta.title,
                  desc: meta.desc,
                  isActive: isActive,
                  onTap: () {
                    widget.data.visibility = opt;
                    widget.onChange();
                    setState(() {});
                  },
                ),
              );
            }),
            const SizedBox(height: 14),
            // 날짜 + 시간 행
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    icon: Icons.calendar_today_rounded,
                    label: '날짜',
                    value: dateText,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTimeButton(
                    icon: Icons.schedule_rounded,
                    label: '시간',
                    value: timeText,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final bool isActive;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, TabTheme.map.bgEnd],
                )
              : null,
          color: isActive ? null : AppOverlays.w06,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          border: Border.all(
            color: isActive ? TabTheme.map.accent : AppOverlays.w15,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                      color: isActive ? AppColors.textOnPastel : AppOverlays.w80,
                      fontFamily: AppTokens.fontDisplay,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? const Color(0xFF5B4A8A)
                          : AppOverlays.w50,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: TabTheme.map.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppOverlays.w06,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: TabTheme.map.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppOverlays.w50,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: AppTokens.fontDisplay,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
