import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../main_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'sign_up_screen.dart';

class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    await ref.read(pinlogAuthProvider.notifier).signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const MainShell(),
        transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  void _showAdminPanel(BuildContext ctx) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminPanel(
        onEnter: _navigateToMain,
        fetchStats: () =>
            ref.read(pinlogAuthProvider.notifier).fetchAdminStats(),
      ),
    );
  }

  void _showForgotPassword(BuildContext ctx) {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    String? resultMsg;
    bool sending = false;

    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1A1030),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '비밀번호 재설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '가입한 이메일로 재설정 링크를 보내드립니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.50),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Pretendard'),
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(
                            color: Color(0xFF8B5CF6), width: 1.5),
                      ),
                    ),
                  ),
                  if (resultMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      resultMsg!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                        color: resultMsg!.startsWith('✓')
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(dialogCtx).pop(),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      Colors.white.withValues(alpha: 0.60),
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: sending
                              ? null
                              : () async {
                                  final email =
                                      resetEmailCtrl.text.trim();
                                  if (email.isEmpty) return;
                                  setDialogState(() => sending = true);
                                  final err = await ref
                                      .read(pinlogAuthProvider.notifier)
                                      .sendPasswordResetEmail(email);
                                  setDialogState(() {
                                    sending = false;
                                    resultMsg = err ?? '✓ 재설정 이메일을 발송했습니다';
                                  });
                                },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFFD946EF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: sending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '발송',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontFamily: 'Pretendard',
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
        },
      ),
    );
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const OnboardingScreen(),
        transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(pinlogAuthProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    ref.listen(pinlogAuthProvider, (prev, next) {
      if (!next.isAuthenticated) return;
      if (prev?.isAuthenticated == true) return;
      if (next.isNewUser) {
        _navigateToOnboarding();
      } else if (next.isAdmin) {
        _showAdminPanel(context);
      } else {
        _navigateToMain();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0820),
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _EmailSignInBgPainter()),
            ),
            SafeArea(
              child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                              24, 8, 24, bottomPad + 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              const Color(0xFF8B5CF6)
                                                  .withValues(alpha: 0.30),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.email_outlined,
                                          size: 26,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        '이메일 로그인',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                          fontFamily: 'Pretendard',
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '등록된 이메일과 비밀번호를 입력하세요',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white
                                              .withValues(alpha: 0.45),
                                          fontFamily: 'Pretendard',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),

                                _Field(
                                  controller: _emailCtrl,
                                  label: '이메일',
                                  hint: 'example@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return '이메일을 입력해주세요';
                                    }
                                    if (!RegExp(r'^[\w\-.]+@[\w\-]+\.[a-z]{2,}$')
                                        .hasMatch(v.trim())) {
                                      return '올바른 이메일 형식이 아닙니다';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _Field(
                                  controller: _passwordCtrl,
                                  label: '비밀번호',
                                  hint: '비밀번호 입력',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.38),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return '비밀번호를 입력해주세요';
                                    }
                                    return null;
                                  },
                                ),

                                if (authState.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Center(
                                      child: Text(
                                        authState.error!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFF6B6B),
                                          fontFamily: 'Pretendard',
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),

                                // 비밀번호 찾기
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showForgotPassword(context),
                                      child: Text(
                                        '비밀번호를 잊으셨나요?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFFA78BFA)
                                              .withValues(alpha: 0.80),
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                GestureDetector(
                                  onTap: authState.isLoading ? null : _submit,
                                  child: AnimatedOpacity(
                                    opacity: authState.isLoading ? 0.6 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFFD946EF)
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.38),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: authState.isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                '로그인',
                                                style: TextStyle(
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
                                ),
                                const SizedBox(height: 24),

                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.of(context).pushReplacement(
                                        PageRouteBuilder(
                                          pageBuilder: (ctx, a1, a2) =>
                                              const SignUpScreen(),
                                          transitionsBuilder:
                                              (ctx, anim, a2, child) =>
                                                  FadeTransition(
                                            opacity: CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.easeOut),
                                            child: child,
                                          ),
                                          transitionDuration: const Duration(
                                              milliseconds: 300),
                                        ),
                                      );
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        text: '계정이 없으신가요?  ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white
                                              .withValues(alpha: 0.38),
                                          fontFamily: 'Pretendard',
                                        ),
                                        children: const [
                                          TextSpan(
                                            text: '가입하기',
                                            style: TextStyle(
                                              color: Color(0xFFA78BFA),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
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
            ),
          ],
        ),
      ),
    );
  }
}


// ─── 입력 필드 ─────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.48),
            fontFamily: 'Pretendard',
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 13,
            ),
            prefixIcon: Icon(icon,
                size: 18, color: Colors.white.withValues(alpha: 0.32)),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: suffixIcon,
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide:
                  BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFFF6B6B)),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide:
                  BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
            ),
            errorStyle: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 11,
              fontFamily: 'Pretendard',
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 어드민 패널 ───────────────────────────────────────────────────────────────

class _AdminPanel extends StatefulWidget {
  final VoidCallback onEnter;
  final Future<Map<String, int>> Function() fetchStats;

  const _AdminPanel({required this.onEnter, required this.fetchStats});

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  Map<String, int>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.fetchStats().then((s) {
      if (mounted) setState(() { _stats = s; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF130D2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
            blurRadius: 40,
            spreadRadius: -4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, bottomPad + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    size: 20, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '운영자 모드',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'PINLOG v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.40),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 구분선
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.10),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // 통계 카드
          _loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                )
              : Row(
                  children: [
                    _StatCard(
                        label: '전체 핀',
                        value: '${_stats!['totalPins']}',
                        icon: Icons.push_pin_outlined,
                        color: const Color(0xFF8B5CF6)),
                    const SizedBox(width: 10),
                    _StatCard(
                        label: '오늘 핀',
                        value: '${_stats!['todayPins']}',
                        icon: Icons.today_outlined,
                        color: const Color(0xFF34D399)),
                    const SizedBox(width: 10),
                    _StatCard(
                        label: '유저 수',
                        value: '${_stats!['totalUsers']}',
                        icon: Icons.people_outline_rounded,
                        color: const Color(0xFFF59E0B)),
                  ],
                ),

          const SizedBox(height: 24),

          // 앱 진입 버튼
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              widget.onEnter();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '앱 진입',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Pretendard',
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.45),
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 배경 ──────────────────────────────────────────────────────────────────────

class _EmailSignInBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 0.85,
          colors: [
            const Color(0xFF5B21B6).withValues(alpha: 0.42),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    final rng = math.Random(42);
    for (int i = 0; i < 55; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.4 + rng.nextDouble() * 0.9,
        Paint()
          ..color = Colors.white
              .withValues(alpha: 0.05 + rng.nextDouble() * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
