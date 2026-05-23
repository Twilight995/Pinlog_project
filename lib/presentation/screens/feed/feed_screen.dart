import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/cosmic/blob.dart';
import '../../widgets/cosmic/category_palette.dart';
import '../../widgets/feed/dogam_glow_background.dart';

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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: DogamGlowBackground()),
          NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 170,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  // bottom: TabBar(58) + 카피 아래 여유(14)
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 72),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '수집 도감',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: AppTokens.fontDisplay,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '기록의 결을 모아 한 권의 책으로',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFC8C1E0),
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
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
        ],
      ),
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
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1233),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _TabChip(
            label: '핀 도감',
            isActive: controller.index == 0,
            onTap: () => controller.animateTo(0),
          ),
          _TabChip(
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
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFE5D0)],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? Border.all(color: const Color(0xFFE04A1F), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive
                  ? const Color(0xFF1A0F3D)
                  : const Color(0xFF7C6FAB),
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 핀 도감 탭 ───────────────────────────────────────────────────────────────

class _PinDogamTab extends StatelessWidget {
  final Map<String, int> pinCountByShape;
  final int unlockedCount;
  final int totalCount;

  const _PinDogamTab({
    required this.pinCountByShape,
    required this.unlockedCount,
    required this.totalCount,
  });

  void _showDetail(
    BuildContext context, {
    required String emoji,
    required String name,
    required int count,
    required bool unlocked,
  }) {
    showAppSheet<void>(
      context,
      builder: (_) => _PinDetailSheet(
        emoji: emoji,
        name: name,
        count: count,
        unlocked: unlocked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockedShapes = AppConstants.pinShapes
        .where((s) => (pinCountByShape[s] ?? 0) > 0)
        .toList();
    final lockedShapes = AppConstants.pinShapes
        .where((s) => (pinCountByShape[s] ?? 0) == 0)
        .toList();

    return CustomScrollView(
      slivers: [
        // ── 수집 현황 카드 (칭호 카드와 동일 구조) ──────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _PinCollectionCard(
              unlockedCount: unlockedCount,
              totalCount: totalCount,
            ),
          ),
        ),
        if (unlockedShapes.isNotEmpty) ...[
          _SectionHeader(label: '수집한 핀', count: unlockedShapes.length),
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
                (context, i) {
                  final shape = unlockedShapes[i];
                  final count = pinCountByShape[shape] ?? 0;
                  final emoji = AppConstants.pinShapeEmojis[shape] ?? '📍';
                  final name = AppConstants.pinShapeNames[shape] ?? shape;
                  return _PinCategoryCard(
                    shape: shape,
                    emoji: emoji,
                    name: name,
                    count: count,
                    unlocked: true,
                    onTap: () => _showDetail(
                      context,
                      emoji: emoji,
                      name: name,
                      count: count,
                      unlocked: true,
                    ),
                  );
                },
                childCount: unlockedShapes.length,
              ),
            ),
          ),
        ],
        if (lockedShapes.isNotEmpty) ...[
          _SectionHeader(label: '미수집 핀', count: lockedShapes.length),
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
                (context, i) {
                  final shape = lockedShapes[i];
                  final emoji = AppConstants.pinShapeEmojis[shape] ?? '📍';
                  final name = AppConstants.pinShapeNames[shape] ?? shape;
                  return _PinCategoryCard(
                    shape: shape,
                    emoji: emoji,
                    name: name,
                    count: 0,
                    unlocked: false,
                    onTap: () => _showDetail(
                      context,
                      emoji: emoji,
                      name: name,
                      count: 0,
                      unlocked: false,
                    ),
                  );
                },
                childCount: lockedShapes.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 핀 수집 현황 카드 (라벤더 그라디언트 + 블롭) ──────────────────────────

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            // 라벤더 그라디언트 베이스
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.pastelLavender.withValues(alpha: 0.6),
                      AppColors.pastelLavender,
                    ],
                  ),
                ),
              ),
            ),
            // 블롭 1 (큰 보라)
            Positioned(
              right: -30,
              top: -30,
              child: Blob(
                size: 230,
                color: AppColors.primary,
                opacity: 0.7,
              ),
            ),
            // 블롭 2 (작은 진보라)
            Positioned(
              right: -60,
              top: 50,
              child: Blob(
                size: 170,
                color: AppColors.primaryDark,
                opacity: 0.65,
              ),
            ),
            // 컨텐츠
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 알약
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: const Text(
                          '수집 현황',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textOnPastel,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ↗ 버튼
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_outward_rounded,
                          size: 20,
                          color: AppColors.textOnPastel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$unlockedCount / $totalCount종',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textOnPastel,
                      fontFamily: AppTokens.fontDisplay,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5B4A8A),
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                  const Spacer(),
                  // 진행률 바
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.textOnPastel,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── 핀 카테고리 카드 (파스텔 그라디언트 / 다크 글래스) ───────────────────

class _PinCategoryCard extends StatelessWidget {
  final String shape;
  final String emoji;
  final String name;
  final int count;
  final bool unlocked;
  final VoidCallback onTap;

  const _PinCategoryCard({
    required this.shape,
    required this.emoji,
    required this.name,
    required this.count,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return unlocked ? _buildUnlocked() : _buildLocked();
  }

  Widget _buildUnlocked() {
    final palette = CategoryPalette.forShape(shape);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.start, palette.end],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnPastel,
                fontFamily: AppTokens.fontBody,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count곳',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: palette.accent,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocked() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgLockedStart, AppColors.bgLockedEnd],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 고스트 이모지 (어떤 카테고리인지 흐릿하게 힌트)
            Opacity(
              opacity: 0.25,
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A8FC0),
                fontFamily: AppTokens.fontBody,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '미수집',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B5E94),
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  paletteIndex: i,
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

  /// 칭호 레벨 (titles 인덱스 + 1).
  int get _level {
    final idx = _titles.indexOf(titleDef);
    return idx < 0 ? 1 : idx + 1;
  }

  @override
  Widget build(BuildContext context) {
    final progress = nextTitle != null && nextTitle!.minPins > 0
        ? (pinCount - titleDef.minPins) /
              (nextTitle!.minPins - titleDef.minPins)
        : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            // Apricot 그라디언트 베이스 (#FFE5D0 → #F2A66B)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE5D0), Color(0xFFF2A66B)],
                  ),
                ),
              ),
            ),
            // Blob 1 — 우상단 큰 오렌지 라디얼 (280×280, opacity 0.55)
            Positioned(
              left: 240,
              top: 60,
              child: Opacity(
                opacity: 0.55,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFE04A1F), Color(0xFFF2A66B)],
                    ),
                  ),
                ),
              ),
            ),
            // Blob 2 — 작은 진한 오렌지 점
            Positioned(
              left: 260,
              top: 110,
              child: Opacity(
                opacity: 0.55,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF9A2B0E),
                  ),
                ),
              ),
            ),
            // Sparkles (4개 흰 점)
            Positioned(
              left: 215,
              top: 25,
              child: Opacity(
                opacity: 0.85,
                child: _sparkle(8),
              ),
            ),
            Positioned(
              left: 285,
              top: 50,
              child: Opacity(opacity: 0.65, child: _sparkle(5)),
            ),
            Positioned(
              left: 240,
              top: 155,
              child: Opacity(opacity: 0.75, child: _sparkle(6)),
            ),
            Positioned(
              left: 340,
              top: 115,
              child: Opacity(opacity: 0.55, child: _sparkle(4)),
            ),
            // "현재 칭호" 펄 (좌상단)
            Positioned(
              left: 20,
              top: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE04A1F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '현재 칭호',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ),
            ),
            // (Lv chip — 큰 칭호명 옆 Row로 묶음, 아래 칭호명 Positioned 참조)
            // ↗ Arrow 흰 원 버튼
            Positioned(
              right: 20,
              top: 20,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  size: 20,
                  color: Color(0xFF4A1A0A),
                ),
              ),
            ),
            // 큰 칭호명 + Lv 칩 (자연스럽게 옆에 붙음)
            Positioned(
              left: 20,
              top: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    titleDef.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: Color(0xFF4A1A0A),
                      fontFamily: AppTokens.fontDisplay,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A1A0A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Lv.$_level',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFE5D0),
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 서브타이틀
            Positioned(
              left: 20,
              top: 100,
              child: Text(
                titleDef.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7A3018),
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ),
            // 진행률 바 — 트랙 (흰 50%)
            Positioned(
              left: 20,
              top: 140,
              child: Container(
                width: 350,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // 진행률 바 — Fill (다크)
            Positioned(
              left: 20,
              top: 140,
              child: Container(
                width: (350 * progress.clamp(0.0, 1.0)).toDouble(),
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A1A0A),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sparkle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
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

  /// 카드 인덱스 — 파스텔 색 결정 (라벤더/블루/핑크 순환).
  final int paletteIndex;

  const _BadgeCard({
    required this.badge,
    required this.earned,
    required this.onTap,
    this.paletteIndex = 0,
  });

  static const _pastels = <Color>[
    Color(0xFFC7BFFF), // 라벤더
    Color(0xFFBFE0FF), // 라이트블루
    Color(0xFFF5C9E0), // 핑크
  ];

  @override
  Widget build(BuildContext context) {
    final pastel = _pastels[paletteIndex % _pastels.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: earned
                ? [Colors.white, pastel]
                : const [Color(0xFF1B181F), Color(0xFF0D0B11)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘 — 활성: 48 흰 원 + 다크 아이콘 / 비활성: 25% 트로피
            if (earned)
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  badge.icon,
                  size: 24,
                  color: const Color(0xFF5B21B6),
                ),
              )
            else
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Opacity(
                    opacity: 0.25,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: earned
                    ? const Color(0xFF1A0F3D)
                    : const Color(0xFF9A8FC0),
                fontFamily: AppTokens.fontBody,
                height: 1.25,
              ),
            ),
          ],
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
