import 'package:flutter/material.dart';

class AppColors {
  // ── 자연 테마 팔레트 (라이프 로그 다이어리 감성) ────────────────────────────
  static const primary = Color(0xFF52B788);     // 세이지 그린 — 메인 액센트
  static const primaryLight = Color(0xFFB5E48C); // 연한 그린 — 그라디언트 밝은 끝
  static const primaryDark = Color(0xFF2D6A4F);  // 딥 포레스트 — 그라디언트 어두운 끝
  static const accent = Color(0xFFE9C46A);       // 웜 골드 — 보조 액센트
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const dark = Color(0xFF1C1C1E);
  static const darkGray = Color(0xFF3A3A3C);
  static const midDark = Color(0xFF48484A);
  static const greyMid = Color(0xFF636366);
  static const grey = Color(0xFF8E8E93);
  static const greyLight = Color(0xFF6E6E73);
  static const greyPale = Color(0xFFAEAEB2);
  static const danger = Color(0xFFFF3B30);       // 삭제 등 위험 액션 전용
  static const blue = Color(0xFF5DADE2);         // 스카이 블루 — 통계/정보
  static const gold = Color(0xFFE9C46A);         // 웜 골드 — 활동 일수

  // 그라디언트 헬퍼
  static const List<Color> primaryGradient = [primaryLight, primary];
  static const List<Color> heroGradient = [Color(0xFF1B4332), Color(0xFF081C15)];

  static const glassWhite = Color(0xA6FFFFFF);
  static const glassBorder = Color(0x80FFFFFF);
}

class AppEmotions {
  static const Map<String, Color> colors = {
    '좋아요': AppColors.primary,      // 세이지 그린 — 긍정적 기억
    '별로에요': AppColors.greyPale,    // 연한 회색 — 무관심·부정
  };

  static const Map<String, IconData> icons = {
    '좋아요': Icons.favorite_rounded,
    '별로에요': Icons.thumb_down_alt_rounded,
  };

  static Color colorOf(String e) => colors[e] ?? AppColors.primary;
  static IconData iconOf(String e) => icons[e] ?? Icons.circle;
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
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      cardColor: Colors.white,
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.dark,
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
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      cardColor: const Color(0xFF2C2C2E),
      fontFamily: 'SF Pro Display',
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

// BuildContext 확장 — 다크/라이트 모드 대응 색상
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => Theme.of(this).cardColor;
  Color get labelColor => isDark ? Colors.white : AppColors.dark;
  Color get subLabelColor => isDark ? const Color(0xFF8E8E93) : AppColors.grey;
  Color get separatorColor => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.05);
  Color get iconBgColor => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.05);

  // 시트 / 패널 배경 (BackdropFilter 뒤에서 사용)
  Color get sheetBg => isDark
      ? const Color(0xFF2C2C2E).withValues(alpha: 0.96)
      : Colors.white.withValues(alpha: 0.88);
  // 유리 버튼 비활성 배경
  Color get glassBtnBg => isDark
      ? const Color(0xFF3A3A3C).withValues(alpha: 0.9)
      : Colors.white.withValues(alpha: 0.65);
  // 유리 테두리
  Color get glassBorder => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.5);
  // 내비게이션 바 배경
  Color get navBg => isDark
      ? const Color(0xFF2C2C2E).withValues(alpha: 0.92)
      : Colors.white.withValues(alpha: 0.85);
  // 비활성 칩 배경
  Color get chipBg => isDark
      ? const Color(0xFF3A3A3C)
      : Colors.white.withValues(alpha: 0.85);
  // 비활성 칩 테두리
  Color get chipBorder => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);
  // 드래그 핸들
  Color get handleColor => isDark
      ? Colors.white.withValues(alpha: 0.25)
      : Colors.black.withValues(alpha: 0.15);
  // 숫자 뱃지 배경
  Color get countBadgeBg => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.07);
  // 빈 상태 아이콘 원형 배경 등 약한 배경
  Color get emptyStateBg => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.05);
  // 프로그레스 바 트랙
  Color get progressBg => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);
  // 텍스트 필드 배경
  Color get fieldBg => isDark
      ? const Color(0xFF3A3A3C)
      : Colors.white.withValues(alpha: 0.9);
  // 텍스트 필드 힌트
  Color get hintColor => isDark
      ? Colors.white.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.28);
}
