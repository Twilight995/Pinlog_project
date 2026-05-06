import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final pins  = ref.watch(pinsProvider);
    final profile = ref.watch(profileProvider);
    final now   = DateTime.now();

    final firstPin = pins.isNotEmpty
        ? pins.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b)
        : null;
    final daysSince = firstPin != null
        ? now.difference(firstPin.createdAt).inDays + 1
        : 0;
    final thisMonthCount = pins
        .where((p) => p.createdAt.year == now.year && p.createdAt.month == now.month)
        .length;
    final recentPins = [...pins]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: context.bgColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
              title: Text(
                '프로필',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.labelColor,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                child: GestureDetector(
                  onTap: () => _showEditSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text(
                          '편집',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Profile card ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ProfileCard(
                nickname: profile.nickname,
                subtitle: profile.subtitle,
                photoPath: profile.photoPath,
                frameId: profile.borderStyle,
                onPhotoTap: _pickPhoto,
              ),
            ),
          ),

          // ── Stats ─────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _StatsRow(total: pins.length, thisMonth: thisMonthCount, daysSince: daysSince),
            ),
          ),

          // ── Frame collection ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FrameSection(
              currentFrameId: profile.borderStyle,
              pinCount: pins.length,
              onEquip: (id) => ref.read(profileProvider.notifier).update(borderStyle: id),
            ),
          ),

          // ── Recent pins ───────────────────────────────────────────────────────
          if (recentPins.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _RecentPinsSection(pins: recentPins),
              ),
            ),

          // ── Settings ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: _SettingsSection(
                notifEnabled: _notifEnabled,
                onNotifChanged: (v) => setState(() => _notifEnabled = v),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
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
  _Frame(id: 'basic',    name: '기본',   unlockAt: 0,  colors: [Color(0xFFCCCCCC), Color(0xFFFFFFFF)]),
  _Frame(id: 'jade',     name: '비취',   unlockAt: 3,  colors: [Color(0xFF52B788), Color(0xFFB5E48C)]),
  _Frame(id: 'explorer', name: '탐험가', unlockAt: 5,  colors: [Color(0xFF0096C7), Color(0xFF90E0EF)]),
  _Frame(id: 'traveler', name: '여행자', unlockAt: 10, colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]),
  _Frame(id: 'nature',   name: '자연인', unlockAt: 20, colors: [Color(0xFF1B4332), Color(0xFF52B788)]),
  _Frame(id: 'legend',   name: '전설',   unlockAt: 50, colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
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
// Profile Card  — avatar + frame displayed together
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final String nickname;
  final String subtitle;
  final String? photoPath;
  final String frameId;
  final VoidCallback onPhotoTap;

  const _ProfileCard({
    required this.nickname,
    required this.subtitle,
    required this.photoPath,
    required this.frameId,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onPhotoTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    children: [
                      // Frame (full canvas)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FramePainter(
                            frameId: frameId,
                            colors: _frameById(frameId).colors,
                          ),
                        ),
                      ),
                      // Avatar (centered, 74 % of total)
                      Center(
                        child: SizedBox(
                          width: 89,
                          height: 89,
                          child: ClipOval(
                            child: photoPath != null
                                ? Image.file(File(photoPath!), fit: BoxFit.cover)
                                : Container(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    child: const Icon(Icons.person_rounded, size: 44, color: AppColors.primary),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Camera badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.bgColor, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
                  ),
                  child: Icon(Icons.camera_alt_rounded, size: 14, color: context.labelColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            nickname,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.labelColor, letterSpacing: -0.3),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: context.subLabelColor, fontWeight: FontWeight.w500),
          ),
        ],
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
                Text(
                  '프레임 컬렉션',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.labelColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '장착 중: ${current.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
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
    const frameColors = [AppColors.grey, Color(0xFFBBBBBB)];
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
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)],
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
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : const Color(0xFFEEEEEE),
                        child: Icon(
                          Icons.person_rounded,
                          size: 30,
                          color: isUnlocked ? AppColors.primary.withValues(alpha: 0.45) : AppColors.grey,
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
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
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
              color: isUnlocked ? context.labelColor : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Stats Row  (matches activity screen style)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final int total;
  final int thisMonth;
  final int daysSince;

  const _StatsRow({required this.total, required this.thisMonth, required this.daysSince});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: '총 핀', value: '$total', unit: '개', color: AppColors.primary),
        const SizedBox(width: 10),
        _StatCard(label: '이번 달', value: '$thisMonth', unit: '개', color: AppColors.blue),
        const SizedBox(width: 10),
        _StatCard(label: '활동 일수', value: '$daysSince', unit: '일', color: AppColors.gold),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.labelColor)),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Recent Pins Section
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentPinsSection extends StatelessWidget {
  final List<PinModel> pins;

  const _RecentPinsSection({required this.pins});

  @override
  Widget build(BuildContext context) {
    final preview = pins.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('최근 기록',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.labelColor)),
              GestureDetector(
                onTap: () => showAppSheet<void>(context, builder: (_) => _AllPinsSheet(pins: pins)),
                child: const Text('전체 보기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: preview.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _RecentPinCard(pin: preview[i]),
          ),
        ),
      ],
    );
  }
}

class _RecentPinCard extends StatelessWidget {
  final PinModel pin;

  const _RecentPinCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    final emotionColor = AppEmotions.colorOf(pin.emotion);
    final dateStr = '${pin.createdAt.month}/${pin.createdAt.day}';

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: emotionColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(AppEmotions.iconOf(pin.emotion), size: 13, color: emotionColor),
                const SizedBox(width: 4),
                Text(pin.emotion,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: emotionColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              pin.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.labelColor),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(dateStr, style: TextStyle(fontSize: 11, color: context.subLabelColor)),
          ),
        ],
      ),
    );
  }
}

// ─── All Pins Sheet ───────────────────────────────────────────────────────────

class _AllPinsSheet extends StatelessWidget {
  final List<PinModel> pins;

  const _AllPinsSheet({required this.pins});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: context.glassBorder, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text('전체 기록',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.labelColor)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${pins.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: pins.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('기록이 없어요', style: TextStyle(color: AppColors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: pins.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, i) => _AllPinRow(pin: pins[i]),
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _AllPinRow extends StatelessWidget {
  final PinModel pin;

  const _AllPinRow({required this.pin});

  @override
  Widget build(BuildContext context) {
    final emotionColor = AppEmotions.colorOf(pin.emotion);
    final d = pin.createdAt;
    final dateStr =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(color: emotionColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.labelColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(AppEmotions.iconOf(pin.emotion), size: 12, color: emotionColor),
                    const SizedBox(width: 4),
                    Text(pin.emotion,
                        style: TextStyle(fontSize: 12, color: emotionColor, fontWeight: FontWeight.w500)),
                    if (pin.description.isNotEmpty) ...[
                      Text('  ·  ', style: TextStyle(fontSize: 12, color: context.subLabelColor)),
                      Expanded(
                        child: Text(
                          pin.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: context.subLabelColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(dateStr, style: TextStyle(fontSize: 12, color: context.subLabelColor)),
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
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(14),
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
        Text('설정',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.labelColor)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              _ToggleRow(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFFFF9500),
                label: '알림',
                subtitle: '새 공유 핀 및 챌린지 알림',
                value: notifEnabled,
                onChanged: onNotifChanged,
                isFirst: true,
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.share_outlined,
                iconColor: AppColors.blue,
                label: '공유 지도',
                subtitle: '친구와 지도 공유하기',
                onTap: () {},
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.info_outline,
                iconColor: AppColors.grey,
                label: '앱 버전',
                subtitle: '1.0.0',
                onTap: null,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isFirst;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 6 : 0, 8, 0),
      child: Row(
        children: [
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.labelColor)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: context.subLabelColor)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.dark),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLast;

  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 0),
        child: Row(
          children: [
            _IconBox(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.labelColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.subLabelColor)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 18, color: context.subLabelColor),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _RowSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 62),
      child: Container(height: 1, color: context.separatorColor),
    );
  }
}
