import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import 'wizard_style.dart';

/// 위자드 공통 스캐폴드.
///
/// 각 단계 화면은 [child]로 컨텐츠만 넘기면 됨.
/// 헤더(뒤로/단계 닷/닫기)와 푸터(액션 버튼)는 자동 구성.
/// 색상은 [WizardStyleScope]에서 읽음 — [WizardStyle.light] 또는 [WizardStyle.cosmic].
class WizardScaffold extends StatefulWidget {
  final int totalSteps;
  final int currentStep;
  final String stepLabel;
  final String questionTop;
  final String questionBottom;
  final String subtitle;
  final Widget child;
  final Widget footer;
  final VoidCallback onClose;
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
  State<WizardScaffold> createState() => _WizardScaffoldState();
}

class _WizardScaffoldState extends State<WizardScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(double from, double to) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(from, to, curve: Curves.easeOut),
      );

  Animation<Offset> _slide(double from, double to, {double dy = 0.025}) =>
      Tween<Offset>(begin: Offset(0, dy), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(from, to, curve: Curves.easeOutQuart),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    totalSteps: widget.totalSteps,
                    currentStep: widget.currentStep,
                    onClose: widget.onClose,
                    onBack: widget.onBack,
                  ),
                  const SizedBox(height: 36),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeTransition(
                          opacity: _fade(0.00, 0.42),
                          child: SlideTransition(
                            position: _slide(0.00, 0.48),
                            child: Text(
                              widget.stepLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ws.stepLabel,
                                letterSpacing: 1.5,
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeTransition(
                          opacity: _fade(0.08, 0.50),
                          child: SlideTransition(
                            position: _slide(0.08, 0.56, dy: 0.04),
                            child: Text(
                              widget.questionTop,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: ws.heading,
                                height: 1.1,
                                fontFamily: AppTokens.fontDisplay,
                              ),
                            ),
                          ),
                        ),
                        FadeTransition(
                          opacity: _fade(0.14, 0.56),
                          child: SlideTransition(
                            position: _slide(0.14, 0.62, dy: 0.04),
                            child: Text(
                              widget.questionBottom,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: ws.heading,
                                height: 1.1,
                                fontFamily: AppTokens.fontDisplay,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeTransition(
                          opacity: _fade(0.22, 0.64),
                          child: SlideTransition(
                            position: _slide(0.22, 0.70),
                            child: Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: ws.muted,
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fade(0.30, 0.78),
                      child: SlideTransition(
                        position: _slide(0.30, 0.82, dy: 0.03),
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: FadeTransition(
                opacity: _fade(0.06, 0.48),
                child: SlideTransition(
                  position: _slide(0.06, 0.44, dy: 0.06),
                  child: widget.footer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 헤더 ──────────────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
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
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  int _activeStep = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _activeStep = widget.currentStep);
    });
  }

  @override
  void didUpdateWidget(_Header old) {
    super.didUpdateWidget(old);
    if (old.currentStep != widget.currentStep) {
      setState(() => _activeStep = widget.currentStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    return Row(
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: widget.onBack == null
              ? const SizedBox.shrink()
              : _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: widget.onBack!,
                ),
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.totalSteps, (i) {
                final isActive = i == _activeStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? ws.dotActive : ws.dotInactive,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ),
        _CircleIconButton(icon: Icons.close_rounded, onTap: widget.onClose),
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
    final ws = context.ws;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: ws.iconBtnBg,
          shape: BoxShape.circle,
          border: Border.all(color: ws.iconBtnBorder),
        ),
        child: Icon(icon, size: 18, color: ws.iconBtnFg),
      ),
    );
  }
}

// ─── 푸터 ──────────────────────────────────────────────────────────────────

/// 위자드 푸터 — 다음/저장 메인 버튼 + 옵션 스킵.
class WizardFooter extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
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
    final ws = context.ws;
    final hasSkip = skipLabel != null && onSkip != null;
    return Row(
      children: [
        if (hasSkip) ...[
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onSkip!();
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  skipLabel!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ws.muted,
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
    final ws = context.ws;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuart,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? [ws.accentLight, ws.accent]
                : [ws.disabledBtnBg1, ws.disabledBtnBg2],
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
                color: enabled ? Colors.white : ws.disabledBtnFg,
                fontFamily: AppTokens.fontDisplay,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 18,
              color: enabled ? Colors.white : ws.disabledBtnFg,
            ),
          ],
        ),
      ),
    );
  }
}
