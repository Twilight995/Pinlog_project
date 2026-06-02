import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_provider.dart';
import '../main_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'email_sign_in_screen.dart';
import 'sign_up_screen.dart';

// ─── 로그인 화면 ──────────────────────────────────────────────────────────────

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _brandFade;
  late final Animation<double> _brandScale;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;
  int _socialIconIndex = 0;
  Timer? _socialIconTimer;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _brandFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOut),
    );
    _brandScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutQuart),
      ),
    );
    _buttonsFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.30, 0.90, curve: Curves.easeOut),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOutCubic),
    ));
    _enterCtrl.forward();
    _socialIconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _socialIconIndex = (_socialIconIndex + 1) % 3);
    });
  }

  @override
  void dispose() {
    _socialIconTimer?.cancel();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _handleApple() async {
    HapticFeedback.lightImpact();
    await ref.read(pinlogAuthProvider.notifier).signInWithApple();
  }

  void _handleGoogle() async {
    HapticFeedback.lightImpact();
    await ref
        .read(pinlogAuthProvider.notifier)
        .signInWithOAuth(OAuthProvider.google);
    // Navigate on success (handled by provider listener below)
  }

  void _handleKakao() async {
    HapticFeedback.lightImpact();
    await ref
        .read(pinlogAuthProvider.notifier)
        .signInWithOAuth(OAuthProvider.kakao);
  }

  void _handleSocialLogin() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SocialLoginSheet(
        onApple: () {
          Navigator.pop(context);
          _handleApple();
        },
        onGoogle: () {
          Navigator.pop(context);
          _handleGoogle();
        },
        onKakao: () {
          Navigator.pop(context);
          _handleKakao();
        },
      ),
    );
  }

  Widget _buildSocialIcon(int index) {
    switch (index) {
      case 0:
        return SvgPicture.asset(
          'lib/img/google-color-svgrepo-com.svg',
          key: const ValueKey('google'),
          width: 22,
          height: 22,
        );
      case 1:
        return SvgPicture.asset(
          'lib/img/apple-inc-svgrepo-com.svg',
          key: const ValueKey('apple'),
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
      default:
        return SizedBox(
          key: const ValueKey('kakao'),
          width: 22,
          height: 22,
          child: SvgPicture.asset(
            'lib/img/kakao-svgrepo-com.svg',
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Color(0xFFFEE500), BlendMode.srcIn),
          ),
        );
    }
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const MainShell(),
        transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToOnboarding(String? nickname, String? avatarUrl) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => OnboardingScreen(
          initialNickname: nickname,
          initialAvatarUrl: avatarUrl,
        ),
        transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(pinlogAuthProvider);

    ref.listen(pinlogAuthProvider, (prev, next) {
      if (!next.isAuthenticated) return;
      if (prev?.isAuthenticated == true) return;
      if (next.isNewUser) {
        _navigateToOnboarding(
            next.provisionalNickname, next.provisionalAvatarUrl);
      } else {
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
            // ── 배경 ──────────────────────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _SignInBgPainter(),
              ),
            ),

            // ── 콘텐츠 ────────────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // 브랜딩 — 스케일 + 페이드
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _brandFade,
                    child: ScaleTransition(
                      scale: _brandScale,
                      child: const _BrandingSection(),
                    ),
                  ),
                  const Spacer(flex: 2),

                  // 버튼 — 슬라이드 업 + 페이드
                  FadeTransition(
                    opacity: _buttonsFade,
                    child: SlideTransition(
                      position: _buttonsSlide,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24, 0, 24, bottomPad + 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (authState.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  authState.error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 13,
                                    fontFamily: 'Pretendard',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // ── 이메일 로그인 버튼 ──────────────────────────
                            GestureDetector(
                              onTap: authState.isLoading || authState.isOAuthWaiting
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          pageBuilder: (_, _, _) =>
                                              const EmailSignInScreen(),
                                          transitionsBuilder:
                                              (_, anim, _, child) {
                                            final fade = CurvedAnimation(
                                              parent: anim,
                                              curve: const Interval(0.0, 0.65,
                                                  curve: Curves.easeOut),
                                              reverseCurve: const Interval(
                                                  0.35, 1.0,
                                                  curve: Curves.easeIn),
                                            );
                                            final slide = Tween<Offset>(
                                              begin: const Offset(0.0, 0.05),
                                              end: Offset.zero,
                                            ).animate(CurvedAnimation(
                                              parent: anim,
                                              curve: Curves.easeOutQuart,
                                              reverseCurve: Curves.easeInCubic,
                                            ));
                                            return FadeTransition(
                                              opacity: fade,
                                              child: SlideTransition(
                                                position: slide,
                                                child: child,
                                              ),
                                            );
                                          },
                                          transitionDuration: const Duration(
                                              milliseconds: 520),
                                          reverseTransitionDuration:
                                              const Duration(milliseconds: 380),
                                        ),
                                      );
                                    },
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      size: 20,
                                      color: Colors.white.withValues(alpha: 0.90),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      '이메일로 로그인',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontFamily: 'Pretendard',
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── 가입 링크 ─────────────────────────────────
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder: (ctx, a1, a2) => const SignUpScreen(),
                                    transitionsBuilder: (ctx, anim, a2, child) =>
                                        SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(1, 0),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      )),
                                      child: child,
                                    ),
                                    transitionDuration: const Duration(milliseconds: 320),
                                  ),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: '계정이 없으신가요?  ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.38),
                                    fontFamily: 'Pretendard',
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: '이메일로 가입하기',
                                      style: TextStyle(
                                        color: Color(0xFFA78BFA),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ── 소셜 계정으로 로그인 버튼 ─────────────────
                            GestureDetector(
                              onTap: authState.isLoading || authState.isOAuthWaiting
                                  ? null
                                  : _handleSocialLogin,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 500),
                                        transitionBuilder: (child, anim) => FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        ),
                                        child: _buildSocialIcon(_socialIconIndex),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '소셜 계정으로 로그인',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.80),
                                        fontFamily: 'Pretendard',
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            Text(
                              '계속하면 서비스 이용약관 및 개인정보 처리방침에 동의하게 됩니다.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.28),
                                fontFamily: 'Pretendard',
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── OAuth 대기 오버레이 ──────────────────────────────────────────
            if (authState.isOAuthWaiting)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1232).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '소셜 로그인 중...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '브라우저에서 로그인을 완료해주세요',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.45),
                              fontFamily: 'Pretendard',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(pinlogAuthProvider.notifier)
                                  .cancelOAuth();
                            },
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.8),
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        ],
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
}

// ─── 브랜딩 섹션 ──────────────────────────────────────────────────────────────

class _BrandingSection extends StatelessWidget {
  const _BrandingSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핀 아이콘 글로우
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.location_pin,
                size: 40,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 20),
            // PINLOG 워드마크
            Text(
              'PINLOG',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 10,
                fontFamily: 'Pretendard',
                shadows: [
                  Shadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                    blurRadius: 28,
                  ),
                  Shadow(
                    color: const Color(0xFFD946EF).withValues(alpha: 0.4),
                    blurRadius: 56,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '나만의 발자국을\n지도 위에 새기다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.55,
                fontFamily: 'Pretendard',
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
    );
  }
}

// ─── 소셜 로그인 선택 시트 ────────────────────────────────────────────────────

class _SocialLoginSheet extends StatelessWidget {
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onKakao;

  const _SocialLoginSheet({
    required this.onApple,
    required this.onGoogle,
    required this.onKakao,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1232).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            '소셜 계정으로 로그인',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
              fontFamily: 'Pretendard',
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),
          _SheetOption(
            icon: SvgPicture.asset(
              'lib/img/apple-inc-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            label: 'Apple로 계속하기',
            onTap: onApple,
          ),
          _SheetOption(
            icon: SvgPicture.asset(
              'lib/img/google-color-svgrepo-com.svg',
              width: 22,
              height: 22,
            ),
            label: 'Google로 계속하기',
            onTap: onGoogle,
          ),
          _SheetOption(
            icon: SizedBox(
              width: 44,
              height: 22,
              child: SvgPicture.asset(
                'lib/img/kakao-svgrepo-com.svg',
                fit: BoxFit.fitWidth,
                colorFilter: const ColorFilter.mode(Color(0xFFFEE500), BlendMode.srcIn),
              ),
            ),
            label: '카카오로 계속하기',
            onTap: onKakao,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.38),
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

class _SheetOption extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 44, child: Center(child: icon)),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Pretendard',
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 배경 페인터 ──────────────────────────────────────────────────────────────

class _SignInBgPainter extends CustomPainter {
  _SignInBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 상단 보라 글로우
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 0.9,
          colors: [
            const Color(0xFF5B21B6).withValues(alpha: 0.50),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // 오른쪽 마젠타 글로우
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, 0.3),
          radius: 0.7,
          colors: [
            const Color(0xFF9B2DB5).withValues(alpha: 0.20),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // 별 필드
    final rng = math.Random(77);
    for (int i = 0; i < 70; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.4 + rng.nextDouble() * 1.0;
      final a = 0.08 + rng.nextDouble() * 0.35;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
