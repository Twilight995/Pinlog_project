import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../main_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final String? initialNickname;
  final String? initialAvatarUrl;

  const OnboardingScreen({
    super.key,
    this.initialNickname,
    this.initialAvatarUrl,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0;

  // Step 1 — 닉네임
  final _nicknameCtrl = TextEditingController();
  final _nicknameFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  // Step 2 — 프로필 사진
  File? _avatarFile;
  String? _uploadedAvatarUrl;
  bool _uploadingAvatar = false;

  bool _completing = false;

  late final AnimationController _slideCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _enterFade;

  // slide direction: 1 = next (left), -1 = back (right)
  // ignore: unused_field
  int _slideDir = 1;
  int _nextStep = 0;
  late Animation<Offset> _slideOut;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeOut;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    if (widget.initialNickname != null) {
      _nicknameCtrl.text = widget.initialNickname!;
    }

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // 기본값 — 애니메이션 전 정적 상태
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.3, 0))
        .animate(_slideCtrl);
    _slideIn = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(_slideCtrl);
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(_slideCtrl);
    _fadeIn  = Tween<double>(begin: 0.0, end: 1.0).animate(_slideCtrl);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _slideCtrl.dispose();
    _nicknameCtrl.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _animateToStep(int next, {int dir = 1}) async {
    _slideDir = dir;
    _nextStep = next;

    // 두 화면 동일 curve → "push" 효과 (충돌 없음)
    const curve = Curves.easeInOutCubic;
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-0.28 * dir, 0), // 살짝 밀려나는 느낌
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: curve));
    _slideIn = Tween<Offset>(
      begin: Offset(1.0 * dir, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: curve));

    // 이전 화면 fade-out → 잔상 제거
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideCtrl.reset();
    await _slideCtrl.forward();
    if (!mounted) return;
    setState(() => _step = next);
    _slideCtrl.reset();
  }

  // ── Step 1 → Step 2 ─────────────────────────────────────────────────────────
  void _onNextFromNickname() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    _nicknameFocus.unfocus();
    _animateToStep(1);
  }

  // ── Step 2 → 완료 ──────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final result = await _showImageSourceSheet();
    if (result == null) return;

    // 소셜 프로필 사진 사용
    if (result == 'social') {
      setState(() {
        _avatarFile = null;
        _uploadedAvatarUrl = widget.initialAvatarUrl;
      });
      return;
    }

    final source = result as ImageSource;
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    setState(() {
      _avatarFile = File(file.path);
      _uploadingAvatar = true;
    });

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'tmp';
      final ext = file.path.split('.').last.toLowerCase();
      final path = '$uid.$ext';
      final bytes = await _avatarFile!.readAsBytes();

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
      if (mounted) setState(() => _uploadedAvatarUrl = url);
    } catch (_) {
      // Storage 버킷이 없어도 로컬 파일을 미리보기로만 표시
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<Object?> _showImageSourceSheet() async {
    final socialUrl = widget.initialAvatarUrl;
    return showModalBottomSheet<Object>(
      context: context,
      backgroundColor: const Color(0xFF1A1232),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (socialUrl != null)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(socialUrl),
                  radius: 14,
                ),
                title: const Text('소셜 프로필 사진 사용',
                    style: TextStyle(color: Colors.white, fontFamily: 'Pretendard')),
                onTap: () => Navigator.pop(context, 'social'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF8B5CF6)),
              title: const Text('갤러리에서 선택',
                  style: TextStyle(color: Colors.white, fontFamily: 'Pretendard')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF8B5CF6)),
              title: const Text('카메라로 촬영',
                  style: TextStyle(color: Colors.white, fontFamily: 'Pretendard')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _onNextFromAvatar() {
    HapticFeedback.lightImpact();
    _complete();
  }

  // ── 온보딩 완료 ───────────────────────────────────────────────────────────────
  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);

    final avatarUrl = _uploadedAvatarUrl ?? widget.initialAvatarUrl;
    await ref.read(pinlogAuthProvider.notifier).completeOnboarding(
          nickname: _nicknameCtrl.text.trim(),
          avatarUrl: avatarUrl,
        );
    // profileProvider 상태 즉시 갱신 (Hive 저장만으론 UI 반영 안 됨)
    await ref.read(profileProvider.notifier).update(
          nickname: _nicknameCtrl.text.trim(),
          photoPath: avatarUrl,
        );
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const MainShell(),
        transitionsBuilder: (ctx, anim, a2, child) {
          final fade = CurvedAnimation(
            parent: anim,
            curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
          );
          final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutQuart),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 680),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pinlogAuthProvider, (prev, next) {
      if (prev?.isNewUser == true && !next.isNewUser && next.isAuthenticated) {
        _navigateToMain();
      }
    });

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0820),
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _OnboardingBgPainter())),
            SafeArea(
              child: FadeTransition(
                opacity: _enterFade,
                child: Column(
                  children: [
                    _TopBar(step: _step),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _slideCtrl,
                        builder: (_, child) {
                          if (_slideCtrl.isAnimating) {
                            return Stack(
                              children: [
                                // 이전 화면: 살짝 밀리며 fade-out
                                FadeTransition(
                                  opacity: _fadeOut,
                                  child: SlideTransition(
                                    position: _slideOut,
                                    child: _StepContent(
                                      step: _step,
                                      nicknameCtrl: _nicknameCtrl,
                                      nicknameFocus: _nicknameFocus,
                                      formKey: _formKey,
                                      avatarFile: _avatarFile,
                                      uploadingAvatar: _uploadingAvatar,
                                      uploadedAvatarUrl: _uploadedAvatarUrl,
                                      initialAvatarUrl: widget.initialAvatarUrl,
                                      completing: _completing,
                                      onPickAvatar: _pickAvatar,
                                      onNextNickname: _onNextFromNickname,
                                      onNextAvatar: _onNextFromAvatar,
                                      bottomPad: bottomPad,
                                    ),
                                  ),
                                ),
                                // 새 화면: 오른쪽에서 slide-in + fade-in
                                FadeTransition(
                                  opacity: _fadeIn,
                                  child: SlideTransition(
                                    position: _slideIn,
                                    child: _StepContent(
                                      step: _nextStep,
                                      nicknameCtrl: _nicknameCtrl,
                                      nicknameFocus: _nicknameFocus,
                                      formKey: _formKey,
                                      avatarFile: _avatarFile,
                                      uploadingAvatar: _uploadingAvatar,
                                      uploadedAvatarUrl: _uploadedAvatarUrl,
                                      initialAvatarUrl: widget.initialAvatarUrl,
                                      completing: _completing,
                                      onPickAvatar: _pickAvatar,
                                      onNextNickname: _onNextFromNickname,
                                      onNextAvatar: _onNextFromAvatar,
                                      bottomPad: bottomPad,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return _StepContent(
                            step: _step,
                            nicknameCtrl: _nicknameCtrl,
                            nicknameFocus: _nicknameFocus,
                            formKey: _formKey,
                            avatarFile: _avatarFile,
                            uploadingAvatar: _uploadingAvatar,
                            uploadedAvatarUrl: _uploadedAvatarUrl,
                            initialAvatarUrl: widget.initialAvatarUrl,
                            completing: _completing,
                            onPickAvatar: _pickAvatar,
                            onNextNickname: _onNextFromNickname,
                            onNextAvatar: _onNextFromAvatar,
                            bottomPad: bottomPad,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 상단 진행 바 ──────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int step;
  const _TopBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(2, (i) {
              final active = i <= step;
              final current = i == step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  height: 3,
                  margin: EdgeInsets.only(right: i < 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: active
                        ? const Color(0xFF8B5CF6)
                        : Colors.white.withValues(alpha: 0.12),
                    boxShadow: current
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.5),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            '${step + 1} / 2',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.35),
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 단계별 콘텐츠 위젯 ──────────────────────────────────────────────────────────

class _StepContent extends StatelessWidget {
  final int step;
  final TextEditingController nicknameCtrl;
  final FocusNode nicknameFocus;
  final GlobalKey<FormState> formKey;
  final File? avatarFile;
  final bool uploadingAvatar;
  final String? uploadedAvatarUrl;
  final String? initialAvatarUrl;
  final bool completing;
  final VoidCallback onPickAvatar;
  final VoidCallback onNextNickname;
  final VoidCallback onNextAvatar;
  final double bottomPad;

  const _StepContent({
    required this.step,
    required this.nicknameCtrl,
    required this.nicknameFocus,
    required this.formKey,
    required this.avatarFile,
    required this.uploadingAvatar,
    required this.uploadedAvatarUrl,
    required this.initialAvatarUrl,
    required this.completing,
    required this.onPickAvatar,
    required this.onNextNickname,
    required this.onNextAvatar,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      0 => _NicknameStep(
          ctrl: nicknameCtrl,
          focus: nicknameFocus,
          formKey: formKey,
          onNext: onNextNickname,
          bottomPad: bottomPad,
        ),
      _ => _AvatarStep(
          avatarFile: avatarFile,
          uploadingAvatar: uploadingAvatar,
          uploadedAvatarUrl: uploadedAvatarUrl,
          initialAvatarUrl: initialAvatarUrl,
          completing: completing,
          onPick: onPickAvatar,
          onNext: onNextAvatar,
          onSkip: onNextAvatar,
          bottomPad: bottomPad,
        ),
    };
  }
}

// ─── Step 1: 닉네임 ────────────────────────────────────────────────────────────

class _NicknameStep extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final GlobalKey<FormState> formKey;
  final VoidCallback onNext;
  final double bottomPad;

  const _NicknameStep({
    required this.ctrl,
    required this.focus,
    required this.formKey,
    required this.onNext,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              icon: Icons.person_outline_rounded,
              title: '닉네임을 정해주세요',
              subtitle: '언제든지 변경할 수 있어요',
            ),
            const SizedBox(height: 36),
            _OnboardingField(
              controller: ctrl,
              focusNode: focus,
              hint: '2자 이상 입력',
              icon: Icons.badge_outlined,
              validator: (v) {
                if (v == null || v.trim().length < 2) return '2자 이상 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 32),
            _PrimaryButton(label: '다음', onTap: onNext),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: 프로필 사진 ────────────────────────────────────────────────────────

class _AvatarStep extends StatelessWidget {
  final File? avatarFile;
  final bool uploadingAvatar;
  final String? uploadedAvatarUrl;
  final String? initialAvatarUrl;
  final bool completing;
  final VoidCallback onPick;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final double bottomPad;

  const _AvatarStep({
    required this.avatarFile,
    required this.uploadingAvatar,
    required this.uploadedAvatarUrl,
    required this.initialAvatarUrl,
    required this.completing,
    required this.onPick,
    required this.onNext,
    required this.onSkip,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? preview;
    if (avatarFile != null) {
      preview = FileImage(avatarFile!);
    } else if (initialAvatarUrl != null) {
      preview = NetworkImage(initialAvatarUrl!);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.camera_alt_outlined,
            title: '프로필 사진을\n설정해주세요',
            subtitle: '나중에 설정할 수도 있어요',
          ),
          const SizedBox(height: 40),
          Center(
            child: GestureDetector(
              onTap: onPick,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      image: preview != null
                          ? DecorationImage(image: preview, fit: BoxFit.cover)
                          : null,
                    ),
                    child: preview == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.25),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: uploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: '시작하기',
            onTap: onNext,
            isLoading: completing,
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: onSkip,
              child: Text(
                '건너뛰기',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 공통 컴포넌트 ────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                Colors.transparent,
              ],
            ),
          ),
          child: Icon(icon, size: 26, color: const Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.25,
            fontFamily: 'Pretendard',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
            fontFamily: 'Pretendard',
          ),
        ),
      ],
    );
  }
}

class _OnboardingField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;

  const _OnboardingField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontFamily: 'Pretendard',
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.22),
          fontSize: 14,
        ),
        prefixIcon:
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.32)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFFF6B6B),
          fontSize: 11,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── 배경 페인터 ──────────────────────────────────────────────────────────────

class _OnboardingBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 0.9,
          colors: [
            const Color(0xFF5B21B6).withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, 0.8),
          radius: 0.7,
          colors: [
            const Color(0xFF9B2DB5).withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    final rng = math.Random(99);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.3 + rng.nextDouble() * 0.9,
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.04 + rng.nextDouble() * 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
