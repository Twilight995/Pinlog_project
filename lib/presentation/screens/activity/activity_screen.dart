import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';

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
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // 앱바
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: context.bgColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
              title: Text(
                '활동',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.labelColor,
                ),
              ),
            ),
          ),

          // 통계 카드 행
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _ColoredStatCard(
                    label: '총 핀',
                    value: '$totalPins',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _ColoredStatCard(
                    label: '이번 달',
                    value: '$thisMonthPins',
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  _ColoredStatCard(
                    label: '활동 일수',
                    value: '$activeDays',
                    color: const Color(0xFF34D399),
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
                  height: 270,
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
                                ? AppColors.primary
                                : AppColors.grey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '스와이프하며 카드 전환',
                  style: TextStyle(fontSize: 11, color: context.subLabelColor),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 통계 색상 카드 ─────────────────────────────────────────────────────────────

class _ColoredStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ColoredStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 히트맵 캘린더 (접이식) ───────────────────────────────────────────────────

class _ActivityHeatmap extends StatefulWidget {
  final List<PinModel> pins;
  const _ActivityHeatmap({required this.pins});

  @override
  State<_ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<_ActivityHeatmap> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1=월

    final dayCount = <int, int>{};
    for (final pin in widget.pins) {
      if (pin.createdAt.year == now.year && pin.createdAt.month == now.month) {
        dayCount[pin.createdAt.day] = (dayCount[pin.createdAt.day] ?? 0) + 1;
      }
    }

    final totalPinsThisMonth = dayCount.values.fold(0, (sum, v) => sum + v);
    final rows = ((firstWeekday - 1 + daysInMonth) / 7).ceil();
    final currentWeekRow = ((firstWeekday - 1 + now.day - 1) ~/ 7);
    final rowsToShow = _expanded
        ? List.generate(rows, (i) => i)
        : [currentWeekRow];

    Widget buildCalendarRow(int row) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: List.generate(7, (col) {
            final cellIdx = row * 7 + col;
            final day = cellIdx - (firstWeekday - 1) + 1;
            final valid = day >= 1 && day <= daysInMonth;
            final count = valid ? (dayCount[day] ?? 0) : 0;
            final isToday = valid && day == now.day;

            Color cellColor;
            Color textColor;
            if (!valid) {
              cellColor = Colors.transparent;
              textColor = Colors.transparent;
            } else if (count == 0) {
              cellColor = context.bgColor;
              textColor = AppColors.grey;
            } else if (count == 1) {
              cellColor = AppColors.primary.withValues(alpha: 0.35);
              textColor = Colors.white;
            } else {
              cellColor = AppColors.primary;
              textColor = Colors.white;
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(color: context.labelColor, width: 1.5)
                          : null,
                    ),
                    child: valid
                        ? Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w400,
                                color: isToday && count == 0 ? context.labelColor : textColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                '${now.year}년 ${now.month}월',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$totalPinsThisMonth개 기록',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Text(
                      _expanded ? '접기' : '전체 보기',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 요일 헤더
          Row(
            children: ['월', '화', '수', '목', '금', '토', '일']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // 캘린더 행
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Column(
              children: rowsToShow.map(buildCalendarRow).toList(),
            ),
          ),
        ],
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

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdays[day.weekday - 1];
    final hasPins = pins.isNotEmpty;

    final Color cardColor;
    final Color accentColor;
    if (isToday && hasPins) {
      cardColor = AppColors.primary.withValues(alpha: 0.14);
      accentColor = AppColors.primary;
    } else if (isToday) {
      cardColor = context.cardBg;
      accentColor = AppColors.primary;
    } else if (hasPins) {
      cardColor = AppColors.primary.withValues(alpha: 0.08);
      accentColor = AppColors.primary.withValues(alpha: 0.75);
    } else {
      cardColor = context.cardBg;
      accentColor = AppColors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.glassBorder,
          width: isToday ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 뱃지 + 요일
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${day.month}월 ${day.day}일',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.subLabelColor,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '오늘',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${pins.length}개',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasPins ? accentColor : AppColors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 핀 목록 or 기록 없음
          if (!hasPins)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 32,
                      color: AppColors.grey.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '기록 없음',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pins.length > 4 ? 4 : pins.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 3 && pins.length > 4) {
                    return Text(
                      '+ ${pins.length - 3}개 더',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    );
                  }
                  final pin = pins[i];
                  final emotionColor = AppEmotions.colorOf(pin.emotion);
                  return Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: emotionColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            AppEmotions.iconOf(pin.emotion),
                            size: 14,
                            color: emotionColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pin.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.labelColor,
                          ),
                        ),
                      ),
                      Text(
                        '${pin.createdAt.hour.toString().padLeft(2, '0')}:${pin.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
