import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';
import '../wizard_style.dart';

/// 위자드 Step 3 — 감정 + 감정 강도.
///
/// "이 순간은 / 어땠나요?" — 감정 (좋아요/별로에요) 토글 + 강도 1~5 별점.
class StepEmotionIntensity extends StatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// 부모 setState 트리거.
  final VoidCallback onChange;

  const StepEmotionIntensity({
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
  State<StepEmotionIntensity> createState() => _StepEmotionIntensityState();
}

class _StepEmotionIntensityState extends State<StepEmotionIntensity> {
  static const _emotionMeta = <String, _EmotionMeta>{
    '좋아요': _EmotionMeta(svgPath: 'lib/img/emotion/hand-heart.svg'),
    '별로에요': _EmotionMeta(svgPath: 'lib/img/emotion/sad-circle-svgrepo-com.svg'),
  };

  List<Color> _gradientFor(String e, BuildContext context) {
    if (e == '좋아요') return [context.primaryLightColor, context.primaryColor];
    return const [Color(0xFFB8D8F2), Color(0xFF7BA8CF)];
  }

  void _selectEmotion(String e) {
    HapticFeedback.selectionClick();
    widget.data.emotion = e;
    widget.onChange();
    setState(() {});
  }

  void _selectIntensity(int v) {
    HapticFeedback.selectionClick();
    widget.data.intensityLevel = v;
    widget.onChange();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final emotion = widget.data.emotion;
    final intensity = widget.data.intensityLevel;
    final activeGradient = _gradientFor(emotion, context);

    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP 3 OF 5',
      questionTop: '이 순간은',
      questionBottom: '어땠나요?',
      subtitle: '감정과 강도로 그 깊이를 남겨두세요',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 감정 토글 (좋아요 / 별로에요) ──────────────────────────────
          Row(
            children: AppConstants.emotions.map((e) {
              final meta = _emotionMeta[e] ?? _emotionMeta.values.first;
              final grad = _gradientFor(e, context);
              final selected = e == emotion;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: e == AppConstants.emotions.last ? 0 : 10,
                  ),
                  child: _EmotionCard(
                    label: e,
                    svgPath: meta.svgPath,
                    gradient: grad,
                    selected: selected,
                    onTap: () => _selectEmotion(e),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // ── 강도 라벨 ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '감정 강도',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.ws.muted,
                  letterSpacing: 0.3,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              Text(
                '$intensity / 5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activeGradient.last,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── 강도 별점 (1~5) ──────────────────────────────────────────
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              final filled = v <= intensity;
              return Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i == 4 ? 0 : 8),
                  child: _IntensityStar(
                    value: v,
                    filled: filled,
                    gradient: activeGradient,
                    onTap: () => _selectIntensity(v),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          // ── 강도 설명 텍스트 ────────────────────────────────────────
          Center(
            child: Text(
              _intensityCaption(intensity),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.ws.muted,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _intensityCaption(int v) {
    switch (v) {
      case 1:
        return '잠깐 스쳐간 느낌';
      case 2:
        return '기록할 만한 순간';
      case 3:
        return '오래 기억하고 싶어요';
      case 4:
        return '마음 깊이 남는 시간';
      case 5:
        return '잊지 못할 한 순간';
      default:
        return '';
    }
  }
}

class _EmotionMeta {
  final String svgPath;
  const _EmotionMeta({required this.svgPath});
}

class _EmotionCard extends StatelessWidget {
  final String label;
  final String svgPath;
  final List<Color> gradient;
  final bool selected;
  final VoidCallback onTap;

  const _EmotionCard({
    required this.label,
    required this.svgPath,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                )
              : null,
          color: selected ? null : ws.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : ws.surfaceBorder,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: gradient.last.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              svgPath,
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(
                selected ? Colors.white : gradient.last,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : context.ws.onSurface,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntensityStar extends StatelessWidget {
  final int value;
  final bool filled;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _IntensityStar({
    required this.value,
    required this.filled,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                )
              : null,
          color: filled ? null : ws.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: 0.30)
                : ws.surfaceBorder,
            width: 1.2,
          ),
        ),
        child: Center(
          child: SvgPicture.asset(
            'lib/img/badge/star.svg',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              filled ? Colors.white : AppOverlays.w33,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
