import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/meeting_provider.dart';
import '../../../data/models/meeting.dart';

class MeetingBottomSheet extends ConsumerWidget {
  const MeetingBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meetingProvider);
    final meeting = state.activeMeeting;
    if (meeting == null) return const SizedBox.shrink();

    final pad = MediaQuery.of(context).padding;
    final timeStr = DateFormat('HH:mm').format(meeting.scheduledAt);
    final isApproaching = meeting.status == MeetingStatus.approaching ||
        meeting.status == MeetingStatus.meeting;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, pad.bottom + 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12082A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 핸들 ─────────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // ── 미팅 정보 ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1B5E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_pin,
                    color: Color(0xFFA78BFA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meeting.friendNickname ?? "친구"} 님과의 약속',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '시간: $timeStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                              fontFamily: 'Pretendard',
                            ),
                          ),
                          if (meeting.targetName != null) ...[
                            Text(
                              '  ·  ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.30),
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            Flexible(
                              child: Text(
                                meeting.targetName!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.55),
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
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
            indent: 18,
            endIndent: 18,
          ),
          const SizedBox(height: 14),

          // ── 이동 수단 선택 ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  '이동 수단',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(width: 12),
                ...TransitMode.values.map(
                  (mode) => _TransitChip(
                    mode: mode,
                    selected: meeting.transitMode == mode,
                    onTap: isApproaching
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(meetingProvider.notifier)
                                .updateTransitMode(mode);
                          },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 출발하기 버튼 ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: isApproaching
                ? Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: const Color(0xFF2D1B5E),
                      border: Border.all(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '이동 중 · 친구와의 거리 추적 중',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA78BFA),
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '출발하기 (Depart)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
    final color =
        selected ? const Color(0xFFA78BFA) : Colors.white.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2D1B5E)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFFA78BFA).withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.12),
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
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
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
