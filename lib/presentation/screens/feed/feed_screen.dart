import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/cosmic/cosmic_background.dart';

// ─── 뱃지 모델 ────────────────────────────────────────────────────────────────

class _BadgeDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(List<PinModel> pins) earned;

  const _BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });
}

// ─── 칭호 모델 ────────────────────────────────────────────────────────────────

class _TitleDef {
  final String title;
  final String subtitle;
  final int minPins;
  final Color color;

  const _TitleDef({
    required this.title,
    required this.subtitle,
    required this.minPins,
    required this.color,
  });
}

// ─── 정의 목록 ────────────────────────────────────────────────────────────────

final _badges = <_BadgeDef>[
  // ── 카테고리 뱃지 ──────────────────────────────────────────────────────────
  _BadgeDef(
    id: 'cafe_addict',
    name: '카페 못 가면 일상생활 불가',
    description: '카페 기록 5회 이상',
    icon: Icons.local_cafe_rounded,
    color: const Color(0xFF8B5E3C),
    earned: (p) => p.where((pin) => pin.pinShape == 'cafe').length >= 5,
  ),
  _BadgeDef(
    id: 'drinking_pro',
    name: '술이 보약, 이론 말고 실천',
    description: '술자리 기록 5회 이상',
    icon: Icons.sports_bar_rounded,
    color: const Color(0xFFE8962E),
    earned: (p) => p.where((pin) => pin.pinShape == 'drinking').length >= 5,
  ),
  _BadgeDef(
    id: 'shopping_lover',
    name: '텅장이 부른다',
    description: '쇼핑 기록 5회 이상',
    icon: Icons.shopping_bag_rounded,
    color: const Color(0xFFE91E8C),
    earned: (p) => p.where((pin) => pin.pinShape == 'shopping').length >= 5,
  ),
  _BadgeDef(
    id: 'driver',
    name: '도로 위의 자유인',
    description: '드라이브 기록 5회 이상',
    icon: Icons.directions_car_rounded,
    color: AppColors.blue,
    earned: (p) => p.where((pin) => pin.pinShape == 'drive').length >= 5,
  ),
  _BadgeDef(
    id: 'runner',
    name: '오늘도 달렸다 (힘들었지만)',
    description: '런닝 기록 5회 이상',
    icon: Icons.directions_run_rounded,
    color: const Color(0xFF4CAF50),
    earned: (p) => p.where((pin) => pin.pinShape == 'running').length >= 5,
  ),
  _BadgeDef(
    id: 'gym_rat',
    name: '헬스장 적금 다 썼다',
    description: '운동 기록 5회 이상',
    icon: Icons.fitness_center_rounded,
    color: AppColors.danger,
    earned: (p) => p.where((pin) => pin.pinShape == 'gym').length >= 5,
  ),
  _BadgeDef(
    id: 'soccer_king',
    name: '축구왕 등극',
    description: '축구 기록 5회 이상',
    icon: Icons.sports_soccer_rounded,
    color: const Color(0xFF43A047),
    earned: (p) => p.where((pin) => pin.pinShape == 'soccer').length >= 5,
  ),
  _BadgeDef(
    id: 'basketball_king',
    name: '코트의 지배자',
    description: '농구 기록 5회 이상',
    icon: Icons.sports_basketball_rounded,
    color: const Color(0xFFE65100),
    earned: (p) => p.where((pin) => pin.pinShape == 'basketball').length >= 5,
  ),
  _BadgeDef(
    id: 'bookworm',
    name: '책 덮으면 기억 안 나지만',
    description: '독서 기록 5회 이상',
    icon: Icons.menu_book_rounded,
    color: AppColors.primary,
    earned: (p) => p.where((pin) => pin.pinShape == 'reading').length >= 5,
  ),
  _BadgeDef(
    id: 'self_dev_addict',
    name: '자기개발 중독자',
    description: '자기개발 기록 5회 이상',
    icon: Icons.psychology_rounded,
    color: const Color(0xFF7B1FA2),
    earned: (p) => p.where((pin) => pin.pinShape == 'selfdev').length >= 5,
  ),
  _BadgeDef(
    id: 'gamer',
    name: '현실보다 게임이 더 재밌어',
    description: '오락 기록 5회 이상',
    icon: Icons.sports_esports_rounded,
    color: const Color(0xFF1565C0),
    earned: (p) => p.where((pin) => pin.pinShape == 'game').length >= 5,
  ),
  _BadgeDef(
    id: 'tech_freak',
    name: '언박싱이 취미인 사람',
    description: '전자기기 기록 5회 이상',
    icon: Icons.devices_rounded,
    color: AppColors.blue,
    earned: (p) => p.where((pin) => pin.pinShape == 'tech').length >= 5,
  ),

  // ── 마일스톤 뱃지 ──────────────────────────────────────────────────────────
  _BadgeDef(
    id: 'first_pin',
    name: '기록의 시작',
    description: '처음으로 핀을 심었어요',
    icon: Icons.flag_rounded,
    color: AppColors.primary,
    earned: (p) => p.isNotEmpty,
  ),
  _BadgeDef(
    id: 'five_pins',
    name: '이제 좀 된다',
    description: '기록 5개 달성',
    icon: Icons.looks_5_rounded,
    color: AppColors.blue,
    earned: (p) => p.length >= 5,
  ),
  _BadgeDef(
    id: 'fifteen_pins',
    name: '진심인 사람',
    description: '기록 15개 달성',
    icon: Icons.emoji_events_rounded,
    color: AppColors.accent,
    earned: (p) => p.length >= 15,
  ),
  _BadgeDef(
    id: 'thirty_pins',
    name: '기록 중독자',
    description: '기록 30개 달성',
    icon: Icons.workspace_premium_rounded,
    color: AppColors.danger,
    earned: (p) => p.length >= 30,
  ),
  _BadgeDef(
    id: 'intense_moment',
    name: '감동의 도가니',
    description: '감동 강도 5점 기록 3회 이상',
    icon: Icons.star_rounded,
    color: AppColors.accent,
    earned: (p) => p.where((pin) => pin.intensityLevel == 5).length >= 3,
  ),
  _BadgeDef(
    id: 'lone_wolf',
    name: '고독한 미식가',
    description: '혼자 기록한 활동 5회 이상',
    icon: Icons.person_rounded,
    color: AppColors.primary,
    earned: (p) => p.where((pin) => pin.companions.isEmpty).length >= 5,
  ),
  _BadgeDef(
    id: 'social_butterfly',
    name: '혼자는 재미없어',
    description: '동행자와 함께한 기록 5회 이상',
    icon: Icons.group_rounded,
    color: AppColors.blue,
    earned: (p) => p.where((pin) => pin.companions.isNotEmpty).length >= 5,
  ),
  _BadgeDef(
    id: 'all_weather',
    name: '천재지변이 와도 기록은 한다',
    description: '3가지 이상 날씨에서 활동',
    icon: Icons.wb_cloudy_rounded,
    color: AppColors.blue,
    earned: (p) => p.map((pin) => pin.weather).toSet().length >= 3,
  ),
  _BadgeDef(
    id: 'four_seasons',
    name: '사계절 챌린저',
    description: '봄·여름·가을·겨울 모두 기록',
    icon: Icons.ac_unit_rounded,
    color: AppColors.primary,
    earned: (p) {
      final months = p.map((pin) => pin.createdAt.month).toSet();
      final spring = months.any((m) => m >= 3 && m <= 5);
      final summer = months.any((m) => m >= 6 && m <= 8);
      final fall = months.any((m) => m >= 9 && m <= 11);
      final winter = months.any((m) => m == 12 || m <= 2);
      return spring && summer && fall && winter;
    },
  ),
  _BadgeDef(
    id: 'thirty_days',
    name: '30일 생존 기념',
    description: '첫 기록으로부터 30일 이상 경과',
    icon: Icons.military_tech_rounded,
    color: AppColors.accent,
    earned: (p) {
      if (p.isEmpty) return false;
      final first = p.reduce(
        (a, b) => a.createdAt.isBefore(b.createdAt) ? a : b,
      );
      return DateTime.now().difference(first.createdAt).inDays >= 30;
    },
  ),
  _BadgeDef(
    id: 'weekend_warrior',
    name: '주말의 왕',
    description: '주말(토·일) 기록 5회 이상',
    icon: Icons.weekend_rounded,
    color: AppColors.primary,
    earned: (p) =>
        p
            .where(
              (pin) =>
                  pin.createdAt.weekday == DateTime.saturday ||
                  pin.createdAt.weekday == DateTime.sunday,
            )
            .length >=
        5,
  ),
];

const _titles = <_TitleDef>[
  _TitleDef(
    title: '핀 초보',
    subtitle: '아직 지도가 비어있어요. 첫 핀을 심어볼까요?',
    minPins: 0,
    color: AppColors.greyPale,
  ),
  _TitleDef(
    title: '일상 탐색가',
    subtitle: '조금씩 기록이 쌓이고 있어요',
    minPins: 5,
    color: AppColors.blue,
  ),
  _TitleDef(
    title: '기록 마니아',
    subtitle: '이 정도면 진심인 거 맞죠?',
    minPins: 15,
    color: AppColors.primary,
  ),
  _TitleDef(
    title: '라이프 큐레이터',
    subtitle: '나만의 지도가 완성되어 가고 있어요',
    minPins: 30,
    color: AppColors.accent,
  ),
  _TitleDef(
    title: '핀 레전드',
    subtitle: '이 지도는 완전히 당신의 이야기예요',
    minPins: 60,
    color: AppColors.danger,
  ),
];

_TitleDef _currentTitle(int pinCount) {
  _TitleDef result = _titles.first;
  for (final t in _titles) {
    if (pinCount >= t.minPins) result = t;
  }
  return result;
}

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(pinsProvider);
    final earnedBadges = _badges.where((b) => b.earned(pins)).toList();
    final currentTitle = _currentTitle(pins.length);
    final nextTitle = _titles.firstWhere(
      (t) => t.minPins > pins.length,
      orElse: () => _titles.last,
    );
    final toNext = nextTitle.minPins > pins.length
        ? nextTitle.minPins - pins.length
        : 0;

    // 핀 도감: 카테고리별 핀 수
    final Map<String, int> pinCountByShape = {};
    for (final shape in AppConstants.pinShapes) {
      pinCountByShape[shape] = pins.where((p) => p.pinShape == shape).length;
    }
    final unlockedCount = pinCountByShape.values.where((c) => c > 0).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        const CosmicBackground(),
        NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
              title: const Text(
                '수집 도감',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 00),
                child: _TabBar(controller: _tabController),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── 핀 도감 ────────────────────────────────────────────
            _PinDogamTab(
              pinCountByShape: pinCountByShape,
              unlockedCount: unlockedCount,
              totalCount: AppConstants.pinShapes.length,
            ),
            // ── 뱃지 도감 ──────────────────────────────────────────
            _BadgeDogamTab(
              pins: pins,
              earnedBadges: earnedBadges,
              currentTitle: currentTitle,
              nextTitle: nextTitle,
              toNext: toNext,
            ),
          ],
        ),
      ),
      ]),
    );
  }
}

// ─── 커스텀 탭바 ──────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabChip(
            icon: Icons.location_on_rounded,
            label: '핀 도감',
            isActive: controller.index == 0,
            onTap: () => controller.animateTo(0),
          ),
          _TabChip(
            icon: Icons.military_tech_rounded,
            label: '칭호 도감',
            isActive: controller.index == 1,
            onTap: () => controller.animateTo(1),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    // 선택된 탭: 라이트모드=흰 카드 + 그림자, 다크모드=밝은 다크 카드 + 그림자
    final activeCardColor = isDark ? AppColors.surface : Colors.white;
    final activeTextColor = isDark ? Colors.white : AppColors.dark;
    final inactiveTextColor = context.subLabelColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isActive ? activeCardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.10,
                      ),
                      blurRadius: 10,
                      offset: const Offset(3, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey(isActive),
                    size: 14,
                    color: isActive ? activeTextColor : inactiveTextColor,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? activeTextColor : inactiveTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 핀 도감 탭 ───────────────────────────────────────────────────────────────
//
// 뱃지(핀 카테고리) 데이터 구조 — 나중에 뱃지별 이미지/색상/카드 정보 수정 시
// _PinBadgeData 목록만 편집하면 됩니다.
//
// 필드 설명:
//   shape       : AppConstants.pinShapes 의 key 값
//   displayName : 화면에 표시될 이름
//   tag         : 카드 상단 소문자 태그 (예: 'CAFE')
//   description : 하단 카드 설명 텍스트
//   circleColor : 뱃지 원의 메인 컬러
//   textColor   : 카드 내 텍스트 컬러
//   cardBgColor : 하단 정보 카드 배경색
//   imagePath   : 뱃지 이미지 에셋 경로 (null 이면 임시 원 도형 표시)
//   earnedDate  : 획득 일시 (null 이면 미수집)

class _PinBadgeData {
  final String shape;
  final String displayName;
  final String tag;
  final String description;
  final Color circleColor;
  final Color textColor;
  final Color cardBgColor;
  final String? imagePath;   // ← 나중에 'assets/badges/cafe.png' 형태로 입력
  final DateTime? earnedDate;

  const _PinBadgeData({
    required this.shape,
    required this.displayName,
    required this.tag,
    required this.description,
    required this.circleColor,
    required this.textColor,
    required this.cardBgColor,
    this.imagePath,
    this.earnedDate,
  });
}

// ── 뱃지 정의 목록 ─────────────────────────────────────────────────────────────
// TODO: 각 뱃지의 imagePath, cardBgColor, textColor 를 나중에 교체하세요.
List<_PinBadgeData> _buildPinBadgeList(Map<String, int> pinCountByShape) {
  return AppConstants.pinShapes.map((shape) {
    final count = pinCountByShape[shape] ?? 0;
    final earned = count > 0;
    // ── 카테고리별 개성 컬러 ───────────────────────────────────────────────────
    final Color circle;
    final Color textColor;
    final Color cardBg;
    switch (shape) {
      case 'cafe':
        circle = const Color(0xFF7C3AED);
        textColor = const Color(0xFFC4B5FD);
        cardBg = const Color(0xFF180E38);
      case 'drinking':
        circle = const Color(0xFFBE185D);
        textColor = const Color(0xFFF9A8D4);
        cardBg = const Color(0xFF1A0A1A);
      case 'shopping':
        circle = const Color(0xFFB45309);
        textColor = const Color(0xFFFCD34D);
        cardBg = const Color(0xFF1A1308);
      case 'drive':
        circle = const Color(0xFF1D4ED8);
        textColor = const Color(0xFF93C5FD);
        cardBg = const Color(0xFF06101C);
      case 'running':
        circle = const Color(0xFF15803D);
        textColor = const Color(0xFF86EFAC);
        cardBg = const Color(0xFF071A0D);
      case 'gym':
        circle = const Color(0xFFDC2626);
        textColor = const Color(0xFFFCA5A5);
        cardBg = const Color(0xFF1C0808);
      case 'soccer':
        circle = const Color(0xFF16A34A);
        textColor = const Color(0xFF86EFAC);
        cardBg = const Color(0xFF071A0D);
      case 'basketball':
        circle = const Color(0xFFEA580C);
        textColor = const Color(0xFFFDBA74);
        cardBg = const Color(0xFF1C0E06);
      case 'reading':
        circle = const Color(0xFF0E7490);
        textColor = const Color(0xFF67E8F9);
        cardBg = const Color(0xFF06141A);
      case 'selfdev':
        circle = const Color(0xFF7C3AED);
        textColor = const Color(0xFFDDD6FE);
        cardBg = const Color(0xFF130E38);
      case 'game':
        circle = const Color(0xFF1D4ED8);
        textColor = const Color(0xFFBFDBFE);
        cardBg = const Color(0xFF061018);
      case 'tech':
        circle = const Color(0xFF0369A1);
        textColor = const Color(0xFF7DD3FC);
        cardBg = const Color(0xFF061218);
      default:
        circle = AppColors.primary;
        textColor = AppColors.greyPale;
        cardBg = AppColors.surface;
    }

    return _PinBadgeData(
      shape: shape,
      displayName: AppConstants.pinShapeNames[shape] ?? shape,
      tag: (AppConstants.pinShapeNames[shape] ?? shape).toUpperCase(),
      description: earned
          ? '${AppConstants.pinShapeNames[shape]} 카테고리를 ${count}곳 기록했어요'
          : '조건을 달성하면 공개됩니다',
      circleColor: circle,
      textColor: textColor,
      cardBgColor: earned ? cardBg : const Color(0xFF0F0F14),
      imagePath: null, // TODO: 'assets/badges/$shape.png'
      earnedDate: earned ? DateTime.now() : null, // TODO: 실제 최초 기록일로 교체
    );
  }).toList();
}

class _PinDogamTab extends StatefulWidget {
  final Map<String, int> pinCountByShape;
  final int unlockedCount;
  final int totalCount;

  const _PinDogamTab({
    required this.pinCountByShape,
    required this.unlockedCount,
    required this.totalCount,
  });

  @override
  State<_PinDogamTab> createState() => _PinDogamTabState();
}

class _PinDogamTabState extends State<_PinDogamTab> {
  // ★ 뱃지 원 크기 — 이 값 하나만 바꾸면 됩니다
  static const double _badgeSize = 72.0;
  static const double _badgeGap = 4.0;

  late final ScrollController _badgeScrollCtrl;
  int _selectedIndex = 0;
  late List<_PinBadgeData> _badges;

  @override
  void initState() {
    super.initState();
    _badges = _buildPinBadgeList(widget.pinCountByShape);
    _badgeScrollCtrl = ScrollController();
    _badgeScrollCtrl.addListener(_onBadgeScroll);
  }

  @override
  void dispose() {
    _badgeScrollCtrl.removeListener(_onBadgeScroll);
    _badgeScrollCtrl.dispose();
    super.dispose();
  }

  void _onBadgeScroll() {
    final itemW = _badgeSize + _badgeGap;
    final idx = (_badgeScrollCtrl.offset / itemW).round()
        .clamp(0, _badges.length - 1);
    if (idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _snapTo(int idx) {
    final itemW = _badgeSize + _badgeGap;
    _badgeScrollCtrl.animateTo(
      idx * itemW,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _badges[_selectedIndex];
    final prevName = _badges[(_selectedIndex - 1 + _badges.length) % _badges.length].displayName;
    final nextName = _badges[(_selectedIndex + 1) % _badges.length].displayName;

    return Stack(
      children: [
        // ── 스크롤 가능한 상단 영역 ──────────────────────────────────────────
        CustomScrollView(
          slivers: [
            // 수집 현황 카드 (투명 배경)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _PinCollectionCard(
                  unlockedCount: widget.unlockedCount,
                  totalCount: widget.totalCount,
                ),
              ),
            ),
            // 뱃지 가로 스크롤 + 하단 정보 카드 높이만큼 여백
            SliverToBoxAdapter(
              child: SizedBox(height: _badgeSize + 16 + 210 + 24),
            ),
          ],
        ),

        // ── 뱃지 가로 스크롤 (하단 카드 위에 올라앉음) ──────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 210 + 58, // 카드 높이 + 네비 높이
          height: _badgeSize + 16,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // ScrollEndNotification 에서만 snap 처리
              // (selectedIndex 업데이트는 addListener의 _onBadgeScroll 에서 담당)
              if (n is ScrollEndNotification) {
                final itemW = _badgeSize + _badgeGap;
                final idx = (_badgeScrollCtrl.offset / itemW).round()
                    .clamp(0, _badges.length - 1);
                _snapTo(idx);
              }
              return false;
            },
            child: ListView.builder(
              controller: _badgeScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(
                16, 8,
                MediaQuery.of(context).size.width - 16 - _badgeSize, // 마지막 뱃지가 왼쪽에 snap
                8,
              ),
              itemCount: _badges.length,
              itemExtent: _badgeSize + _badgeGap,
              itemBuilder: (_, i) => _PinBadgeCircle(
                badge: _badges[i],
                size: _badgeSize,
              ),
            ),
          ),
        ),

        // ── 하단 정보 카드 ────────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 58, // 네비 높이
          height: 210,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: b.earnedDate != null ? b.cardBgColor : const Color(0xFF0F0F14),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(
                top: BorderSide(
                  color: b.circleColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 태그 + 아이콘 버튼 2개
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: b.circleColor.withValues(alpha: 0.6),
                        ),
                        child: Text(b.tag),
                      ),
                      const Spacer(),
                      _CardIconBtn(icon: Icons.ios_share_rounded),
                      const SizedBox(width: 8),
                      _CardIconBtn(icon: Icons.more_horiz_rounded),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 뱃지 이름 — 큰 bold 타이틀
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1.22,
                      color: b.earnedDate != null
                          ? b.textColor
                          : const Color(0xFF4B4069),
                    ),
                    child: Text(
                      b.earnedDate != null ? b.displayName : '미수집 뱃지',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 9),
                  // 구분선
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 9),
                  // 설명
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: (b.earnedDate != null ? b.textColor : const Color(0xFF4B4069))
                          .withValues(alpha: 0.65),
                    ),
                    child: Text(
                      b.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  // 획득 일자 라벨
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: b.circleColor,
                    ),
                    child: Text(
                      b.earnedDate != null
                          ? '획득 일자  ${b.earnedDate!.year}.${b.earnedDate!.month.toString().padLeft(2,'0')}.${b.earnedDate!.day.toString().padLeft(2,'0')}'
                          : '획득 조건 미달성',
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 뱃지 이름 가로 3개 나열 (이전·현재·다음)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          prevName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Color(0x33FFFFFF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: b.textColor,
                          ),
                          child: Text(
                            b.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          nextName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Color(0x33FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 카드 내 아이콘 버튼 ───────────────────────────────────────────────────────

class _CardIconBtn extends StatelessWidget {
  final IconData icon;
  const _CardIconBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.6)),
    );
  }
}

// ── 뱃지 원 위젯 ──────────────────────────────────────────────────────────────
// imagePath 가 있으면 이미지, 없으면 임시 동심원 도형 표시

class _PinBadgeCircle extends StatelessWidget {
  final _PinBadgeData badge;
  final double size;

  const _PinBadgeCircle({required this.badge, required this.size});

  @override
  Widget build(BuildContext context) {
    final earned = badge.earnedDate != null;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: badge.imagePath != null
            // ── 실제 이미지 ─────────────────────────────────────────────────
            ? Image.asset(
                badge.imagePath!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            // ── 임시 동심원 도형 ────────────────────────────────────────────
            : CustomPaint(
                size: Size(size, size),
                painter: _BadgeCirclePainter(
                  color: badge.circleColor,
                  earned: earned,
                ),
              ),
      ),
    );
  }
}

class _BadgeCirclePainter extends CustomPainter {
  final Color color;
  final bool earned;
  const _BadgeCirclePainter({required this.color, required this.earned});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    if (!earned) {
      canvas.drawCircle(
          c, r, Paint()..color = const Color(0xFF1E1E28));
      canvas.drawCircle(
          c, r * 0.5,
          Paint()..color = const Color(0xFF2A2A38));
      return;
    }

    // 외곽 원
    canvas.drawCircle(
        c, r,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill);
    // 중간 원
    canvas.drawCircle(
        c, r * 0.65,
        Paint()
          ..color = color.withValues(alpha: 0.55));
    // 내부 원
    canvas.drawCircle(
        c, r * 0.35,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BadgeCirclePainter old) =>
      old.color != color || old.earned != earned;
}

// ─── 핀 수집 현황 카드 (완전 투명 배경) ─────────────────────────────────────

class _PinCollectionCard extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;

  const _PinCollectionCard({
    required this.unlockedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;
    final remaining = totalCount - unlockedCount;
    final subtitle = unlockedCount == 0
        ? '아직 수집한 핀이 없어요. 첫 핀을 심어볼까요?'
        : remaining == 0
            ? '모든 핀을 수집했어요. 진정한 핀 마스터!'
            : '$totalCount종 중 $unlockedCount종을 모았어요';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 수집 현황 알약 태그
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '수집 현황',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ),
              const Spacer(),
              // 작은 화살표 버튼
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_outward_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$unlockedCount / $totalCount종',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          // 진행률 바
          Stack(
            children: [
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// _PinCategoryCard 는 새 디자인에서 제거됨 (뱃지 원 + 하단 카드 방식으로 대체)

// ─── 핀 상세 시트 (뱃지 상세 시트와 동일 디자인) ──────────────────────────────

class _PinDetailSheet extends StatelessWidget {
  final String emoji;
  final String name;
  final int count;
  final bool unlocked;

  const _PinDetailSheet({
    required this.emoji,
    required this.name,
    required this.count,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: unlocked
                  ? color.withValues(alpha: 0.12)
                  : context.emptyStateBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: unlocked
                  ? Text(emoji, style: const TextStyle(fontSize: 40))
                  : const Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: AppColors.grey,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.labelColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            unlocked
                ? '$name 카테고리를 $count곳 기록했어요'
                : '아직 $name 카테고리를 기록하지 않았어요',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: unlocked
                  ? color.withValues(alpha: 0.08)
                  : context.emptyStateBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  unlocked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: unlocked ? color : AppColors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  unlocked ? '수집 완료' : '아직 수집하지 못했어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? color : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── 뱃지 도감 탭 ─────────────────────────────────────────────────────────────

class _BadgeDogamTab extends StatelessWidget {
  final List<PinModel> pins;
  final List<_BadgeDef> earnedBadges;
  final _TitleDef currentTitle;
  final _TitleDef nextTitle;
  final int toNext;

  const _BadgeDogamTab({
    required this.pins,
    required this.earnedBadges,
    required this.currentTitle,
    required this.nextTitle,
    required this.toNext,
  });

  void _showDetail(BuildContext context, _BadgeDef badge, bool earned) {
    showAppSheet<void>(
      context,
      builder: (_) => _BadgeDetailSheet(badge: badge, earned: earned),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockedBadges = _badges.where((b) => !b.earned(pins)).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TitleCard(
              titleDef: currentTitle,
              nextTitle: toNext > 0 ? nextTitle : null,
              toNext: toNext,
              pinCount: pins.length,
            ),
          ),
        ),
        if (earnedBadges.isNotEmpty) ...[
          _SectionHeader(label: '획득한 뱃지', count: earnedBadges.length),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _BadgeCard(
                  badge: earnedBadges[i],
                  earned: true,
                  onTap: () => _showDetail(context, earnedBadges[i], true),
                ),
                childCount: earnedBadges.length,
              ),
            ),
          ),
        ],
        if (lockedBadges.isNotEmpty) ...[
          _SectionHeader(label: '미획득 뱃지', count: lockedBadges.length),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _BadgeCard(
                  badge: lockedBadges[i],
                  earned: false,
                  onTap: () => _showDetail(context, lockedBadges[i], false),
                ),
                childCount: lockedBadges.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 칭호 카드 ────────────────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  final _TitleDef titleDef;
  final _TitleDef? nextTitle;
  final int toNext;
  final int pinCount;

  const _TitleCard({
    required this.titleDef,
    required this.nextTitle,
    required this.toNext,
    required this.pinCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = nextTitle != null && nextTitle!.minPins > 0
        ? (pinCount - titleDef.minPins) /
              (nextTitle!.minPins - titleDef.minPins)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            titleDef.color.withValues(alpha: 0.15),
            titleDef.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: titleDef.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: titleDef.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '현재 칭호',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            titleDef.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: titleDef.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titleDef.subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.grey),
          ),
          if (nextTitle != null && toNext > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '다음 칭호까지 여행 $toNext회',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
                Text(
                  nextTitle!.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: nextTitle!.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: context.progressBg,
                valueColor: AlwaysStoppedAnimation<Color>(titleDef.color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 섹션 헤더 ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.labelColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: context.countBadgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greyLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 뱃지 카드 ────────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final _BadgeDef badge;
  final bool earned;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.badge,
    required this.earned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: earned ? 1.0 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: earned
                ? [
                    BoxShadow(
                      color: badge.color.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: earned
                      ? badge.color.withValues(alpha: 0.12)
                      : context.emptyStateBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  earned ? badge.icon : Icons.lock_rounded,
                  size: 26,
                  color: earned ? badge.color : AppColors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: earned ? context.labelColor : AppColors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 뱃지 상세 시트 ───────────────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  final _BadgeDef badge;
  final bool earned;

  const _BadgeDetailSheet({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: earned
                  ? badge.color.withValues(alpha: 0.12)
                  : context.emptyStateBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              earned ? badge.icon : Icons.lock_rounded,
              size: 40,
              color: earned ? badge.color : AppColors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.labelColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: earned
                  ? badge.color.withValues(alpha: 0.08)
                  : context.emptyStateBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  earned
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: earned ? badge.color : AppColors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  earned ? '획득 완료' : '아직 획득하지 못했어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: earned ? badge.color : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}