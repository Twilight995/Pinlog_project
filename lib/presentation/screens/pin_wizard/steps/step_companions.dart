import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';

/// 위자드 Step 4 — 날씨 + 동행자.
///
/// "누구와 / 함께였나요?" — 날씨 칩 + 동행자 입력 + 칩 목록.
/// 동행자는 옵션 — "혼자였어요"로 스킵 가능. 날씨는 항상 선택돼있음(기본값 맑음).
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

  void _selectWeather(String w) {
    HapticFeedback.selectionClick();
    widget.data.weather = w;
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
      stepLabel: 'STEP 4 OF 5',
      questionTop: '누구와',
      questionBottom: '함께였나요?',
      subtitle: '오늘의 날씨와 함께 남겨두세요',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
        skipLabel: hasCompanions ? null : '혼자였어요',
        onSkip: hasCompanions ? null : widget.onSkip,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 날씨 ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '오늘의 날씨',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              Text(
                _WeatherMeta.captionFor(widget.data.weather),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      _WeatherMeta.metaFor(widget.data.weather).gradient.last,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: Row(
              children: List.generate(AppConstants.weathers.length, (i) {
                final w = AppConstants.weathers[i];
                final selected = w == widget.data.weather;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == AppConstants.weathers.length - 1 ? 0 : 8,
                    ),
                    child: _WeatherTile(
                      label: w,
                      meta: _WeatherMeta.metaFor(w),
                      selected: selected,
                      onTap: () => _selectWeather(w),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 28),
          // ── 동행자 ──────────────────────────────────────────────────
          const Text(
            '동행자',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(height: 10),
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
      ),
    );
  }
}

/// 날씨별 분위기 (그라디언트 + 한 줄 캡션).
class _WeatherMeta {
  final String emoji;
  final List<Color> gradient;
  final String caption;
  const _WeatherMeta({
    required this.emoji,
    required this.gradient,
    required this.caption,
  });

  /// 라벨 텍스트(예: '☀️ 맑음')에서 이모지를 떼고 핵심 단어로 매칭.
  static _WeatherMeta metaFor(String label) {
    if (label.contains('맑음')) {
      return const _WeatherMeta(
        emoji: '☀️',
        gradient: [Color(0xFFFFD27A), Color(0xFFF59E5C)],
        caption: '따스한 햇살이 닿던 날',
      );
    }
    if (label.contains('비')) {
      return const _WeatherMeta(
        emoji: '🌧',
        gradient: [Color(0xFF8FA8D8), Color(0xFF4A6FB5)],
        caption: '빗방울이 마음을 두드리던 날',
      );
    }
    if (label.contains('흐림')) {
      return const _WeatherMeta(
        emoji: '☁️',
        gradient: [Color(0xFFCABBE0), Color(0xFF8B7BAF)],
        caption: '잿빛 하늘이 포근하던 날',
      );
    }
    if (label.contains('눈')) {
      return const _WeatherMeta(
        emoji: '🌨',
        gradient: [Color(0xFFE7F0FA), Color(0xFFA8C9E8)],
        caption: '하얗게 내려앉던 고요',
      );
    }
    if (label.contains('바람')) {
      return const _WeatherMeta(
        emoji: '🌬',
        gradient: [Color(0xFFB3E6D3), Color(0xFF55AE8E)],
        caption: '시원한 바람결이 스치던 날',
      );
    }
    return const _WeatherMeta(
      emoji: '🌤',
      gradient: [Color(0xFFFFD27A), Color(0xFFF59E5C)],
      caption: '오늘의 공기',
    );
  }

  static String captionFor(String label) => metaFor(label).caption;
}

class _WeatherTile extends StatelessWidget {
  final String label; // 예: '☀️ 맑음'
  final _WeatherMeta meta;
  final bool selected;
  final VoidCallback onTap;

  const _WeatherTile({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 라벨에서 이모지 뒤 텍스트만 추출 ('☀️ 맑음' → '맑음').
    final words = label.trim().split(' ');
    final name = words.length > 1 ? words.sublist(1).join(' ') : label;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        transform: selected
            ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: meta.gradient,
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    meta.gradient.first.withValues(alpha: 0.10),
                    meta.gradient.last.withValues(alpha: 0.04),
                  ],
                ),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : meta.gradient.last.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: meta.gradient.last.withValues(alpha: 0.50),
                    blurRadius: 22,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(meta.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : AppColors.textPrimary.withValues(alpha: 0.85),
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
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
