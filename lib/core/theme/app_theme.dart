import 'package:flutter/material.dart';

class AppColors {
  // ── 브랜드 액센트 (변경 없음) ─────────────────────────────────────────────
  static const primary = Color(0xFF8B5CF6);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryDark = Color(0xFF5B21B6);
  static const accent = Color(0xFFD946EF);

  // ── 다크 모드 중립 서피스 (퍼플 제거, 순수 블랙 계열) ────────────────────
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const dark = Color(0xFF0A0A0A);
  static const darkGray = Color(0xFF141414);
  static const midDark = Color(0xFF1E1E1E);

  // ── 기존 호환 레거시 (점진 교체) ─────────────────────────────────────────
  static const greyMid = Color(0xFF6D5FA0);
  static const grey = Color(0xFF8E8E93);
  static const greyLight = Color(0xFF7C6FAB);
  static const greyPale = Color(0xFFAEAEB2);
  static const danger = Color(0xFFFF3B30);
  static const blue = Color(0xFF60A5FA);
  static const gold = Color(0xFFF59E0B);

  static const List<Color> primaryGradient = [primaryLight, primary];
  static const List<Color> heroGradient = [Color(0xFF141414), Color(0xFF0A0A0A)];

  static const glassWhite = Color(0xA6FFFFFF);
  static const glassBorder = Color(0x80FFFFFF);

  // ── 텍스트 ───────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textMuted = Color(0xFF888888);
  static const textOnPastel = Color(0xFF1A0F3D);

  // ── 다크 배경 변형 ────────────────────────────────────────────────────────
  static const bgDeepBlack = Color(0xFF050505);
  static const bgWarmDark = Color(0xFF111111);
  static const bgControlPill = Color(0xFF1A1A1A);
  static const bgCosmicCardStart = Color(0xFF141414);
  static const bgCosmicCardEnd = Color(0xFF0A0A0A);
  static const bgLockedStart = Color(0xFF1A1A1A);
  static const bgLockedEnd = Color(0xFF0D0D0D);

  // ── 파스텔 ───────────────────────────────────────────────────────────────
  static const pastelLavender = Color(0xFFC7BFFF);
  static const pastelYellow = Color(0xFFFFE9A8);
  static const pastelMint = Color(0xFFBFEFE4);
  static const pastelPink = Color(0xFFF5C9E0);
  static const pastelPeach = Color(0xFFFFD3B6);

  static const warmCream = Color(0xFFFFFAF0);
  static const warmAmber = Color(0xFFFFB347);
  static const warmHoney = Color(0xFFFFC857);
  static const warmGold = Color(0xFFFFD888);
  static const warmBrown = Color(0xFF7A4A1A);
}

/// 글래스 오버레이
class AppOverlays {
  static const w04 = Color(0x0AFFFFFF);
  static const w06 = Color(0x0FFFFFFF);
  static const w08 = Color(0x14FFFFFF);
  static const w12 = Color(0x1FFFFFFF);
  static const w15 = Color(0x26FFFFFF);
  static const w25 = Color(0x40FFFFFF);
  static const w33 = Color(0x55FFFFFF);
  static const w50 = Color(0x80FFFFFF);
  static const w67 = Color(0xAAFFFFFF);
  static const w80 = Color(0xCCFFFFFF);
  static const w85 = Color(0xD9FFFFFF);
}

/// 탭별 테마 컬러
class TabTheme {
  final Color accent;
  final Color deep;
  final Color light;
  final Color bgStart;
  final Color bgEnd;

  const TabTheme({
    required this.accent,
    required this.deep,
    required this.light,
    required this.bgStart,
    required this.bgEnd,
  });

  static const map = TabTheme(
    accent: Color(0xFF5A9970),
    deep: Color(0xFF2A6B4A),
    light: Color(0xFF8AB89A),
    bgStart: Color(0xFFFFFFFF),
    bgEnd: Color(0xFFD2E5D8),
  );

  static const pinCollection = TabTheme(
    accent: Color(0xFF8B5CF6),
    deep: Color(0xFF5B21B6),
    light: Color(0xFFA78BFA),
    bgStart: Color(0xFFFFFFFF),
    bgEnd: Color(0xFFC7BFFF),
  );

  static const badge = TabTheme(
    accent: Color(0xFFF2A66B),
    deep: Color(0xFFE04A1F),
    light: Color(0xFFFFE5D0),
    bgStart: Color(0xFFFFE5D0),
    bgEnd: Color(0xFFF2A66B),
  );

  static const activity = TabTheme(
    accent: Color(0xFF34D399),
    deep: Color(0xFF0F766E),
    light: Color(0xFFBFEFE4),
    bgStart: Color(0xFFE6FAF5),
    bgEnd: Color(0xFF7BC9B5),
  );

  static const profile = TabTheme(
    accent: Color(0xFF3B82F6),
    deep: Color(0xFF1E40AF),
    light: Color(0xFF93C5FD),
    bgStart: Color(0xFFDCEDFF),
    bgEnd: Color(0xFFBFDBFE),
  );
}

class AppTokens {
  static const radiusCard = 28.0;
  static const radiusPill = 999.0;
  static const radiusChip = 20.0;
  static const radiusButton = 18.0;

  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const spaceLg = 16.0;
  static const spaceXl = 24.0;
  static const space2xl = 32.0;

  static const sizeDisplay = 40.0;
  static const sizeH1 = 32.0;
  static const sizeH2 = 22.0;
  static const sizeH3 = 17.0;
  static const sizeBody = 14.0;
  static const sizeCaption = 12.0;
  static const sizeTag = 11.0;

  static const fontDisplay = 'Pretendard';
  static const fontBody = 'Pretendard';
}

class AppEmotions {
  static const Map<String, Color> colors = {
    '좋아요': AppColors.primary,
    '별로에요': AppColors.greyPale,
  };

  static const Map<String, IconData> icons = {
    '좋아요': Icons.favorite_rounded,
    '별로에요': Icons.thumb_down_alt_rounded,
  };

  static Color colorOf(String e) => colors[e] ?? AppColors.primary;
  static IconData iconOf(String e) => icons[e] ?? Icons.circle;
}

// ─── 테마 프리셋 ──────────────────────────────────────────────────────────────

class AppThemePreset {
  final String name;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final bool isCustom;

  const AppThemePreset({
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    this.isCustom = false,
  });

  // ── WCAG 접근성 헬퍼 ──────────────────────────────────────────────────────

  /// WCAG 2.1 대비 비율: (lighter + 0.05) / (darker + 0.05)
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker  = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 배경 bg 기준으로 minRatio 이상이 될 때까지 HSL 밝기 조정.
  /// 12회 이진 탐색 후에도 기준 미달이면 브랜드 보라(#8B5CF6) 반환.
  static Color enforceContrast(
    Color color,
    Color bg, {
    double minRatio = 4.5,
    Color fallback = const Color(0xFF8B5CF6),
  }) {
    if (contrastRatio(color, bg) >= minRatio) return color;

    final hsl    = HSLColor.fromColor(color);
    final goUp   = bg.computeLuminance() < 0.18; // 어두운 bg → 밝게
    double lo    = goUp ? hsl.lightness : 0.0;
    double hi    = goUp ? 1.0 : hsl.lightness;

    for (int i = 0; i < 14; i++) {
      final mid  = (lo + hi) / 2;
      final c    = hsl.withLightness(mid).toColor();
      final ok   = contrastRatio(c, bg) >= minRatio;
      if (goUp) {
        if (ok) { hi = mid; } else { lo = mid; }
      } else {
        if (ok) { lo = mid; } else { hi = mid; }
      }
    }

    final adjusted = hsl.withLightness(goUp ? hi : lo).toColor();
    return contrastRatio(adjusted, bg) >= minRatio ? adjusted : fallback;
  }

  // 임의 색상으로 preset 생성 — WCAG 검증 + light/dark 자동 도출
  factory AppThemePreset.fromColor(Color color, {String name = '커스텀'}) {
    final lum = color.computeLuminance();

    // 극단값 (거의 검정/흰색) → 브랜드 보라 폴백
    Color safe = color;
    if (lum < 0.03 || lum > 0.88) {
      safe = const Color(0xFF8B5CF6);
    }

    final hsl  = HSLColor.fromColor(safe);
    final light = hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
    final dark  = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();

    return AppThemePreset(
      name: name,
      primary: safe,
      primaryLight: light,
      primaryDark: dark,
      isCustom: true,
    );
  }

  // 어떤 primary 색상 위에서도 가독성 있는 텍스트 색상
  Color get onPrimary =>
      primary.computeLuminance() > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;

  static const purple = AppThemePreset(
    name: '보라',
    primary: Color(0xFF8B5CF6),
    primaryLight: Color(0xFFA78BFA),
    primaryDark: Color(0xFF5B21B6),
  );
  static const yellow = AppThemePreset(
    name: '노랑',
    primary: Color(0xFFFFCC00),
    primaryLight: Color(0xFFFFE066),
    primaryDark: Color(0xFFB89400),
  );
  static const blue = AppThemePreset(
    name: '파랑',
    primary: Color(0xFF3B82F6),
    primaryLight: Color(0xFF60A5FA),
    primaryDark: Color(0xFF1D4ED8),
  );
  static const green = AppThemePreset(
    name: '초록',
    primary: Color(0xFF22C55E),
    primaryLight: Color(0xFF4ADE80),
    primaryDark: Color(0xFF15803D),
  );
  static const orange = AppThemePreset(
    name: '주황',
    primary: Color(0xFFF97316),
    primaryLight: Color(0xFFFB923C),
    primaryDark: Color(0xFFC2410C),
  );
  static const pink = AppThemePreset(
    name: '분홍',
    primary: Color(0xFFEC4899),
    primaryLight: Color(0xFFF472B6),
    primaryDark: Color(0xFF9D174D),
  );
  static const red = AppThemePreset(
    name: '빨강',
    primary: Color(0xFFEF4444),
    primaryLight: Color(0xFFF87171),
    primaryDark: Color(0xFFB91C1C),
  );
  static const teal = AppThemePreset(
    name: '청록',
    primary: Color(0xFF14B8A6),
    primaryLight: Color(0xFF2DD4BF),
    primaryDark: Color(0xFF0F766E),
  );
  static const indigo = AppThemePreset(
    name: '인디고',
    primary: Color(0xFF6366F1),
    primaryLight: Color(0xFF818CF8),
    primaryDark: Color(0xFF4338CA),
  );
  static const amber = AppThemePreset(
    name: '앰버',
    primary: Color(0xFFF59E0B),
    primaryLight: Color(0xFFFBBF24),
    primaryDark: Color(0xFFB45309),
  );

  static const List<AppThemePreset> presets = [
    purple, yellow, blue, green, orange, pink,
    red, teal, indigo, amber,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemePreset && runtimeType == other.runtimeType &&
      primary.toARGB32() == other.primary.toARGB32();

  @override
  int get hashCode => primary.toARGB32().hashCode;
}

// ─── 테마 스코프 ──────────────────────────────────────────────────────────────

class AppThemeScope extends InheritedWidget {
  final AppThemePreset preset;

  const AppThemeScope({
    super.key,
    required this.preset,
    required super.child,
  });

  static AppThemePreset of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.preset ??
      AppThemePreset.purple;

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) => preset != oldWidget.preset;
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F2F2),
      cardColor: Colors.white,
      fontFamily: 'Pretendard',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF0A0A0A),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      fontFamily: 'Pretendard',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

// BuildContext 확장
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => isDark ? const Color(0xFF141414) : Colors.white;
  Color get labelColor => isDark ? Colors.white : const Color(0xFF0A0A0A);
  Color get subLabelColor => isDark ? const Color(0xFF888888) : const Color(0xFF6B6B6B);
  Color get separatorColor => isDark
      ? const Color(0xFF222222)
      : Colors.black.withValues(alpha: 0.05);
  Color get iconBgColor => isDark
      ? const Color(0xFF1E1E1E)
      : Colors.black.withValues(alpha: 0.05);

  Color get sheetBg => isDark ? const Color(0xFF141414) : Colors.white;
  Color get glassBtnBg => isDark
      ? const Color(0xFF1E1E1E)
      : Colors.white.withValues(alpha: 0.85);
  Color get glassBorder => isDark
      ? const Color(0xFF2A2A2A)
      : Colors.black.withValues(alpha: 0.08);
  Color get navBg => isDark ? const Color(0xFF0F0F0F) : Colors.white;
  Color get chipBg => isDark
      ? const Color(0xFF1E1E1E)
      : Colors.white.withValues(alpha: 0.85);
  Color get chipBorder => isDark
      ? const Color(0xFF2A2A2A)
      : Colors.black.withValues(alpha: 0.06);
  Color get handleColor => isDark
      ? const Color(0xFF444444)
      : Colors.black.withValues(alpha: 0.15);
  Color get countBadgeBg => isDark
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFEEEEEE);
  Color get emptyStateBg => isDark
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF0F0F0);
  Color get progressBg => isDark
      ? const Color(0xFF2A2A2A)
      : Colors.black.withValues(alpha: 0.08);
  Color get fieldBg => isDark
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFF0F0F0);
  Color get hintColor => isDark
      ? const Color(0xFF555555)
      : Colors.black.withValues(alpha: 0.28);

  // Adaptive glass/cosmic card (dark gradient on dark, white on light)
  Color get glassCardStart => isDark ? AppColors.bgCosmicCardStart : Colors.white;
  Color get glassCardEnd => isDark ? AppColors.bgCosmicCardEnd : const Color(0xFFF6F6F6);
  List<BoxShadow>? get glassCardShadow => isDark
      ? null
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ];

  // Adaptive circle icon bg (dark on dark, light gray on light)
  Color get circleIconBg => isDark
      ? const Color(0xFF1A1A1A)
      : Colors.black.withValues(alpha: 0.05);

  // Adaptive overlay pill bg
  Color get overlayPillBg => isDark
      ? AppOverlays.w08
      : Colors.black.withValues(alpha: 0.04);
  Color get overlayPillBorder => isDark
      ? AppOverlays.w12
      : Colors.black.withValues(alpha: 0.07);

  // ── 테마 컬러 (AppThemeScope 에서 읽음) ──────────────────────────────────────
  AppThemePreset get themePreset => AppThemeScope.of(this);
  Color get primaryColor => themePreset.primary;
  Color get primaryLightColor => themePreset.primaryLight;
  Color get primaryDarkColor => themePreset.primaryDark;

  // 라이트 배경 기준 레퍼런스 (#F5F3EE 근사, luminance ≈ 0.89)
  static const _kLightBg = Color(0xFFF5F3EE);
  // 다크 배경 기준 레퍼런스 (#0D0820 근사, luminance ≈ 0.002)
  static const _kDarkBg  = Color(0xFF0D0820);

  /// 라이트 배경 위에서 WCAG 4.5:1 이상이 보장된 primaryColor.
  Color get readablePrimary =>
      AppThemePreset.enforceContrast(primaryColor, _kLightBg);

  /// 다크 배경 위에서 WCAG 4.5:1 이상이 보장된 primaryColor.
  Color get readablePrimaryOnDark =>
      AppThemePreset.enforceContrast(primaryColor, _kDarkBg);

  /// primaryColor 배경 위에서 가독성 있는 텍스트 색상 (밝으면 어두운 색, 어두우면 흰색).
  Color get onPrimaryColor => themePreset.onPrimary;
}
