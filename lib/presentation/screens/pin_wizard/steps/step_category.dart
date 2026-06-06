import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/common/color_picker_sheet.dart';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryGrid(
              selected: widget.data.pinShape,
              onSelect: (shape) {
                HapticFeedback.selectionClick();
                widget.data.pinShape = shape;
                widget.onChange();
                setState(() {});
              },
            ),
            const SizedBox(height: 28),
            _PinColorPicker(
              data: widget.data,
              onChange: () {
                widget.onChange();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
          ],
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

// ─── 핀 색상 피커 ─────────────────────────────────────────────────────────────

const _outerPresets = <Color?>[
  null,               // 테마 색 (기본)
  Color(0xFFFF3B30),  // 레드
  Color(0xFFFF9500),  // 오렌지
  Color(0xFFFFCC00),  // 옐로우
  Color(0xFF34C759),  // 그린
  Color(0xFF00C7BE),  // 틸
  Color(0xFF007AFF),  // 블루
  Color(0xFF5856D6),  // 퍼플
  Color(0xFFFF2D55),  // 핑크
  Color(0xFFAF52DE),  // 바이올렛
  Color(0xFFFFFFFF),  // 화이트
  Color(0xFF8E8E93),  // 그레이
];

const _innerPresets = <Color?>[
  null,               // 자동 (외부 색 기반 다크)
  Color(0xFF0A0A0A),  // 블랙
  Color(0xFF1C1C1E),  // 차콜
  Color(0xFF0A1628),  // 다크 네이비
  Color(0xFF0F2D1F),  // 다크 그린
  Color(0xFF1A0A28),  // 다크 퍼플
  Color(0xFF280A10),  // 다크 레드
  Color(0xFFBF2626),  // 레드
  Color(0xFFBF6000),  // 오렌지
  Color(0xFF1A7A3C),  // 그린
  Color(0xFF0055BF),  // 블루
  Color(0xFF5B21B6),  // 퍼플
  Color(0xFFBF1A5F),  // 핑크
  Color(0xFF0D7377),  // 틸
  Color(0xFFD4A017),  // 골드
  Color(0xFF6B3A2A),  // 브라운
  Color(0xFF5C5C6E),  // 슬레이트
  Color(0xFFE5E5EA),  // 라이트 그레이
  Color(0xFFFFFFFF),  // 화이트
];

class _PinColorPicker extends StatelessWidget {
  final WizardData data;
  final VoidCallback onChange;

  const _PinColorPicker({required this.data, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    final themeAccent = context.primaryColor;
    final outerColor = data.pinOuterColor != null
        ? Color(data.pinOuterColor!)
        : themeAccent;
    final innerColor = data.pinInnerColor != null
        ? Color(data.pinInnerColor!)
        : _deriveDarkBody(outerColor);

    final svgPath = AppConstants.pinShapeSvgs[data.pinShape] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 라벨 + 미리보기
        Row(
          children: [
            Text(
              '핀 색상',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ws.muted,
                letterSpacing: 0.4,
                fontFamily: AppTokens.fontBody,
              ),
            ),
            const Spacer(),
            _PinPreview(
              outerColor: outerColor,
              innerColor: innerColor,
              svgPath: svgPath,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 외부 (테두리/글로우)
        Text(
          '테두리 / 글로우',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: ws.muted.withValues(alpha: 0.7),
            fontFamily: AppTokens.fontBody,
          ),
        ),
        const SizedBox(height: 8),
        _ColorSwatchRow(
          presets: _outerPresets,
          selectedArgb: data.pinOuterColor,
          themeColor: themeAccent,
          onSelect: (c) {
            data.pinOuterColor = c?.toARGB32();
            onChange();
          },
        ),
        const SizedBox(height: 14),

        // 내부 (바디)
        Text(
          '핀 내부',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: ws.muted.withValues(alpha: 0.7),
            fontFamily: AppTokens.fontBody,
          ),
        ),
        const SizedBox(height: 8),
        _ColorSwatchRow(
          presets: _innerPresets,
          selectedArgb: data.pinInnerColor,
          themeColor: _deriveDarkBody(outerColor),
          onSelect: (c) {
            data.pinInnerColor = c?.toARGB32();
            onChange();
          },
        ),
      ],
    );
  }

  Color _deriveDarkBody(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness(0.10)
        .withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: 0.96);
  }
}

class _PinPreview extends StatelessWidget {
  final Color outerColor;
  final Color innerColor;
  final String svgPath;

  const _PinPreview({
    required this.outerColor,
    required this.innerColor,
    required this.svgPath,
  });

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final lighter = Color.lerp(outerColor, Colors.white, 0.35)!;
    final darker = Color.lerp(outerColor, Colors.black, 0.15)!;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: outerColor.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // border ring (gradient via ShaderMask)
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [lighter, darker],
            ).createShader(rect),
            child: Container(
              width: size - 2,
              height: size - 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          // body
          Container(
            width: size - 7,
            height: size - 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: innerColor,
            ),
          ),
          // icon
          if (svgPath.isNotEmpty)
            SvgPicture.asset(
              svgPath,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
        ],
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final List<Color?> presets;
  final int? selectedArgb;
  final Color themeColor;
  final ValueChanged<Color?> onSelect;

  const _ColorSwatchRow({
    required this.presets,
    required this.selectedArgb,
    required this.themeColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...presets.map((c) {
            final argb = c?.toARGB32();
            final isSelected = selectedArgb == argb;
            final displayColor = c ?? themeColor;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(c);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: displayColor,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.10),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: displayColor.withValues(alpha: 0.5),
                            blurRadius: 5,
                          )
                        ]
                      : null,
                ),
                child: c == null
                    ? Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      )
                    : null,
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AppColorPickerSheet(
                  initial: selectedArgb != null ? Color(selectedArgb!) : null,
                  onPick: (c) => onSelect(c),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                    Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
