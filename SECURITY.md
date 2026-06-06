# Pinlog — 보안 노트

> 최종 업데이트: 2026-06-02  
> 이 파일은 git에 커밋해도 됨 (실제 키 값 없음)

---

## 외부 서비스 키 관리

실제 키/비밀값은 **절대 이 파일에 기록하지 말 것.**  
키 메모는 `/Users/daul/Desktop/pinlog_credentials.md` (Desktop, git 외부) 에 보관.

| 서비스 | 용도 | 키 위치 |
|--------|------|---------|
| Supabase URL + Anon Key | DB/Auth | `lib/core/supabase_config.dart` (gitignored) |
| Resend API Key | 이메일 발송 | Desktop 메모 파일 |
| Mapbox Token | 지도 | `ios/Runner/Info.plist` (비공개) |
| Firebase GoogleService-Info | FCM 클라이언트 | `ios/Runner/GoogleService-Info.plist` (gitignored) |
| Firebase Service Account JSON | send-fcm Edge Function | Supabase 대시보드 → Functions → send-fcm → Secrets ✅ 설정 완료 |

---

## 코드 감사 결과 (2026-06-02 기준)

`flutter analyze`: **이슈 0개**

### CRITICAL — 전부 수정 완료

| ID | 내용 | 상태 |
|----|------|------|
| C-01 | 전화번호 OTP 목업 — 0.7초 지연 후 `_phoneVerified = true` (실제 검증 없음) | ✅ FIXED: OTP 단계 제거, 선택 입력으로 전환 |
| C-02 | 계정 탈퇴 시 로컬 Hive 데이터 미삭제 | ✅ FIXED: `deleteAccount()`에 Hive 전체 초기화 추가 |

### HIGH — 전부 수정 완료

| ID | 내용 | 상태 |
|----|------|------|
| H-01 | 시드 핀 visibility 불일치 (`'public'` → `'🌐 전체 공개'`) | ✅ FIXED |
| H-02 | 백업 복원 시 `createdAt` null → 런타임 크래시 | ✅ FIXED: `DateTime.tryParse` + fallback |
| H-03 | 동기화 OFF 중 핀 삭제 → 재활성화 시 유령 핀 복구 | ✅ FIXED: 서버 핀과 로컬 비교 후 고아 핀 삭제 |
| H-04 | 약속 추적 종료 — unawaited Future | ✅ FIXED: `unawaited()` 래핑 |
| H-05 | 친구 목록 — 빈 배열이 Hive 폴백 차단 | ✅ FIXED: `isNotEmpty` 조건 추가 |

### MEDIUM

| ID | 내용 | 상태 |
|----|------|------|
| M-01 | 핀 색상 미입력 시 `#000000` 기본값 | 허용됨 (의도적 기본값) |
| M-02 | FCM 토큰 갱신 시 unawaited | 낮은 위험 — 갱신 실패해도 기존 토큰 유효 |

---

## 인증 흐름 보안

### 이메일 회원가입
- 클라이언트 사전 검증 (`_isValidEmailFormat`) → Supabase 호출 전 형식 체크
- 한국 도메인 (`naver.com`, `daum.net` 등) 감지 시 사용자 친화 안내 메시지 표시
- 서버: Supabase GoTrue OTP 발송 (6자리, 600초 만료)
- 커스텀 SMTP (Resend + pinlog.site) 적용 — 모든 도메인 발송 가능

### OAuth 소셜 로그인
- **Apple**: Sign In with Apple + Supabase idToken 검증 + SHA256 nonce
- **Google**: 외부 브라우저 → `io.supabase.pinlog://login-callback/` deep link 콜백  
  iOS SceneDelegate → PinlogDeepLinkChannel → Dart MethodChannel 처리
- **카카오**: OAuth 브라우저 콜백 방식 (Google과 동일 패턴)

### 세션 관리
- `_sessionSub`: `AuthChangeEvent.signedOut` 감지 → 자동 로그아웃
- `main_shell.dart`: `AuthChangeEvent.signedIn` 감지 → Supabase 핀 자동 다운로드
- OAuth 대기 중 타임아웃: 사용자가 뒤로가기 시 `cancelOAuth()` 호출

### 계정 완전 삭제 흐름
```
deleteAccount() 호출
  ├─ Supabase: pins / friendships / scheduled_meetings / users 행 삭제
  ├─ Edge Function delete-user → auth.admin.deleteUser() (auth.users 완전 제거)
  ├─ Hive: pins / profile / settings 박스 전체 초기화
  └─ signOut()
```

---

## Supabase RLS 설정 (미완료 — 대시보드 적용 필요)

현재 RLS 정책 미적용 상태. 배포 전 아래 SQL을 Supabase 대시보드 → SQL Editor에서 실행:

```sql
-- pins: 본인만 쓰기, 공개 핀은 전체 읽기
ALTER TABLE pins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "본인 핀 쓰기" ON pins FOR ALL USING (auth.uid() = uid);
CREATE POLICY "공개 핀 읽기" ON pins FOR SELECT USING (visibility = '🌐 전체 공개');

-- users: 본인만 수정
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "본인 프로필 수정" ON users FOR ALL USING (auth.uid() = uid);

-- friendships: 본인 관계만 접근
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "친구 관계 접근" ON friendships FOR ALL
  USING (auth.uid() = user_uid OR auth.uid() = friend_uid);

-- scheduled_meetings: 참여자만 접근
ALTER TABLE scheduled_meetings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "약속 참여자 접근" ON scheduled_meetings FOR ALL
  USING (auth.uid() = meet_uid OR auth.uid() = invitee_uid);
```

---

## 이메일 발송 인프라

| 항목 | 값 |
|------|----|
| 서비스 | Resend |
| 도메인 | pinlog.site |
| 발신 주소 | no-reply@pinlog.site |
| SMTP Host | smtp.resend.com:465 |
| 무료 한도 | 월 3,000건 / 일 100건 |
| DNS 상태 | ✅ Verified (DKIM + SPF + DMARC) |

---

## gitignore 보안 처리 현황

| 파일/경로 | 이유 |
|-----------|------|
| `lib/core/supabase_config.dart` | Supabase URL + Anon Key |
| `ios/Runner/GoogleService-Info.plist` | Firebase 앱 설정 |
| `ios/Runner/Runner.entitlements` | Apple 인증 설정 |
| `ios/Pinlog.xcworkspace/` | 빌드 산출물 |
| `devtools_options.yaml` | 로컬 개발 도구 설정 |
