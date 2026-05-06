import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';

// ─── 날짜 그루핑 ──────────────────────────────────────────────────────────────

class _Section {
  final String title;
  final List<PinModel> pins;
  _Section(this.title, this.pins);
}

List<_Section> _groupByDate(List<PinModel> pins) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final twoWeeksAgo = today.subtract(const Duration(days: 14));

  final buckets = <String, List<PinModel>>{
    '오늘': [],
    '어제': [],
    '이번 주': [],
    '지난 주': [],
    '이전': [],
  };

  for (final pin in pins) {
    final d = DateTime(pin.createdAt.year, pin.createdAt.month, pin.createdAt.day);
    if (!d.isBefore(today)) {
      buckets['오늘']!.add(pin);
    } else if (!d.isBefore(yesterday)) {
      buckets['어제']!.add(pin);
    } else if (d.isAfter(weekAgo)) {
      buckets['이번 주']!.add(pin);
    } else if (d.isAfter(twoWeeksAgo)) {
      buckets['지난 주']!.add(pin);
    } else {
      buckets['이전']!.add(pin);
    }
  }

  return buckets.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => _Section(e.key, e.value))
      .toList();
}

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(pinsProvider);
    final now = DateTime.now();

    final thisMonth = pins
        .where((p) =>
            p.createdAt.year == now.year && p.createdAt.month == now.month)
        .length;

    final firstPin = pins.isNotEmpty
        ? pins.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b)
        : null;
    final daysSince =
        firstPin != null ? now.difference(firstPin.createdAt).inDays + 1 : 0;

    final sorted = [...pins]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sections = _groupByDate(sorted);

    // Flat list: section headers interleaved with items (최대 5개 표시)
    final listItems = <Widget>[];
    for (int sIdx = 0; sIdx < sections.length; sIdx++) {
      final section = sections[sIdx];
      final isLastSection = sIdx == sections.length - 1;
      final hasMore = section.pins.length > 5;
      final displayPins = hasMore ? section.pins.take(5).toList() : section.pins;

      listItems.add(_SectionHeader(
        title: section.title,
        count: section.pins.length,
        onViewAll: hasMore
            ? () => showAppSheet<void>(
                  context,
                  builder: (_) => _SectionAllPinsSheet(
                    title: section.title,
                    pins: section.pins,
                  ),
                )
            : null,
      ));
      for (int i = 0; i < displayPins.length; i++) {
        listItems.add(_ActivityItem(
          pin: displayPins[i],
          isLast: isLastSection && i == displayPins.length - 1,
        ));
      }
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _StatsRow(
                total: pins.length,
                thisMonth: thisMonth,
                daysSince: daysSince,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ActivityHeatmap(pins: pins),
            ),
          ),
          if (listItems.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: _EmptyState(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => listItems[i],
                  childCount: listItems.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 히트맵 캘린더 ────────────────────────────────────────────────────────────

class _ActivityHeatmap extends StatelessWidget {
  final List<PinModel> pins;

  const _ActivityHeatmap({required this.pins});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1=Mon

    final dayCount = <int, int>{};
    for (final pin in pins) {
      if (pin.createdAt.year == now.year && pin.createdAt.month == now.month) {
        dayCount[pin.createdAt.day] = (dayCount[pin.createdAt.day] ?? 0) + 1;
      }
    }

    final totalPinsThisMonth =
        dayCount.values.fold(0, (sum, v) => sum + v);
    final rows = ((firstWeekday - 1 + daysInMonth) / 7).ceil();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${now.year}년 ${now.month}월',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.labelColor,
                ),
              ),
              Text(
                '$totalPinsThisMonth개 기록',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          ...List.generate(rows, (row) {
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
                    cellColor = const Color(0xFF8E8E93).withValues(alpha: 0.4);
                    textColor = AppColors.dark;
                  } else {
                    cellColor = AppColors.dark;
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
                                      fontWeight: count > 0
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isToday && count == 0
                                          ? context.labelColor
                                          : textColor,
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
          }),
        ],
      ),
    );
  }
}

// ─── 섹션 헤더 ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, required this.count, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
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
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.greyLight,
              ),
            ),
          ),
          const Spacer(),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: const Text(
                '전체 보기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int total;
  final int thisMonth;
  final int daysSince;

  const _StatsRow({
    required this.total,
    required this.thisMonth,
    required this.daysSince,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: '총 핀', value: '$total', unit: '개', color: AppColors.primary),
        const SizedBox(width: 10),
        _StatCard(label: '이번 달', value: '$thisMonth', unit: '개', color: AppColors.blue),
        const SizedBox(width: 10),
        _StatCard(label: '활동 일수', value: '$daysSince', unit: '일', color: AppColors.gold),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.labelColor,
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity Item ────────────────────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  final PinModel pin;
  final bool isLast;

  const _ActivityItem({required this.pin, required this.isLast});

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.month}/${d.day}';
  }

  int _estimateTemp(DateTime date, String weather) {
    const monthBase = [2, 4, 9, 15, 20, 24, 27, 28, 23, 17, 10, 3];
    int base = monthBase[date.month - 1];
    if (weather.contains('맑음')) base += 2;
    if (weather.contains('흐림')) base -= 2;
    if (weather.contains('비')) base -= 3;
    if (weather.contains('눈')) base -= 5;
    if (weather.contains('바람')) base -= 1;
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppEmotions.colorOf(pin.emotion);
    final icon = AppEmotions.iconOf(pin.emotion);
    final temp = _estimateTemp(pin.createdAt, pin.weather);
    final tempStr = temp >= 0 ? '+$temp°C' : '$temp°C';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(icon, size: 18, color: color)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: context.separatorColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pin.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.labelColor,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(pin.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          pin.weather,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.greyLight),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                              color: AppColors.grey, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tempStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greyLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                              color: AppColors.grey, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pin.emotion,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

// ─── 섹션 전체 보기 시트 ──────────────────────────────────────────────────────

class _SectionAllPinsSheet extends StatelessWidget {
  final String title;
  final List<PinModel> pins;

  const _SectionAllPinsSheet({required this.title, required this.pins});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: context.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.labelColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${pins.length}개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: pins.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, i) {
                final pin = pins[i];
                final color = AppEmotions.colorOf(pin.emotion);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(AppEmotions.iconOf(pin.emotion), size: 18, color: color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pin.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.labelColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pin.createdAt.month}/${pin.createdAt.day}  ${pin.createdAt.hour.toString().padLeft(2, '0')}:${pin.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        pin.weather,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: bottomInset + 8),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.emptyStateBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.timeline_rounded, size: 40, color: AppColors.grey),
        ),
        const SizedBox(height: 16),
        Text(
          '아직 기록된 활동이 없어요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.labelColor,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '지도를 탭해서 첫 번째 핀을 심어보세요',
          style: TextStyle(fontSize: 13, color: AppColors.grey),
        ),
      ],
    );
  }
}
