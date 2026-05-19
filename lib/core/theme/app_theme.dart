import 'package:flutter/material.dart';

class AppColors {
  // ── 다크 퍼플 우주 테마 팔레트 ──────────────────────────────────────────────
  static const primary = Color(0xFF8B5CF6);      // 바이올렛 — 메인 액센트
  static const primaryLight = Color(0xFFA78BFA); // 연한 바이올렛 — 그라디언트 밝은 끝
  static const primaryDark = Color(0xFF5B21B6);  // 딥 바이올렛 — 그라디언트 어두운 끝
  static const accent = Color(0xFFD946EF);       // 마젠타 — 보조 액센트
  static const background = Color(0xFF0D0B1A);   // 다크 네이비 — 앱 기본 배경
  static const surface = Color(0xFF1E0A3C);      // 다크 퍼플 — 카드/시트 배경
  static const dark = Color(0xFF0D0B1A);
  static const darkGray = Color(0xFF1E0A3C);
  static const midDark = Color(0xFF2D1B69);
  static const greyMid = Color(0xFF6D5FA0);
  static const grey = Color(0xFF8E8E93);
  static const greyLight = Color(0xFF7C6FAB);
  static const greyPale = Color(0xFFAEAEB2);
  static const danger = Color(0xFFFF3B30);       // 삭제 등 위험 액션 전용
  static const blue = Color(0xFF60A5FA);         // 블루 — 통계/정보
  static const gold = Color(0xFFF59E0B);         // 앰버 골드 — 활동 일수

  // 그라디언트 헬퍼
  static const List<Color> primaryGradient = [primaryLight, primary];
  static const List<Color> heroGradient = [Color(0xFF1E0A3C), Color(0xFF0D0B1A)];

  static const glassWhite = Color(0xA6FFFFFF);
  static const glassBorder = Color(0x80FFFFFF);

  // ── 텍스트 (디자인 토큰) ──────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC8C1E0);
  static const textMuted = Color(0xFF7C6FAB);
  static const textOnPastel = Color(0xFF1A0F3D);

  // ── 다크 배경 변형 (디자인 토큰) ────────────────────────────────────────
  static const bgDeepBlack = Color(0xFF0A0612);
  static const bgWarmDark = Color(0xFF16121C); // 네비 / 시트
  static const bgControlPill = Color(0xFF1A1233); // 컨트롤 알약
  static const bgCosmicCardStart = Color(0xFF15101E); // 코스믹 카드 그라디언트 시작
  static const bgCosmicCardEnd = Color(0xFF0A0612);
  static const bgLockedStart = Color(0xFF1B181F); // 잠긴 카드 그라디언트
  static const bgLockedEnd = Color(0xFF0D0B11);

  // ── 파스텔 (디자인 토큰) ────────────────────────────────────────────────
  static const pastelLavender = Color(0xFFC7BFFF);
  static const pastelYellow = Color(0xFFFFE9A8);
  static const pastelMint = Color(0xFFBFEFE4);
  static const pastelPink = Color(0xFFF5C9E0);
  static const pastelPeach = Color(0xFFFFD3B6);

  // ── 따스한 호박 팔레트 (성공 모먼트) ─────────────────────────────────────
  static const warmCream = Color(0xFFFFFAF0);
  static const warmAmber = Color(0xFFFFB347);
  static const warmHoney = Color(0xFFFFC857);
  static const warmGold = Color(0xFFFFD888);
  static const warmBrown = Color(0xFF7A4A1A);
}

/// 글래스 오버레이 — 다크 배경 위에 깔리는 흰 반투명
class AppOverlays {
  static const w04 = Color(0x0AFFFFFF); // 4%
  static const w06 = Color(0x0FFFFFFF); // 6%
  static const w08 = Color(0x14FFFFFF); // 8%
  static const w12 = Color(0x1FFFFFFF); // 12%
  static const w15 = Color(0x26FFFFFF); // 15%
  static const w25 = Color(0x40FFFFFF); // 25%
  static const w33 = Color(0x55FFFFFF); // 33%
  static const w50 = Color(0x80FFFFFF); // 50%
  static const w67 = Color(0xAAFFFFFF); // 67%
  static const w80 = Color(0xCCFFFFFF); // 80%
  static const w85 = Color(0xD9FFFFFF); // 85%
}

/// 탭별 테마 컬러 (각 탭 고유 아이덴티티)
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

  /// 지도 — 마젠타 (장소·핀)
  static const map = TabTheme(
    accent: Color(0xFFE91E8C),
    deep: Color(0xFFC2186F),
    light: Color(0xFFFF4DA1),
    bgStart: Color(0xFFFFFFFF),
    bgEnd: Color(0xFFFFE0EE),
  );

  /// 도감 핀 — 라벤더 (수집)
  static const pinCollection = TabTheme(
    accent: Color(0xFF8B5CF6),
    deep: Color(0xFF5B21B6),
    light: Color(0xFFA78BFA),
    bgStart: Color(0xFFFFFFFF),
    bgEnd: Color(0xFFC7BFFF),
  );

  /// 도감 칭호 — 코랄 (성취)
  static const badge = TabTheme(
    accent: Color(0xFFF2A66B),
    deep: Color(0xFFE04A1F),
    light: Color(0xFFFFE5D0),
    bgStart: Color(0xFFFFE5D0),
    bgEnd: Color(0xFFF2A66B),
  );

  /// 활동 — 민트 (성장)
  static const activity = TabTheme(
    accent: Color(0xFF34D399),
    deep: Color(0xFF0F766E),
    light: Color(0xFFBFEFE4),
    bgStart: Color(0xFFE6FAF5),
    bgEnd: Color(0xFF7BC9B5),
  );

  /// 프로필 — 블루 (정체성)
  static const profile = TabTheme(
    accent: Color(0xFF3B82F6),
    deep: Color(0xFF1E40AF),
    light: Color(0xFF93C5FD),
    bgStart: Color(0xFFDCEDFF),
    bgEnd: Color(0xFFBFDBFE),
  );
}

/// 디자인 토큰 — radius / spacing / font size
class AppTokens {
  // Radius
  static const radiusCard = 28.0;
  static const radiusPill = 999.0;
  static const radiusChip = 20.0;
  static const radiusButton = 18.0;

  // Spacing
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const spaceLg = 16.0;
  static const spaceXl = 24.0;
  static const space2xl = 32.0;

  // Font sizes
  static const sizeDisplay = 40.0;
  static const sizeH1 = 32.0;
  static const sizeH2 = 22.0;
  static const sizeH3 = 17.0;
  static const sizeBody = 14.0;
  static const sizeCaption = 12.0;
  static const sizeTag = 11.0;

  // Font family
  static const fontDisplay = 'Pretendard';
  static const fontBody = 'Pretendard';
}

class AppEmotions {
  static const Map<String, Color> colors = {
    '좋아요': AppColors.primary,      // 바이올렛 — 긍정적 기억
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
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
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
  Color get subLabelColor => isDark ? AppColors.greyMid : AppColors.grey;
  Color get separatorColor => isDark
      ? AppColors.primary.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.05);
  Color get iconBgColor => isDark
      ? AppColors.primary.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.05);

  // 시트 / 패널 배경 (BackdropFilter 뒤에서 사용)
  Color get sheetBg => isDark
      ? AppColors.surface.withValues(alpha: 0.96)
      : Colors.white.withValues(alpha: 0.88);
  // 유리 버튼 비활성 배경
  Color get glassBtnBg => isDark
      ? AppColors.midDark.withValues(alpha: 0.9)
      : Colors.white.withValues(alpha: 0.65);
  // 유리 테두리
  Color get glassBorder => isDark
      ? AppColors.primary.withValues(alpha: 0.2)
      : Colors.white.withValues(alpha: 0.5);
  // 내비게이션 바 배경
  Color get navBg => isDark
      ? AppColors.surface.withValues(alpha: 0.92)
      : Colors.white.withValues(alpha: 0.85);
  // 비활성 칩 배경
  Color get chipBg => isDark
      ? AppColors.midDark
      : Colors.white.withValues(alpha: 0.85);
  // 비활성 칩 테두리
  Color get chipBorder => isDark
      ? AppColors.primary.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.06);
  // 드래그 핸들
  Color get handleColor => isDark
      ? AppColors.primary.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.15);
  // 숫자 뱃지 배경
  Color get countBadgeBg => isDark
      ? AppColors.primary.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.07);
  // 빈 상태 아이콘 원형 배경 등 약한 배경
  Color get emptyStateBg => isDark
      ? AppColors.primary.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.05);
  // 프로그레스 바 트랙
  Color get progressBg => isDark
      ? AppColors.primary.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.08);
  // 텍스트 필드 배경
  Color get fieldBg => isDark
      ? AppColors.midDark
      : Colors.white.withValues(alpha: 0.9);
  // 텍스트 필드 힌트
  Color get hintColor => isDark
      ? Colors.white.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.28);
}
