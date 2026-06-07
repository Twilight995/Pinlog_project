import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/services/social_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';

class FriendPinsScreen extends ConsumerWidget {
  final Friend friend;

  const FriendPinsScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = friend.supabaseUid!;
    final pinsAsync = ref.watch(friendPinsProvider(uid));
    final primary = context.primaryColor;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── 앱바 ──────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: context.bgColor,
            foregroundColor: context.labelColor,
            elevation: 0,
            pinned: true,
            title: Text(
              '${friend.name} 님의 핀',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.labelColor,
                fontFamily: 'Pretendard',
              ),
            ),
            actions: [
              // 새로고침
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: context.subLabelColor, size: 20),
                onPressed: () => ref.invalidate(friendPinsProvider(uid)),
              ),
            ],
          ),

          // ── 콘텐츠 ────────────────────────────────────────────────────
          pinsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  '핀을 불러오지 못했어요',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.subLabelColor,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
            data: (pins) {
              if (pins.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 48,
                          color:
                              context.subLabelColor.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '공개된 핀이 없어요',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.subLabelColor,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${friend.name} 님이 공개로 설정한 핀이 없어요',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.subLabelColor
                                .withValues(alpha: 0.65),
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                sliver: SliverList.separated(
                  itemCount: pins.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _FriendPinCard(
                    pin: pins[i],
                    themeColor: primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 핀 카드 ──────────────────────────────────────────────────────────────────

class _FriendPinCard extends StatelessWidget {
  final PinModel pin;
  final Color themeColor;

  const _FriendPinCard({required this.pin, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(pin.createdAt);
    final emotionColor = AppEmotions.colorOf(pin.emotion);
    final hasPhoto =
        pin.photoPaths.isNotEmpty && pin.photoPaths.first.startsWith('http');

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사진 (있을 경우)
          if (hasPhoto)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              child: Image.network(
                pin.photoPaths.first,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 + 감정
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pin.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.labelColor,
                          fontFamily: 'Pretendard',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: emotionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppEmotions.iconOf(pin.emotion),
                            size: 11,
                            color: emotionColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pin.emotion,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: emotionColor,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (pin.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    pin.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.subLabelColor,
                      fontFamily: 'Pretendard',
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // 메타 정보
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 11,
                        color: context.subLabelColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.subLabelColor,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 강도 별
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < pin.intensityLevel
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 11,
                        color: i < pin.intensityLevel
                            ? themeColor
                            : context.subLabelColor.withValues(alpha: 0.3),
                      ),
                    ),
                    const Spacer(),
                    // 공개 범위 배지
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pin.visibility.replaceAll(RegExp(r'\s.*'), ''),
                        style: TextStyle(
                          fontSize: 10,
                          color: themeColor,
                          fontFamily: 'Pretendard',
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
    );
  }
}
