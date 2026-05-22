import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// 위자드 공통 스캐폴드.
///
/// 각 단계 화면은 [child]로 컨텐츠만 넘기면 됨.
/// 헤더(뒤로/단계 닷/닫기)와 푸터(액션 버튼)는 자동 구성.
class WizardScaffold extends StatelessWidget {
  /// 전체 단계 수 (4).
  final int totalSteps;

  /// 현재 단계 (0-based).
  final int currentStep;

  /// `STEP 1 OF 4` 같은 라벨에 표시될 텍스트는 자동 계산.
  /// 부제와 큰 질문은 [stepLabel]/[questionTop]/[questionBottom]으로 전달.
  final String stepLabel;
  final String questionTop;
  final String questionBottom;
  final String subtitle;

  /// 본문 (질문 아래 입력 영역).
  final Widget child;

  /// 푸터 버튼 영역. 일반적으로 [WizardFooter]를 넘김.
  final Widget footer;

  /// 닫기(✕) 콜백.
  final VoidCallback onClose;

  /// 뒤로(←) 콜백. null이면 첫 단계로 간주하고 버튼 숨김.
  final VoidCallback? onBack;

  const WizardScaffold({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.stepLabel,
    required this.questionTop,
    required this.questionBottom,
    required this.subtitle,
    required this.child,
    required this.footer,
    required this.onClose,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // 본문 — 헤더 + 질문 + child
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    totalSteps: totalSteps,
                    currentStep: currentStep,
                    onClose: onClose,
                    onBack: onBack,
                  ),
                  const SizedBox(height: 36),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA78BFA),
                            letterSpacing: 1.5,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          questionTop,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.1,
                            fontFamily: AppTokens.fontDisplay,
                          ),
                        ),
                        Text(
                          questionBottom,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                            height: 1.1,
                            fontFamily: AppTokens.fontDisplay,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(child: child),
                ],
              ),
            ),
            // 푸터 — 하단 고정
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  const _Header({
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 뒤로 버튼 (1단계에선 자리 차지만)
        SizedBox(
          width: 46,
          height: 46,
          child: onBack == null
              ? const SizedBox.shrink()
              : _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack!,
                ),
        ),
        // 단계 닷
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(totalSteps, (i) {
                final isActive = i == currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFA78BFA)
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ),
        // 닫기 버튼
        _CircleIconButton(icon: Icons.close_rounded, onTap: onClose),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppOverlays.w08,
          shape: BoxShape.circle,
          border: Border.all(color: AppOverlays.w15),
        ),
        child: Icon(icon, size: 18, color: AppOverlays.w85),
      ),
    );
  }
}

// ─── 푸터 ─────────────────────────────────────────────────────────────────

/// 위자드 푸터 — 다음/저장 메인 버튼 + 옵션 스킵.
class WizardFooter extends StatelessWidget {
  /// 메인 버튼 라벨 ("다음" 또는 "기록 심기").
  final String primaryLabel;

  /// 메인 버튼 아이콘 (다음 = arrow_right, 저장 = check).
  final IconData primaryIcon;

  /// 메인 버튼 콜백.
  final VoidCallback onPrimary;

  /// 메인 버튼 활성화 여부.
  final bool primaryEnabled;

  /// 스킵 라벨 ("건너뛰기" / "혼자였어요"). null이면 풀폭.
  final String? skipLabel;
  final VoidCallback? onSkip;

  const WizardFooter({
    super.key,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.skipLabel,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final hasSkip = skipLabel != null && onSkip != null;
    return Row(
      children: [
        if (hasSkip) ...[
          GestureDetector(
            onTap: onSkip,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  skipLabel!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: _PrimaryButton(
            label: primaryLabel,
            icon: primaryIcon,
            enabled: primaryEnabled,
            onTap: onPrimary,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? const [Color(0xFFA78BFA), Color(0xFF7C3AED)]
                : [AppOverlays.w12, AppOverlays.w08],
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : AppOverlays.w50,
                fontFamily: AppTokens.fontDisplay,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 18,
              color: enabled ? Colors.white : AppOverlays.w50,
            ),
          ],
        ),
      ),
    );
  }
}
