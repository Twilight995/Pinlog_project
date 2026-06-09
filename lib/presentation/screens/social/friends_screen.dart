import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/services/social_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreFriends = ref.watch(friendsStreamProvider);
    final localFriends = ref.watch(friendsProvider);
    final supaFriends = firestoreFriends.valueOrNull;
    // 친밀도는 로컬 Hive에만 저장 — Supabase 친구 목록에 병합
    final localIntimacyMap = {for (final f in localFriends) f.code: f.intimacyLevel};
    final mergedFriends = supaFriends?.map(
      (f) => f.copyWith(intimacyLevel: localIntimacyMap[f.code] ?? 1),
    ).toList();
    final friends = (mergedFriends != null && mergedFriends.isNotEmpty) ? mergedFriends : localFriends;
    final myCode = ref.watch(myFriendCodeProvider);
    final pendingRequests = ref.watch(pendingRequestsProvider).valueOrNull ?? [];
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 헤더 ────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: context.labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '친구',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.labelColor,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 내 친구 코드 카드 ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _MyCodeCard(code: myCode),
            ),
          ),

          // ── 안내 배너 ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _InfoBanner(),
            ),
          ),

          // ── 친구 신청 섹션 (수신된 신청 있을 때만 표시) ──────────────────────
          if (pendingRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: _PendingRequestsSection(
                requests: pendingRequests,
                onAccept: (req) => _acceptRequest(req, context, ref),
                onReject: (req) => _rejectRequest(req, ref),
              ),
            ),

          // ── 친구 목록 헤더 ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  Text(
                    '친구 목록',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.labelColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${friends.length}명',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showAddFriendSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: context.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_add_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '친구 추가',
                            style: TextStyle(
                              fontSize: 13,
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

          // ── 친구 목록 ────────────────────────────────────────────────────────
          if (friends.isEmpty)
            const SliverToBoxAdapter(child: _EmptyFriends())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: friends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _FriendCard(
                  friend: friends[i],
                  onRemove: () async {
                    final f = friends[i];
                    await ref.read(friendsProvider.notifier).removeFriend(f.code);
                    final uid = f.supabaseUid;
                    if (uid != null && uid.isNotEmpty) {
                      await ref.read(socialServiceProvider).removeFriend(uid);
                    }
                    ref.invalidate(friendsStreamProvider);
                  },
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _showAddFriendSheet(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (_) => const _AddFriendSheet(),
    );
  }

  Future<void> _acceptRequest(
    FriendRequest req,
    BuildContext context,
    WidgetRef ref,
  ) async {
    final err = await ref.read(socialServiceProvider).acceptFriendRequest(
      req.id, req.fromUid, req.fromNickname, req.fromFriendCode,
    );
    if (!context.mounted) return;
    // 성공 시에만 로컬 Hive에 추가
    if (err == null) {
      await ref.read(friendsProvider.notifier).addFriend(
        req.fromFriendCode, req.fromNickname, uid: req.fromUid, notify: false,
      );
    }
    // 항상 두 스트림 재조회 — 성공/실패 무관하게 신청 목록 즉시 제거
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(friendsStreamProvider);
    if (!context.mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${req.fromNickname} 님의 신청을 수락했어요'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _rejectRequest(FriendRequest req, WidgetRef ref) async {
    await ref.read(socialServiceProvider).rejectFriendRequest(req.id);
    ref.invalidate(pendingRequestsProvider);
  }
}

// ─── 내 코드 카드 ─────────────────────────────────────────────────────────────

class _MyCodeCard extends StatelessWidget {
  final String code;
  const _MyCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.primaryColor,
            context.primaryColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              const Text(
                '내 친구 코드',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 코드 박스
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _copyCode(context, code),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '이 코드를 친구에게 알려주세요.\n친구가 코드를 입력하면 연결됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.6),
          ),
        ],
      ),
    );
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: 'Pinlog 친구 코드: $code'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '코드가 복사되었습니다!',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── 안내 배너 ────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '친구가 추가되면 공유 지도에서 함께 방문한 장소를 확인할 수 있어요.',
              style: TextStyle(
                fontSize: 12,
                color: context.primaryColor.withValues(alpha: 0.85),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 빈 상태 ──────────────────────────────────────────────────────────────────

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: context.subLabelColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '아직 친구가 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.subLabelColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '위 버튼을 눌러 친구 코드를 입력해보세요',
              style: TextStyle(
                fontSize: 12,
                color: context.subLabelColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 데모 아바타 헬퍼 ─────────────────────────────────────────────────────────

Widget _buildFriendAvatar(Friend friend, Color intimacyColor, {double size = 44}) {
  final isDemo = friend.supabaseUid?.startsWith('demo_') == true;
  if (!isDemo) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: intimacyColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: intimacyColor.withValues(alpha: 0.55), width: 1.8),
      ),
      child: Center(
        child: Text(
          friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            color: intimacyColor,
          ),
        ),
      ),
    );
  }

  // 데모 친구: 그라데이션 아이콘 아바타
  final grad = friend.code == 'DEMO01'
      ? [const Color(0xFFFFB347), const Color(0xFFFDCB6E)] // 지후: 따뜻한 오렌지-노랑
      : [const Color(0xFF0CEBEB), const Color(0xFF20E3B2)]; // 서연: 민트-청록

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: grad,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shape: BoxShape.circle,
      border: Border.all(color: intimacyColor.withValues(alpha: 0.6), width: 1.8),
    ),
    child: Icon(
      Icons.person_rounded,
      size: size * 0.56,
      color: Colors.white,
    ),
  );
}

// ─── 친밀도 색상 ──────────────────────────────────────────────────────────────

Color _intimacyColor(int level) {
  const colors = [
    Color(0xFFBBBBBB), // 1 — 회색
    Color(0xFF74B9FF), // 2 — 하늘
    Color(0xFF00CEC9), // 3 — 민트
    Color(0xFFFDCB6E), // 4 — 노랑
    Color(0xFFE17055), // 5 — 주황 (핵심 친구)
  ];
  return colors[(level - 1).clamp(0, 4)];
}

// ─── 친구 카드 ────────────────────────────────────────────────────────────────

class _FriendCard extends ConsumerWidget {
  final Friend friend;
  final Future<void> Function() onRemove;

  const _FriendCard({required this.friend, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _intimacyColor(friend.intimacyLevel);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FriendProfileScreen(friend: friend),
        ),
      ),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 아바타
          _buildFriendAvatar(friend, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      friend.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.labelColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 친밀도 별 표시
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) => Icon(
                        i < friend.intimacyLevel
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 10,
                        color: i < friend.intimacyLevel
                            ? color
                            : context.subLabelColor.withValues(alpha: 0.3),
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '코드: ${friend.code} • ${DateFormat('yy.M.d').format(friend.addedAt)} 추가',
                  style: TextStyle(fontSize: 11, color: context.subLabelColor),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showOptionsSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.more_horiz,
                size: 20,
                color: context.subLabelColor,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                _buildFriendAvatar(friend, _intimacyColor(friend.intimacyLevel), size: 40),
                const SizedBox(width: 12),
                Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.labelColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 친밀도 설정
            Text(
              '친밀도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.subLabelColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final level = i + 1;
                final selected = friend.intimacyLevel == level;
                final c = _intimacyColor(level);
                return GestureDetector(
                  onTap: () {
                    ref.read(friendsProvider.notifier).setIntimacy(friend.code, level);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected ? c.withValues(alpha: 0.18) : context.fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? c : Colors.transparent,
                        width: 1.8,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(level, (_) => Icon(
                            Icons.favorite_rounded,
                            size: 8,
                            color: c,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _intimacyLabel(level),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: selected ? c : context.subLabelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // 삭제
            GestureDetector(
              onTap: () => _confirmRemove(context),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: const Center(
                  child: Text(
                    '친구 삭제',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _intimacyLabel(int level) {
    const labels = ['지인', '친구', '친한', '절친', '베프'];
    return labels[(level - 1).clamp(0, 4)];
  }

  void _confirmRemove(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${friend.name} 님을 친구 목록에서 삭제할까요?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.labelColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.labelColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onRemove();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '삭제',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
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

// ─── 친구 추가 시트 ──────────────────────────────────────────────────────────

class _AddFriendSheet extends ConsumerStatefulWidget {
  const _AddFriendSheet();

  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<_AddFriendSheet> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      _showError('코드는 6자리여야 합니다.');
      return;
    }
    setState(() => _loading = true);
    try {
      final service = ref.read(socialServiceProvider);
      final userData = await service.getUserByCode(code);
      if (!mounted) return;
      if (userData == null) {
        _showError('존재하지 않는 코드예요. 다시 확인해주세요.');
        setState(() => _loading = false);
        return;
      }
      final targetUid = userData['uid'] as String? ?? '';
      final targetFriendCode = userData['friend_code'] as String? ?? code;
      final serverName = userData['nickname'] as String? ?? '';
      final localName = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : (serverName.isNotEmpty ? serverName : code);

      final err = await service.sendFriendRequest(targetUid, localName, targetFriendCode);
      if (!mounted) return;
      if (err != null) {
        _showError(err);
        setState(() => _loading = false);
        return;
      }
      // 신청 완료
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text('$localName 님에게 친구 신청을 보냈어요!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {
      if (!mounted) return;
      _showError('연결 중 오류가 발생했어요. 다시 시도해주세요.');
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '친구 추가',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.labelColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: context.subLabelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '친구 코드',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.subLabelColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: context.labelColor,
            ),
            decoration: InputDecoration(
              hintText: 'A1B2C3',
              hintStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: context.hintColor,
              ),
              counterText: '',
              filled: true,
              fillColor: context.fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '이름 (선택사항)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.subLabelColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            maxLength: 20,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.labelColor,
            ),
            decoration: InputDecoration(
              hintText: '입력 안 하면 상대방 닉네임 사용',
              hintStyle: TextStyle(fontSize: 14, color: context.hintColor),
              counterText: '',
              filled: true,
              fillColor: context.fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: _loading
                      ? context.primaryColor.withValues(alpha: 0.5)
                      : context.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '신청 보내기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

// ─── 친구 신청 섹션 ───────────────────────────────────────────────────────────

class _PendingRequestsSection extends StatelessWidget {
  final List<FriendRequest> requests;
  final void Function(FriendRequest) onAccept;
  final void Function(FriendRequest) onReject;

  const _PendingRequestsSection({
    required this.requests,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '친구 신청',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${requests.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...requests.map((req) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PendingRequestCard(
              request: req,
              onAccept: () => onAccept(req),
              onReject: () => onReject(req),
            ),
          )),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                request.fromNickname.isNotEmpty
                    ? request.fromNickname[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromNickname,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.labelColor,
                  ),
                ),
                Text(
                  '코드: ${request.fromFriendCode}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.subLabelColor,
                  ),
                ),
              ],
            ),
          ),
          // 거절 버튼
          GestureDetector(
            onTap: onReject,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: context.subLabelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 수락 버튼
          GestureDetector(
            onTap: onAccept,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
