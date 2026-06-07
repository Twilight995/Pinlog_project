import 'dart:io';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/friends_provider.dart';
import '../../../application/providers/pin_provider.dart';
import '../../../data/models/pin_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../auth/sign_in_screen.dart';
import '../../../application/services/backup_service.dart';
import '../../../application/services/fcm_service.dart';
import '../../../application/services/social_service.dart';
import '../../../application/services/pin_sync_service.dart';
import '../../../application/services/storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../legal/terms_screen.dart';
import 'account_settings_screen.dart';
import '../../../application/providers/nav_provider.dart';
import '../schedule/schedule_screen.dart';
import '../social/mock_social_preview.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifEnabled = FCMService.instance.isEnabled;
  bool _syncEnabled = PinSyncService.instance.isEnabled;
  bool _isEditing = false;
  bool _isExporting = false;
  late final ScrollController _sc;

  static const double _collapseRange = 56.0;

  double get _t =>
      (_sc.hasClients ? _sc.offset : 0.0).clamp(0.0, _collapseRange) /
      _collapseRange;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    _sc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins    = ref.watch(pinsProvider);
    final profile = ref.watch(profileProvider);
    final friends = ref.watch(friendsProvider);

    final t = _t;
    final topPad  = MediaQuery.of(context).padding.top;
    final largeOp = 1.0 - Curves.easeInCubic.transform((t / 0.65).clamp(0.0, 1.0));
    final smallOp = Curves.easeOutCubic.transform(((t - 0.38) / 0.62).clamp(0.0, 1.0));

    // 컬렉션 통계
    final usedCategories = pins.map((p) => p.pinShape)
        .toSet()
        .intersection(AppConstants.pinShapes.toSet())
        .length;
    final totalCategories = AppConstants.pinShapes.length;

    // 정렬된 최근 핀
    final sortedPins = [...pins]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentPins = sortedPins.take(5).toList();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad),
          // 고정 44px 바: 스크롤 시 작은 타이틀만
          SizedBox(
            height: 44,
            child: Center(
              child: Opacity(
                opacity: smallOp,
                child: Text(
                  '프로필',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.labelColor,
                  ),
                ),
              ),
            ),
          ),
          // 큰 타이틀 (접힘)
          ClipRect(
            child: Align(
              alignment: Alignment.bottomLeft,
              heightFactor: 1.0 - t,
              child: Opacity(
                opacity: largeOp,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '프로필',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: context.labelColor,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '내 발걸음과 함께 자라는 공간',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          color: context.labelColor.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 콘텐츠
          Expanded(
            child: CustomScrollView(
              controller: _sc,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── 프로필 카드 ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _ProfileCard(
                      nickname: profile.nickname,
                      subtitle: profile.subtitle,
                      photoPath: profile.photoPath,
                      frameId: profile.borderStyle,
                      isEditing: _isEditing,
                      usedCategories: usedCategories,
                      totalCategories: totalCategories,
                      pinCount: pins.length,
                      friendCount: friends.length,
                      onEditToggle: () => setState(() => _isEditing = !_isEditing),
                      onPhotoTap: _isEditing ? _pickPhoto : null,
                      onNameTap: _isEditing ? () => _showEditSheet(context) : null,
                    ),
                  ),
                ),

                // ── 프레임 컬렉션 (편집 모드) ──────────────────────────────────
                SliverToBoxAdapter(
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 320),
                    crossFadeState: _isEditing
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstCurve: Curves.easeOut,
                    secondCurve: Curves.easeIn,
                    sizeCurve: Curves.easeInOut,
                    firstChild: _FrameSection(
                      currentFrameId: profile.borderStyle,
                      pinCount: pins.length,
                      onEquip: (id) =>
                          ref.read(profileProvider.notifier).update(borderStyle: id),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                ),

                // ── 최근 기록 캐러셀 ───────────────────────────────────────────
                if (recentPins.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
                      child: _RecentPinsSection(
                        pins: recentPins,
                        onViewAll: () =>
                            ref.read(activeTabProvider.notifier).state = 1,
                        onPinTap: _showPinDetail,
                      ),
                    ),
                  ),

                // ── 테마 색상 ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                    child: _ThemeColorSection(
                      currentPreset: ref.watch(themePresetProvider),
                      onSelect: (p) =>
                          ref.read(themePresetProvider.notifier).setPreset(p),
                    ),
                  ),
                ),

                // ── 계정 정보 ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                    child: const _AccountSection(),
                  ),
                ),

                // ── 설정 ──────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SettingsSection(
                      notifEnabled: _notifEnabled,
                      onNotifChanged: (v) async {
                        setState(() => _notifEnabled = v);
                        await FCMService.instance.setEnabled(v);
                      },
                      syncEnabled: _syncEnabled,
                      onSyncChanged: (v) async {
                        setState(() => _syncEnabled = v);
                        await PinSyncService.instance.setEnabled(v);
                        if (v) {
                          final pins = ref.read(pinsProvider);
                          await PinSyncService.instance.uploadAll(pins);
                        }
                      },
                      isExporting: _isExporting,
                      onExportBackup: () async {
                        if (_isExporting) return;
                        setState(() => _isExporting = true);
                        try {
                          final pins = ref.read(pinsProvider);
                          if (pins.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('저장된 핀이 없습니다.')),
                            );
                            return;
                          }
                          final sz = MediaQuery.sizeOf(context);
                          await backupService.exportPins(
                            pins,
                            sharePositionOrigin: Rect.fromLTWH(
                              0, sz.height / 2, sz.width, 1),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('내보내기 실패: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isExporting = false);
                        }
                      },
                      onImportBackup: () => _showImportDialog(context),
                      onSignOut: () => _showSignOutDialog(context),
                      onDeleteAccount: () => _showDeleteAccountDialog(context),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSignIn() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const SignInScreen(),
        transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  Future<void> _showSignOutDialog(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('로그아웃',
                style: TextStyle(color: Color(0xFFFF9500))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pinlogAuthProvider.notifier).signOut();
    _navigateToSignIn();
  }

  Future<void> _showDeleteAccountDialog(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text(
          '탈퇴 시 핀, 친구 목록, 약속 등 모든 데이터가 영구 삭제되며 복구할 수 없습니다.\n\n정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('탈퇴하기',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pinlogAuthProvider.notifier).deleteAccount();
    _navigateToSignIn();
  }

  Future<void> _showImportDialog(BuildContext ctx) async {
    final ctrl = TextEditingController();
    final confirmed = await showGeneralDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dCtx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.download_rounded, size: 19, color: context.primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('백업 가져오기', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: context.labelColor, letterSpacing: -0.3,
                          )),
                          Text('내보낸 JSON을 붙여넣으세요', style: TextStyle(
                            fontSize: 11, color: context.subLabelColor,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.glassBorder, width: 1.2),
                  ),
                  child: TextField(
                    controller: ctrl,
                    maxLines: 7,
                    style: TextStyle(fontSize: 12, color: context.labelColor, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'JSON 내용을 붙여넣으세요...',
                      hintStyle: TextStyle(color: context.subLabelColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dCtx, false),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.glassBorder, width: 1.2),
                          ),
                          child: Center(child: Text('취소', style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: context.subLabelColor,
                          ))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dCtx, true),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: context.primaryColor.withValues(alpha: 0.32),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(child: Text('가져오기', style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                          ))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      final imported = await backupService.importFromJson(ctrl.text.trim());
      final notifier = ref.read(pinsProvider.notifier);
      for (final pin in imported) {
        notifier.add(pin);
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${imported.length}개 핀을 가져왔습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('올바른 백업 파일이 아닙니다'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPinDetail(String pinId) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.30),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, _, _) => PinDetailSheet(
        pinId: pinId,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/profile_photo.jpg';
    final localFile = await File(xfile.path).copy(dest);
    if (!mounted) return;
    // 로컬 먼저 반영 (빠른 UI 업데이트)
    ref.read(profileProvider.notifier).update(photoPath: dest);
    // 백그라운드 업로드: 성공 시 URL로 교체
    final url = await StorageService.instance.uploadProfilePhoto(localFile);
    if (url != null && mounted) {
      ref.read(profileProvider.notifier).update(photoPath: url);
      await StorageService.instance.updateAvatarUrl(url);
    }
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
          ref.read(socialServiceProvider).createOrUpdateUser(
            friendCode: ref.read(myFriendCodeProvider),
            nickname: nickname,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Frame System
// ═══════════════════════════════════════════════════════════════════════════════

class _Frame {
  final String id;
  final String name;
  final int unlockAt;
  final List<Color> colors;
  final String? svgPath;

  const _Frame({
    required this.id,
    required this.name,
    required this.unlockAt,
    required this.colors,
    this.svgPath,
  });
}

const _kFrames = [
  _Frame(id: 'basic', name: '기본', unlockAt: 0,  colors: [Color(0xFFCCCCCC), Color(0xFFFFFFFF)]),
  _Frame(
    id: 'floral_ring', name: '꽃 원형', unlockAt: 7,
    colors: [Color(0xFFFF8FAB), Color(0xFFFFD6E7)],
    svgPath: 'lib/img/frame/circular-flowers-ornamental-frame-svgrepo-com.svg',
  ),
  _Frame(
    id: 'floral_corner', name: '꽃 코너', unlockAt: 15,
    colors: [Color(0xFF52B788), Color(0xFFB5E48C)],
    svgPath: 'lib/img/frame/floral-design-corner-ornamental-shape-svgrepo-com.svg',
  ),
  _Frame(
    id: 'floral_square', name: '꽃 사각', unlockAt: 30,
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    svgPath: 'lib/img/frame/frame-square-of-floral-design-svgrepo-com.svg',
  ),
  _Frame(
    id: 'branches', name: '가지', unlockAt: 45,
    colors: [Color(0xFF1B4332), Color(0xFF52B788)],
    svgPath: 'lib/img/frame/two-branches-symbol-of-frame-svgrepo-com.svg',
  ),
];

_Frame _frameById(String id) =>
    _kFrames.firstWhere((f) => f.id == id, orElse: () => _kFrames.first);

class _FramePainter extends CustomPainter {
  final String frameId;
  final List<Color> colors;

  const _FramePainter({required this.frameId, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final aR = size.width * 0.37;
    final sw = size.width * 0.028;
    canvas.drawCircle(
      c, aR + sw / 2,
      Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = colors.first,
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.frameId != frameId || old.colors[0] != colors[0];
}

// ─── Frame Collection Section ─────────────────────────────────────────────────

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
                    color: context.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '장착 중: ${current.name}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 104,
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
                    border: Border.all(color: context.primaryColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: context.primaryColor.withValues(alpha: 0.3), blurRadius: 10),
                    ],
                  )
                : null,
            child: Stack(
              children: [
                if (frame.svgPath == null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FramePainter(frameId: frame.id, colors: displayColors),
                    ),
                  ),
                Center(
                  child: SizedBox(
                    width: 53,
                    height: 53,
                    child: ClipOval(
                      child: Container(
                        color: isUnlocked
                            ? context.primaryColor.withValues(alpha: 0.08)
                            : const Color(0xFFEEEEEE),
                        child: SvgPicture.asset(
                          'lib/img/ui/profile-circle-svgrepo-com.svg',
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            isUnlocked
                                ? context.primaryColor.withValues(alpha: 0.45)
                                : AppColors.grey,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (frame.svgPath != null)
                  Positioned.fill(
                    child: SvgPicture.asset(
                      frame.svgPath!,
                      fit: BoxFit.contain,
                      colorFilter: isUnlocked
                          ? null
                          : const ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
                    ),
                  ),
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
                if (isEquipped)
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(color: context.primaryColor, shape: BoxShape.circle),
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
// Profile Card  — 친구 UI 기반 재설계
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final String nickname;
  final String subtitle;
  final String? photoPath;
  final String frameId;
  final bool isEditing;
  final int usedCategories;
  final int totalCategories;
  final int pinCount;
  final int friendCount;
  final VoidCallback onEditToggle;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onNameTap;

  const _ProfileCard({
    required this.nickname,
    required this.subtitle,
    required this.photoPath,
    required this.frameId,
    required this.isEditing,
    required this.usedCategories,
    required this.totalCategories,
    required this.pinCount,
    required this.friendCount,
    required this.onEditToggle,
    this.onPhotoTap,
    this.onNameTap,
  });

  int get _level => pinCount ~/ 10 + 1;

  String get _levelCaption {
    if (_level <= 1) return '기록을 시작했어요';
    if (_level <= 3) return '꾸준히 기록 중';
    if (_level <= 6) return '베테랑 여행자';
    return '전설의 핀로거';
  }

  double get _collectionPct =>
      totalCategories == 0 ? 0 : usedCategories / totalCategories;

  String get _collectionCaption {
    if (_collectionPct == 0) return '시작해볼까요?';
    if (_collectionPct < 0.34) return '기록을 쌓아가요';
    if (_collectionPct < 0.67) return '절반을 채웠어요!';
    if (_collectionPct < 1.0) return '거의 다 왔어요!';
    return '컬렉션 완성!';
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 아바타 행 ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            child: Row(
              children: [
                // 아바타
                GestureDetector(
                  onTap: onPhotoTap,
                  child: _AvatarSquare(
                    nickname: nickname,
                    photoPath: photoPath,
                    primaryColor: primary,
                    isEditing: isEditing,
                    frameId: frameId,
                  ),
                ),
                const SizedBox(width: 14),
                // 이름 + 서브타이틀
                Expanded(
                  child: GestureDetector(
                    onTap: onNameTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                nickname,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: context.labelColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (isEditing) ...[
                              const SizedBox(width: 5),
                              Icon(Icons.edit_rounded, size: 13, color: primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle.isEmpty ? 'welcome back' : 'welcome back · $subtitle',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.subLabelColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 편집 버튼
                GestureDetector(
                  onTap: onEditToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: isEditing
                          ? primary.withValues(alpha: 0.15)
                          : context.bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isEditing
                            ? primary.withValues(alpha: 0.4)
                            : context.separatorColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEditing ? Icons.check_rounded : Icons.edit_outlined,
                          size: 13,
                          color: isEditing ? primary : context.labelColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isEditing ? '완료' : '편집',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isEditing ? primary : context.labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 구분선 ─────────────────────────────────────────────────────
          Container(height: 1, color: context.separatorColor),

          // ── 컬렉션 진행 ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _CollectionProgress(
              usedCategories: usedCategories,
              totalCategories: totalCategories,
              pct: _collectionPct,
              caption: _collectionCaption,
              primaryColor: context.readablePrimary,
              separatorColor: context.separatorColor,
              labelColor: context.labelColor,
              subLabelColor: context.subLabelColor,
            ),
          ),

          // ── 구분선 ─────────────────────────────────────────────────────
          Container(height: 1, color: context.separatorColor),

          // ── 스탯 박스 행 ───────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.emoji_events_rounded,
                    label: '핀 레전드',
                    value: '$_level',
                    valueSuffix: ' Lv',
                    caption: _levelCaption,
                    labelColor: context.labelColor,
                    subLabelColor: context.subLabelColor,
                  ),
                ),
                VerticalDivider(width: 1, color: context.separatorColor),
                Expanded(
                  child: _StatBox(
                    icon: Icons.people_outline,
                    label: '함께한 사람',
                    value: '$friendCount',
                    valueSuffix: ' 명',
                    caption: '소중한 동행자들',
                    labelColor: context.labelColor,
                    subLabelColor: context.subLabelColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── 정사각형 아바타 ───────────────────────────────────────────────────────────

class _AvatarSquare extends StatelessWidget {
  final String nickname;
  final String? photoPath;
  final Color primaryColor;
  final bool isEditing;
  final String frameId;

  const _AvatarSquare({
    required this.nickname,
    required this.photoPath,
    required this.primaryColor,
    required this.isEditing,
    this.frameId = 'basic',
  });

  Widget _photoPlaceholder(String nickname) => Center(
        child: Text(
          nickname.isEmpty ? 'P' : nickname[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final frame = _frameById(frameId);
    final hasFrame = frameId != 'basic' && frame.svgPath != null;

    // 프레임 있을 때 바깥 Stack은 90x90, 아바타는 68x68 중앙 배치
    final outer = hasFrame ? 90.0 : 68.0;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── 아바타 + 카메라 아이콘 ────────────────────────────────────────
          Align(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: photoPath == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [primaryColor, primaryColor.withValues(alpha: 0.70)],
                          )
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photoPath != null
                      ? (photoPath!.startsWith('http')
                          ? Image.network(photoPath!, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _photoPlaceholder(nickname))
                          : Image.file(File(photoPath!), fit: BoxFit.cover))
                      : _photoPlaceholder(nickname),
                ),
                if (isEditing)
                  AnimatedOpacity(
                    opacity: isEditing ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // ── 프레임 SVG 오버레이 ───────────────────────────────────────────
          if (hasFrame)
            Positioned.fill(
              child: IgnorePointer(
                child: SvgPicture.asset(
                  frame.svgPath!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 컬렉션 진행 섹션 ─────────────────────────────────────────────────────────

class _CollectionProgress extends StatelessWidget {
  final int usedCategories;
  final int totalCategories;
  final double pct;
  final String caption;
  final Color primaryColor;
  final Color separatorColor;
  final Color labelColor;
  final Color subLabelColor;

  const _CollectionProgress({
    required this.usedCategories,
    required this.totalCategories,
    required this.pct,
    required this.caption,
    required this.primaryColor,
    required this.separatorColor,
    required this.labelColor,
    required this.subLabelColor,
  });

  @override
  Widget build(BuildContext context) {
    final dotCount = min(totalCategories, 14);
    final usedShapes = AppConstants.pinShapes.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더 행
        Row(
          children: [
            Text(
              '이번 컬렉션',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: subLabelColor,
              ),
            ),
            const Spacer(),
            Text(
              '$usedCategories / $totalCategories',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subLabelColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 큰 퍼센트 + 캡션
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${(pct * 100).round()}',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: labelColor,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' %',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: labelColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                caption,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 프로그레스 바
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: separatorColor),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 카테고리 도트 행
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dotCount, (i) {
            final shape = AppConstants.pinShapes[i];
            final isUsed = usedShapes.contains(shape);
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUsed
                    ? primaryColor
                    : primaryColor.withValues(alpha: 0.18),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── 스탯 박스 ────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String valueSuffix;
  final String caption;
  final Color labelColor;
  final Color subLabelColor;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueSuffix,
    required this.caption,
    required this.labelColor,
    required this.subLabelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: subLabelColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subLabelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: labelColor,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: valueSuffix,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              color: subLabelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Recent Pins Carousel
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentPinsSection extends StatefulWidget {
  final List<PinModel> pins;
  final VoidCallback onViewAll;
  final void Function(String pinId)? onPinTap;

  const _RecentPinsSection({required this.pins, required this.onViewAll, this.onPinTap});

  @override
  State<_RecentPinsSection> createState() => _RecentPinsSectionState();
}

class _RecentPinsSectionState extends State<_RecentPinsSection> {
  late final PageController _pc;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.84);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              Text(
                '최근 기록',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: context.labelColor,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onViewAll,
                child: Row(
                  children: [
                    Text(
                      '전체 보기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.readablePrimary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: context.readablePrimary),
                  ],
                ),
              ),
            ],
          ),
        ),
        // PageView
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pc,
            itemCount: pins.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 20 : 6,
                right: i == pins.length - 1 ? 20 : 6,
              ),
              child: _PinCard(
                pin: pins[i],
                onTap: widget.onPinTap != null
                    ? () => widget.onPinTap!(pins[i].id)
                    : null,
              ),
            ),
          ),
        ),
        // 페이지 인디케이터
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pins.length, (i) {
            final isActive = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? context.readablePrimary
                    : context.readablePrimary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PinCard extends StatelessWidget {
  final dynamic pin; // PinModel
  final VoidCallback? onTap;

  const _PinCard({required this.pin, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;
    final shape = pin.pinShape as String? ?? 'cafe';
    final svgPath = AppConstants.pinShapeSvgs[shape];
    final catName = AppConstants.pinShapeNames[shape] ?? shape;
    final created = pin.createdAt as DateTime;
    final timeStr =
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    Widget svgIcon(double size, Color color) {
      if (svgPath != null) {
        return SvgPicture.asset(
          svgPath,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      }
      return Icon(Icons.place_rounded, size: size, color: color);
    }

    // 밝은 테마에서 가시성 보장: 텍스트/아이콘용 읽기 가능한 색상
    final readable = context.readablePrimary;
    final onBadge = context.onPrimaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.22),
            primary.withValues(alpha: 0.06),
            context.cardBg,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.20), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 행: 카테고리 배지 + 화살표
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: readable,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      svgIcon(13, onBadge),
                      const SizedBox(width: 5),
                      Text(
                        catName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: onBadge,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.north_east_rounded, size: 15, color: readable),
                ),
              ],
            ),
            const Spacer(),
            // 하단: 제목
            Text(
              pin.title as String? ?? '',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.labelColor,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                svgIcon(12, readable),
                const SizedBox(width: 5),
                Text(
                  '$catName · $timeStr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: readable,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Profile Edit Sheet
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
                  color: context.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withValues(alpha: 0.3),
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
// Theme Color Picker
// ═══════════════════════════════════════════════════════════════════════════════

class _ThemeColorSection extends StatefulWidget {
  final AppThemePreset currentPreset;
  final ValueChanged<AppThemePreset> onSelect;

  const _ThemeColorSection({required this.currentPreset, required this.onSelect});

  @override
  State<_ThemeColorSection> createState() => _ThemeColorSectionState();
}

class _ThemeColorSectionState extends State<_ThemeColorSection> {
  bool _expanded = false;

  void _openCustomPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(
        initial: widget.currentPreset.isCustom ? widget.currentPreset.primary : null,
        onPick: (color) {
          widget.onSelect(AppThemePreset.fromColor(color));
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.currentPreset.isCustom;
    final primary  = widget.currentPreset.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text('테마 색상',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.labelColor)),
              const SizedBox(width: 10),
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: isCustom ? null : primary,
                  shape: BoxShape.circle,
                  gradient: isCustom
                      ? const SweepGradient(colors: [
                          Color(0xFFFF0000), Color(0xFFFF8800), Color(0xFFFFFF00),
                          Color(0xFF00FF00), Color(0xFF0088FF), Color(0xFF8800FF),
                          Color(0xFFFF0088), Color(0xFFFF0000),
                        ])
                      : null,
                  border: Border.all(color: context.separatorColor, width: 1.5),
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: context.labelColor.withValues(alpha: 0.4), size: 22),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...AppThemePreset.presets.map((preset) {
                            final isSelected = !isCustom && preset == widget.currentPreset;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => widget.onSelect(preset),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                  width: isSelected ? 42 : 32,
                                  height: isSelected ? 42 : 32,
                                  decoration: BoxDecoration(
                                    color: preset.primary,
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: preset.primary.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))]
                                        : [],
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check_rounded, size: 15, color: preset.onPrimary)
                                      : null,
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () => _openCustomPicker(context),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              width: isCustom ? 42 : 32,
                              height: isCustom ? 42 : 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(colors: [
                                  Color(0xFFFF0000), Color(0xFFFF8800), Color(0xFFFFFF00),
                                  Color(0xFF00FF00), Color(0xFF0088FF), Color(0xFF8800FF),
                                  Color(0xFFFF0088), Color(0xFFFF0000),
                                ]),
                                border: isCustom ? Border.all(color: Colors.white, width: 2.5) : null,
                                boxShadow: isCustom
                                    ? [BoxShadow(color: widget.currentPreset.primary.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))]
                                    : [],
                              ),
                              child: isCustom
                                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                  : const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── 커스텀 색상 피커 시트 ────────────────────────────────────────────────────

class _ColorPickerSheet extends StatefulWidget {
  final Color? initial;
  final ValueChanged<Color> onPick;

  const _ColorPickerSheet({this.initial, required this.onPick});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late double _hue;
  late double _saturation;
  late double _lightness;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final hsl = HSLColor.fromColor(widget.initial!);
      _hue        = hsl.hue;
      _saturation = hsl.saturation.clamp(0.4, 1.0);
      _lightness  = hsl.lightness.clamp(0.3, 0.7);
    } else {
      _hue = 200.0; _saturation = 0.78; _lightness = 0.52;
    }
  }

  Color get _color => HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();
  Color get _onColor => _color.computeLuminance() > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, pad + 24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: context.chipBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('색상 직접 설정',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.labelColor)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, size: 20, color: context.subLabelColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('색조', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.subLabelColor)),
          const SizedBox(height: 8),
          _GradientSlider(
            value: _hue / 360.0,
            gradientColors: const [
              Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
              Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
            ],
            onChanged: (v) => setState(() => _hue = v * 360.0),
          ),
          const SizedBox(height: 16),
          Text('채도', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.subLabelColor)),
          const SizedBox(height: 8),
          _GradientSlider(
            value: (_saturation - 0.4) / 0.6,
            gradientColors: [
              HSLColor.fromAHSL(1.0, _hue, 0.4, _lightness).toColor(),
              HSLColor.fromAHSL(1.0, _hue, 1.0, _lightness).toColor(),
            ],
            onChanged: (v) => setState(() => _saturation = v * 0.6 + 0.4),
          ),
          const SizedBox(height: 16),
          Text('밝기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.subLabelColor)),
          const SizedBox(height: 8),
          _GradientSlider(
            value: (_lightness - 0.3) / 0.4,
            gradientColors: [
              HSLColor.fromAHSL(1.0, _hue, _saturation, 0.3).toColor(),
              HSLColor.fromAHSL(1.0, _hue, _saturation, 0.7).toColor(),
            ],
            onChanged: (v) => setState(() => _lightness = v * 0.4 + 0.3),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => widget.onPick(_color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 52,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text('이 색상 적용하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _onColor)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientSlider extends StatelessWidget {
  final double value;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({required this.value, required this.gradientColors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const thumbW = 22.0;
      final thumbX = (value * (w - thumbW)).clamp(0.0, w - thumbW);

      void handleDx(double dx) => onChanged((dx / w).clamp(0.0, 1.0));

      return GestureDetector(
        onHorizontalDragUpdate: (d) => handleDx(d.localPosition.dx),
        onTapDown: (d) => handleDx(d.localPosition.dx),
        child: SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              Positioned(
                left: thumbX,
                child: Container(
                  width: thumbW, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settings Section
// ═══════════════════════════════════════════════════════════════════════════════

class _SettingsSection extends StatelessWidget {
  final bool notifEnabled;
  final ValueChanged<bool> onNotifChanged;
  final bool syncEnabled;
  final ValueChanged<bool> onSyncChanged;
  final bool isExporting;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const _SettingsSection({
    required this.notifEnabled,
    required this.onNotifChanged,
    required this.syncEnabled,
    required this.onSyncChanged,
    required this.isExporting,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = context.primaryColor;
    final mutedColor = context.labelColor.withValues(alpha: 0.38);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('설정',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.labelColor, letterSpacing: -0.3)),
        const SizedBox(height: 14),
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
                iconColor: themeColor,
                label: '알림',
                subtitle: '새 공유 핀 및 챌린지 알림',
                value: notifEnabled,
                onChanged: onNotifChanged,
                isFirst: true,
              ),
              _RowSeparator(),
              _ToggleRow(
                icon: Icons.cloud_sync_outlined,
                iconColor: themeColor,
                label: '클라우드 동기화',
                subtitle: '핀을 Supabase에 자동 저장',
                value: syncEnabled,
                onChanged: onSyncChanged,
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.upload_outlined,
                iconColor: isExporting ? mutedColor : themeColor,
                label: '핀 내보내기',
                subtitle: isExporting ? '파일 생성 중...' : 'JSON 백업 파일로 저장/공유',
                trailing: isExporting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: themeColor,
                        ),
                      )
                    : null,
                onTap: isExporting ? null : onExportBackup,
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.download_outlined,
                iconColor: themeColor,
                label: '핀 가져오기',
                subtitle: 'JSON 백업 파일에서 복원',
                onTap: onImportBackup,
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.description_outlined,
                iconColor: themeColor,
                label: '이용약관',
                subtitle: '서비스 이용 약관 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TermsScreen()),
                ),
              ),
              _RowSeparator(),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => _TapRow(
                  icon: Icons.info_outline,
                  iconColor: mutedColor,
                  label: '앱 버전',
                  subtitle: 'v${snapshot.data?.version ?? '1.0.0'}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MockSocialPreviewPage()),
                  ),
                ),
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.logout_rounded,
                iconColor: themeColor,
                label: '로그아웃',
                subtitle: '현재 계정에서 로그아웃',
                onTap: onSignOut,
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.delete_forever_outlined,
                iconColor: const Color(0xFFFF3B30),
                label: '계정 탈퇴',
                subtitle: '계정 및 모든 데이터 영구 삭제',
                onTap: onDeleteAccount,
                isLast: true,
                isDestructive: true,
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
                Text(label,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.labelColor)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: context.subLabelColor)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: context.primaryColor),
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
  final bool isDestructive;
  final Widget? trailing;

  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
    this.isDestructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDestructive
        ? const Color(0xFFFF3B30)
        : context.labelColor;
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
                  Text(label,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: context.subLabelColor)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: context.subLabelColor)
            else
              const SizedBox.shrink(),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
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

// ── 계정 정보 섹션 ─────────────────────────────────────────────────────────────
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final themeColor = context.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('계정',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.labelColor, letterSpacing: -0.3)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              _TapRow(
                icon: Icons.manage_accounts_outlined,
                iconColor: themeColor,
                label: '계정 설정',
                subtitle: '이메일 확인 · 비밀번호 변경',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
              _RowSeparator(),
              _TapRow(
                icon: Icons.calendar_today_outlined,
                iconColor: themeColor,
                label: '일정',
                subtitle: '친구와의 핀 약속 내역',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScheduleScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
