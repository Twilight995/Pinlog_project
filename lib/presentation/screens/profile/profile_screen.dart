import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/cosmic/blob.dart';
import '../../widgets/cosmic/category_palette.dart';
import '../../widgets/cosmic/cosmic_background.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifEnabled = true;
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final pins    = ref.watch(pinsProvider);
    final profile = ref.watch(profileProvider);

    // 수집 진행도: 12종 카테고리 중 몇 종 모았는지
    final totalCategories = AppConstants.pinShapes.length;
    final collectedCategories = AppConstants.pinShapes
        .where((shape) => pins.any((p) => p.pinShape == shape))
        .length;

    // 칭호 (도감 탭의 _titles 정의에 따른 레벨/타이틀 미러)
    final titleData = _resolveTitle(pins.length);

    // 함께한 사람 unique 수
    final companionsSet = <String>{};
    for (final p in pins) {
      companionsSet.addAll(p.companions);
    }

    // 최근 핀 (최신 3개)
    final recentPins = [...pins]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final topRecent = recentPins.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      body: Stack(
        children: [
          const Positioned.fill(child: CosmicBackground()),
          CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── 헤더: "프로필" + 감성 카피 (활동/도감과 동일 패턴) ───────────
            const SliverAppBar(
              pinned: true,
              expandedHeight: 112,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '프로필',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: AppTokens.fontDisplay,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '내 발걸음과 함께 자라는 공간',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFC8C1E0),
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 통합 프로필 카드 (프로필 + 컬렉션 + 칭호/동행자) ─────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _UnifiedProfileCard(
                  nickname: profile.nickname,
                  photoPath: profile.photoPath,
                  onEditTap: () => _showEditSheet(context),
                  collected: collectedCategories,
                  total: totalCategories,
                  collectedShapes: AppConstants.pinShapes
                      .where((s) => pins.any((p) => p.pinShape == s))
                      .toSet(),
                  level: titleData.$1,
                  titleName: titleData.$2,
                  toNext: _toNext(pins.length, titleData.$1),
                  companionsCount: companionsSet.length,
                ),
              ),
            ),

            // ── 최근 기록 섹션 (carousel) ────────────────────────────────────
            if (topRecent.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                  child: _RecentSection(pins: topRecent),
                ),
              ),

            // ── 프레임 컬렉션 (편집 모드에서만) ──────────────────────────────
            if (_isEditing)
              SliverToBoxAdapter(
                child: _FrameSection(
                  currentFrameId: profile.borderStyle,
                  pinCount: pins.length,
                  onEquip: (id) => ref
                      .read(profileProvider.notifier)
                      .update(borderStyle: id),
                ),
              ),

            // ── 닉네임 편집 버튼 (편집 모드에서만) ───────────────────────────
            if (_isEditing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _EditNameButton(
                    nickname: profile.nickname,
                    subtitle: profile.subtitle,
                    onTap: () => _showEditSheet(context),
                  ),
                ),
              ),

            // ── 설정 ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: _SettingsSection(
                  notifEnabled: _notifEnabled,
                  onNotifChanged: (v) =>
                      setState(() => _notifEnabled = v),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        ],
      ),
    );
  }

  /// 핀 개수로 현재 칭호 레벨(1-5) + 이름 결정.
  /// (도감 탭 `_titles` 정의 미러 — 0/5/15/30/60 기준)
  (int, String) _resolveTitle(int pinCount) {
    if (pinCount >= 60) return (5, '핀 레전드');
    if (pinCount >= 30) return (4, '라이프 큐레이터');
    if (pinCount >= 15) return (3, '기록 마니아');
    if (pinCount >= 5) return (2, '일상 탐색가');
    return (1, '핀 초보');
  }

  /// 현재 레벨에서 다음 레벨까지 남은 핀 수. 5레벨이면 0.
  int _toNext(int pinCount, int level) {
    const thresholds = [5, 15, 30, 60];
    if (level >= 5) return 0;
    return thresholds[level - 1] - pinCount;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/profile_photo.jpg';
    await File(xfile.path).copy(dest);
    if (!mounted) return;
    ref.read(profileProvider.notifier).update(photoPath: dest);
  }

  void _showEditSheet(BuildContext context) {
    final profile = ref.read(profileProvider);
    showAppSheet<void>(
      context,
      builder: (_) => _ProfileEditSheet(
        initialNickname: profile.nickname,
        initialSubtitle: profile.subtitle,
        onSave: (nickname, subtitle) {
          ref.read(profileProvider.notifier).update(nickname: nickname, subtitle: subtitle);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Frame System — collectible decorative frames (like LoL / Discord)
// ═══════════════════════════════════════════════════════════════════════════════

class _Frame {
  final String id;
  final String name;
  final int unlockAt; // required pin count
  final List<Color> colors;
  const _Frame({required this.id, required this.name, required this.unlockAt, required this.colors});
}

const _kFrames = [
  _Frame(id: 'basic',    name: '기본',   unlockAt: 0,   colors: [Color(0xFFCCCCCC), Color(0xFFFFFFFF)]),
  _Frame(id: 'jade',     name: '비취',   unlockAt: 3,   colors: [Color(0xFF52B788), Color(0xFFB5E48C)]),
  _Frame(id: 'explorer', name: '탐험가', unlockAt: 5,   colors: [Color(0xFF0096C7), Color(0xFF90E0EF)]),
  _Frame(id: 'traveler', name: '여행자', unlockAt: 10,  colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]),
  _Frame(id: 'nature',   name: '자연인', unlockAt: 20,  colors: [Color(0xFF1B4332), Color(0xFF52B788)]),
  _Frame(id: 'legend',   name: '전설',   unlockAt: 50,  colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
  _Frame(id: 'sakura',   name: '벚꽃',   unlockAt: 70,  colors: [Color(0xFFFF8FAB), Color(0xFFFFD6E7)]),
  _Frame(id: 'galaxy',   name: '은하',   unlockAt: 100, colors: [Color(0xFF7C3AED), Color(0xFF38BDF8)]),
  _Frame(id: 'aurora',   name: '오로라', unlockAt: 150, colors: [Color(0xFF22D3EE), Color(0xFFA855F7)]),
  _Frame(id: 'cosmic',   name: '코스믹', unlockAt: 200, colors: [Color(0xFFC026D3), Color(0xFFFFD700)]),
];

_Frame _frameById(String id) =>
    _kFrames.firstWhere((f) => f.id == id, orElse: () => _kFrames.first);

// ─── Frame CustomPainter ──────────────────────────────────────────────────────

class _FramePainter extends CustomPainter {
  final String frameId;
  final List<Color> colors;

  const _FramePainter({required this.frameId, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // Avatar occupies ~74 % of total → radius ≈ 37 %
    final aR = size.width * 0.37; // avatar radius
    final oR = size.width / 2 - 1; // outer bound

    switch (frameId) {
      case 'basic':    _basic(canvas, c, aR, size);
      case 'jade':     _jade(canvas, c, aR, oR, size);
      case 'explorer': _explorer(canvas, c, aR, oR, size);
      case 'traveler': _traveler(canvas, c, aR, oR, size);
      case 'nature':   _nature(canvas, c, aR, oR, size);
      case 'legend':   _legend(canvas, c, aR, oR, size);
      case 'sakura':   _sakura(canvas, c, aR, oR, size);
      case 'galaxy':   _galaxy(canvas, c, aR, oR, size);
      case 'aurora':   _aurora(canvas, c, aR, oR, size);
      case 'cosmic':   _cosmic(canvas, c, aR, oR, size);
    }
  }

  // Thin clean ring
  void _basic(Canvas c, Offset center, double aR, Size s) {
    final sw = s.width * 0.028;
    c.drawCircle(center, aR + sw / 2,
        Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = colors.first);
  }

  // Smooth gradient ring
  void _jade(Canvas c, Offset center, double aR, double oR, Size s) {
    final rR = aR + (oR - aR) * 0.4;
    final sw = s.width * 0.05;
    _gradientRing(c, center, rR, sw, s);
  }

  // Gradient ring + 4 compass diamond points
  void _explorer(Canvas c, Offset center, double aR, double oR, Size s) {
    final rR = aR + (oR - aR) * 0.35;
    _gradientRing(c, center, rR, s.width * 0.045, s);
    final tipR = aR + (oR - aR) * 0.82;
    final ds = s.width * 0.055;
    final paint = Paint()..color = colors.first..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 - pi / 2;
      final px = center.dx + tipR * cos(angle);
      final py = center.dy + tipR * sin(angle);
      final path = Path()
        ..moveTo(px, py - ds)
        ..lineTo(px + ds * 0.55, py)
        ..lineTo(px, py + ds)
        ..lineTo(px - ds * 0.55, py)
        ..close();
      c.drawPath(path, paint);
    }
  }

  // Gradient ring + 8 dots
  void _traveler(Canvas c, Offset center, double aR, double oR, Size s) {
    final rR = aR + (oR - aR) * 0.35;
    _gradientRing(c, center, rR, s.width * 0.045, s);
    final dotR = aR + (oR - aR) * 0.82;
    final dotSize = s.width * 0.045;
    final paint = Paint()..color = colors.first..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = i * 2 * pi / 8 - pi / 2;
      c.drawCircle(Offset(center.dx + dotR * cos(angle), center.dy + dotR * sin(angle)), dotSize, paint);
    }
  }

  // Gradient ring + 6 leaf shapes
  void _nature(Canvas c, Offset center, double aR, double oR, Size s) {
    final rR = aR + (oR - aR) * 0.35;
    _gradientRing(c, center, rR, s.width * 0.05, s);
    final leafR = aR + (oR - aR) * 0.8;
    for (int i = 0; i < 6; i++) {
      final angle = i * 2 * pi / 6 - pi / 2;
      _leaf(c, Offset(center.dx + leafR * cos(angle), center.dy + leafR * sin(angle)),
            angle, s.width * 0.07, colors.last);
    }
  }

  void _leaf(Canvas c, Offset pos, double rotation, double size, Color color) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(rotation + pi / 2);
    final path = Path()
      ..moveTo(0, -size * 0.7)
      ..quadraticBezierTo(size * 0.55, -size * 0.2, 0, size * 0.55)
      ..quadraticBezierTo(-size * 0.55, -size * 0.2, 0, -size * 0.7);
    c.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    c.restore();
  }

  // Golden glow + double ring + 4 diamond accents
  void _legend(Canvas c, Offset center, double aR, double oR, Size s) {
    // Glow
    c.drawCircle(center, aR + (oR - aR) * 0.5,
        Paint()
          ..color = colors.first.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.12
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.06));
    // Outer ring
    _gradientRing(c, center, aR + (oR - aR) * 0.75, s.width * 0.025, s);
    // Inner ring
    final innerR = aR + (oR - aR) * 0.2;
    final rect2 = Rect.fromCircle(center: center, radius: innerR);
    c.drawCircle(center, innerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.03
          ..shader = LinearGradient(
            colors: [colors.last, colors.first],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(rect2));
    // 4 diagonal accent dots
    final dotR = aR + (oR - aR) * 0.78;
    final dotSize = s.width * 0.055;
    final dotPaint = Paint()..color = colors.first..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 - pi / 4;
      c.drawCircle(Offset(center.dx + dotR * cos(angle), center.dy + dotR * sin(angle)), dotSize, dotPaint);
    }
  }

  // ── 벚꽃: 핑크 그라디언트 링 + 8개 꽃 ───────────────────────────────────────
  void _sakura(Canvas c, Offset center, double aR, double oR, Size s) {
    final rR = aR + (oR - aR) * 0.35;
    _gradientRing(c, center, rR, s.width * 0.04, s);
    final flowerR = aR + (oR - aR) * 0.83;
    for (int i = 0; i < 8; i++) {
      final angle = i * 2 * pi / 8 - pi / 2;
      final pos = Offset(center.dx + flowerR * cos(angle), center.dy + flowerR * sin(angle));
      _sakuraFlower(c, pos, angle, s.width * 0.06);
    }
  }

  void _sakuraFlower(Canvas c, Offset pos, double rotation, double size) {
    c.save();
    c.translate(pos.dx, pos.dy);
    for (int p = 0; p < 5; p++) {
      c.save();
      c.rotate(rotation + p * 2 * pi / 5);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(size * 0.35, -size * 0.25, 0, -size * 0.62)
        ..quadraticBezierTo(-size * 0.35, -size * 0.25, 0, 0);
      c.drawPath(path, Paint()..color = colors.first..style = PaintingStyle.fill);
      c.restore();
    }
    c.drawCircle(Offset.zero, size * 0.13,
        Paint()..color = colors.last..style = PaintingStyle.fill);
    c.restore();
  }

  // ── 은하: 듀얼 링 + 별 25개 산포 ───────────────────────────────────────────
  void _galaxy(Canvas c, Offset center, double aR, double oR, Size s) {
    // 외부 얇은 링
    _gradientRing(c, center, aR + (oR - aR) * 0.78, s.width * 0.022, s);
    // 내부 링
    final innerR = aR + (oR - aR) * 0.3;
    final rect2 = Rect.fromCircle(center: center, radius: innerR);
    c.drawCircle(center, innerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.032
          ..shader = LinearGradient(
            colors: [colors.last, colors.first],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(rect2));
    // 별 산포 (결정론적 배치)
    final starZone = oR - aR;
    for (int i = 0; i < 25; i++) {
      // 의사 랜덤: 각도와 거리를 인덱스 기반으로 분산
      final a = (i * 137.508) * pi / 180; // golden angle
      final frac = 0.42 + (i % 5) * 0.115;
      final r = aR + starZone * frac;
      final sx = center.dx + r * cos(a);
      final sy = center.dy + r * sin(a);
      final sz = i % 3 == 0 ? s.width * 0.018 : s.width * 0.010;
      final col = i % 2 == 0 ? colors.first : colors.last;
      _star4(c, Offset(sx, sy), sz, col);
    }
  }

  void _star4(Canvas c, Offset pos, double size, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(pos.dx, pos.dy - size)
      ..lineTo(pos.dx + size * 0.3, pos.dy - size * 0.3)
      ..lineTo(pos.dx + size, pos.dy)
      ..lineTo(pos.dx + size * 0.3, pos.dy + size * 0.3)
      ..lineTo(pos.dx, pos.dy + size)
      ..lineTo(pos.dx - size * 0.3, pos.dy + size * 0.3)
      ..lineTo(pos.dx - size, pos.dy)
      ..lineTo(pos.dx - size * 0.3, pos.dy - size * 0.3)
      ..close();
    c.drawPath(path, paint);
  }

  // ── 오로라: 레인보우 스윕 링 + 반짝이 점 ────────────────────────────────────
  void _aurora(Canvas c, Offset center, double aR, double oR, Size s) {
    // 그로우 헤일로
    c.drawCircle(center, aR + (oR - aR) * 0.5,
        Paint()
          ..color = colors.first.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.14
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.07));
    // 5색 스윕 링
    final rR = aR + (oR - aR) * 0.5;
    final rect = Rect.fromCircle(center: center, radius: rR);
    c.drawCircle(center, rR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.065
          ..shader = SweepGradient(
            colors: const [
              Color(0xFF22D3EE), // cyan
              Color(0xFF86EFAC), // green
              Color(0xFFFFD700), // gold
              Color(0xFFF472B6), // pink
              Color(0xFFA855F7), // purple
              Color(0xFF22D3EE), // back to cyan (wrap)
            ],
            startAngle: 0,
            endAngle: 2 * pi,
          ).createShader(rect));
    // 반짝이 점 10개
    final sparkR = aR + (oR - aR) * 0.84;
    final sparkColors = [colors.first, colors.last, const Color(0xFF86EFAC), const Color(0xFFF472B6)];
    for (int i = 0; i < 10; i++) {
      final angle = i * 2 * pi / 10 - pi / 2;
      final col = sparkColors[i % sparkColors.length];
      c.drawCircle(
        Offset(center.dx + sparkR * cos(angle), center.dy + sparkR * sin(angle)),
        s.width * (i % 2 == 0 ? 0.022 : 0.014),
        Paint()
          ..color = col
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  // ── 코스믹: 강렬한 글로우 + 트리플 링 + 8 다이아몬드 ─────────────────────
  void _cosmic(Canvas c, Offset center, double aR, double oR, Size s) {
    // 외부 글로우
    c.drawCircle(center, aR + (oR - aR) * 0.55,
        Paint()
          ..color = colors.first.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.16
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.09));
    // 내부 글로우 (보색)
    c.drawCircle(center, aR + (oR - aR) * 0.3,
        Paint()
          ..color = colors.last.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.10
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.05));
    // 아우터 링
    _gradientRing(c, center, aR + (oR - aR) * 0.80, s.width * 0.022, s);
    // 미드 링 (역방향 그라디언트)
    final midR = aR + (oR - aR) * 0.5;
    final rect2 = Rect.fromCircle(center: center, radius: midR);
    c.drawCircle(center, midR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.030
          ..shader = LinearGradient(
            colors: [colors.last, colors.first],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ).createShader(rect2));
    // 이너 씬 링
    final innerR = aR + (oR - aR) * 0.15;
    final rect3 = Rect.fromCircle(center: center, radius: innerR);
    c.drawCircle(center, innerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.018
          ..shader = SweepGradient(
            colors: [colors.first, colors.last, colors.first],
            startAngle: 0,
            endAngle: 2 * pi,
          ).createShader(rect3));
    // 8개 다이아몬드 (교차 크기)
    final dR = aR + (oR - aR) * 0.84;
    for (int i = 0; i < 8; i++) {
      final angle = i * 2 * pi / 8 - pi / 2;
      final ds = i % 2 == 0 ? s.width * 0.052 : s.width * 0.033;
      final col = i % 2 == 0 ? colors.first : colors.last;
      final px = center.dx + dR * cos(angle);
      final py = center.dy + dR * sin(angle);
      final path = Path()
        ..moveTo(px, py - ds)
        ..lineTo(px + ds * 0.58, py)
        ..lineTo(px, py + ds)
        ..lineTo(px - ds * 0.58, py)
        ..close();
      c.drawPath(path,
          Paint()
            ..color = col
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0));
    }
  }

  void _gradientRing(Canvas c, Offset center, double r, double sw, Size s) {
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(center, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..shader = LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.frameId != frameId || old.colors[0] != colors[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// 컴팩트 헤더 — 작은 아바타 + Welcome back + 닉네임 + 편집 버튼
// ═══════════════════════════════════════════════════════════════════════════════

class _CompactHeader extends StatelessWidget {
  final String nickname;
  final String? photoPath;
  final bool isEditing;
  final VoidCallback? onPhotoTap;
  final VoidCallback onEditTap;

  const _CompactHeader({
    required this.nickname,
    required this.photoPath,
    required this.isEditing,
    required this.onPhotoTap,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 작은 아바타 (52x52)
        GestureDetector(
          onTap: onPhotoTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TabTheme.profile.bgEnd,
                  TabTheme.profile.accent,
                ],
              ),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: photoPath != null
                  ? Image.file(File(photoPath!), fit: BoxFit.cover)
                  : const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Welcome + 닉네임
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
            ],
          ),
        ),
        // 원형 편집 버튼
        GestureDetector(
          onTap: onEditTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.bgControlPill,
              shape: BoxShape.circle,
              border: Border.all(color: TabTheme.profile.accent, width: 1),
            ),
            child: Icon(
              isEditing ? Icons.check_rounded : Icons.edit_outlined,
              size: 18,
              color: TabTheme.profile.light,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 진행률 글래스 카드 — 다크 코스믹 + 블루 글로우 + 원형 진행률
// ═══════════════════════════════════════════════════════════════════════════════

class _ProgressGlassCard extends StatelessWidget {
  final int collected;
  final int total;

  const _ProgressGlassCard({required this.collected, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? collected / total : 0.0;
    final percent = (progress * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: Stack(
        children: [
          // 다크 코스믹 베이스
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bgCosmicCardStart,
                    AppColors.bgCosmicCardEnd,
                  ],
                ),
              ),
            ),
          ),
          // 오른쪽 부드러운 블루 글로우 클러스터
          Positioned(
            right: -80,
            top: -80,
            child: Blob(
              size: 280,
              color: TabTheme.profile.accent,
              opacity: 0.45,
            ),
          ),
          Positioned(
            right: -30,
            top: -20,
            child: Blob(
              size: 180,
              color: TabTheme.profile.light,
              opacity: 0.55,
            ),
          ),
          // 작은 흰 별 3개
          const Positioned(
              right: 60, top: 18, child: _Star(size: 3, opacity: 0.9)),
          const Positioned(
              right: 30, top: 60, child: _Star(size: 2, opacity: 0.7)),
          const Positioned(
              right: 90, top: 78, child: _Star(size: 2, opacity: 0.6)),
          // 컨텐츠
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 원형 진행률
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 5,
                          backgroundColor: AppOverlays.w08,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            TabTheme.profile.light,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '잘 채워가고 있어요!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total종 중 $collected종 수집했어요 ✨',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ],
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

class _Star extends StatelessWidget {
  final double size;
  final double opacity;
  const _Star({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 닉네임 편집 버튼 (편집 모드에서만)
// ═══════════════════════════════════════════════════════════════════════════════

class _EditNameButton extends StatelessWidget {
  final String nickname;
  final String subtitle;
  final VoidCallback onTap;

  const _EditNameButton({
    required this.nickname,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppOverlays.w08,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(color: AppOverlays.w12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: AppTokens.fontDisplay,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_rounded,
              size: 18,
              color: TabTheme.profile.light,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Frame Collection Section
// ═══════════════════════════════════════════════════════════════════════════════

class _FrameSection extends StatelessWidget {
  final String currentFrameId;
  final int pinCount;
  final ValueChanged<String> onEquip;

  const _FrameSection({
    required this.currentFrameId,
    required this.pinCount,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final current = _frameById(currentFrameId);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '프레임 컬렉션',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: AppTokens.fontDisplay,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppOverlays.w08,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '장착 중: ${current.name}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TabTheme.profile.light,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _kFrames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final frame = _kFrames[i];
                final unlocked = pinCount >= frame.unlockAt;
                final equipped = frame.id == currentFrameId;
                return _FrameItem(
                  frame: frame,
                  isUnlocked: unlocked,
                  isEquipped: equipped,
                  onTap: unlocked ? () => onEquip(frame.id) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameItem extends StatelessWidget {
  final _Frame frame;
  final bool isUnlocked;
  final bool isEquipped;
  final VoidCallback? onTap;

  const _FrameItem({
    required this.frame,
    required this.isUnlocked,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const frameColors = [AppColors.textMuted, Color(0xFFBBBBBB)];
    final displayColors = isUnlocked ? frame.colors : frameColors;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 72,
            height: 72,
            decoration: isEquipped
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: TabTheme.profile.accent, width: 2.5),
                    boxShadow: [BoxShadow(color: TabTheme.profile.accent.withValues(alpha: 0.3), blurRadius: 10)],
                  )
                : null,
            child: Stack(
              children: [
                // Frame preview
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FramePainter(frameId: frame.id, colors: displayColors),
                  ),
                ),
                // Avatar placeholder
                Center(
                  child: SizedBox(
                    width: 53,
                    height: 53,
                    child: ClipOval(
                      child: Container(
                        color: isUnlocked
                            ? AppColors.bgControlPill
                            : AppColors.bgLockedStart,
                        child: Icon(
                          Icons.person_rounded,
                          size: 30,
                          color: isUnlocked ? TabTheme.profile.light : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                // Lock overlay with pin requirement hint
                if (!isUnlocked)
                  Positioned.fill(
                    child: ClipOval(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
                            const SizedBox(height: 2),
                            Text(
                              '${frame.unlockAt}핀',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Equipped check badge
                if (isEquipped)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: TabTheme.profile.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            frame.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? AppColors.textPrimary : AppColors.textMuted,
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// Profile Edit Sheet  (nickname + subtitle only; frame equipped from collection)
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileEditSheet extends StatefulWidget {
  final String initialNickname;
  final String initialSubtitle;
  final void Function(String nickname, String subtitle) onSave;

  const _ProfileEditSheet({
    required this.initialNickname,
    required this.initialSubtitle,
    required this.onSave,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _subtitleCtrl;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.initialNickname);
    _subtitleCtrl = TextEditingController(text: widget.initialSubtitle);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) return;
    widget.onSave(nickname, _subtitleCtrl.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('프로필 수정',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.labelColor)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, size: 20, color: context.subLabelColor),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _FieldLabel('닉네임'),
          const SizedBox(height: 8),
          _EditField(controller: _nicknameCtrl, hint: 'Pinlog 탐험가', maxLength: 20),
          const SizedBox(height: 16),
          _FieldLabel('한 줄 소개'),
          const SizedBox(height: 8),
          _EditField(controller: _subtitleCtrl, hint: '기억을 지도에 새기는 중', maxLength: 40),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _save,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('저장',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.subLabelColor));
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;

  const _EditField({required this.controller, required this.hint, required this.maxLength});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.labelColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: context.subLabelColor),
        counterText: '',
        filled: true,
        fillColor: context.bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settings Section
// ═══════════════════════════════════════════════════════════════════════════════

class _SettingsSection extends StatelessWidget {
  final bool notifEnabled;
  final ValueChanged<bool> onNotifChanged;

  const _SettingsSection({required this.notifEnabled, required this.onNotifChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            '설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: AppTokens.fontDisplay,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Column(
                children: [
                  _ToggleRow(
                    icon: Icons.notifications_outlined,
                    label: '알림',
                    subtitle: '새 공유 핀 및 챌린지 알림',
                    value: notifEnabled,
                    onChanged: onNotifChanged,
                  ),
                  const _RowSeparator(),
                  _TapRow(
                    icon: Icons.share_outlined,
                    label: '공유 지도',
                    subtitle: '친구와 지도 공유하기',
                    trailing: _RowTrailing.chevron,
                    onTap: () {},
                  ),
                  const _RowSeparator(),
                  _TapRow(
                    icon: Icons.info_outline,
                    label: '앱 버전',
                    subtitle: null,
                    trailing: _RowTrailing.version,
                    versionText: 'v1.0.0',
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          _GlassSquareIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
          ),
          _CustomToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 커스텀 토글 (펜 v2 스타일 — ON 민트 / OFF 회색).
class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF5BB89E)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _RowTrailing { chevron, version }

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final _RowTrailing trailing;
  final String? versionText;
  final VoidCallback? onTap;

  const _TapRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.versionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            _GlassSquareIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing == _RowTrailing.chevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF7C6FAB),
              )
            else if (trailing == _RowTrailing.version && versionText != null)
              Text(
                versionText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C6FAB),
                  fontFamily: AppTokens.fontBody,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 펜 v2 스타일 글래스 사각 아이콘 박스 (36×36, cornerRadius 12, 흰 14%, 보라 아이콘).
class _GlassSquareIcon extends StatelessWidget {
  final IconData icon;

  const _GlassSquareIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 17,
        color: const Color(0xFFA78BFA),
      ),
    );
  }
}


class _RowSeparator extends StatelessWidget {
  const _RowSeparator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// 미니 통계 칩 행 — 칭호(Lv) + 함께한 사람
// ═══════════════════════════════════════════════════════════════════════════════

class _MiniStatRow extends StatelessWidget {
  final int level;
  final String titleName;
  final int companionsCount;

  const _MiniStatRow({
    required this.level,
    required this.titleName,
    required this.companionsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: Icons.emoji_events_rounded,
            value: '$level',
            unit: 'Lv',
            label: titleName,
            gradient: const [Color(0xFFFFE5B0), Color(0xFFD9A05C)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.people_alt_rounded,
            value: '$companionsCount',
            unit: '명',
            label: '함께한 사람',
            gradient: const [Color(0xFFC7BFFF), Color(0xFF8B5CF6)],
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final List<Color> gradient;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: Colors.white,
                                fontFamily: AppTokens.fontDisplay,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Text(
                                unit,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFA8A1C8),
                                  fontFamily: AppTokens.fontBody,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Color(0xFF7C6FAB),
                            fontFamily: AppTokens.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 최근 기록 섹션 — 헤더 + carousel (좌 peek + 센터 focus + 우 peek) + dots
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentSection extends StatefulWidget {
  final List<PinModel> pins;
  const _RecentSection({required this.pins});

  @override
  State<_RecentSection> createState() => _RecentSectionState();
}

class _RecentSectionState extends State<_RecentSection> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.74);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '최근 기록',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '전체 보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA78BFA),
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: Color(0xFFA78BFA),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.pins.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final pin = widget.pins[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _RecentCard(pin: pin),
              );
            },
          ),
        ),
        if (widget.pins.length > 1) ...[
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.pins.length, (i) {
                final isActive = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: isActive ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFA78BFA)
                        : Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  final PinModel pin;
  const _RecentCard({required this.pin});

  String get _timeStr {
    final h = pin.createdAt.hour.toString().padLeft(2, '0');
    final m = pin.createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _categoryName =>
      AppConstants.pinShapeNames[pin.pinShape] ?? pin.pinShape;
  String get _emoji =>
      AppConstants.pinShapeEmojis[pin.pinShape] ?? '📍';

  @override
  Widget build(BuildContext context) {
    final palette = CategoryPalette.forShape(pin.pinShape);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          // 베이스 그라디언트 (카테고리 색)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.start,
                    palette.end,
                  ],
                ),
              ),
            ),
          ),
          // 큰 블롭
          Positioned(
            right: -40,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.accent.withValues(alpha: 0.55),
                    palette.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 작은 블롭
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.accent.withValues(alpha: 0.45),
                    palette.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // sparkles
          const Positioned(
              left: 60, top: 30, child: _Star(size: 6, opacity: 0.8)),
          const Positioned(
              right: 60, bottom: 60, child: _Star(size: 5, opacity: 0.65)),
          // 컨텐츠
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 카테고리 펄
                    Container(
                      height: 26,
                      padding: const EdgeInsets.fromLTRB(11, 0, 11, 0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_emoji, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 5),
                          Text(
                            _categoryName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: AppTokens.fontBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 흰 ↗ 버튼
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: Color(0xFF1A0F3D),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  pin.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Color(0xFF1A0F3D),
                    fontFamily: AppTokens.fontDisplay,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_emoji $_categoryName · $_timeStr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.accent,
                    fontFamily: AppTokens.fontBody,
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


// ═══════════════════════════════════════════════════════════════════════════════
// 통합 프로필 카드 — 프로필 + 이번 컬렉션 + 칭호/동행자 (3섹션, divider 구분)
// 펜 v3 디자인
// ═══════════════════════════════════════════════════════════════════════════════

class _UnifiedProfileCard extends StatelessWidget {
  final String nickname;
  final String? photoPath;
  final VoidCallback onEditTap;
  final int collected;
  final int total;
  final Set<String> collectedShapes;
  final int level;
  final String titleName;
  final int toNext;
  final int companionsCount;

  const _UnifiedProfileCard({
    required this.nickname,
    required this.photoPath,
    required this.onEditTap,
    required this.collected,
    required this.total,
    required this.collectedShapes,
    required this.level,
    required this.titleName,
    required this.toNext,
    required this.companionsCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.04),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // ── 섹션 1: 프로필 헤더 ────────────────────────────────────
              _ProfileSection(
                nickname: nickname,
                photoPath: photoPath,
                onEditTap: onEditTap,
              ),
              _CardDivider(),
              // ── 섹션 2: 이번 컬렉션 ───────────────────────────────────
              _CollectionSection(
                collected: collected,
                total: total,
                collectedShapes: collectedShapes,
              ),
              _CardDivider(),
              // ── 섹션 3: 핀 레전드 | 함께한 사람 ────────────────────────
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniCell(
                        icon: Icons.emoji_events_rounded,
                        label: '핀 레전드',
                        value: '$level',
                        unit: 'Lv',
                        sub: toNext > 0
                            ? '다음 레벨까지 $toNext핀'
                            : '최고 레벨 달성',
                      ),
                    ),
                    Container(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Expanded(
                      child: _MiniCell(
                        icon: Icons.people_alt_rounded,
                        label: '함께한 사람',
                        value: '$companionsCount',
                        unit: '명',
                        sub: companionsCount > 0
                            ? '소중한 동행자들'
                            : '아직 동행자 없음',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String nickname;
  final String? photoPath;
  final VoidCallback onEditTap;

  const _ProfileSection({
    required this.nickname,
    required this.photoPath,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 아바타 (56 라운드 사각)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC7BFFF), Color(0xFF8B5CF6)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: photoPath != null
                  ? Image.file(File(photoPath!), fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        nickname.isNotEmpty
                            ? nickname.substring(0, 1).toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // 닉네임 + 카피
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppTokens.fontDisplay,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'welcome back · 오늘도 함께해요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFA8A1C8),
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 편집 버튼
          GestureDetector(
            onTap: onEditTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '편집',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSection extends StatelessWidget {
  final int collected;
  final int total;
  final Set<String> collectedShapes;

  const _CollectionSection({
    required this.collected,
    required this.total,
    required this.collectedShapes,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? collected / total : 0.0;
    final percent = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨 + N/N
          Row(
            children: [
              const Text(
                '이번 컬렉션',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
              const Spacer(),
              Text(
                '$collected / $total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C6FAB),
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 큰 % + 카피
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: Colors.white,
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: AppTokens.fontDisplay,
                  ),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '잘 채워가고 있어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFA78BFA),
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFA78BFA), Color(0xFFC7BFFF)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 12개 카테고리 도트
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: AppConstants.pinShapes.map((shape) {
              final unlocked = collectedShapes.contains(shape);
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? const Color(0xFFA78BFA)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String sub;

  const _MiniCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFFA78BFA)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: Colors.white,
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFA8A1C8),
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C6FAB),
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
    );
  }
}
