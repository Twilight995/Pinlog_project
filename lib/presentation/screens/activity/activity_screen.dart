import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/cosmic/category_palette.dart';
import '../../widgets/cosmic/cosmic_background.dart';

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late final PageController _pageCtrl;
  int _currentPage = 0;

  static const int _dayCount = 30;

  @override
  void initState() {
    super.initState();
    _currentPage = _dayCount - 1; // 오늘
    _pageCtrl = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(pinsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 통계
    final totalPins = pins.length;
    final thisMonthPins = pins
        .where((p) => p.createdAt.year == now.year && p.createdAt.month == now.month)
        .length;
    final activeDays = pins
        .map((p) => DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day))
        .toSet()
        .length;

    // 최근 30일 (index 0 = 29일 전, index 29 = 오늘)
    final days = List.generate(
      _dayCount,
      (i) => today.subtract(Duration(days: _dayCount - 1 - i)),
    );

    // 날짜별 핀 그루핑
    final pinsByDay = <DateTime, List<PinModel>>{};
    for (final pin in pins) {
      final d = DateTime(pin.createdAt.year, pin.createdAt.month, pin.createdAt.day);
      (pinsByDay[d] ??= []).add(pin);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      body: Stack(
        children: [
          const Positioned.fill(child: CosmicBackground()),
          CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // 앱바 — 도감 탭과 동일한 크기 + 감성 카피
          const SliverAppBar(
            pinned: true,
            expandedHeight: 112,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '활동',
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
                          '지나온 발걸음을 들여다보는 시간',
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
          ),

          // 메인 통계 히어로 (이번 달)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _MainStatHero(count: thisMonthPins),
            ),
          ),

          // 미니 통계 칩 2개 (총 핀 / 활동한 날)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _GlassMiniStatCard(
                      icon: Icons.location_on_outlined,
                      value: '$totalPins',
                      unit: '개',
                      label: '총 핀',
                      gradient: const [Color(0xFFBFEFE4), Color(0xFF5BB89E)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GlassMiniStatCard(
                      icon: Icons.event_available_outlined,
                      value: '$activeDays',
                      unit: '일',
                      label: '활동한 날',
                      gradient: const [Color(0xFFC7BFFF), Color(0xFF8B5CF6)],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 캘린더 (접이식)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ActivityHeatmap(pins: pins),
            ),
          ),

          // 하루 카드 PageView
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  height: 302,
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: days.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      final day = days[i];
                      final dayPins = List<PinModel>.from(pinsByDay[day] ?? [])
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _DayCard(
                          day: day,
                          pins: dayPins,
                          isToday: day == today,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 페이지 점 표시기
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_dayCount, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: isActive ? 14 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? TabTheme.activity.accent
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '스와이프하며 카드 전환',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

// ─── 메인 통계 히어로 (이번 달) ─────────────────────────────────────────────

class _MainStatHero extends StatelessWidget {
  final int count;
  const _MainStatHero({required this.count});

  String get _subCopy {
    if (count == 0) return '이번 달 첫 핀을 심어볼까요?';
    if (count < 5) return '이번 달 발걸음이 시작되고 있어요';
    if (count < 15) return '이번 달 차곡차곡 쌓이고 있어요';
    return '이번 달 가장 활발한 한 달이었어요';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            // 민트 그라디언트 베이스
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFBFEFE4),
                      Color(0xFF8AD2BE),
                      Color(0xFF5BB89E),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // 우상단 화이트 하이라이트 블롭
            Positioned(
              right: -100,
              top: -60,
              child: Container(
                width: 320,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xCCFFFFFF),
                      Color(0x59FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // 좌측 진그린 블롭
            Positioned(
              left: -50,
              top: 60,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xCC3D8055),
                      Color(0x663D8055),
                      Color(0x003D8055),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // 컨텐츠
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 다크 펄
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60F2F23),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '이번 달',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 캘린더 흰 원 버튼
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Color(0xFF0F2F23),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 큰 숫자
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: Color(0xFF0F2F23),
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '개의 순간',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F2F23),
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _subCopy,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F5C45),
                      fontFamily: AppTokens.fontBody,
                    ),
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

// ─── 미니 통계 글래스 카드 ──────────────────────────────────────────────────

class _GlassMiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final List<Color> gradient;

  const _GlassMiniStatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: Row(
            children: [
              // 컬러 원 + 아이콘
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: Colors.white,
                            fontFamily: AppTokens.fontDisplay,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            unit,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFA8A1C8),
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF7C6FAB),
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 히트맵 캘린더 (접이식) ───────────────────────────────────────────────────

class _ActivityHeatmap extends StatelessWidget {
  final List<PinModel> pins;
  const _ActivityHeatmap({required this.pins});

  /// 최근 한 달(35칸 = 5주) 핀 카운트 → 강도 (0~4).
  /// 0=없음, 1=1~2개, 2=3~4개, 3=5~7개, 4=8개+
  int _intensity(int count) {
    if (count == 0) return 0;
    if (count <= 2) return 1;
    if (count <= 4) return 2;
    if (count <= 7) return 3;
    return 4;
  }

  static const _levelColors = <Color>[
    Color(0x0FFFFFFF), // 0 — 없음 (옅은 흰)
    Color(0x66BFEFE4), // 1 — 라이트 민트
    Color(0x995BB89E), // 2 — 민트
    Color(0xFF3D8055), // 3 — 진한 민트
    Color(0xFF1F5C45), // 4 — 딥 그린
  ];

  /// 오늘 기준 가장 최근 연속 활동 일수.
  int _calcStreak(Map<DateTime, int> byDay, DateTime today) {
    var streak = 0;
    var cursor = today;
    while ((byDay[cursor] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 일별 카운트 (전체 핀 대상)
    final byDay = <DateTime, int>{};
    for (final pin in pins) {
      final d = DateTime(
          pin.createdAt.year, pin.createdAt.month, pin.createdAt.day);
      byDay[d] = (byDay[d] ?? 0) + 1;
    }

    // 최근 5주 (35일) 그리드 — 월요일 시작
    // 마지막 행이 이번 주이고 오늘은 그 행의 weekday 위치
    final todayDow = today.weekday; // 1=월 ~ 7=일
    final lastMonday = today.subtract(Duration(days: todayDow - 1));
    final firstMonday = lastMonday.subtract(const Duration(days: 7 * 4));

    final days = List.generate(35, (i) => firstMonday.add(Duration(days: i)));
    final recordedDays =
        days.where((d) => !d.isAfter(today) && (byDay[d] ?? 0) > 0).length;
    final streak = _calcStreak(byDay, today);

    final dateLabel =
        '${today.month}월 ${today.day}일 기준';

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '최근 한 달',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C6FAB),
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 연속 N일 화염 칩
                  Container(
                    height: 26,
                    padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5BB89E), Color(0xFF3D8055)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '연속 $streak일',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 요일 라벨 (월~일)
              Row(
                children: ['월', '화', '수', '목', '금', '토', '일']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C6FAB),
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),

              // 5×7 히트맵 그리드
              Column(
                children: List.generate(5, (week) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: week == 4 ? 0 : 6),
                    child: Row(
                      children: List.generate(7, (dow) {
                        final d = days[week * 7 + dow];
                        final isFuture = d.isAfter(today);
                        final count = isFuture ? 0 : (byDay[d] ?? 0);
                        final lvl = _intensity(count);
                        return Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: dow == 6 ? 0 : 6),
                            child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: _levelColors[lvl],
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // 강도 레전드 + 기록일 수
              Row(
                children: [
                  const Text(
                    '적음',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C6FAB),
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._levelColors.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )),
                  const SizedBox(width: 4),
                  const Text(
                    '많음',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C6FAB),
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$recordedDays일 기록',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA8A1C8),
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 하루 카드 ─────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<PinModel> pins;
  final bool isToday;

  const _DayCard({
    required this.day,
    required this.pins,
    required this.isToday,
  });

  static const _weekdays = ['', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${day.month}월 ${day.day}일';
    final dowLabel = _weekdays[day.weekday];
    // 최대 3개 표시
    final displayPins = pins.take(3).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 302,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.06),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isToday) ...[
                                Container(
                                  height: 18,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5BB89E),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'TODAY',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: Color(0xFF0F2F23),
                                      fontFamily: AppTokens.fontBody,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFA8A1C8),
                                  fontFamily: AppTokens.fontBody,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dowLabel,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: AppTokens.fontDisplay,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pins.isNotEmpty)
                      Container(
                        height: 32,
                        padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.07),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${pins.length}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '개의 순간',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA8A1C8),
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (pins.isEmpty)
                  _EmptyDay(isToday: isToday)
                else
                  Column(
                    children: [
                      for (var i = 0; i < displayPins.length; i++) ...[
                        _PinRow(pin: displayPins[i]),
                        if (i < displayPins.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  final PinModel pin;
  const _PinRow({required this.pin});

  String get _timeStr {
    final h = pin.createdAt.hour.toString().padLeft(2, '0');
    final m = pin.createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _meta {
    if (pin.companions.isEmpty) return '혼자';
    if (pin.companions.length == 1) return pin.companions.first;
    return '${pin.companions.first}·${pin.companions.length - 1}명';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CategoryPalette.forShape(pin.pinShape);
    final emoji = AppConstants.pinShapeEmojis[pin.pinShape] ?? '📍';

    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 시간
          SizedBox(
            width: 44,
            child: Text(
              _timeStr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFA8A1C8),
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 카테고리 색 라디얼 원 + 이모지
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.accent.withValues(alpha: 0.70),
                  palette.accent.withValues(alpha: 0.20),
                  palette.accent.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          // 제목 + 메타
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  pin.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 10,
                      color: Color(0xFF7C6FAB),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA8A1C8),
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 강도 칩 (★ + 숫자)
          Container(
            height: 22,
            padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
            decoration: BoxDecoration(
              color: const Color(0xCC1A0F3D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 10,
                  color: Color(0xFFFFD27A),
                ),
                const SizedBox(width: 3),
                Text(
                  '${pin.intensityLevel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 핀 없는 날 ────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final bool isToday;
  const _EmptyDay({required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 174,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 32,
            color: Colors.white.withValues(alpha: 0.30),
          ),
          const SizedBox(height: 10),
          Text(
            isToday ? '오늘 아직 기록이 없어요' : '이 날은 핀이 없어요',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C6FAB),
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
    );
  }
}
