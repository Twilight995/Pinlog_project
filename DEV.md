# Pinlog — 개발 노트

> 최종 업데이트: 2026-06-02  
> 발표일: 2026-06-11 (수요일)

---

## 프로젝트 개요

**Pinlog**는 방문한 장소를 지도 위에 핀으로 기록하는 위치 기반 라이프 로그 앱.  
감정·날씨·동행자·사진 등 메타데이터를 함께 저장하고, 뱃지·칭호 시스템으로 기록 동기부여 제공.

| 항목 | 값 |
|------|----|
| 플랫폼 | Flutter (iOS 우선, Android 지원) |
| 상태관리 | Riverpod (StateNotifierProvider) |
| 로컬 저장소 | Hive (오프라인 캐시) |
| 지도 | Mapbox (`mapbox_maps_flutter ^2.5.0`) |
| 메인 백엔드 | Supabase (Auth + DB + Storage + Realtime) |
| 푸시 알림 (서버) | Firebase FCM + Supabase Edge Function (`send-fcm`) |
| 푸시 알림 (로컬) | `flutter_local_notifications` (리캡 알림) |
| 이메일 발송 | Resend (pinlog.site 도메인, SMTP) |

---

## 백엔드 구조

```
┌────────────────────────────────────────────────────────────┐
│                        Flutter 앱                           │
├───────────────────┬────────────────────────────────────────┤
│  Firebase (보조)  │            Supabase (메인)              │
├───────────────────┼────────────────────────────────────────┤
│ FCM 토큰 발급     │ Auth (Google / Apple / Email OTP)       │
│ 인앱 배너 수신    │ users / pins / friendships 테이블       │
│ fcm_token 저장    │ Realtime Presence (동행 실시간 위치)    │
│                   │ Storage (아바타, 핀 사진)               │
│                   │ Edge Functions (delete-user, send-fcm) │
└───────────────────┴────────────────────────────────────────┘
```

### Firebase 실제 사용 현황
| 패키지 | 실사용 여부 | 내용 |
|--------|------------|------|
| `firebase_core` | ✅ 사용 | 초기화 |
| `firebase_messaging` | ✅ 사용 | FCM 토큰 발급 → `users.fcm_token` 저장, 포그라운드 인앱 배너 |
| `firebase_storage` | ✅ **제거 완료** | pubspec에서 삭제 (2026-06-02). 코드는 처음부터 Supabase Storage 사용 |

---

## 핵심 데이터 흐름

### 핀 저장 (Supabase Primary 구조)
```
앱 시작
  └─ PinsNotifier 생성자
       ├─ load()             → Hive 로컬 캐시 즉시 표시 (오프라인 UX)
       ├─ _initFromServer()  → 로그인 상태이면 Supabase 다운로드
       └─ _backfillCountryCodes() → 역지오코딩으로 국가코드 보정

핀 생성/수정/삭제
  ├─ Hive 즉시 저장 (UI 반응성)
  └─ PinSyncService.uploadPin/deletePin() → Supabase 동기화 (로그인 시 항상)

로그인 이벤트 (main_shell.dart)
  └─ onAuthStateChange(signedIn) → loadFromServer() → 서버 핀 전체 다운로드
```

### FCM 서버 푸시 알림 흐름
```
친구 추가 (friends_provider.dart)
  └─ addFriend() 완료
       └─ _notifyFriend(targetUid)
            └─ Supabase.functions.invoke('send-fcm')
                 → send-fcm Edge Function
                 → users.fcm_token 조회
                 → Firebase FCM HTTP v1 API
                 → 상대방 폰에 "새 친구 요청이 왔어요" 알림

약속 생성 (meeting_provider.dart)
  └─ createMeeting() 성공
       └─ _notifyInvitee(inviteeUid, placeName)
            └─ Supabase.functions.invoke('send-fcm')
                 → "약속 요청이 왔어요" 알림
```

### 리캡 알림 흐름
```
앱 시작 → MainShell.initState()
  └─ _checkRecap()
       ├─ alreadyShownToday() → 하루 1회 제한
       ├─ getMemoriesForToday() → 날짜 일치 핀 탐색 (최대 10년 전)
       ├─ NotificationService.showRecapNotification() → 로컬 푸시 발송
       └─ RecapPopup.show() → 전체화면 모달
```

---

## 구현 완료 기능 목록

| 기능 | 핵심 파일 |
|------|-----------|
| 핀 CRUD + Supabase 서버 동기화 | `pin_provider.dart`, `pin_sync_service.dart` |
| Mapbox 지도 + 3D 지구본 전환 | `map_screen.dart` |
| 핀 클러스터링 + 국기 마커 (41개국) | `map_screen.dart` (`_countrySvgs`) |
| 핀 색상 커스터마이징 | `pin_create_sheet.dart`, `pin_detail_sheet.dart` |
| 동행 — Realtime 실시간 위치 공유 | `donghaeng_provider.dart` |
| On This Day 리캡 팝업 | `recap_service.dart`, `recap_popup.dart` |
| 리캡 로컬 푸시 알림 | `notification_service.dart`, `main_shell.dart` |
| 위치 기반 리캡 배너 (300m 이내) | `map_screen.dart` (RecapLocationBanner) |
| 피드 + 뱃지 도감 (16개 카테고리) | `feed_screen.dart` |
| 칭호 시스템 (핀 개수 기반 6단계) | `feed_screen.dart` |
| Apple / Google / 카카오 소셜 로그인 | `auth_provider.dart` |
| 이메일 OTP 회원가입 (6자리, Resend) | `email_verify_screen.dart`, `auth_provider.dart` |
| 온보딩 + 닉네임 Hive 즉시 저장 | `onboarding_screen.dart`, `auth_provider.dart` |
| 친구 시스템 (친구코드 기반) | `friends_provider.dart`, `friends_screen.dart` |
| 약속 잡기 (scheduled_meetings) | `meeting_provider.dart` |
| FCM 인앱 배너 + 화면 이동 | `fcm_service.dart` |
| FCM 서버 푸시 (친구 추가 / 약속 생성) | `friends_provider.dart`, `meeting_provider.dart` |
| 계정 완전 탈퇴 (로컬 + Supabase + auth) | `auth_provider.dart`, `delete-user` Edge Function |
| 테마 시스템 (4가지 프리셋) | `app_theme.dart`, `theme_provider.dart` |

---

## 막혔던 문제 & 해결 과정

### 1. Mapbox 두 번째 인스턴스 충돌
**상황**: 동행 기능을 위해 새 화면에 MapWidget 추가 시도 → iOS PlatformView 충돌로 크래시  
**원인**: Flutter iOS에서 Mapbox MapWidget은 동시에 1개 인스턴스만 허용  
**해결**: 새 화면 포기 → 기존 `map_screen.dart`에 별도 `PointAnnotationManager`(`_donghaengManager`)로 레이어 통합.  
`GlobalKey + KeyedSubtree`로 MapScreen이 탭 전환 시에도 dispose되지 않게 고정.

---

### 2. Supabase Realtime Presence 타입 오류
**상황**: `onPresenceSync()` 콜백에 `List<PresenceState>` 타입 작성 → 컴파일 에러  
**원인**: 실제 타입은 `List<SinglePresenceState>` (각 항목의 `.presences`가 `List<Presence>`)  
**해결**: `flutter analyze`로 정확한 타입 확인 후 수정.

---

### 3. subscribe() await 오류
**상황**: `await _channel!.subscribe()` 작성 → 타입 에러  
**원인**: `subscribe()`는 `RealtimeChannel` 반환 (동기). `unsubscribe()`만 Future  
**해결**: `await` 제거

---

### 4. 이메일 회원가입 "Email address is invalid" (naver.com)
**상황**: naver.com 이메일로 회원가입 시 Supabase가 invalid 오류 반환  
**원인**: Supabase 내장 SMTP의 발신 도메인 제한 (한국 도메인 수신 거부)  
**해결**:
1. `_translateSignUpError()` 추가 → 영어 에러를 한국어로 번역 + 한국 도메인 감지 시 안내
2. Resend 커스텀 SMTP (smtp.resend.com:465) + pinlog.site 도메인 DNS 인증
3. 결과: naver.com 포함 모든 도메인 발송 성공

---

### 5. 이메일 OTP 자릿수 불일치
**상황**: Supabase OTP 8자리 기본 설정인데 앱 UI는 6칸 → 인증 항상 실패  
**해결**: Supabase 대시보드에서 OTP length 8→6 변경. 코드에 `_kOtpLength = 6` 상수 도입

---

### 6. 회원가입 후 닉네임 "Pinlog 탐험가" 고정
**상황**: 온보딩에서 닉네임 입력 후 프로필 화면에 여전히 기본값 표시  
**원인**: `completeOnboarding()`이 Supabase에만 저장, 앱이 실제로 읽는 Hive에는 저장 안 함  
**해결**:
1. `completeOnboarding()`에 `repo.setNickname(nickname)` 추가
2. `_finalizeLogin()`에서 Supabase 조회 → Hive 동기화 (기기 변경 시 자동 복원)

---

### 7. Gabia DNS MX 레코드 저장 오류
**상황**: MX 레코드 저장 시 "점(.)으로 끝나야 합니다" 오류  
**원인**: DNS FQDN은 마지막에 `.` 필수  
**해결**: `feedback-smtp.ap-northeast-1.amazonses.com.` (끝에 점 추가)

---

### 8. 핀 데이터 서버 동기화 비활성화 문제
**상황**: `PinSyncService`에 `isEnabled` 조건이 있어 클라우드 동기화가 기본 OFF 상태  
**원인**: 초기 설계가 동기화를 사용자 옵션으로 만들었으나 서버 저장이 핵심 요건  
**해결**: `isEnabled` guard 제거 → 로그인 시 항상 동기화. `_initFromServer()` 생성자 추가.  
`main_shell.dart`에 `onAuthStateChange(signedIn)` 리스너 → `loadFromServer()` 호출

---

### 9. 국기 SVG 에셋 경로 불일치
**상황**: 24개 국기 SVG가 `lib/img/` 루트에 있었으나 `_countrySvgs`는 `lib/img/flag/` 경로 참조.  
pubspec.yaml에도 개별 등록 없음 → 런타임에서 fallback 삼각형 깃발 표시  
**해결**: 전체 파일을 `lib/img/flag/`로 이동. 중복 파일(`(1).svg`) 삭제. CA 국기도 디렉토리로 통합.

---

### 10. Supabase 친구 목록 빈 배열이 Hive 폴백 차단 (H-05)
**상황**: Supabase에서 빈 배열(`[]`) 반환 시 null 체크를 통과해 로컬 Hive 폴백이 작동 안 함  
**해결**: `(supaFriends != null && supaFriends.isNotEmpty) ? supaFriends : localFriends`

---

## 기술 선택 이유

### Mapbox (vs Google Maps)
지구본 모드(Globe Projection) — zoom 최소 시 3D 구체 렌더링. 앱 정체성에 맞는 시각적 경험.  
단점: 네이티브 SDK 브릿지라 마커를 Canvas로 직접 비트맵으로 구워야 함 (`_markerCache`로 캐싱).

### Supabase (vs Firebase 완전 대체)
처음엔 Firebase(Firestore + Auth)로 시작. 교수님 조언으로 Supabase 전면 이전.  
이유: PostgreSQL 기반 복잡 쿼리 + RLS SQL 표현, 오픈소스, 무료 티어 넉넉.  
Firebase는 FCM 수신 전용으로만 잔류.

### Hive (vs SQLite)
스키마 마이그레이션 없이 Dart 객체 직렬화. 오프라인 우선 설계 (Supabase 미연결 시 Hive 캐시 표시).

### Riverpod (vs Bloc/Provider)
컴파일 타임 안전성. 보일러플레이트 없이 `ref.watch()` 한 줄로 UI 리빌드.

---

## Edge Functions

| 함수명 | 역할 | 상태 |
|--------|------|------|
| `delete-user` | JWT 검증 후 admin API로 `auth.users` 완전 삭제 | ✅ 배포 완료 |
| `send-fcm` | 대상 uid의 FCM 토큰 조회 → Firebase HTTP v1 API 발송 | ✅ 배포 완료 + 환경변수 설정 완료 |

### send-fcm 트리거 시점
| 트리거 | 메서드 | 알림 내용 |
|--------|--------|-----------|
| 친구 추가 | `FriendsNotifier._notifyFriend()` | "새 친구 요청이 왔어요" |
| 약속 생성 | `MeetingNotifier._notifyInvitee()` | "약속 요청이 왔어요 + 장소명" |
