import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/donghaeng_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/donghaeng_session.dart';

class DonghaengSessionPanel extends ConsumerWidget {
  const DonghaengSessionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(donghaengProvider);
    if (!state.isActive) return const SizedBox.shrink();

    final session = state.session!;
    final myLat = state.myLat;
    final myLng = state.myLng;
    final bottomPad = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);
    final themeColor = context.primaryColor;

    return Positioned(
      bottom: bottomPad + 89,
      left: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: context.cardBg.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themeColor,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '동행 중 · ${session.pinTitle}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.labelColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(donghaengProvider.notifier).endSession();
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.subLabelColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 참여자 목록
                ...session.participants.map((p) {
                  final isMe = p.uid == _firstParticipantUid(session);
                  final dist = (myLat != null && myLng != null && !isMe)
                      ? p.distanceTo(myLat, myLng)
                      : null;
                  final color = isMe ? themeColor : _colorForUid(p.uid);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.18),
                            border: Border.all(color: color, width: 1.8),
                          ),
                          child: Center(
                            child: Text(
                              isMe
                                  ? '나'
                                  : (p.nickname.isNotEmpty ? p.nickname[0] : '?'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isMe ? '나' : p.nickname,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.labelColor,
                            ),
                          ),
                        ),
                        if (p.arrivedHome)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34D399).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '귀가 완료',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          )
                        else if (dist != null)
                          Text(
                            _formatDist(dist),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.subLabelColor,
                            ),
                          )
                        else if (!isMe && p.lat == null)
                          Text(
                            '위치 대기 중',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.subLabelColor,
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 4),

                // 집 도착 버튼
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(donghaengProvider.notifier).markArrivedHome();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeColor.withValues(alpha: 0.9),
                          themeColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '집 도착!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _firstParticipantUid(DonghaengSession session) =>
      session.participants.isNotEmpty ? session.participants.first.uid : '';

  String _formatDist(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Color _colorForUid(String uid) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ];
    if (uid.isEmpty) return colors[0];
    return colors[uid.codeUnitAt(0) % colors.length];
  }
}
