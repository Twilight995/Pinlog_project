import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/meeting_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/meeting.dart';

class MeetingBottomSheet extends ConsumerWidget {
  final VoidCallback? onClose;

  const MeetingBottomSheet({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meetingProvider);
    final meeting = state.activeMeeting;
    if (meeting == null) return const SizedBox.shrink();

    final timeStr = DateFormat('M월 d일 HH:mm').format(meeting.scheduledAt);
    final isApproaching = meeting.status == MeetingStatus.approaching ||
        meeting.status == MeetingStatus.meeting;
    final primary = context.primaryColor;
    final primaryLight = context.primaryLightColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryLight.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.13),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 핸들 ──────────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── 헤더: 친구 정보 + 상태 배지 ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_pin, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${meeting.friendNickname ?? "친구"} 님과의 약속',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.labelColor,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(isApproaching: isApproaching, status: meeting.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: context.subLabelColor),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.subLabelColor,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                          if (meeting.targetName != null && meeting.targetName!.isNotEmpty) ...[
                            Text(
                              '  ·  ',
                              style: TextStyle(fontSize: 12, color: context.subLabelColor),
                            ),
                            Flexible(
                              child: Text(
                                meeting.targetName!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.subLabelColor,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: context.separatorColor, indent: 18, endIndent: 18),
          const SizedBox(height: 12),

          // ── 이동 수단 ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  '이동 수단',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.subLabelColor,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(width: 12),
                ...TransitMode.values.map(
                  (mode) => _TransitChip(
                    mode: mode,
                    selected: meeting.transitMode == mode,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(meetingProvider.notifier).updateTransitMode(mode);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── ETA ────────────────────────────────────────────────────────────
          _EtaRow(state: state, meeting: meeting),

          const SizedBox(height: 12),

          // ── 버튼 ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: isApproaching
                ? Row(
                    children: [
                      // 닫기 — 시트만 닫음, 약속은 유지
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onClose?.call();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: context.fieldBg,
                              border: Border.all(color: context.glassBorder),
                            ),
                            child: Center(
                              child: Text(
                                '닫기',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.subLabelColor,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 약속 완료
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            ref.read(meetingProvider.notifier).completeMeeting();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: primary.withValues(alpha: 0.10),
                              border: Border.all(color: primary.withValues(alpha: 0.30)),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 16, color: primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '약속 완료',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(meetingProvider.notifier).depart();
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: LinearGradient(
                          colors: [primary, primaryLight],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.38),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '출발하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.onPrimaryColor,
                            fontFamily: 'Pretendard',
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 상태 배지 ────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isApproaching;
  final MeetingStatus status;

  const _StatusBadge({required this.isApproaching, required this.status});

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
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

// ─── ETA 행 ───────────────────────────────────────────────────────────────────

class _EtaRow extends StatelessWidget {
  final MeetingState state;
  final Meeting meeting;

  const _EtaRow({required this.state, required this.meeting});

  int? get _etaMinutes {
    if (state.etaSeconds != null) {
      return (state.etaSeconds! / 60).ceil().clamp(1, 999);
    }
    final d = state.distanceToTargetMeters;
    if (d == null || d <= 0) return null;
    final speedMs = switch (meeting.transitMode) {
      TransitMode.walking => 5000 / 3600,
      TransitMode.transit => 25000 / 3600,
      TransitMode.driving => 30000 / 3600,
    };
    return (d / speedMs / 60).ceil().clamp(1, 999);
  }

  String get _distLabel {
    final d = state.distanceToTargetMeters;
    if (d == null) return '';
    if (d < 1000) return '${d.round()}m';
    return '${(d / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final eta = _etaMinutes;
    if (eta == null && _distLabel.isEmpty) return const SizedBox.shrink();
    final primary = context.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 14, color: primary),
            const SizedBox(width: 6),
            Text(
              eta != null ? '목적지까지 약 $eta분' : '목적지까지 $_distLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
                fontFamily: 'Pretendard',
              ),
            ),
            if (_distLabel.isNotEmpty && eta != null) ...[
              Text(
                '  ·  $_distLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: context.subLabelColor,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 이동 수단 칩 ─────────────────────────────────────────────────────────────

class _TransitChip extends StatelessWidget {
  final TransitMode mode;
  final bool selected;
  final VoidCallback? onTap;

  const _TransitChip({
    required this.mode,
    required this.selected,
    this.onTap,
  });

  String get _svgPath => switch (mode) {
        TransitMode.driving => 'lib/img/car-svgrepo-com.svg',
        TransitMode.transit => 'lib/img/bus-svgrepo-com.svg',
        TransitMode.walking => 'lib/img/walk-svgrepo-com.svg',
      };

  String get _label => switch (mode) {
        TransitMode.driving => '자동차',
        TransitMode.transit => '대중교통',
        TransitMode.walking => '도보',
      };

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;
    final color = selected ? primary : context.subLabelColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.12) : context.fieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? primary.withValues(alpha: 0.55) : context.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              _svgPath,
              width: 15,
              height: 15,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(width: 4),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
