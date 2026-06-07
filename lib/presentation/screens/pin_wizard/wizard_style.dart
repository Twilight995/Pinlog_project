import 'package:flutter/material.dart';

/// 위자드 테마 토큰.
///
/// 두 가지 프리셋:
/// - [WizardStyle.light]  라이트 클린 (기본값)
/// - [WizardStyle.cosmic] 다크 코스믹 글로우 (대안 테마)
class WizardStyle {
  final Color background;
  final bool hasCosmic;       // CosmicBackground 오버레이 사용 여부
  final Color heading;        // 큰 질문 텍스트
  final Color stepLabel;      // "STEP N OF 5"
  final Color muted;          // subtitle · label · skip · counter
  final Color surface;        // 카드/입력 배경
  final Color surfaceBorder;  // 카드 테두리 (중립)
  final Color onSurface;      // 카드 위 텍스트 (입력값)
  final Color hint;           // placeholder
  final Color dotActive;      // 진행 표시 도트 — 활성
  final Color dotInactive;    // 진행 표시 도트 — 비활성
  final Color iconBtnBg;      // 원형 뒤로/닫기 버튼 배경
  final Color iconBtnBorder;
  final Color iconBtnFg;      // 원형 버튼 아이콘 색
  final Color accent;          // 버튼 그라디언트 끝 / 진한 강조색
  final Color accentLight;     // 버튼 그라디언트 시작 / 연한 강조색
  final Color disabledBtnBg1; // 기본 버튼 비활성 그라디언트 시작
  final Color disabledBtnBg2; // 기본 버튼 비활성 그라디언트 끝
  final Color disabledBtnFg;  // 기본 버튼 비활성 텍스트/아이콘

  const WizardStyle({
    required this.background,
    required this.hasCosmic,
    required this.heading,
    required this.stepLabel,
    required this.muted,
    required this.surface,
    required this.surfaceBorder,
    required this.onSurface,
    required this.hint,
    required this.dotActive,
    required this.dotInactive,
    required this.iconBtnBg,
    required this.iconBtnBorder,
    required this.iconBtnFg,
    required this.accent,
    required this.accentLight,
    required this.disabledBtnBg1,
    required this.disabledBtnBg2,
    required this.disabledBtnFg,
  });

  /// 라이트 클린 테마 — 기본값.
  static const light = WizardStyle(
    background: Color(0xFFF2F2F7),
    hasCosmic: false,
    heading: Color(0xFF0A0A0A),
    stepLabel: Color(0xFF8B5CF6),
    muted: Color(0xFF6B6B6B),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x14000000),
    onSurface: Color(0xFF0A0A0A),
    hint: Color(0x44000000),
    dotActive: Color(0xFF8B5CF6),
    dotInactive: Color(0x22000000),
    iconBtnBg: Color(0xFFEEEEEE),
    iconBtnBorder: Color(0x0A000000),
    iconBtnFg: Color(0xFF0A0A0A),
    accent: Color(0xFF7C3AED),
    accentLight: Color(0xFFA78BFA),
    disabledBtnBg1: Color(0xFFE8E8E8),
    disabledBtnBg2: Color(0xFFDDDDDD),
    disabledBtnFg: Color(0xFFAAAAAA),
  );

  static WizardStyle fromTheme(Color primary, {bool isDark = false}) {
    final hsl = HSLColor.fromColor(primary);
    final lighter = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    if (isDark) {
      return WizardStyle(
        background: const Color(0xFF0C0C10),
        hasCosmic: false,
        heading: const Color(0xFFFFFFFF),
        stepLabel: primary,
        muted: const Color(0xFF8E8E93),
        surface: const Color(0xFF1C1C1E),
        surfaceBorder: const Color(0x22FFFFFF),
        onSurface: const Color(0xFFFFFFFF),
        hint: const Color(0x50FFFFFF),
        dotActive: primary,
        dotInactive: const Color(0x30FFFFFF),
        iconBtnBg: const Color(0x18FFFFFF),
        iconBtnBorder: const Color(0x22FFFFFF),
        iconBtnFg: const Color(0xEEFFFFFF),
        accent: primary,
        accentLight: lighter,
        disabledBtnBg1: const Color(0x18FFFFFF),
        disabledBtnBg2: const Color(0x12FFFFFF),
        disabledBtnFg: const Color(0x55FFFFFF),
      );
    }
    return WizardStyle(
      background: const Color(0xFFF2F2F7),
      hasCosmic: false,
      heading: const Color(0xFF0A0A0A),
      stepLabel: primary,
      muted: const Color(0xFF6B6B6B),
      surface: const Color(0xFFFFFFFF),
      surfaceBorder: const Color(0x14000000),
      onSurface: const Color(0xFF0A0A0A),
      hint: const Color(0x44000000),
      dotActive: primary,
      dotInactive: const Color(0x22000000),
      iconBtnBg: const Color(0xFFEEEEEE),
      iconBtnBorder: const Color(0x0A000000),
      iconBtnFg: const Color(0xFF0A0A0A),
      accent: primary,
      accentLight: lighter,
      disabledBtnBg1: const Color(0xFFE8E8E8),
      disabledBtnBg2: const Color(0xFFDDDDDD),
      disabledBtnFg: const Color(0xFFAAAAAA),
    );
  }

  /// 다크 코스믹 테마 — 구 기본값, 선택 가능 테마로 보존.
  static const cosmic = WizardStyle(
    background: Color(0xFF000000),
    hasCosmic: true,
    heading: Color(0xFFFFFFFF),
    stepLabel: Color(0xFFA78BFA),
    muted: Color(0xFF888888),
    surface: Color(0x0FFFFFFF),
    surfaceBorder: Color(0x26FFFFFF),
    onSurface: Color(0xFFFFFFFF),
    hint: Color(0x40FFFFFF),
    dotActive: Color(0xFFA78BFA),
    dotInactive: Color(0x40FFFFFF),
    iconBtnBg: Color(0x14FFFFFF),
    iconBtnBorder: Color(0x26FFFFFF),
    iconBtnFg: Color(0xD9FFFFFF),
    accent: Color(0xFF7C3AED),
    accentLight: Color(0xFFA78BFA),
    disabledBtnBg1: Color(0x1FFFFFFF),
    disabledBtnBg2: Color(0x14FFFFFF),
    disabledBtnFg: Color(0x80FFFFFF),
  );
}

/// [WizardStyle]을 하위 트리에 주입하는 InheritedWidget.
class WizardStyleScope extends InheritedWidget {
  final WizardStyle style;

  const WizardStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  static WizardStyle of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WizardStyleScope>()
          ?.style ??
      WizardStyle.light;

  @override
  bool updateShouldNotify(WizardStyleScope old) => old.style != style;
}

/// BuildContext 확장 — `context.ws.heading` 형태로 토큰 접근.
extension WizardStyleX on BuildContext {
  WizardStyle get ws => WizardStyleScope.of(this);
}
