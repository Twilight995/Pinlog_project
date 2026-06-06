import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/providers/meeting_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'demo_meeting_screen.dart';
import 'shared_map_screen.dart';

// ─── 데모 허브 페이지 ──────────────────────────────────────────────────────────

class MockSocialPreviewPage extends ConsumerWidget {
  const MockSocialPreviewPage({super.key});

  bool _isDemoOn(List<Friend> friends) =>
      friends.any((f) => f.supabaseUid?.startsWith('demo_') == true);

  void _toggle(WidgetRef ref, bool currentlyOn) {
    HapticFeedback.selectionClick();
    if (currentlyOn) {
      ref.read(friendsProvider.notifier).clearDemoFriends();
      ref.read(meetingProvider.notifier).clearDemoMeeting();
    } else {
      ref.read(friendsProvider.notifier).addDemoFriends();
      ref.read(meetingProvider.notifier).injectDemoMeeting();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final demoOn = _isDemoOn(friends);
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 헤더 ──────────────────────────────────────────────────────
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
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: context.labelColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '소셜 데모',
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

          // ── 데모 토글 카드 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: GestureDetector(
                onTap: () => _toggle(ref, demoOn),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: demoOn
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF8B5CF6),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: demoOn ? null : context.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: demoOn
                          ? Colors.transparent
                          : context.glassBorder,
                    ),
                    boxShadow: demoOn
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: demoOn
                              ? Colors.white.withValues(alpha: 0.18)
                              : const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.science_rounded,
                          size: 22,
                          color: demoOn
                              ? Colors.white
                              : const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '데모 모드',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: demoOn
                                    ? Colors.white
                                    : context.labelColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              demoOn
                                  ? '친구 2명 · 약속 1건이 활성화됐어요'
                                  : '탭하면 친구·약속 데이터가 자동 주입됩니다',
                              style: TextStyle(
                                fontSize: 12,
                                color: demoOn
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : context.subLabelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 토글 인디케이터
                      Container(
                        width: 48,
                        height: 28,
                        decoration: BoxDecoration(
                          color: demoOn
                              ? Colors.white.withValues(alpha: 0.25)
                              : context.fieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: demoOn
                                ? Colors.white.withValues(alpha: 0.40)
                                : context.glassBorder,
                          ),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: demoOn
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: demoOn
                                  ? Colors.white
                                  : context.subLabelColor
                                      .withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 섹션 레이블 ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                '스크린샷 화면',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.subLabelColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // ── S2 공유 지도 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _DemoCard(
                tag: 'S2',
                title: '공유 지도',
                subtitle: '친구 핀이 지도에 함께 표시됩니다',
                icon: Icons.map_rounded,
                accentColor: const Color(0xFF10B981),
                locked: !demoOn,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const SharedMapScreen()),
                ),
              ),
            ),
          ),

          // ── S3 약속 생성 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _DemoCard(
                tag: 'S3',
                title: '약속 생성 화면',
                subtitle: '친구 선택 · 장소 · 시간 · 이동 수단',
                icon: Icons.handshake_rounded,
                accentColor: const Color(0xFF3B82F6),
                locked: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const _S3MeetingCreatePage()),
                ),
              ),
            ),
          ),

          // ── S4 약속 진행 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _DemoCard(
                tag: 'S4',
                title: '약속 진행 중 (동행 패널)',
                subtitle: '실시간 위치 공유 · ETA · 이동 수단',
                icon: Icons.near_me_rounded,
                accentColor: const Color(0xFFD946EF),
                locked: !demoOn,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const DemoMeetingScreen()),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: botPad + 40)),
        ],
      ),
    );
  }
}

// ─── 데모 카드 ─────────────────────────────────────────────────────────────────

class _DemoCard extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool locked;
  final VoidCallback onTap;

  const _DemoCard({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.glassBorder),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.labelColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      locked ? '데모 모드를 먼저 켜주세요' : subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: locked
                            ? context.subLabelColor
                            : context.subLabelColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.subLabelColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// S3 — 약속 생성 화면 (정적 목업, 이미 디자인 완성)
// ══════════════════════════════════════════════════════════════════

class _S3MeetingCreatePage extends StatelessWidget {
  const _S3MeetingCreatePage();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    const primary = Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Stack(
        children: [
          // 지도 배경
          Positioned.fill(child: CustomPaint(painter: _MapBgPainter())),
          Positioned.fill(
            child: Container(
                color: Colors.black.withValues(alpha: 0.52)),
          ),

          // 뒤로가기
          Positioned(
            top: topPad.clamp(0.0, 62.0) + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ),

          // 바텀 시트
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              constraints: BoxConstraints(maxHeight: size.height * 0.80),
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding:
                  EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        margin:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.handshake_rounded,
                              color: primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('약속 잡기',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _MockLabel('친구 선택'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MockChip(name: '김지후', selected: true, color: primary),
                        const SizedBox(width: 8),
                        _MockChip(name: '이서연', selected: false, color: primary),
                        const SizedBox(width: 8),
                        _MockChip(name: '박민준', selected: false, color: primary),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _MockLabel('만날 장소'),
                    const SizedBox(height: 10),
                    _MockField(
                      value: '성수역 2번 출구',
                      icon: Icons.location_on_rounded,
                      color: primary,
                    ),
                    const SizedBox(height: 22),
                    _MockLabel('약속 시간'),
                    const SizedBox(height: 10),
                    _MockField(
                      value: '2026년 6월 5일 (금)  오후 7:00',
                      icon: Icons.schedule_rounded,
                      color: primary,
                    ),
                    const SizedBox(height: 22),
                    _MockLabel('이동 수단'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MockTransit(
                            label: '대중교통',
                            icon: Icons.directions_transit_rounded,
                            selected: true,
                            color: primary),
                        const SizedBox(width: 8),
                        _MockTransit(
                            label: '도보',
                            icon: Icons.directions_walk_rounded,
                            selected: false,
                            color: primary),
                        const SizedBox(width: 8),
                        _MockTransit(
                            label: '자동차',
                            icon: Icons.directions_car_rounded,
                            selected: false,
                            color: primary),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.40),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('약속 만들기',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
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

class _MockLabel extends StatelessWidget {
  final String text;
  const _MockLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF888888),
          letterSpacing: 0.4));
}

class _MockField extends StatelessWidget {
  final String value;
  final IconData icon;
  final Color color;
  const _MockField(
      {required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      );
}

class _MockChip extends StatelessWidget {
  final String name;
  final bool selected;
  final Color color;
  const _MockChip(
      {required this.name, required this.selected, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected
                  ? color
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1),
        ),
        child: Text(name,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? color
                    : Colors.white.withValues(alpha: 0.55))),
      );
}

class _MockTransit extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  const _MockTransit(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? color
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? color
                    : Colors.white.withValues(alpha: 0.40)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? color
                        : Colors.white.withValues(alpha: 0.40))),
          ],
        ),
      );
}

// ─── 지도 배경 페인터 ─────────────────────────────────────────────────────────

class _MapBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0F1923));

    final road = Paint()
      ..color = const Color(0xFF1E2A35)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final lines = [
      [Offset(0, size.height * 0.22), Offset(size.width, size.height * 0.22)],
      [Offset(0, size.height * 0.48), Offset(size.width, size.height * 0.48)],
      [Offset(0, size.height * 0.72), Offset(size.width, size.height * 0.72)],
      [Offset(size.width * 0.20, 0), Offset(size.width * 0.20, size.height)],
      [Offset(size.width * 0.50, 0), Offset(size.width * 0.50, size.height)],
      [Offset(size.width * 0.78, 0), Offset(size.width * 0.78, size.height)],
    ];
    for (final l in lines) {
      canvas.drawLine(l[0], l[1], road);
    }

    final block = Paint()..color = const Color(0xFF18242F);
    final rects = [
      Rect.fromLTWH(size.width * 0.21, size.height * 0.23,
          size.width * 0.28, size.height * 0.24),
      Rect.fromLTWH(size.width * 0.51, size.height * 0.23,
          size.width * 0.26, size.height * 0.24),
      Rect.fromLTWH(size.width * 0.21, size.height * 0.49,
          size.width * 0.28, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.51, size.height * 0.49,
          size.width * 0.26, size.height * 0.22),
    ];
    for (final r in rects) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), block);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

