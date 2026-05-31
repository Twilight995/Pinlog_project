import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../onboarding/onboarding_screen.dart';
import 'email_verify_screen.dart';

// 전화번호 자동 하이픈 포맷터 (010-XXXX-XXXX)
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 7) buf.write('-');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // 기본 필드
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;

  // 아이디
  final _usernameCtrl    = TextEditingController();
  bool  _usernameChecking = false;
  bool? _usernameAvailable; // null=미확인 true=사용가능 false=중복

  // 전화번호
  final _phoneCtrl  = TextEditingController();
  bool  _showPhone  = false;
  bool  _sendingOtp = false;
  bool  _phoneVerified = false;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onEmailChanged);
    _usernameCtrl.addListener(_onUsernameEdited);
  }

  void _onEmailChanged() {
    final email = _emailCtrl.text.trim();
    if (email.contains('@')) {
      final prefix = email.split('@').first;
      if (_usernameCtrl.text.isEmpty || _isAutoUsername) {
        _usernameCtrl.text = prefix;
      }
    }
    // 이메일 바뀌면 아이디 확인 초기화
    setState(() {
      _usernameAvailable = null;
      _showPhone = false;
    });
  }

  bool get _isAutoUsername {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) return false;
    return _usernameCtrl.text == email.split('@').first;
  }

  void _onUsernameEdited() {
    if (_usernameAvailable != null) {
      setState(() {
        _usernameAvailable = null;
        _showPhone = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── 아이디 중복 확인 ──────────────────────────────────────────────────────────

  Future<void> _checkUsername() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _usernameChecking = true);
    final available = await ref
        .read(pinlogAuthProvider.notifier)
        .checkUsernameAvailable(username);
    setState(() {
      _usernameChecking = false;
      _usernameAvailable = available;
      if (available) _showPhone = true;
    });
    if (available) HapticFeedback.lightImpact();
  }

  // ── 전화번호 인증 (목업) ──────────────────────────────────────────────────────
  // TODO(twilio): Supabase SMS 프로바이더(Twilio) 설정 후 실제 OTP 발송으로 교체
  //   - sendSignupPhoneOtp(phone) → OTP 섹션 표시
  //   - verifySignupPhoneOtp(phone, token) → _phoneVerified = true

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = '전화번호를 입력해주세요');
      return;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() => _phoneError = '올바른 전화번호를 입력해주세요');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() { _sendingOtp = true; _phoneError = null; });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _sendingOtp = false;
      _phoneVerified = true;
    });
    HapticFeedback.mediumImpact();
  }

  // ── 회원가입 제출 ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_usernameAvailable != true) {
      setState(() {}); // 아이디 확인 필요 메시지는 validator에서 처리
      return;
    }

    if (_showPhone && !_phoneVerified) {
      setState(() => _phoneError = '전화번호 인증을 완료해주세요');
      return;
    }

    HapticFeedback.lightImpact();
    await ref.read(pinlogAuthProvider.notifier).signUpWithEmail(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      username: _usernameCtrl.text.trim(),
      phone: _phoneVerified ? _phoneCtrl.text.trim() : null,
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
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        _navigateToOnboarding();
        return;
      }
      if (next.pendingEmail != null && prev?.pendingEmail == null) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, _, _) =>
                EmailVerifyScreen(email: next.pendingEmail!),
            transitionsBuilder: (_, anim, _, child) => FadeTransition(
              opacity: CurvedAnimation(
                parent: anim,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 520),
            reverseTransitionDuration: const Duration(milliseconds: 380),
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0820),
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SignUpBgPainter()),
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
                              24, 4, 24, bottomPad + 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── 헤더 ───────────────────────────────────
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
                                          Icons.location_pin,
                                          size: 28,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        '계정 만들기',
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
                                        '나만의 지도 일기를 시작해요',
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
                                const SizedBox(height: 36),

                                // ── 이메일 ─────────────────────────────────
                                _SignUpField(
                                  controller: _emailCtrl,
                                  label: '이메일',
                                  hint: 'example@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return '이메일을 입력해주세요';
                                    }
                                    if (!RegExp(
                                            r'^[\w\-.]+@[\w\-]+\.[a-z]{2,}$')
                                        .hasMatch(v.trim())) {
                                      return '올바른 이메일 형식이 아닙니다';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // ── 비밀번호 ───────────────────────────────
                                _SignUpField(
                                  controller: _passwordCtrl,
                                  label: '비밀번호',
                                  hint: '8자 이상, 영문+숫자 포함',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: Colors.white
                                          .withValues(alpha: 0.38),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 8) {
                                      return '8자 이상 입력해주세요';
                                    }
                                    if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
                                      return '영문자를 포함해주세요';
                                    }
                                    if (!RegExp(r'[0-9]').hasMatch(v)) {
                                      return '숫자를 포함해주세요';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // ── 비밀번호 확인 ──────────────────────────
                                _SignUpField(
                                  controller: _confirmCtrl,
                                  label: '비밀번호 확인',
                                  hint: '비밀번호를 다시 입력하세요',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscureConfirm,
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm),
                                    child: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: Colors.white
                                          .withValues(alpha: 0.38),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v != _passwordCtrl.text) {
                                      return '비밀번호가 일치하지 않습니다';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // ── 아이디 (중복확인) ────────────────────────
                                _buildUsernameSection(),

                                // ── 전화번호 섹션 (슬라이드 인) ─────────────
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: _showPhone
                                      ? _buildPhoneSection()
                                      : const SizedBox.shrink(),
                                ),

                                // ── 오류 메시지 ───────────────────────────
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

                                const SizedBox(height: 30),

                                // ── 시작하기 버튼 ─────────────────────────
                                GestureDetector(
                                  onTap:
                                      authState.isLoading ? null : _submit,
                                  child: AnimatedOpacity(
                                    opacity:
                                        authState.isLoading ? 0.6 : 1.0,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFFD946EF),
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
                                                '시작하기',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Colors.white,
                                                  fontFamily: 'Pretendard',
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // ── 로그인 링크 ───────────────────────────
                                Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).pop(),
                                    child: RichText(
                                      text: TextSpan(
                                        text: '이미 계정이 있으신가요?  ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white
                                              .withValues(alpha: 0.38),
                                          fontFamily: 'Pretendard',
                                        ),
                                        children: const [
                                          TextSpan(
                                            text: '로그인',
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

  // ── 아이디 섹션 ──────────────────────────────────────────────────────────────

  Widget _buildUsernameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '아이디',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.48),
            fontFamily: 'Pretendard',
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: _usernameCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '아이디를 입력해주세요';
                  if (_usernameAvailable != true) return '아이디 중복 확인을 해주세요';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: _usernameAvailable == true
                            ? const Color(0xFF34D399).withValues(alpha: 0.55)
                            : _usernameAvailable == false
                                ? const Color(0xFFFF6B6B).withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.10)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                      color: _usernameAvailable == true
                          ? const Color(0xFF34D399)
                          : const Color(0xFF8B5CF6),
                      width: 1.5,
                    ),
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
            ),
            const SizedBox(width: 10),
            _ActionButton(
              label: _usernameAvailable == true ? '확인됨' : '중복 확인',
              isLoading: _usernameChecking,
              done: _usernameAvailable == true,
              onTap: (_usernameChecking || _usernameAvailable == true)
                  ? null
                  : _checkUsername,
            ),
          ],
        ),
        // 상태 표시
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _usernameAvailable != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    children: [
                      Icon(
                        _usernameAvailable!
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 13,
                        color: _usernameAvailable!
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFF6B6B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _usernameAvailable!
                            ? '사용 가능한 아이디입니다'
                            : '이미 사용 중인 아이디입니다',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: _usernameAvailable!
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── 전화번호 + OTP 섹션 ───────────────────────────────────────────────────────

  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),

        // 구분선
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        Text(
          '전화번호',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.48),
            fontFamily: 'Pretendard',
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_PhoneFormatter()],
                enabled: !_phoneVerified,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                ),
                decoration: InputDecoration(
                  hintText: '010-0000-0000',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                  filled: true,
                  fillColor: _phoneVerified
                      ? const Color(0xFF34D399).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.07),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: _phoneVerified
                            ? const Color(0xFF34D399).withValues(alpha: 0.50)
                            : Colors.white.withValues(alpha: 0.10)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        const BorderRadius.all(Radius.circular(12)),
                    borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6), width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: const Color(0xFF34D399)
                            .withValues(alpha: 0.40)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (_phoneVerified)
              _ActionButton(
                label: '인증됨',
                isLoading: false,
                done: true,
                onTap: null,
              )
            else
              _ActionButton(
                label: '인증',
                isLoading: _sendingOtp,
                done: false,
                onTap: _sendingOtp ? null : _sendOtp,
              ),
          ],
        ),

        // 전화번호 오류
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 13, color: Color(0xFFFF6B6B)),
                const SizedBox(width: 5),
                Text(
                  _phoneError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFF6B6B),
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),

        // 인증완료 배지
        if (_phoneVerified)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 13, color: Color(0xFF34D399)),
                const SizedBox(width: 5),
                const Text(
                  '전화번호 인증이 완료되었습니다',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF34D399),
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),

      ],
    );
  }
}

// ─── 액션 버튼 (중복확인/인증/확인) ───────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool done;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFF34D399).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? const Color(0xFF34D399).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: done
                        ? const Color(0xFF34D399)
                        : Colors.white.withValues(alpha: onTap == null ? 0.45 : 1.0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Pretendard',
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── 입력 필드 컴포넌트 ────────────────────────────────────────────────────────

class _SignUpField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _SignUpField({
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

// ─── 배경 페인터 ──────────────────────────────────────────────────────────────

class _SignUpBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.55),
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
          center: const Alignment(-0.85, 0.5),
          radius: 0.65,
          colors: [
            const Color(0xFF9B2DB5).withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    final rng = math.Random(99);
    for (int i = 0; i < 65; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.4 + rng.nextDouble() * 1.0;
      final a = 0.06 + rng.nextDouble() * 0.30;
      canvas.drawCircle(
          Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
