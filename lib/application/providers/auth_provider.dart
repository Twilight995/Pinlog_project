import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/pin_repository.dart';
import '../../data/repositories/profile_repository.dart';

// ─── Hive 키 ──────────────────────────────────────────────────────────────────
const _kAuthModeKey = 'auth_mode';
const _kAuthModeDemo = 'demo';
const _kAuthModeSupabase = 'supabase';

// ─── State ────────────────────────────────────────────────────────────────────

class PinlogAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isOAuthWaiting;
  final bool isNewUser;
  final bool isAdmin;
  final String? provisionalNickname;
  final String? provisionalAvatarUrl;
  final String? error;
  final String? pendingEmail; // 이메일 OTP 인증 대기 중

  const PinlogAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isOAuthWaiting = false,
    this.isNewUser = false,
    this.isAdmin = false,
    this.provisionalNickname,
    this.provisionalAvatarUrl,
    this.error,
    this.pendingEmail,
  });

  PinlogAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isOAuthWaiting,
    bool? isNewUser,
    bool? isAdmin,
    String? provisionalNickname,
    String? provisionalAvatarUrl,
    String? error,
    String? pendingEmail,
  }) =>
      PinlogAuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        isOAuthWaiting: isOAuthWaiting ?? this.isOAuthWaiting,
        isNewUser: isNewUser ?? this.isNewUser,
        isAdmin: isAdmin ?? this.isAdmin,
        provisionalNickname: provisionalNickname ?? this.provisionalNickname,
        provisionalAvatarUrl: provisionalAvatarUrl ?? this.provisionalAvatarUrl,
        error: error,
        pendingEmail: pendingEmail ?? this.pendingEmail,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

// iOS SceneDelegate → AppDelegate → PinlogDeepLinkChannel → Dart
const _deepLinkChannel = MethodChannel('com.pinlog/deeplink');

class PinlogAuthNotifier extends StateNotifier<PinlogAuthState> {
  StreamSubscription<AuthState>? _oauthSub;
  StreamSubscription<AuthState>? _sessionSub;

  PinlogAuthNotifier() : super(const PinlogAuthState()) {
    _init();
    _listenNativeDeepLink();
  }

  @override
  void dispose() {
    _oauthSub?.cancel();
    _sessionSub?.cancel();
    _deepLinkChannel.setMethodCallHandler(null);
    super.dispose();
  }

  /// iOS SceneDelegate 가 URL scheme 콜백을 수신하면 우리 전용 채널로 전달.
  /// app_links v7 EventChannel/MethodChannel 이 미등록인 경우의 완전 우회 경로.
  void _listenNativeDeepLink() {
    _deepLinkChannel.setMethodCallHandler((call) async {
      debugPrint('🔗 [Pinlog] deepLink handler called: ${call.method}');
      if (call.method != 'onDeepLink') return;
      final urlStr = call.arguments as String?;
      if (urlStr == null) return;
      final uri = Uri.tryParse(urlStr);
      if (uri == null || !urlStr.contains('login-callback')) return;

      // 이메일 인증(type=signup/recovery) 또는 OAuth 대기 중 콜백 허용
      final fragment = Uri.splitQueryString(uri.fragment);
      final queryType = uri.queryParameters['type'] ?? fragment['type'];
      final isEmailCallback =
          queryType == 'signup' || queryType == 'recovery';

      debugPrint('🔗 [Pinlog] isOAuthWaiting=${state.isOAuthWaiting} type=$queryType url=$urlStr');
      if (!state.isOAuthWaiting && !isEmailCallback) return;
      await _processOAuthUrl(uri);
    });
  }

  Future<void> _processOAuthUrl(Uri uri) async {
    debugPrint('🔗 [Pinlog] _processOAuthUrl: $uri');
    // URL 자체에 오류 파라미터가 있으면 서버 측 OAuth 실패 — 스피너 해제
    final urlError = uri.queryParameters['error'] ??
        Uri.splitQueryString(uri.fragment)['error'];
    if (urlError != null) {
      debugPrint('❌ [Pinlog] OAuth server error in URL: $urlError');
      state = state.copyWith(
        isOAuthWaiting: false,
        isLoading: false,
        error: '로그인에 실패했습니다. 다시 시도해주세요.',
      );
      return;
    }
    // _oauthSub 를 먼저 취소해 onAuthStateChange.signedIn 이중 처리 방지
    _oauthSub?.cancel();
    _oauthSub = null;
    try {
      final response =
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
      final session = response.session;
      final user = session.user;
      final meta = user.userMetadata ?? {};
      final nickname =
          (meta['full_name'] as String?)?.trim() ??
          (meta['name'] as String?)?.trim() ??
          (meta['preferred_username'] as String?);
      final avatarUrl = meta['avatar_url'] as String?;
      debugPrint('✅ [Pinlog] getSessionFromUrl success: ${user.id}');
      _persistMode(_kAuthModeSupabase);
      _listenSession();
      await _finalizeLogin(user.id, nickname: nickname, avatarUrl: avatarUrl);
    } catch (e) {
      debugPrint('❌ [Pinlog] getSessionFromUrl error: $e');
      state = state.copyWith(
        isOAuthWaiting: false,
        isLoading: false,
        error: '로그인 처리 중 오류가 발생했습니다. 다시 시도해주세요.',
      );
    }
  }

  Future<void> _init() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _persistMode(_kAuthModeSupabase);
      _listenSession();
      // 온보딩 미완료 여부 확인
      final isNew = await _checkIsNewUser(session.user.id);
      state = PinlogAuthState(isAuthenticated: true, isNewUser: isNew);
      return;
    }
    final stored = Hive.box<dynamic>('settings').get(_kAuthModeKey) as String?;
    if (stored == _kAuthModeDemo) {
      state = const PinlogAuthState(isAuthenticated: true);
    }
    if (stored == _kAuthModeSupabase) {
      Hive.box<dynamic>('settings').delete(_kAuthModeKey);
    }
  }

  /// users 테이블에 레코드가 없으면 신규 사용자
  Future<bool> _checkIsNewUser(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('uid')
          .eq('uid', uid)
          .maybeSingle();
      return res == null;
    } catch (_) {
      return false;
    }
  }

  /// 로그인 성공 후 공통 처리 — 신규/기존/어드민 분기
  Future<void> _finalizeLogin(
    String uid, {
    String? nickname,
    String? avatarUrl,
  }) async {
    final isNew = await _checkIsNewUser(uid);
    if (isNew) {
      state = PinlogAuthState(
        isAuthenticated: true,
        isNewUser: true,
        provisionalNickname: nickname,
        provisionalAvatarUrl: avatarUrl,
      );
      return;
    }
    // Supabase users 테이블에서 닉네임을 가져와 Hive에 동기화
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('nickname, friend_code')
          .eq('uid', uid)
          .maybeSingle();
      if (res != null) {
        final repo = ProfileRepository();
        final remoteNick   = res['nickname']    as String?;
        final remoteCode   = res['friend_code'] as String?;
        final remoteAvatar = res['avatar_url']  as String?;
        if (remoteNick != null && remoteNick.isNotEmpty) {
          await repo.setNickname(remoteNick);
        }
        if (remoteCode != null && remoteCode.isNotEmpty) {
          await repo.setFriendCode(remoteCode);
        }
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          await repo.setPhotoPath(remoteAvatar);
        }
      }
    } catch (_) {}

    final isAdmin = await _checkIsAdmin(uid);
    state = PinlogAuthState(isAuthenticated: true, isAdmin: isAdmin);
  }

  Future<bool> _checkIsAdmin(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('is_admin')
          .eq('uid', uid)
          .maybeSingle();
      return (res?['is_admin'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 어드민 통계 조회
  Future<Map<String, int>> fetchAdminStats() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client.from('pins').select('id').count(),
        Supabase.instance.client.from('users').select('uid').count(),
      ]);
      final totalPins = results[0].count;
      final totalUsers = results[1].count;

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todayRes = await Supabase.instance.client
          .from('pins')
          .select('id')
          .gte('created_at', '${todayStr}T00:00:00')
          .count();
      final todayPins = todayRes.count;

      return {
        'totalPins': totalPins,
        'totalUsers': totalUsers,
        'todayPins': todayPins,
      };
    } catch (_) {
      return {'totalPins': 0, 'totalUsers': 0, 'todayPins': 0};
    }
  }

  // JWT 만료/강제 로그아웃 감지
  void _listenSession() {
    _sessionSub?.cancel();
    _sessionSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && state.isAuthenticated) {
        Hive.box<dynamic>('settings').delete(_kAuthModeKey);
        state = const PinlogAuthState();
      }
    });
  }

  void _persistMode(String mode) {
    Hive.box<dynamic>('settings').put(_kAuthModeKey, mode);
  }

  // ── Nonce 헬퍼 ───────────────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return digest.toString();
  }

  // ── Apple Sign In ─────────────────────────────────────────────────────────

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('Apple ID token is null');

      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (res.session != null) {
        final user = res.session!.user;
        // Apple은 최초 로그인 시에만 이름 제공
        String? nickname;
        final given = credential.givenName;
        final family = credential.familyName;
        if (given != null || family != null) {
          nickname = [given, family].whereType<String>().join(' ').trim();
          if (nickname.isEmpty) nickname = null;
        }
        nickname ??=
            (user.userMetadata?['full_name'] as String?)?.split(' ').first;

        _persistMode(_kAuthModeSupabase);
        _listenSession();
        await _finalizeLogin(user.id, nickname: nickname);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = const PinlogAuthState(); // 사용자가 직접 취소
      } else {
        state = state.copyWith(isLoading: false, error: 'Apple 로그인 실패: ${e.message}');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Apple 로그인 중 오류가 발생했습니다.');
    }
  }

  /// Apple Demo Mode (fallback — 실기기 외 환경)
  Future<void> signInDemo() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 1200));
    _persistMode(_kAuthModeDemo);
    state = const PinlogAuthState(isAuthenticated: true);
  }

  /// 카카오 SDK 직접 로그인 (OIDC) — account_email scope 우회
  Future<void> signInWithKakao() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await kakao.UserApi.instance.loginWithKakaoAccount();

      final idToken = token.idToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Kakao OIDC 토큰 없음 — 카카오 로그인 설정에서 OpenID Connect를 활성화해주세요.',
        );
        return;
      }

      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: idToken,
        accessToken: token.accessToken,
      );

      if (res.session != null) {
        final user = res.session!.user;
        final meta = user.userMetadata ?? {};
        final nickname =
            (meta['full_name'] as String?)?.trim() ??
            (meta['name'] as String?)?.trim() ??
            (meta['preferred_username'] as String?);
        final avatarUrl = meta['avatar_url'] as String?;
        _persistMode(_kAuthModeSupabase);
        _listenSession();
        await _finalizeLogin(user.id, nickname: nickname, avatarUrl: avatarUrl);
      } else {
        state = state.copyWith(isLoading: false, error: '카카오 로그인에 실패했습니다.');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '[Kakao] $e');
    }
  }

  /// Supabase OAuth (Google)
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.pinlog://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
        // Google 캐시된 인증 코드 우회 — 항상 계정 선택 화면 표시
        queryParams: provider == OAuthProvider.google
            ? {'prompt': 'select_account'}
            : {},
      );
      if (!launched) {
        state = state.copyWith(
          isLoading: false,
          error: '브라우저를 열 수 없습니다. 다시 시도해주세요.',
        );
        return;
      }
      state = state.copyWith(isLoading: false, isOAuthWaiting: true);
      _listenOAuthCallback();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isOAuthWaiting: false,
        error: '로그인 중 오류가 발생했습니다.',
      );
    }
  }

  void _listenOAuthCallback() {
    _oauthSub?.cancel();
    _oauthSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _oauthSub?.cancel();
        _oauthSub = null;
        final user = data.session!.user;
        final meta = user.userMetadata ?? {};
        final nickname = (meta['full_name'] as String?)?.split(' ').first ??
            (meta['name'] as String?)?.split(' ').first ??
            (meta['preferred_username'] as String?);
        final avatarUrl = meta['avatar_url'] as String?;
        _persistMode(_kAuthModeSupabase);
        _listenSession();
        await _finalizeLogin(user.id, nickname: nickname, avatarUrl: avatarUrl);
      }
    });
  }

  /// OAuth 대기 취소 (브라우저 뒤로가기 등)
  void cancelOAuth() {
    _oauthSub?.cancel();
    _oauthSub = null;
    state = const PinlogAuthState();
  }

  /// 아이디(닉네임) 중복 확인. true = 사용 가능
  Future<bool> checkUsernameAvailable(String username) async {
    if (username.isEmpty) return false;
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('uid')
          .eq('nickname', username)
          .maybeSingle();
      return res == null;
    } catch (_) {
      return true;
    }
  }

  /// 비밀번호 재설정 이메일 발송. null = 성공
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.pinlog://login-callback/',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return '이메일 발송에 실패했습니다.';
    }
  }

  // 한국 주요 이메일 도메인 — GoTrue 내부 검증 우회 대상
  static const _knownKoreanDomains = {
    'naver.com', 'daum.net', 'kakao.com', 'hanmail.net',
    'nate.com', 'korea.com', 'empal.com',
  };

  static bool _isValidEmailFormat(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty || domain.isEmpty) return false;
    return domain.contains('.');
  }

  /// 이메일 회원가입. username 은 user_metadata 에 저장
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? username,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    // 클라이언트 사전 검증 — 알려진 한국 도메인은 통과시킴
    if (!_isValidEmailFormat(email)) {
      state = state.copyWith(
        isLoading: false,
        error: '이메일 형식이 올바르지 않습니다.\n예: example@naver.com',
      );
      return;
    }

    try {
      final meta = <String, dynamic>{};
      if (username != null) {
        meta['username'] = username;
        meta['display_name'] = username;
      }

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'io.supabase.pinlog://login-callback/',
        data: meta.isEmpty ? null : meta,
      );
      if (res.session != null) {
        _persistMode(_kAuthModeSupabase);
        _listenSession();
        state = const PinlogAuthState(isAuthenticated: true, isNewUser: true);
      } else if (res.user != null) {
        // 이메일 OTP 인증 화면으로 이동
        state = PinlogAuthState(pendingEmail: email);
      } else {
        state = state.copyWith(isLoading: false, error: '가입에 실패했습니다. 다시 시도해주세요.');
      }
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _translateSignUpError(e.message, email: email),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '가입 중 오류가 발생했습니다.');
    }
  }

  /// 이메일 OTP 인증
  Future<void> verifyEmailOtp(String email, String token) async {
    state = PinlogAuthState(pendingEmail: email, isLoading: true);
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      if (res.session != null) {
        _persistMode(_kAuthModeSupabase);
        _listenSession();
        state = const PinlogAuthState(isAuthenticated: true, isNewUser: true);
      } else {
        state = PinlogAuthState(
          pendingEmail: email,
          error: '인증에 실패했습니다. 코드를 확인해주세요.',
        );
      }
    } on AuthException catch (e) {
      state = PinlogAuthState(pendingEmail: email, error: e.message);
    } catch (e) {
      state = PinlogAuthState(pendingEmail: email, error: '인증 중 오류가 발생했습니다.');
    }
  }

  /// 인증 이메일 재전송
  Future<void> resendVerificationEmail(String email) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'io.supabase.pinlog://login-callback/',
      );
    } catch (_) {}
  }

  /// 이메일 인증 대기 상태 해제 (뒤로가기)
  void clearPendingEmail() {
    state = const PinlogAuthState();
  }

  /// 이메일 로그인
  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.session != null) {
        _persistMode(_kAuthModeSupabase);
        _listenSession();
        await _finalizeLogin(res.session!.user.id);
      } else {
        state = state.copyWith(
            isLoading: false, error: '이메일 또는 비밀번호가 올바르지 않습니다.');
      }
    } on AuthException catch (e) {
      debugPrint('❌ [Auth] AuthException: ${e.message} (statusCode: ${e.statusCode})');
      state = state.copyWith(
          isLoading: false, error: _translateAuthError(e.message));
    } catch (e, st) {
      debugPrint('❌ [Auth] signInWithEmail unknown error: $e\n$st');
      state = state.copyWith(isLoading: false, error: '로그인 중 오류가 발생했습니다.');
    }
  }

  String _translateSignUpError(String message, {String? email}) {
    final m = message.toLowerCase();
    if (m.contains('email address') && m.contains('invalid')) {
      // naver/daum 등 한국 도메인이 Supabase 서버에서 거부된 경우
      if (email != null) {
        final domain = email.contains('@') ? email.split('@').last.toLowerCase() : '';
        if (_knownKoreanDomains.contains(domain)) {
          return '이 이메일 도메인은 현재 지원되지 않습니다.\nGmail 또는 다른 이메일로 가입해주세요.';
        }
      }
      return '올바르지 않은 이메일 주소입니다.\n이메일 형식을 확인해주세요.';
    }
    if (m.contains('already registered') || m.contains('user already exists')) {
      return '이미 가입된 이메일입니다.\n로그인을 시도해주세요.';
    }
    if (m.contains('password should be at least') ||
        m.contains('password is too short')) {
      return '비밀번호가 너무 짧습니다. 8자 이상 입력해주세요.';
    }
    if (m.contains('too many requests') || m.contains('rate limit')) {
      return '잠시 후 다시 시도해주세요.\n(요청이 너무 많습니다)';
    }
    if (m.contains('network') || m.contains('connection')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (m.contains('signup is disabled')) {
      return '현재 회원가입이 비활성화되어 있습니다.';
    }
    return '가입 중 오류가 발생했습니다. 다시 시도해주세요.';
  }

  String _translateAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials') ||
        m.contains('invalid credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (m.contains('email not confirmed')) {
      return '이메일 인증이 완료되지 않았습니다.\n받은 인증 메일을 확인해주세요.';
    }
    if (m.contains('user not found')) {
      return '등록되지 않은 이메일입니다.\n가입 후 이용해주세요.';
    }
    if (m.contains('too many requests') || m.contains('rate limit')) {
      return '잠시 후 다시 시도해주세요.\n(요청이 너무 많습니다)';
    }
    if (m.contains('network') || m.contains('connection')) {
      return '네트워크 연결을 확인해주세요.';
    }
    return '로그인 중 오류가 발생했습니다.';
  }

  // ─── 온보딩 완료 ──────────────────────────────────────────────────────────────

  /// 닉네임·프로필을 users 테이블에 저장하고 온보딩 종료
  Future<void> completeOnboarding({
    required String nickname,
    String? avatarUrl,
  }) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final friendCode =
        uid.replaceAll('-', '').substring(0, 6).toUpperCase();
    final data = <String, dynamic>{
      'uid': uid,
      'friend_code': friendCode,
      'nickname': nickname,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    try {
      await client.from('users').upsert(data, onConflict: 'uid');
    } catch (_) {}

    final repo = ProfileRepository();
    try {
      await repo.setNickname(nickname);
      await repo.setFriendCode(friendCode);
      if (avatarUrl != null) await repo.setPhotoPath(avatarUrl);
    } catch (_) {}

    state = const PinlogAuthState(isAuthenticated: true);
  }

  // ─── 로그아웃 / 탈퇴 ─────────────────────────────────────────────────────────

  /// 비밀번호 변경 (로그인 상태). null = 성공
  Future<String?> changePassword(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return '비밀번호 변경에 실패했습니다.';
    }
  }

  Future<void> signOut() async {
    _oauthSub?.cancel();
    _oauthSub = null;
    _sessionSub?.cancel();
    _sessionSub = null;
    await Supabase.instance.client.auth.signOut();
    Hive.box<dynamic>('settings').delete(_kAuthModeKey);
    try { await PinRepository().clearAll(); } catch (_) {}
    state = const PinlogAuthState();
  }

  Future<void> deleteAccount() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await client.from('pins').delete().eq('uid', uid);
      // 양방향 친구 관계 모두 삭제
      await client.from('friendships').delete().eq('user_uid', uid);
      await client.from('friendships').delete().eq('friend_uid', uid);
      await client.from('scheduled_meetings').delete().eq('meet_uid', uid);
      await client.from('scheduled_meetings').delete().eq('invitee_uid', uid);
      await client.from('users').delete().eq('uid', uid);
    } catch (_) {}

    try {
      await client.functions.invoke('delete-user');
    } catch (_) {}

    // C-02: 로컬 Hive 데이터 초기화
    try {
      await PinRepository().clearAll();
      await Hive.box<String>('profile').clear();
      await Hive.box<dynamic>('settings').clear();
    } catch (_) {}

    await signOut();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final pinlogAuthProvider =
    StateNotifierProvider<PinlogAuthNotifier, PinlogAuthState>(
  (ref) => PinlogAuthNotifier(),
);
