import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/meeting_provider.dart';
import '../../../application/providers/nav_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/meeting.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(allMeetingsProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '일정',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.labelColor,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: meetingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(
                child: Text(
                  '일정을 불러오지 못했어요',
                  style: TextStyle(color: context.subLabelColor, fontSize: 14),
                ),
              ),
              data: (meetings) {
                if (meetings.isEmpty) {
                  return _EmptyState(
                    onGoToMap: () =>
                        ref.read(activeTabProvider.notifier).state = 0,
                  );
                }

                final upcoming = meetings
                    .where((m) => m.status != MeetingStatus.completed)
                    .toList();
                final past = meetings
                    .where((m) => m.status == MeetingStatus.completed)
                    .toList();

                return RefreshIndicator(
                  color: context.primaryColor,
                  onRefresh: () => ref.refresh(allMeetingsProvider.future),
                  child: ListView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 90,
                    ),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _SectionHeader(label: '예정된 약속'),
                        const SizedBox(height: 8),
                        ...upcoming.map((m) => _MeetingCard(meeting: m)),
                        const SizedBox(height: 20),
                      ],
                      if (past.isNotEmpty) ...[
                        _SectionHeader(label: '지난 약속'),
                        const SizedBox(height: 8),
                        ...past.map((m) => _MeetingCard(meeting: m)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.subLabelColor,
        fontFamily: AppTokens.fontBody,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ─── Meeting card ──────────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final isDone = meeting.status == MeetingStatus.completed;
    final primary = context.primaryColor;
    final dateStr = DateFormat('M월 d일 (E) a h:mm', 'ko').format(meeting.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? context.glassBorder
              : primary.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: isDone
            ? null
            : [
                BoxShadow(
                  color: primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Row(
        children: [
          // Avatar
          _Avatar(
            avatarUrl: meeting.friendAvatarUrl,
            isDone: isDone,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      meeting.friendNickname ?? '친구',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDone
                            ? context.subLabelColor
                            : context.labelColor,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: meeting.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.subLabelColor,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                if (meeting.targetName != null &&
                    meeting.targetName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: context.subLabelColor,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          meeting.targetName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.subLabelColor,
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Transit mode icon
          SvgPicture.asset(
            meeting.transitSvgPath,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              isDone ? context.subLabelColor : primary,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final bool isDone;
  const _Avatar({this.avatarUrl, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.iconBgColor,
        border: Border.all(
          color: isDone
              ? context.glassBorder
              : context.primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Icon(
        Icons.person_rounded,
        size: 22,
        color: context.subLabelColor,
      );
}

// ─── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final MeetingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MeetingStatus.upcoming => ('예정', context.primaryColor),
      MeetingStatus.approaching => ('이동 중', const Color(0xFFF59E0B)),
      MeetingStatus.meeting => ('만남 중', const Color(0xFF34D399)),
      MeetingStatus.completed => ('완료', context.subLabelColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: AppTokens.fontBody,
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onGoToMap;
  const _EmptyState({required this.onGoToMap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: context.subLabelColor.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            '현재 예정된 핀 일정은 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.subLabelColor,
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '친구와 약속을 잡아보세요',
            style: TextStyle(
              fontSize: 13,
              color: context.subLabelColor.withValues(alpha: 0.65),
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onGoToMap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.primaryColor.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                '지도에서 약속 잡기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.primaryColor,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
