import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 색상 직접 설정 바텀시트 — HSL 슬라이더 3개 (색조/채도/밝기)
class AppColorPickerSheet extends StatefulWidget {
  final Color? initial;
  final ValueChanged<Color> onPick;

  const AppColorPickerSheet({super.key, this.initial, required this.onPick});

  @override
  State<AppColorPickerSheet> createState() => _AppColorPickerSheetState();
}

class _AppColorPickerSheetState extends State<AppColorPickerSheet> {
  late double _hue;
  late double _saturation;
  late double _lightness;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final hsl = HSLColor.fromColor(widget.initial!);
      _hue = hsl.hue;
      _saturation = hsl.saturation.clamp(0.0, 1.0);
      _lightness = hsl.lightness.clamp(0.05, 0.95);
    } else {
      _hue = 200.0;
      _saturation = 0.78;
      _lightness = 0.52;
    }
  }

  Color get _color =>
      HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();

  Color get _onColor =>
      _color.computeLuminance() > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, pad + 24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.chipBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '색상 직접 설정',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.labelColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, size: 20, color: context.subLabelColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('색조', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.subLabelColor)),
          const SizedBox(height: 8),
          AppGradientSlider(
            value: _hue / 360.0,
            gradientColors: const [
              Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
              Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
            ],
            onChanged: (v) => setState(() => _hue = v * 360.0),
          ),
          const SizedBox(height: 16),
          Text('채도', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.subLabelColor)),
          const SizedBox(height: 8),
          AppGradientSlider(
            value: _saturation,
            gradientColors: [
              HSLColor.fromAHSL(1.0, _hue, 0.0, _lightness).toColor(),
              HSLColor.fromAHSL(1.0, _hue, 1.0, _lightness).toColor(),
            ],
            onChanged: (v) => setState(() => _saturation = v),
          ),
          const SizedBox(height: 16),
          Text('밝기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.subLabelColor)),
          const SizedBox(height: 8),
          AppGradientSlider(
            value: (_lightness - 0.05) / 0.90,
            gradientColors: [
              HSLColor.fromAHSL(1.0, _hue, _saturation, 0.05).toColor(),
              HSLColor.fromAHSL(1.0, _hue, _saturation, 0.95).toColor(),
            ],
            onChanged: (v) => setState(() => _lightness = v * 0.90 + 0.05),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onPick(_color);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 52,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '이 색상 적용하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _onColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppGradientSlider extends StatelessWidget {
  final double value;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  const AppGradientSlider({
    super.key,
    required this.value,
    required this.gradientColors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const thumbW = 22.0;
      final thumbX = (value * (w - thumbW)).clamp(0.0, w - thumbW);

      void handleDx(double dx) => onChanged((dx / w).clamp(0.0, 1.0));

      return GestureDetector(
        onHorizontalDragUpdate: (d) => handleDx(d.localPosition.dx),
        onTapDown: (d) => handleDx(d.localPosition.dx),
        child: SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              Positioned(
                left: thumbX,
                child: Container(
                  width: thumbW,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: const [
                      BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
