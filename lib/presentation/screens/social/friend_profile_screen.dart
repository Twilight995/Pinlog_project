import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'friend_pins_screen.dart';

class FriendProfileScreen extends ConsumerWidget {
  final Friend friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = context.primaryColor;
    final canViewPins =
        friend.intimacyLevel >= 2 && (friend.supabaseUid?.isNotEmpty ?? false);
    final daysTogether =
        DateTime.now().difference(friend.addedAt).inDays + 1;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── 앱바 ────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: context.bgColor,
            foregroundColor: context.labelColor,
            elevation: 0,
            pinned: true,
            title: Text(
              '친구 프로필',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.labelColor,
                fontFamily: 'Pretendard',
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 프로필 카드 ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.20),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 아바타
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primary.withValues(alpha: 0.30),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              friend.name.isNotEmpty
                                  ? friend.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: primary,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: context.labelColor,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                friend.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.subLabelColor,
                                  fontFamily: 'Pretendard',
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 친밀도 별
                              Row(
                                children: List.generate(5, (i) => Icon(
                                  i < friend.intimacyLevel
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 14,
                                  color: i < friend.intimacyLevel
                                      ? primary
                                      : context.subLabelColor
                                          .withValues(alpha: 0.3),
                                )),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 통계 row ─────────────────────────────────────────────
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.calendar_today_outlined,
                        label: '함께한 날',
                        value: '$daysTogether일',
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.favorite_rounded,
                        label: '친밀도',
                        value: '${friend.intimacyLevel} / 5',
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.calendar_month_outlined,
                        label: '추가일',
                        value: DateFormat('yy.M.d').format(friend.addedAt),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── 핀 보기 버튼 ──────────────────────────────────────────
                  if (canViewPins) ...[
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FriendPinsScreen(friend: friend),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [primary, context.primaryLightColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 18, color: context.onPrimaryColor),
                            const SizedBox(width: 8),
                            Text(
                              '${friend.name} 님의 핀 보기',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.onPrimaryColor,
                                fontFamily: 'Pretendard',
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.fieldBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 16,
                              color: context.subLabelColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              friend.supabaseUid == null
                                  ? '핀 공유는 앱 로그인 친구에게만 가능해요'
                                  : '친밀도 2 이상이 되면 핀을 볼 수 있어요',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.subLabelColor,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 통계 칩 ──────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: context.primaryColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.labelColor,
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.subLabelColor,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
