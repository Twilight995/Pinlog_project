import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../onboarding/onboarding_screen.dart';

class EmailVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const EmailVerifyScreen({required this.email, super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen>
    with TickerProviderStateMixin {
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  late final AnimationController _enterCtrl;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  late final AnimationController _shakeCtrl;
  late final Animation<Offset> _shakeAnim;

  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;

  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _verified = false;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _enterFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _enterSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutQuart));
    _enterCtrl.forward();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0.025, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.025, 0), end: const Offset(-0.025, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.025, 0), end: const Offset(0.015, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.015, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startResendTimer();

    _otpFocus.addListener(() => setState(() {}));
    _otpCtrl.addListener(() {
      setState(() {});
      if (_otpCtrl.text.length == 6 && !_verified) {
        _autoSubmit();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocus.requestFocus();
    });
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _enterCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoSubmit() async {
    _otpFocus.unfocus();
    HapticFeedback.lightImpact();
    await ref.read(pinlogAuthProvider.notifier).verifyEmailOtp(
      widget.email,
      _otpCtrl.text,
    );
  }

  void _shakeAndClear() {
    _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reverse());
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _otpCtrl.clear();
        _otpFocus.requestFocus();
      }
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    HapticFeedback.lightImpact();
    await ref.read(pinlogAuthProvider.notifier)
        .resendVerificationEmail(widget.email);
    _startResendTimer();
    _otpCtrl.clear();
    _otpFocus.requestFocus();
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    _verified = true;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const OnboardingScreen(),
        transitionsBuilder: (_, anim, _, screen) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: screen,
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
        _successCtrl.forward();
        Future.delayed(const Duration(milliseconds: 400), _navigateToOnboarding);
      }
      if (next.error != null && next.error != prev?.error && !next.isLoading) {
        _shakeAndClear();
      }
    });

    final code = _otpCtrl.text;
    final isFocused = _otpFocus.hasFocus;
    final hasError = authState.error != null && code.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0820),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _VerifyBgPainter()),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _enterFade,
                child: SlideTransition(
                  position: _enterSlide,
                  child: Column(
                    children: [
                      // ── 상단 바 ─────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                ref.read(pinlogAuthProvider.notifier).clearPendingEmail();
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),

                      // ── 본문 ─────────────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPad + 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Spacer(flex: 2),

                              // 아이콘 + 글로우
                              _buildIconSection(),
                              const SizedBox(height: 26),

                              // 타이틀
                              const Text(
                                '이메일 인증',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                              const SizedBox(height: 10),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.48),
                                    fontFamily: 'Pretendard',
                                    height: 1.6,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _maskEmail(widget.email),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.70),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: ' 으로\n6자리 인증 코드를 보냈습니다'),
                                  ],
                                ),
                              ),

                              const Spacer(flex: 2),

                              // ── OTP 입력 박스 ──────────────────────────
                              SlideTransition(
                                position: _shakeAnim,
                                child: _buildOtpRow(code, isFocused, hasError, authState),
                              ),

                              const SizedBox(height: 18),

                              // 오류/안내 메시지
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: child,
                                ),
                                child: authState.error != null
                                    ? Text(
                                        authState.error!,
                                        key: ValueKey(authState.error),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFFF6B6B),
                                          fontFamily: 'Pretendard',
                                        ),
                                        textAlign: TextAlign.center,
                                      )
                                    : Text(
                                        '스팸 메일함도 확인해보세요',
                                        key: const ValueKey('hint'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.25),
                                          fontFamily: 'Pretendard',
                                        ),
                                      ),
                              ),

                              const Spacer(flex: 3),

                              // 인증하기 버튼
                              _buildVerifyButton(code, authState),

                              const SizedBox(height: 22),

                              // 재전송
                              GestureDetector(
                                onTap: _resend,
                                child: AnimatedOpacity(
                                  opacity: _resendSeconds > 0 ? 0.38 : 1.0,
                                  duration: const Duration(milliseconds: 400),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'Pretendard',
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _resendSeconds > 0
                                              ? '재전송 가능까지  '
                                              : '코드를 받지 못하셨나요?  ',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.42),
                                          ),
                                        ),
                                        TextSpan(
                                          text: _resendSeconds > 0
                                              ? '${_resendSeconds}s'
                                              : '재전송',
                                          style: const TextStyle(
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final pulse = _pulseCtrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // 외부 글로우
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.18 + pulse * 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // 내부 컨테이너
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.14 + pulse * 0.06),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35 + pulse * 0.15),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                size: 34,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOtpRow(String code, bool isFocused, bool hasError, PinlogAuthState authState) {
    return GestureDetector(
      onTap: () => _otpFocus.requestFocus(),
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            // 시각적 OTP 박스 6개
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final digit = i < code.length ? code[i] : null;
                final isActive = isFocused && i == code.length && !authState.isLoading;
                final isFilled = digit != null;
                final isSuccess = authState.isAuthenticated;

                return AnimatedBuilder(
                  animation: _successCtrl,
                  builder: (context, child) {
                    final successT = _successCtrl.value;
                    final successColor = Color.lerp(
                      const Color(0xFF8B5CF6),
                      const Color(0xFF22C55E),
                      successT,
                    )!;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: isFilled
                            ? successColor.withValues(alpha: 0.12 + successT * 0.06)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: hasError
                              ? const Color(0xFFFF6B6B).withValues(alpha: 0.65)
                              : isSuccess
                                  ? successColor.withValues(alpha: 0.7)
                                  : isActive
                                      ? const Color(0xFF8B5CF6)
                                      : isFilled
                                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.45)
                                          : Colors.white.withValues(alpha: 0.12),
                          width: (isActive || isSuccess) ? 1.5 : 1.0,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ]
                            : isFilled && isSuccess
                                ? [
                                    BoxShadow(
                                      color: successColor.withValues(alpha: 0.22),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                      ),
                      child: Center(
                        child: digit != null
                            ? Text(
                                digit,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: isSuccess
                                      ? successColor
                                      : Colors.white,
                                  fontFamily: 'Pretendard',
                                ),
                              )
                            : isActive
                                ? AnimatedBuilder(
                                    animation: _pulseCtrl,
                                    builder: (context, child) => Opacity(
                                      opacity: _pulseCtrl.value > 0.5 ? 1.0 : 0.0,
                                      child: Container(
                                        width: 2,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6),
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                      ),
                    );
                  },
                );
              }),
            ),

            // 투명 숨김 TextField (실제 입력 캡처)
            Opacity(
              opacity: 0.01,
              child: TextField(
                controller: _otpCtrl,
                focusNode: _otpFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 1, color: Colors.transparent),
                cursorColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyButton(String code, PinlogAuthState authState) {
    final isReady = code.length == 6 && !authState.isLoading && !_verified;

    return GestureDetector(
      onTap: isReady ? _autoSubmit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isReady
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isReady ? null : Colors.white.withValues(alpha: 0.06),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.42),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
          border: isReady
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.11)),
        ),
        child: Center(
          child: authState.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  '인증하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isReady
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.28),
                    fontFamily: 'Pretendard',
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final idx = email.indexOf('@');
    if (idx <= 2) return email;
    final local = email.substring(0, idx);
    final domain = email.substring(idx);
    final visible = local[0];
    final masked = '$visible${'*' * (local.length - 2)}${local[local.length - 1]}';
    return '$masked$domain';
  }
}

// ─── 배경 페인터 ──────────────────────────────────────────────────────────────

class _VerifyBgPainter extends CustomPainter {
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
            const Color(0xFF5B21B6).withValues(alpha: 0.42),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, 0.65),
          radius: 0.72,
          colors: [
            const Color(0xFF9B2DB5).withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    final rng = math.Random(55);
    for (int i = 0; i < 65; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.4 + rng.nextDouble() * 0.95,
        Paint()
          ..color = Colors.white
              .withValues(alpha: 0.04 + rng.nextDouble() * 0.24),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
