# Pinlog — TODO

> 최종 업데이트: 2026-06-06 (D-5)
> 발표일: 2026-06-11 (수요일)

---

## 긴급 (발표 전 필수)

- [ ] **Supabase Storage 버킷 공개 설정**
  - 대시보드 → Storage → `avatars` / `pin-photos` 버킷 → Policies
  - `avatars`: Public (프로필 사진 URL 외부 접근 필요)
  - `pin-photos`: Public 또는 인증된 사용자만 읽기

- [ ] **실기기 통합 테스트**
  - [ ] 카카오 로그인 실기기 확인 (SceneDelegate 수정 후 미확인)
  - [ ] 카카오 닉네임 정상 저장 확인 ("다 울" → "다울")
  - [ ] 카카오 프로필 사진 정상 로드 확인 (getPhotoPath 수정 후 미확인)
  - [ ] 회원가입 선택 사진 프로필에서 정상 표시 확인 (동일 수정)
  - [ ] 핀 생성 → Supabase 대시보드에서 저장 확인
  - [ ] 로그아웃 → 재로그인 → 핀 자동 복원 확인
  - [ ] 친구 추가 → 상대방 폰에 FCM 푸시 알림 수신 확인
  - [ ] 약속 생성 → 상대방 폰에 FCM 푸시 알림 수신 확인
  - [ ] 리캡 알림 실기기에서 발송 확인
  - [ ] 동행 기능 iPhone 2대로 테스트

---

## 배포 (팀원 기기 설치)

iOS 배포 방법 3가지 — 상황에 맞게 선택:

### A. TestFlight (권장, $99/년)
Apple Developer Program 가입 후 진행.
```
Xcode → Product → Archive
→ App Store Connect 업로드
→ TestFlight에서 팀원 이메일로 초대
→ 팀원: TestFlight 앱 설치 후 수락
```
- 가장 깔끔. 링크 하나로 누구나 설치 가능.

### B. 직접 설치 — Mac + USB (무료, 발표용 현실적)
팀원 폰을 Mac에 USB 연결 후 Xcode에서 직접 빌드/설치.
```
Xcode → 상단 기기 선택 → 팀원 폰 선택 → Run (▶)
```
- Apple 무료 계정으로 가능.
- 폰마다 직접 연결해야 하고 7일마다 재설치 필요.
- 발표 전날 한 번에 설치하면 충분.

### C. 발표 당일 미러링 (가장 간단)
- iPhone → AirPlay → MacBook 화면 미러링 → 프로젝터 연결
- 설정: 제어 센터 → 화면 미러링 → MacBook 선택
- 팀원 기기 배포 불필요. 발표자 1대로 진행.

---

## 외부 설정 (코드 완성, 대시보드만 남음)

- [ ] **Supabase RLS 정책 적용** — SECURITY.md의 SQL 참고, 대시보드 → Table Editor → 각 테이블 → RLS
- [ ] **Twilio SMS** — 전화번호 인증 연동 (유료 서비스, 현재 선택 입력으로 우회 처리됨)

---

## 웹 (pinlog.site)

- [ ] 웹 랜딩페이지 최종 완성 (SVG 아이콘 교체 남음)
- [x] Vercel 배포 + pinlog.site 도메인 연결 ✅
- [ ] 발표용 QR코드 생성 (앱 다운로드 or 랜딩페이지 링크)

---

## 기능 개선 (발표 후)

- [ ] 동행 히스토리 화면 개선 (SharedMapScreen → Mapbox로 이전)
- [ ] 친구 핀 실시간 업데이트 (Supabase Realtime Subscribe)
- [ ] 월간 리캡 요약 화면
- [ ] App Store 정식 배포 (Apple Developer 계정 + 심사)

---

## 완료된 항목 ✅

### 인증
- [x] 이메일 OTP 회원가입 (6자리, 600초 만료)
- [x] 커스텀 SMTP (Resend + pinlog.site 도메인, DKIM/SPF/DMARC 인증)
- [x] naver.com 등 한국 도메인 감지 + 사용자 안내 메시지
- [x] Apple Sign In (SHA256 nonce + Supabase idToken 검증)
- [x] Google / 카카오 OAuth 소셜 로그인
- [x] 온보딩 닉네임 Hive 즉시 저장 버그 수정
- [x] 로그인 시 Supabase → Hive 닉네임 자동 동기화
- [x] 카카오 닉네임 split 버그 수정 (`"다 울"` → `"다울"`, `.trim()` 적용)
- [x] 카카오 프로필 사진 URL 삭제 버그 수정 (`ProfileRepository.getPhotoPath` HTTP URL 처리)
- [x] 회원가입 선택 사진 URL 삭제 버그 수정 (동일)
- [x] SceneDelegate `kakao://` URL 인터셉션 수정 (SDK로 라우팅 정상화)

### 핀 & 지도
- [x] 핀 CRUD + Supabase Primary 서버 저장 (로그인 시 항상 동기화)
- [x] 로그인 이벤트 감지 → Supabase 핀 자동 다운로드
- [x] Mapbox 3D 지구본 전환
- [x] 핀 클러스터링
- [x] 국기 마커 41개국 (`lib/img/flag/` 통합 정리 완료)
- [x] Mapbox 한국어 레이블 (`MapboxMapsOptions.setLanguage('ko')`)

### 소셜 & 약속
- [x] 약속잡기 / 친구 관리 → 지도 좌상단 슬라이딩 메뉴로 이동 (프로필 탭에서 제거)
- [x] ETA 계산 Mapbox Directions API 연동 (도보/자차 실제 경로 기반, 30초 쓰로틀)
- [x] 대중교통 ETA 거리 기반 fallback (API 미지원)

### 리캡
- [x] On This Day 날짜 기반 리캡 팝업 (하루 1회, 최대 10년 전)
- [x] 위치 기반 리캡 배너 (300m 이내, 1년 이상 된 핀)
- [x] 리캡 로컬 푸시 알림 (`flutter_local_notifications`)
- [x] 리캡 팝업 Supabase Storage URL 사진 지원

### 소셜 & 푸시
- [x] 친구 코드 기반 친구 추가
- [x] 동행 기능 (Supabase Realtime Presence)
- [x] FCM 인앱 배너 + 화면 이동 네비게이션
- [x] 친구 추가 시 상대방에게 FCM 서버 푸시 발송 (`_notifyFriend`)
- [x] 약속 생성 시 초대받은 친구에게 FCM 서버 푸시 발송 (`_notifyInvitee`)

### 디자인 & 에셋
- [x] 앱 아이콘 업데이트 (라이트/다크 디자인 기반 15개 사이즈 재생성)

### 인프라 & 배포
- [x] `delete-user` Edge Function 작성 + Supabase 배포 완료
- [x] `send-fcm` Edge Function 작성 + Supabase 배포 완료
- [x] `send-fcm` Firebase 환경변수 설정
- [x] firebase_storage 의존성 제거 (pubspec.yaml)
- [x] seedDemoPins dead code 제거 (112줄)
- [x] 코드 감사 CRITICAL / HIGH 이슈 전부 수정
- [x] `flutter analyze` 이슈 0개
- [x] PinLogWEB Sharp 디자인 (버튼/카드 radius, letter-spacing)
- [x] PinLogWEB 네온 hover (`neon.js` + `.neon-spot` CSS)
- [x] PinLogWEB 커스텀 커서 (`cursor.js` + `#cursorDot`/`#cursorRing` CSS)
- [x] PinLogWEB favicon 추가 (`favicon.png`, `apple-touch-icon.png`)
- [x] Vercel 배포 (`pinlog.site`) ✅
