# Pinlog — 보안 일지 (Security Log)

> 이 파일은 보안 관련 변경 사항, 설계 결정, 취약점 발견·수정을 시간순으로 기록한다.  
> 새로운 보안 변경이 생길 때마다 이 파일에 항목을 추가한다.  
> 기능 정리는 맨 아래 섹션에 정리한다.

---

## 보안 변경 일지

### 2026-05-28 — 초기 보안 설계 구현

| # | 항목 | 내용 | 파일 |
|---|------|------|------|
| S-001 | 인증 초기화 버그 수정 | Hive `auth_mode: supabase` 값이 실제 Supabase 세션 없이도 `isAuthenticated = true`로 설정되던 문제 수정. 앱 시작 시 Supabase 세션 유무를 **먼저** 확인하고, 세션 없이 Hive에 supabase 값이 있으면 즉시 삭제 | `auth_provider.dart:58` |
| S-002 | JWT 만료 자동 로그아웃 | `AuthChangeEvent.signedOut` 이벤트 감지 → 앱 상태 즉시 비인증으로 전환. `_listenSession()` 구독은 로그인 성공 즉시 시작 | `auth_provider.dart:79` |
| S-003 | 비밀번호 복잡도 강화 | 기존: 8자 이상만 허용. 변경 후: 8자 + 영문자(`[a-zA-Z]`) + 숫자(`[0-9]`) 모두 포함 필수 | `sign_up_screen.dart:220` |
| S-004 | Firebase Auth 제거 | 불필요한 Firebase Anonymous Auth 의존성 제거. Supabase `signInAnonymously()`로 대체. `firebase_auth` 패키지 pubspec 삭제 | `auth_service.dart`, `pubspec.yaml` |
| S-005 | 자격증명 분리 | Supabase URL·anonKey를 `main.dart` 하드코딩 → `secrets.dart`(gitignore)로 이동 | `main.dart:39`, `secrets.dart` |
| S-006 | 계정 탈퇴 구현 | 탈퇴 시 Supabase 전 테이블(pins/friendships/scheduled_meetings/users) 삭제 후 로그아웃. 확인 다이얼로그 필수 | `auth_provider.dart:211`, `profile_screen.dart:305` |
| S-007 | 로그아웃 구현 | 프로필 설정에 로그아웃 버튼 추가. 로그아웃 시 `_sessionSub` 구독 해제 + Hive auth_mode 삭제 + Supabase 세션 무효화 | `profile_screen.dart:281`, `auth_provider.dart:194` |
| S-008 | RLS 전면 활성화 | pins, users, friendships, scheduled_meetings 4개 테이블 모두 `ENABLE ROW LEVEL SECURITY` 설정 및 최소 권한 정책 적용 | Supabase SQL Editor |

---

## 보안 원칙

### 1. 인증 계층 (Authentication)
- **메인 인증:** Supabase Auth (Google OAuth / Kakao OAuth / Email+Password)
- **익명 세션:** Supabase `signInAnonymously()` — 로그인 전 임시 UID 발급
- **세션 저장:** `supabase_flutter` 내부적으로 iOS Keychain / Android EncryptedSharedPreferences 사용
- **세션 유효성:** 앱 시작 시 Supabase 실 세션 확인 → Hive 캐시 우선 신뢰 금지

### 2. 접근 제어 계층 (Authorization — Supabase RLS)
```
모든 테이블 접근 규칙은 PostgreSQL RLS로 서버에서 강제된다.
클라이언트 코드 우회 = 불가 (anonKey로 직접 API 호출해도 RLS 적용)
```

| 테이블 | SELECT | INSERT/UPDATE/DELETE |
|--------|--------|----------------------|
| `pins` | 본인 + 공개 + (친구관계 + 친구공개) | 본인 UID만 |
| `users` | 인증된 모든 사용자 (친구 코드 검색) | 본인 UID만 |
| `friendships` | 본인 관계만 | 본인 UID만 |
| `scheduled_meetings` | 생성자 or 초대받은 사람 | 생성자만 |

### 3. 입력 검증 계층 (Input Validation)
- 이메일: `^[\w\-.]+@[\w\-]+\.[a-z]{2,}$` 정규식
- 비밀번호: 8자 이상 + 영문 포함 + 숫자 포함
- 닉네임: `.trim()` 후 2자 이상
- 친구 코드: `.toUpperCase()` + 6자 고정
- Supabase SDK 자동 파라미터화 쿼리 → SQL Injection 방어

### 4. 전송 보안 (Transport Security)
- 모든 외부 통신 HTTPS/WSS
- iOS ATS(App Transport Security) 기본 활성화 → HTTP 차단
- 인증서 피닝은 현재 미적용 (고위험 기능 추가 시 검토)

---

## 잔존 위험 및 추후 과제

| ID | 위험 | 현황 | 처리 계획 |
|----|------|------|----------|
| R-001 | Supabase auth.users 레코드 완전 삭제 불가 | `deleteAccount()`는 데이터 테이블만 삭제, auth 레코드는 잔존 | Edge Function `delete_user` 구현 필요 |
| R-002 | 친구 코드 브루트포스 | Supabase Rate Limiting 의존 | 클라이언트 attempt 카운터 추가 예정 |
| R-003 | Hive 평문 저장 | 핀/프로필 데이터 암호화 미적용 | `hive.openEncryptedBox()` 적용 검토 |
| R-004 | 인증서 피닝 미적용 | 이론적 중간자 공격 가능 | 배포 전 고려 |
| R-005 | Apple 로그인 미구현 | 데모 모드만 | Apple Developer 등록 후 |

---

## 교차 검증 체크리스트

```
[ ] auth_provider.dart:58 — _init(): Supabase session check 먼저, Hive supabase 값 없으면 삭제
[ ] auth_provider.dart:79 — _listenSession(): signedOut 이벤트 → state 초기화
[ ] auth_provider.dart:194 — signOut(): _sessionSub?.cancel() 포함 여부
[ ] auth_provider.dart:211 — deleteAccount(): 4개 테이블 delete() 후 signOut() 호출
[ ] sign_up_screen.dart:220 — password validator: [a-zA-Z] AND [0-9] RegExp 존재
[ ] main.dart:39 — Secrets.supabaseUrl / Secrets.supabaseAnonKey 참조 여부
[ ] .gitignore — lib/core/secrets.dart 포함 여부
[ ] pubspec.yaml — firebase_auth 항목 없음 확인
[ ] Supabase Dashboard — 4개 테이블 RLS Enabled 상태 확인
```

---

---

## [기능 정리] 보안 관련 코드 위치 참조표

> 발표 자료 제작용 — 각 파일의 보안 기능이 구현된 정확한 라인 범위

---

### `lib/application/providers/auth_provider.dart` (254줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| Hive 키 상수 정의 | 7–11 | `auth_mode`, `demo`, `supabase` 문자열 키 |
| `PinlogAuthState` 모델 | 14–39 | 인증 상태 4가지 필드 (authenticated / loading / oauthWaiting / error) |
| `PinlogAuthNotifier` 선언 | 43–57 | StateNotifier + 2개 StreamSubscription 필드 |
| **앱 시작 세션 검증** | 58–78 | Supabase 실 세션 우선 확인 → Hive 캐시 우회 방지 (보안 버그 수정) |
| **JWT 만료 자동 로그아웃** | 79–89 | `_listenSession()` — signedOut 이벤트 감지 → 강제 로그아웃 |
| Hive 모드 저장 | 90–93 | `_persistMode()` — settings box에 인증 모드 기록 |
| Supabase 유저 테이블 동기화 | 95–113 | `_upsertUser()` — 로그인 후 users 테이블에 프로필 upsert |
| Apple 데모 로그인 | 114–122 | 1.2초 딜레이 후 인증 완료 처리 |
| Google/Kakao OAuth | 125–148 | `signInWithOAuth()` — 브라우저 열기 + 딥링크 대기 상태 |
| OAuth 콜백 리스너 | 149–168 | `_listenOAuthCallback()` — `AuthChangeEvent.signedIn` 감지 |
| 이메일 회원가입 | 169–193 | `signUpWithEmail()` — bcrypt 해싱은 Supabase 서버 담당 |
| 이메일 로그인 | 194–212 | `signInWithEmail()` — 세션 발급 확인 후 `_listenSession()` 시작 |
| **로그아웃** | 213–224 | `signOut()` — 구독 해제 + Hive 삭제 + Supabase 서버 토큰 무효화 |
| **계정 탈퇴** | 226–248 | `deleteAccount()` — 4개 테이블 데이터 삭제 후 signOut() |
| Riverpod Provider | 251–254 | `pinlogAuthProvider` — StateNotifierProvider 등록 |

---

### `lib/application/services/auth_service.dart` (29줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| Supabase 클라이언트 참조 | 16 | `Supabase.instance.client` |
| 인증 상태 스트림 | 18–19 | `authStateChanges` — onAuthStateChange → user 매핑 |
| 현재 사용자 조회 | 21–22 | `currentUser`, `uid` getter |
| 익명 로그인 | 24–27 | `signInAnonymously()` — 앱 시작 시 임시 UID 발급 |
| 로그아웃 | 29 | `signOut()` |

---

### `lib/presentation/screens/auth/sign_up_screen.dart` (502줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 폼 상태 관리 | 17–26 | 4개 TextEditingController + 비밀번호 표시 토글 |
| 진입 애니메이션 | 33–44 | fade + slide (500ms, easeOut) |
| **폼 제출** | 56–64 | `_submit()` — validate() 후 `signUpWithEmail()` 호출 |
| 닉네임 검증 | 186–189 | trim() 후 2자 이상 |
| **이메일 형식 검증** | 198–204 | `^[\w\-.]+@[\w\-]+\.[a-z]{2,}$` 정규식 |
| **비밀번호 복잡도** | 220–225 | 8자 + 영문자 포함 + 숫자 포함 (3중 조건) |
| 비밀번호 확인 | 241–244 | 두 필드 일치 검사 |
| `_SignUpField` 컴포넌트 | 360–453 | 재사용 가능한 스타일 TextFormField |
| 배경 페인터 | 457–500 | 반투명 성운 + 별 65개 |

---

### `lib/presentation/screens/auth/email_sign_in_screen.dart` (487줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 진입 애니메이션 | 32–44 | fade + slide (400ms, easeOut) |
| **이메일 로그인 제출** | 52–59 | `_submit()` — validate() 후 `signInWithEmail()` 호출 |
| 메인 진입 | 61–68 | `_navigateToMain()` — 전체 스택 제거 후 MainShell 이동 |
| 이메일 검증 | 122–130 | 빈 값 + 정규식 이중 검사 |
| 비밀번호 검증 | 138–142 | 빈 값 검사 (강도는 회원가입에서 이미 통과) |
| 가입하기 링크 | 200–225 | `SignUpScreen`으로 `pushReplacement` 이동 |
| `_Field` 컴포넌트 | 267–380 | 재사용 가능한 스타일 TextFormField |

---

### `lib/presentation/screens/profile/profile_screen.dart` (2,247줄) — 보안 관련 부분

| 기능 | 라인 | 설명 |
|------|------|------|
| **로그인 화면으로 이동** | 266–280 | `_navigateToSignIn()` — 전체 스택 제거 + fade transition |
| **로그아웃 다이얼로그** | 281–304 | `_showSignOutDialog()` — 확인 후 signOut() + 화면 이동 |
| **계정 탈퇴 다이얼로그** | 305–330 | `_showDeleteAccountDialog()` — 경고 + 확인 후 deleteAccount() + 화면 이동 |
| 로그아웃 설정 행 | 2036–2043 | `_TapRow` — 주황 아이콘, "로그아웃" 레이블 |
| 계정 탈퇴 설정 행 | 2044–2053 | `_TapRow` — 빨간 아이콘, 파괴적 스타일 (`isDestructive: true`) |

---

### `lib/core/secrets.dart` (10줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| Mapbox 공개 토큰 | 4 | `mapboxPublicToken` — gitignore 처리 |
| Supabase 엔드포인트 | 8 | `supabaseUrl` — gitignore 처리 |
| Supabase 공개 키 | 9 | `supabaseAnonKey` — publishable key (RLS로 보호) |

---

*작성: daoule_ee · Claude Sonnet 4.6 · 2026-05-28*
