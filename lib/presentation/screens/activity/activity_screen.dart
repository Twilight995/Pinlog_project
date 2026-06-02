import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/cosmic/blob.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late final PageController _pageCtrl;
  late final ScrollController _sc;
  int _currentPage = 0;

  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';

  static const int _dayCount = 30;
  static const double _collapseRange = 100.0;

  double get _t =>
      (_sc.hasClients ? _sc.offset : 0.0).clamp(0.0, _collapseRange) /
      _collapseRange;

  void _openPinDetail(String pinId) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.30),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, _, _) => PinDetailSheet(
        pinId: pinId,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentPage = _dayCount - 1;
    _pageCtrl = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.88,
    );
    _sc = ScrollController();
    _sc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _sc.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
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
    final lastMonthDate = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);
    final lastMonthPins = pins
        .where((p) => p.createdAt.year == lastMonthDate.year && p.createdAt.month == lastMonthDate.month)
        .length;
    final monthDiff = thisMonthPins - lastMonthPins;

    // 감정 분포
    final likeCount = pins.where((p) => p.emotion == '좋아요').length;
    final likePercent = totalPins > 0 ? likeCount / totalPins : 0.0;

    // 최다 활동 요일
    final weekdayCounts = List<int>.filled(7, 0);
    for (final pin in pins) {
      weekdayCounts[pin.createdAt.weekday - 1]++;
    }
    var topWeekdayIdx = 0;
    for (var i = 1; i < 7; i++) {
      if (weekdayCounts[i] > weekdayCounts[topWeekdayIdx]) topWeekdayIdx = i;
    }
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final topWeekdayLabel = totalPins > 0 ? weekdayLabels[topWeekdayIdx] : '-';
    final topWeekdayCount = weekdayCounts[topWeekdayIdx];

    // 검색 결과
    final List<PinModel> searchResults;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      searchResults = pins
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      searchResults = const [];
    }

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

    final t = _t;
    final topPad = MediaQuery.of(context).padding.top;
    final largeOp = 1.0 - Curves.easeInCubic.transform((t / 0.70).clamp(0.0, 1.0));
    final smallOp = Curves.easeOutCubic.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad),
          // 고정 헤더 — 검색 활성 시 서치바로 전환
          SizedBox(
            height: 44,
            child: _showSearch
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            autofocus: true,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.trim()),
                            style: TextStyle(
                              fontSize: 15,
                              color: context.labelColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                            decoration: InputDecoration(
                              hintText: '핀 검색...',
                              hintStyle: TextStyle(
                                color: context.subLabelColor,
                                fontSize: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: context.subLabelColor,
                              ),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              filled: true,
                              fillColor: context.cardBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _showSearch = false;
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                            _searchFocus.unfocus();
                          },
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.primaryColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Opacity(
                              opacity: smallOp,
                              child: Text(
                                '활동',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: context.labelColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showSearch = true);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: context.subLabelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // 큰 타이틀 (접힘, 검색 중에는 숨김)
          if (!_showSearch)
            ClipRect(
              child: Align(
                alignment: Alignment.bottomLeft,
                heightFactor: 1.0 - t,
                child: Opacity(
                  opacity: largeOp,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '활동',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: context.labelColor,
                            height: 1.0,
                            fontFamily: AppTokens.fontDisplay,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '나의 기록을 돌아보세요',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.labelColor.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 콘텐츠
          Expanded(
            child: Stack(
              children: [
                CustomScrollView(
              controller: _sc,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
          // 통계 카드 행
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _PastelStatCard(
                    label: '총 핀',
                    value: '$totalPins',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(width: 10),
                  _PastelStatCard(
                    label: '이번 달',
                    value: '$thisMonthPins',
                    icon: Icons.calendar_month_rounded,
                    trend: monthDiff == 0
                        ? null
                        : '${monthDiff > 0 ? '+' : ''}$monthDiff 지난달',
                    trendUp: monthDiff >= 0,
                  ),
                  const SizedBox(width: 10),
                  _PastelStatCard(
                    label: '활동 일수',
                    value: '$activeDays',
                    icon: Icons.local_fire_department_rounded,
                  ),
                ],
              ),
            ),
          ),

          // 통계 카드 행 2: 감정 분포 + 최다 요일
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _EmotionStatCard(
                    likeCount: likeCount,
                    totalCount: totalPins,
                    likePercent: likePercent,
                  ),
                  const SizedBox(width: 10),
                  _WeekdayStatCard(
                    topWeekday: topWeekdayLabel,
                    topCount: totalPins > 0 ? topWeekdayCount : 0,
                  ),
                ],
              ),
            ),
          ),

          // 캘린더 (접이식, 검색 중에는 숨김)
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _ActivityHeatmap(pins: pins),
              ),
            ),

          // 검색 결과 OR 하루 카드 PageView
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: _searchQuery.isNotEmpty && searchResults.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 52,
                            color: context.subLabelColor.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '검색 결과가 없어요',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.subLabelColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      itemCount: searchResults.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) =>
                          _SearchResultItem(
                            pin: searchResults[i],
                            onTap: () => _openPinDetail(searchResults[i].id),
                          ),
                    ),
            ),

          // 하루 카드 PageView (검색 중에는 숨김)
          if (_searchQuery.isEmpty)
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
                const SizedBox(height: 14),

                // 날짜 네비게이터 (dots 대체)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _currentPage > 0
                          ? () => _pageCtrl.animateToPage(
                                _currentPage - 1,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 22,
                          color: _currentPage > 0
                              ? context.subLabelColor
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      children: [
                        Text(
                          '${days[_currentPage].month}월 ${days[_currentPage].day}일',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.labelColor,
                            fontFamily: AppTokens.fontDisplay,
                          ),
                        ),
                        if (_currentPage < _dayCount - 1)
                          Text(
                            '${_dayCount - 1 - _currentPage}일 전',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: context.subLabelColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _currentPage < _dayCount - 1
                          ? () => _pageCtrl.animateToPage(
                                _currentPage + 1,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: _currentPage < _dayCount - 1
                              ? context.subLabelColor
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0) + 90),
              ],
            ),
          ),
                ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 28,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.bgColor,
                            context.bgColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
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


// ─── 통계 파스텔 카드 ──────────────────────────────────────────────────────

class _PastelStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? trend;
  final bool trendUp;

  const _PastelStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;
    final isDark = context.isDark;

    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: isDark
              ? context.cardBg
              : primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.22),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isDark
                      ? context.subLabelColor
                      : primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? context.subLabelColor
                        : primary.withValues(alpha: 0.75),
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : context.labelColor,
                    fontFamily: AppTokens.fontDisplay,
                    height: 1.0,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Icon(
                          trendUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 11,
                          color: trendUp
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trend!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: trendUp
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
  bool _expanded = true;

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
              cellColor = Colors.transparent;
              textColor = context.subLabelColor;
            } else if (count == 1) {
              cellColor = context.primaryColor.withValues(alpha: 0.38);
              textColor = Colors.white;
            } else {
              cellColor = context.primaryColor.withValues(alpha: 0.85);
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
                          ? Border.all(
                              color: context.isDark
                                  ? Colors.white
                                  : context.primaryColor,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: valid
                        ? Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w400,
                                color: isToday && count == 0
                                    ? (context.isDark
                                        ? Colors.white
                                        : context.primaryColor)
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
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bgCosmicCardStart, AppColors.bgCosmicCardEnd],
              )
            : null,
        color: context.isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.glassCardShadow,
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
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$totalPinsThisMonth개 기록',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.subLabelColor,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Text(
                      _expanded ? '접기' : '전체 보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color.lerp(context.primaryColor, Colors.white, 0.65)!,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color.lerp(context.primaryColor, Colors.white, 0.65)!,
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
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.subLabelColor,
                            fontFamily: AppTokens.fontBody,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // 베이스 — 활동(민트) 파스텔 그라디언트 / 빈 날은 중립 카드
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: hasPins
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(context.primaryColor, Colors.white, 0.72)!,
                          Color.lerp(context.primaryColor, Colors.white, 0.28)!,
                        ],
                      )
                    : context.isDark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.bgCosmicCardStart,
                              AppColors.bgCosmicCardEnd,
                            ],
                          )
                        : null,
                color: hasPins || context.isDark ? null : Colors.white,
              ),
            ),
          ),
          // 카드 안 블롭 (있는 날만)
          if (hasPins) ...[
            Positioned(
              right: -40,
              top: -20,
              child: Blob(
                size: 180,
                color: context.primaryColor,
                opacity: 0.55,
              ),
            ),
            Positioned(
              right: -10,
              top: 80,
              child: Blob(
                size: 120,
                color: context.primaryDarkColor,
                opacity: 0.55,
              ),
            ),
          ],
          // 컨텐츠
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 뱃지 + 요일
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: hasPins
                            ? Color.lerp(context.primaryColor, Colors.white, 0.65)!
                            : AppOverlays.w08,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${day.month}월 ${day.day}일',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: hasPins
                              ? const Color(0xFF1A1A1A)
                              : context.subLabelColor,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      weekday,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasPins
                            ? context.primaryDarkColor
                            : context.subLabelColor,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.primaryDarkColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '오늘',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${pins.length}개',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasPins
                            ? const Color(0xFF1A1A1A)
                            : context.subLabelColor,
                        fontFamily: AppTokens.fontBody,
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
                            isToday
                                ? Icons.add_location_alt_outlined
                                : Icons.location_off_rounded,
                            size: 34,
                            color: context.subLabelColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isToday ? '오늘의 첫 기억을 남겨보세요' : '이 날은 기록이 없어요',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.subLabelColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(height: 4),
                            Text(
                              '지도에서 핀을 추가해보세요',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: context.subLabelColor.withValues(alpha: 0.7),
                                fontFamily: AppTokens.fontBody,
                              ),
                            ),
                          ],
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
                              fontWeight: FontWeight.w700,
                              color: context.primaryDarkColor,
                              fontFamily: AppTokens.fontBody,
                            ),
                          );
                        }
                        final pin = pins[i];
                        return Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  AppEmotions.iconOf(pin.emotion),
                                  size: 14,
                                  color: context.primaryDarkColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pin.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                  fontFamily: AppTokens.fontBody,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${pin.createdAt.hour.toString().padLeft(2, '0')}:${pin.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: AppTokens.fontBody,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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

// ─── 감정 분포 카드 ─────────────────────────────────────────────────────────────

class _EmotionStatCard extends StatelessWidget {
  final int likeCount;
  final int totalCount;
  final double likePercent;

  const _EmotionStatCard({
    required this.likeCount,
    required this.totalCount,
    required this.likePercent,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;
    final isDark = context.isDark;

    return Expanded(
      child: Container(
        height: 88,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isDark ? context.cardBg : primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.22),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: isDark
                      ? context.subLabelColor
                      : primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  '감정 분포',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? context.subLabelColor
                        : primary.withValues(alpha: 0.75),
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalCount > 0
                      ? '좋아요 ${(likePercent * 100).round()}%'
                      : '-',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : context.labelColor,
                    fontFamily: AppTokens.fontDisplay,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: likePercent,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white12
                        : primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 최다 요일 카드 ─────────────────────────────────────────────────────────────

class _WeekdayStatCard extends StatelessWidget {
  final String topWeekday;
  final int topCount;

  const _WeekdayStatCard({required this.topWeekday, required this.topCount});

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;
    final isDark = context.isDark;

    return Expanded(
      child: Container(
        height: 88,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isDark ? context.cardBg : primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.22),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 14,
                  color: isDark
                      ? context.subLabelColor
                      : primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  '최다 요일',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? context.subLabelColor
                        : primary.withValues(alpha: 0.75),
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  topWeekday,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : context.labelColor,
                    fontFamily: AppTokens.fontDisplay,
                    height: 1.0,
                  ),
                ),
                if (topCount > 0) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '요일 $topCount개',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.subLabelColor,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 검색 결과 아이템 ──────────────────────────────────────────────────────────

class _SearchResultItem extends StatelessWidget {
  final PinModel pin;
  final VoidCallback? onTap;
  const _SearchResultItem({required this.pin, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.glassCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                AppEmotions.iconOf(pin.emotion),
                size: 18,
                color: context.primaryColor,
              ),
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
                    fontWeight: FontWeight.w700,
                    color: context.labelColor,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                if (pin.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pin.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.subLabelColor,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${pin.createdAt.year}. ${pin.createdAt.month}. ${pin.createdAt.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.subLabelColor,
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
