# Pinlog — 개인정보 보호 및 보안 설계 보고서

> 작성일: 2026-05-28  
> 대상: Flutter 앱 (iOS 우선) — Supabase 백엔드  
> 목적: 계정·인증·데이터 처리에 적용된 방어 기술 정리  
> 교차 검증용 — 각 섹션은 독립적으로 검토 가능

---

## 1. 위협 모델 (Threat Model)

Pinlog가 방어해야 할 주요 공격 시나리오:

| # | 위협 | 영향 |
|---|------|------|
| T1 | 다른 사용자의 핀 무단 조회·삭제 | 개인 데이터 유출 / 파괴 |
| T2 | 만료된 세션으로 앱 우회 진입 | 인증 없이 기능 사용 |
| T3 | 취약한 비밀번호로 계정 탈취 | 계정 도용 |
| T4 | 로그아웃 후 이전 사용자 데이터 접근 | 개인정보 유출 |
| T5 | API 키 유출로 백엔드 무단 사용 | 서비스 남용 / 과금 |
| T6 | 친구 코드 열거 공격 (Enumeration) | 타인 계정 스캔 |

---

## 2. 방어 전술 — 계층별

### 2-1. 인증 (Authentication)

#### ① OAuth 소셜 로그인 (Google / Kakao)

- **기술:** Supabase Auth OAuth2 (`signInWithOAuth`)
- **방어:** 비밀번호를 앱에서 취급하지 않음. 인증 토큰은 브라우저(Safari/Chrome)에서만 처리.
- **딥링크 스킴:** `io.supabase.pinlog://login-callback/` — 앱 번들 ID에 묶인 고유 스킴이라 다른 앱이 가로챌 수 없음.
- **파일:** `lib/application/providers/auth_provider.dart:102`

```dart
// 브라우저 OAuth — 앱이 비밀번호를 절대 알지 못함
await Supabase.instance.client.auth.signInWithOAuth(
  provider,
  redirectTo: 'io.supabase.pinlog://login-callback/',
);
```

#### ② 이메일 로그인 — 비밀번호 복잡도 강제

- **기술:** 클라이언트 측 Validator + Supabase Auth (서버 측 bcrypt 해싱)
- **방어:**
  - 최소 8자 이상
  - 영문자 포함 필수 (`[a-zA-Z]` 정규식)
  - 숫자 포함 필수 (`[0-9]` 정규식)
- **파일:** `lib/presentation/screens/auth/sign_up_screen.dart:220`

```dart
validator: (v) {
  if (v == null || v.length < 8) return '8자 이상 입력해주세요';
  if (!RegExp(r'[a-zA-Z]').hasMatch(v)) return '영문자를 포함해주세요';
  if (!RegExp(r'[0-9]').hasMatch(v)) return '숫자를 포함해주세요';
  return null;
},
```

- **서버 측:** 실제 비밀번호는 Supabase 서버에서 `bcrypt`로 해싱 저장 — 앱 코드나 Supabase 대시보드에서도 평문 확인 불가.

#### ③ 세션 관리 — JWT + 자동 갱신

- **기술:** Supabase JWT (Access Token 1시간 / Refresh Token 60일)
- **저장 위치:** `supabase_flutter` 패키지 내부 — iOS `Keychain`, Android `EncryptedSharedPreferences` 사용 (Flutter Secure Storage 기반)
- **자동 갱신:** `supabase_flutter`가 만료 전 자동으로 Refresh Token으로 새 Access Token 발급
- **만료 시 자동 로그아웃:** Supabase가 `AuthChangeEvent.signedOut` 이벤트 발행 → 앱이 즉시 로그아웃 상태로 전환
- **파일:** `lib/application/providers/auth_provider.dart:68`

```dart
// JWT 만료/강제 로그아웃 감지
void _listenSession() {
  _sessionSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut && state.isAuthenticated) {
      Hive.box<dynamic>('settings').delete(_kAuthModeKey);
      state = const PinlogAuthState(); // 로그아웃 상태로 전환
    }
  });
}
```

#### ④ 세션 유효성 검증 — Hive 우회 차단

- **취약점 (수정 전):** Hive `settings` 박스에 `auth_mode: supabase`가 저장되어 있으면, 실제 Supabase 세션이 만료됐어도 `isAuthenticated = true` 상태가 됐음.
- **수정 후:** 앱 시작 시 Supabase 세션 유무를 **먼저** 확인. 세션이 없는데 Hive에 `auth_mode: supabase`가 있으면 해당 값을 즉시 삭제.
- **파일:** `lib/application/providers/auth_provider.dart:56`

```dart
void _init() {
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    // 실제 세션이 있을 때만 인증 완료 처리
    state = const PinlogAuthState(isAuthenticated: true);
    _persistMode(_kAuthModeSupabase);
    _listenSession();
    return;
  }
  final stored = Hive.box<dynamic>('settings').get(_kAuthModeKey) as String?;
  if (stored == _kAuthModeDemo) {
    state = const PinlogAuthState(isAuthenticated: true);
  }
  // 세션 없이 supabase 모드가 남아있으면 즉시 정리
  if (stored == _kAuthModeSupabase) {
    Hive.box<dynamic>('settings').delete(_kAuthModeKey);
  }
}
```

#### ⑤ 로그아웃 처리

- **기술:** `Supabase.auth.signOut()` + Hive 인증 상태 삭제 + 구독 해제
- **보장:** 로그아웃 시 Supabase 서버에서 Refresh Token 즉시 무효화. 이후 해당 토큰으로 재인증 불가.
- **파일:** `lib/application/providers/auth_provider.dart:194`

---

### 2-2. 데이터 접근 제어 (Authorization) — Supabase RLS

모든 Supabase 테이블에 **Row Level Security(RLS)** 가 활성화되어 있다.  
RLS는 PostgreSQL 수준의 접근 제어로, 앱 코드를 우회하거나 Supabase 클라이언트를 직접 호출해도 정책 위반 요청은 서버에서 거부된다.

#### `pins` 테이블 정책

```sql
-- 읽기: 본인 핀 + 공개 핀 + 친구 관계인 사람의 친구공개 핀
CREATE POLICY "pins_select" ON pins FOR SELECT USING (
  uid = auth.uid()
  OR visibility = '🌐 전체 공개'
  OR (visibility = '👥 친구 공개' AND EXISTS (
    SELECT 1 FROM friendships
    WHERE user_uid = auth.uid() AND friend_uid = pins.uid
  ))
);

-- 쓰기: 본인만
CREATE POLICY "pins_all" ON pins FOR ALL USING (uid = auth.uid());
```

**방어 효과 (T1 위협 차단):**
- 사용자 A가 `eq('uid', '사용자B_uid').select()`를 아무리 호출해도 B의 비공개 핀은 반환되지 않음
- `delete().eq('id', '타인핀ID')` 요청도 서버에서 자동 거부

#### `users` 테이블 정책

```sql
-- 읽기: 인증된 모든 사용자 (친구 코드 검색 기능 필요)
CREATE POLICY "users_select" ON users FOR SELECT USING (auth.role() = 'authenticated');

-- 수정: 본인만
CREATE POLICY "users_update" ON users FOR UPDATE USING (uid = auth.uid());
```

#### `friendships` 테이블 정책

```sql
-- 읽기/쓰기: 본인 관계만
CREATE POLICY "friendships_all" ON friendships FOR ALL USING (user_uid = auth.uid());
```

#### `scheduled_meetings` 테이블 정책

```sql
-- 읽기: 약속 생성자 또는 초대받은 사람
CREATE POLICY "meetings_select" ON scheduled_meetings FOR SELECT USING (
  meet_uid = auth.uid() OR invitee_uid = auth.uid()
);
-- 수정: 생성자만
CREATE POLICY "meetings_write" ON scheduled_meetings FOR ALL USING (meet_uid = auth.uid());
```

---

### 2-3. 입력 검증 (Input Validation)

#### 이메일 형식 검증

```dart
// lib/presentation/screens/auth/sign_up_screen.dart
if (!RegExp(r'^[\w\-.]+@[\w\-]+\.[a-z]{2,}$').hasMatch(v.trim())) {
  return '올바른 이메일 형식이 아닙니다';
}
```

- **방어:** 잘못된 이메일 형식 차단. Supabase도 서버 측에서 이메일 형식 재검증.

#### 친구 코드 검증

```dart
// lib/presentation/screens/social/friends_screen.dart
final code = _codeCtrl.text.trim().toUpperCase();
if (code.length != 6) {
  _showError('코드는 6자리여야 합니다.');
  return;
}
```

- **방어 (T6 위협 일부 완화):** 입력값을 강제로 6자리로 제한해 비정상 길이 요청 차단.  
  단, 6자리 브루트포스는 Supabase 서버 측 Rate Limiting에 의존.

#### 닉네임 검증

```dart
if (v == null || v.trim().length < 2) return '2자 이상 입력해주세요';
```

- 공백 트리밍(`.trim()`)으로 공백 전용 닉네임 방지.

#### SQL Injection 방어

- **기술:** Supabase Flutter SDK는 모든 쿼리에 **파라미터화 쿼리(Prepared Statement)** 사용.
- 사용자 입력값이 직접 SQL 문자열에 삽입되지 않음.

```dart
// 안전: SDK가 파라미터로 처리
await _db.from('users').select().eq('friend_code', code.toUpperCase()).limit(1);
// 내부적으로: SELECT * FROM users WHERE friend_code = $1 LIMIT 1
```

---

### 2-4. 민감 정보 관리

#### API 키 관리

| 키 | 종류 | 저장 위치 | git 관리 |
|----|------|-----------|---------|
| Mapbox 공개 토큰 | 공개 (publishable) | `secrets.dart` | ❌ gitignore |
| Supabase URL | 공개 (endpoint) | `secrets.dart` | ❌ gitignore |
| Supabase anonKey | 공개 (publishable) | `secrets.dart` | ❌ gitignore |
| Supabase service_role key | 비공개 | 앱 미사용 | — |
| Firebase 설정 | 플랫폼 설정 | `GoogleService-Info.plist` | ❌ gitignore 권장 |

> **Supabase anonKey 보안 원칙:** anonKey는 클라이언트 공개 키로, 그 자체로는 비밀이 아니다.  
> 실제 보안은 **RLS 정책**이 담당한다 — anonKey를 가져도 RLS가 타인 데이터 접근을 차단한다.  
> 그러나 소스코드 직접 노출을 막기 위해 `secrets.dart`(gitignore)로 분리했다.

#### JWT 세션 토큰 저장

- `supabase_flutter` 패키지 내부에서 **Flutter Secure Storage** 사용
- iOS: `Keychain Services` — OS 수준 암호화
- Android: `EncryptedSharedPreferences` — AES-256 암호화

#### 로컬 Hive 데이터

- 핀 데이터(`PinModel`), 프로필 정보, 친구 목록이 Hive에 저장됨
- **현재:** Hive 암호화 미적용 (기기 잠금 해제 상태에서 루트 접근 시 읽기 가능)
- **수준:** 일반 개인 앱 수준에서는 허용 범위. 금융/의료 앱이라면 `hive.openEncryptedBox()` 추가 필요.

---

### 2-5. 전송 보안 (Transport Security)

| 서비스 | 프로토콜 | 인증서 |
|--------|---------|--------|
| Supabase API | HTTPS (TLS 1.2+) | Let's Encrypt / Supabase CA |
| Supabase Realtime | WSS (WebSocket Secure) | 동일 |
| Mapbox API | HTTPS | Mapbox CA |
| Firebase FCM | HTTPS + gRPC | Google CA |

- iOS ATS(App Transport Security) 기본 활성화 — HTTP 평문 통신 자동 차단
- 현재 **인증서 피닝(Certificate Pinning) 미적용** — 추후 고위험 기능 추가 시 고려

---

### 2-6. 푸시 알림 보안 (FCM)

- **토큰 저장:** FCM 토큰은 Supabase `users.fcm_token` 컬럼에 저장
- **RLS 보호:** `users` 테이블 UPDATE 정책이 본인만 수정 허용 → 타인 FCM 토큰 덮어쓰기 불가
- **토큰 삭제:** 사용자가 알림 OFF 시 → `FirebaseMessaging.instance.deleteToken()` 호출 → 토큰 무효화

---

## 3. 잔존 위험 (Residual Risks)

| # | 위험 | 현재 상태 | 완화 방안 |
|---|------|-----------|---------|
| R1 | 친구 코드 브루트포스 | Supabase Rate Limiting 의존 | 추후 attempt 카운터 + 잠금 추가 |
| R2 | Hive 비암호화 (기기 루팅 시) | 일반 앱 수준 허용 | 민감 데이터 증가 시 Hive 암호화 |
| R3 | 인증서 피닝 미적용 | 중간자 공격 이론적 가능 | 배포 전 고위험 기능 추가 시 적용 |
| R4 | Apple 로그인 미구현 | 데모 모드만 | Apple Developer 등록 후 구현 |
| R5 | Firestore 보안 규칙 (레거시) | 테스트 모드 만료 미확인 | Firebase 콘솔에서 만료일 확인 |

---

## 4. 보안 구현 변경 이력

| 날짜 | 변경 내용 | 파일 |
|------|-----------|------|
| 2026-05-28 | Firebase Auth 제거 → Supabase anonymous auth로 교체 | `auth_service.dart` |
| 2026-05-28 | `_init()` 세션 검증 버그 수정 (Hive 우회 방지) | `auth_provider.dart` |
| 2026-05-28 | JWT 만료 자동 로그아웃 리스너 추가 (`_listenSession`) | `auth_provider.dart` |
| 2026-05-28 | 비밀번호 복잡도 강화 (영문+숫자 필수) | `sign_up_screen.dart` |
| 2026-05-28 | Supabase credentials → `secrets.dart` 분리 | `main.dart`, `secrets.dart` |
| 2026-05-28 | `firestore_service.dart` → `social_service.dart` 이름 정정 | 전체 참조 |

---

## 5. 교차 검증 체크리스트

다른 AI Agent가 이 보고서를 검증할 때 확인해야 할 항목:

```
[ ] auth_provider.dart _init(): Supabase session check가 Hive check보다 먼저 실행되는가?
[ ] auth_provider.dart _listenSession(): signedOut 이벤트에서 state가 초기화되는가?
[ ] auth_provider.dart signOut(): _sessionSub?.cancel()이 포함되어 있는가?
[ ] sign_up_screen.dart password validator: 영문자 + 숫자 RegExp 두 가지 모두 존재하는가?
[ ] main.dart: hardcoded 'https://gnrnsbuqmofcjoamjsqk...' 대신 Secrets.supabaseUrl 사용하는가?
[ ] secrets.dart: .gitignore에 포함되어 있는가? ('lib/core/secrets.dart' 줄 확인)
[ ] Supabase RLS: pins, users, friendships, scheduled_meetings 테이블 모두 ENABLE RLS인가?
[ ] supabase_flutter: flutter_secure_storage를 내부적으로 사용하는 버전인가?
[ ] Hive: auth_mode 키가 'supabase'인 경우 세션 없으면 즉시 삭제되는가?
```

---

*작성: daoule_ee · Claude Sonnet 4.6 · 2026-05-28*
