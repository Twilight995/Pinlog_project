# Pinlog — 개발 현황 문서

> 최종 업데이트: 2026-05-28  
> 플랫폼: Flutter (iOS 우선 개발)  
> 상태: `flutter analyze` 이슈 0개 · Supabase DB 설정 완료

---

## 1. 프로젝트 개요

**Pinlog**는 방문한 장소를 지도 위에 핀으로 기록하는 위치 기반 라이프 로그 앱이다.  
감정·날씨·동행자·사진 등 메타데이터를 함께 저장하고, 배지·칭호 시스템으로 기록 동기부여를 제공한다.  
친구와 공개 핀을 공유하는 소셜 지도, 약속 잡기, 클라우드 동기화를 지원한다.

| 항목 | 값 |
|------|----|
| 앱 이름 | Pinlog |
| 패키지 | `pinlog` |
| Dart SDK | ^3.11.4 |
| 상태관리 | Riverpod (StateNotifierProvider) |
| 로컬 저장소 | Hive |
| 지도 | Mapbox (`mapbox_maps_flutter ^2.5.0`) |

---

## 2. 백엔드 구조 — Supabase 중심, Firebase FCM 보조

원래 Firebase(Firestore + Auth)로 시작했으나, **Supabase로 전면 이전**했다.  
이전 이유: Supabase는 PostgreSQL 기반이라 복잡한 쿼리와 RLS가 직관적이고,  
오픈소스라 벤더 종속이 없으며, 최근 개발자 커뮤니티에서 Firebase 대체제로 빠르게 확산 중이다.

현재 Firebase는 **iOS/Android 푸시 알림(FCM)** 전용으로만 사용한다.  
FCM은 Google의 APNs/GCM 인프라를 직접 사용하므로 Supabase에 대응하는 서비스가 없다.

```
┌──────────────────────────────────────────────────────────────────────┐
│                           Flutter 앱                                  │
├──────────────────────┬───────────────────────────────────────────────┤
│  Firebase (FCM만)    │              Supabase (메인 백엔드)            │
├──────────────────────┼───────────────────────────────────────────────┤
│ 푸시 알림 전송 (FCM) │ 로그인 (Google OAuth / Kakao OAuth / 이메일)  │
│                      │ 익명 로그인 (Supabase Auth anonymous)         │
│                      │ users 테이블 — 프로필, 친구 코드, FCM 토큰    │
│                      │ pins 테이블 — 핀 클라우드 동기화              │
│                      │ friendships 테이블 — 친구 관계                │
│                      │ scheduled_meetings 테이블 — 약속              │
│                      │ Realtime Presence — 실시간 위치 공유          │
└──────────────────────┴───────────────────────────────────────────────┘
```

---

### 2-1. Firebase — FCM 전용

#### FCM (Firebase Cloud Messaging) — 푸시 알림
- **파일:** `lib/application/services/fcm_service.dart`
- **동작:**
  1. 앱 시작 시 `FCMService.instance.init()` 호출
  2. iOS 알림 권한 요청
  3. FCM 토큰 발급 → Supabase `users.fcm_token` 컬럼에 저장
  4. 포그라운드/백그라운드 메시지 수신 처리
  5. 토큰 갱신 시 자동 재업로드

```dart
// main.dart
try { await FCMService.instance.init(); } catch (_) {}
// APNs 미설정 시 에러를 조용히 무시하고 앱 계속 실행
```

- **설정 파일:** `ios/Runner/GoogleService-Info.plist`
- **토글:** 프로필 화면 → 설정 → 알림 스위치 (Hive에 저장)

> `firebase_storage`는 pubspec에서 제거됨 (미사용)

---

### 2-2. Supabase — 담당 역할

#### ① 인증 (Auth)
- **파일:** `lib/application/providers/auth_provider.dart`
- **지원 방식:**
  | 방식 | 상태 |
  |------|------|
  | Google OAuth | ✅ 구현 완료 |
  | Kakao OAuth | ✅ 구현 완료 |
  | 이메일/비밀번호 | ✅ 구현 완료 |
  | Apple (데모) | ✅ 데모 계정 진입 (실 Apple 로그인은 추후) |

- 로그인 성공 시 Supabase `auth.users`에 자동 등록
- `users` 테이블에 프로필 정보 upsert

#### ② `users` 테이블 — 사용자 프로필
```sql
users
├── uid          UUID  (= Supabase auth.users.id)
├── nickname     TEXT
├── friend_code  TEXT  (6자리 대문자, 친구 추가에 사용)
├── fcm_token    TEXT  (Firebase FCM 토큰)
└── updated_at   TIMESTAMPTZ
```
- **담당 파일:** `social_service.dart`
- 프로필 수정 시, 앱 시작 시 자동 동기화

#### ③ `pins` 테이블 — 핀 클라우드 동기화
```sql
pins
├── id             TEXT  PRIMARY KEY
├── uid            UUID  → auth.users
├── title          TEXT
├── description    TEXT
├── latitude       DOUBLE PRECISION
├── longitude      DOUBLE PRECISION
├── emotion        TEXT
├── weather        TEXT
├── companions     TEXT[]
├── intensity_level INT
├── pin_shape      TEXT
├── visibility     TEXT  ('나만보기' | '👥 친구 공개' | '🌐 전체 공개')
├── photo_paths    TEXT[]
├── country_code   TEXT
├── created_at     TIMESTAMPTZ
└── updated_at     TIMESTAMPTZ
```
- **담당 파일:** `lib/application/services/pin_sync_service.dart`
- **동작:** 프로필 설정에서 "클라우드 동기화" 토글 ON → 전체 핀 업로드 + 이후 변경분 자동 upsert
- **공유 지도:** `visibility`가 `👥 친구 공개` / `🌐 전체 공개`인 핀을 친구가 조회 가능

#### ④ `friendships` 테이블 — 친구 관계
```sql
friendships
├── id           UUID  PRIMARY KEY
├── user_uid     UUID  → auth.users
├── friend_uid   UUID  → auth.users
├── friend_code  TEXT
├── nickname     TEXT
└── added_at     TIMESTAMPTZ
```
- **담당 파일:** `lib/application/services/social_service.dart`
- **동작:** 친구 코드로 상대방 `users` 조회 → 양방향 `friendships` 행 생성
- **실시간 스트림:** `_db.from('friendships').stream(...)` → `friendsStreamProvider`

#### ⑤ `scheduled_meetings` 테이블 — 약속
```sql
scheduled_meetings
├── id           UUID  PRIMARY KEY  DEFAULT gen_random_uuid()
├── meet_uid     UUID  → auth.users  (약속 생성자)
├── invitee_uid  UUID  → auth.users  (초대받은 친구)
├── target_lat   DOUBLE PRECISION
├── target_lng   DOUBLE PRECISION
├── target_name  TEXT
├── scheduled_at TIMESTAMPTZ
├── transit_mode TEXT  ('driving' | 'transit' | 'walking')
├── status       TEXT  ('upcoming' | 'completed' | 'cancelled')
├── created_at   TIMESTAMPTZ
└── updated_at   TIMESTAMPTZ
```
- **담당 파일:** `lib/data/repositories/meeting_repository.dart`
- **실시간 위치 공유:** Supabase Realtime Presence 채널 `meeting:{id}` 사용

---

---

## 3. Supabase RLS 정책 요약

| 테이블 | 읽기 | 쓰기 |
|--------|------|------|
| `pins` | 본인 핀 + 공개/친구공개 핀 | 본인만 |
| `scheduled_meetings` | 생성자 또는 초대받은 사람 | 생성자만 |
| `users` | 인증된 사용자 모두 (친구 코드 검색용) | 본인만 |
| `friendships` | 본인 관계만 | 본인만 |

---

## 4. 로컬 저장소 — Hive

클라우드 의존 없이 오프라인에서도 동작하는 기반 저장소.

| Box 이름 | 저장 데이터 |
|----------|------------|
| `pins` | PinModel 전체 (HiveTypeAdapter, TypeId 0) |
| `profile` | 닉네임·소개·사진 경로·친구 코드 |
| `settings` | 테마 색상, 알림 ON/OFF, 동기화 ON/OFF, 마지막 동기화 시각, auth_mode |
| `friends` | 친구 목록 (Supabase 스트림 오프라인 폴백) |

---

## 5. 디렉토리 구조

```
lib/
├── main.dart                                      # 앱 진입점, Firebase + Supabase 초기화
├── core/
│   ├── secrets.dart                               # Mapbox 토큰 (gitignore)
│   ├── firebase_options.dart                      # Firebase 플랫폼 설정 (자동생성)
│   ├── theme/app_theme.dart                       # 테마 프리셋 10종 + 커스텀
│   └── utils/sheet_utils.dart                     # showAppSheet() 헬퍼
├── data/
│   ├── models/
│   │   ├── pin_model.dart / pin_model.g.dart      # Hive 핀 모델
│   │   └── meeting.dart                           # 약속 모델
│   └── repositories/
│       ├── pin_repository.dart                    # 핀 로컬 CRUD
│       ├── profile_repository.dart                # 프로필 로컬 저장
│       ├── meeting_repository.dart                # 약속 Supabase CRUD
│       └── shared_map_repository.dart             # 친구 공개핀 조회
├── application/
│   ├── providers/                                 # Riverpod 상태
│   │   ├── auth_provider.dart                     # Supabase 인증 상태
│   │   ├── pin_provider.dart                      # 핀 목록·필터
│   │   ├── profile_provider.dart                  # 프로필 상태
│   │   ├── friends_provider.dart                  # 친구 목록
│   │   ├── meeting_provider.dart                  # 약속 상태
│   │   └── theme_provider.dart                    # 테마 프리셋
│   └── services/
│       ├── auth_service.dart                      # Supabase 익명 로그인 + 인증 상태
│       ├── social_service.dart                    # 친구/유저 — Supabase
│       ├── fcm_service.dart                       # Firebase 푸시 알림
│       ├── pin_sync_service.dart                  # Supabase 핀 동기화
│       └── backup_service.dart                    # JSON 내보내기/가져오기
└── presentation/
    ├── screens/
    │   ├── splash/splash_screen.dart              # 지구본 + 별똥별 애니메이션
    │   ├── auth/sign_in_screen.dart               # 로그인 (Google/Kakao/Apple/이메일)
    │   ├── auth/sign_up_screen.dart               # 이메일 회원가입
    │   ├── main_shell.dart                        # 플로팅 알약 네비게이션
    │   ├── map/map_screen.dart                    # 지도 탭
    │   ├── feed/feed_screen.dart                  # 도감 탭
    │   ├── activity/activity_screen.dart          # 활동 탭
    │   ├── profile/profile_screen.dart            # 프로필 탭
    │   ├── pin_wizard/                            # 5단계 핀 생성 위자드
    │   └── social/
    │       ├── friends_screen.dart                # 친구 관리
    │       └── shared_map_screen.dart             # 공유 지도
    └── widgets/
        ├── map/pin_detail_sheet.dart              # 핀 상세
        ├── map/pin_create_sheet.dart              # 핀 편집 시트 (수정 전용)
        └── meeting/meeting_create_sheet.dart      # 약속 생성 시트
```

---

## 6. 앱 시작 흐름

```
main()
 ├── Hive.initFlutter()
 ├── Firebase.initializeApp()          ← Firebase 초기화 (FCM용)
 ├── FCMService.instance.init()        ← 푸시 알림 초기화 (실패해도 앱 계속)
 ├── Supabase.initialize()             ← Supabase 초기화 (인증 + DB)
 ├── MapboxOptions.setAccessToken()    ← 지도 초기화
 └── runApp(ProviderScope(PinlogApp))
       └── SplashScreen
             └── (항상 로그인 화면) SignInScreen   ← 테스트 모드
                   └── (로그인 성공) MainShell
                         ├── Tab 0: MapScreen
                         ├── Tab 1: FeedScreen
                         ├── Tab 2: ActivityScreen
                         └── Tab 3: ProfileScreen
```

---

## 7. 핀 데이터 흐름

```
핀 생성 (PinWizardScreen)
    │
    ▼
PinsNotifier.add(pin)          ← Riverpod 상태 업데이트
    │
    ├── PinRepository.add()    ← Hive 로컬 저장 (항상)
    │
    └── (동기화 ON인 경우)
        PinSyncService.uploadPin()  ← Supabase pins 테이블 upsert

핀 조회
    ├── 내 핀:     Hive (오프라인 우선)
    ├── 공유 지도: Supabase pins 조회 (visibility 필터)
    └── 백업:      BackupService → JSON 파일 내보내기 / 가져오기
```

---

## 8. 핵심 데이터 모델 (`PinModel`)

Hive TypeId: **0** — 15개 필드

| Field | 타입 | 설명 |
|-------|------|------|
| 0 | `String` | id (UUID v4) |
| 1 | `String` | title |
| 2 | `String` | description |
| 3 | `double` | latitude |
| 4 | `double` | longitude |
| 5 | `String` | emotion |
| 6 | `String` | weather |
| 7 | `List<String>` | companions |
| 8 | `int` | intensityLevel (1~5) |
| 9 | `String` | pinShape (카테고리 키) |
| 10 | `String` | visibility |
| 11 | `List<String>` | photoPaths |
| 12 | `DateTime` | createdAt |
| 13 | `String?` | (미사용) |
| 14 | `String` | countryCode (ISO 3166-1 alpha-2) |

---

## 9. 의존성 패키지

### 지도 / 위치
| 패키지 | 역할 |
|--------|------|
| `mapbox_maps_flutter` | Mapbox 네이티브 지도 |
| `geolocator` | GPS 위치 조회 |
| `geocoding` | 역지오코딩 |
| `latlong2` | 위도/경도 타입 |

### 백엔드
| 패키지 | 역할 |
|--------|------|
| `supabase_flutter` | DB · Auth · Realtime |
| `firebase_core` | Firebase 초기화 (FCM 필수) |
| `firebase_messaging` | 푸시 알림 (FCM) |

### 로컬 저장 / 유틸
| 패키지 | 역할 |
|--------|------|
| `hive_flutter` | 로컬 NoSQL 저장소 |
| `flutter_riverpod` | 상태관리 |
| `share_plus` | JSON 백업 파일 공유 |
| `image_picker` | 사진 첨부 |
| `path_provider` | 파일 저장 경로 |
| `flutter_svg` | SVG 렌더링 |
| `uuid` | ID 생성 |
| `permission_handler` | 권한 요청 |

---

## 10. 구현 완료 기능

### 인증
- [x] Google OAuth 로그인 (Supabase)
- [x] Kakao OAuth 로그인 (Supabase)
- [x] 이메일/비밀번호 로그인·가입 (Supabase)
- [x] Apple 데모 진입 (실 Apple 로그인은 Apple Developer 등록 후)

### 지도 & 핀
- [x] Mapbox 지도 4종 스타일
- [x] 핀 마커 (테마색 원 + SVG 아이콘 + 글로우)
- [x] 클러스터 마커 + 스프링 전환 애니메이션
- [x] 지구본 모드 (국가별 국기 클러스터)
- [x] 5단계 핀 생성 위자드 (PinWizardScreen)
- [x] 핀 상세보기 · 편집 · 삭제
- [x] 감정/공개범위 필터

### 소셜
- [x] 친구 코드 생성 · 친구 추가/삭제 (Supabase)
- [x] 친구 목록 실시간 스트림
- [x] 공유 지도 (친구 공개핀 지도에 표시)
- [x] 약속 잡기 (장소·시간·교통수단 설정)
- [x] 실시간 위치 공유 (Supabase Realtime Presence)

### 클라우드 & 백업
- [x] 핀 클라우드 동기화 (Supabase pins 테이블)
- [x] JSON 백업 내보내기 (share_plus)
- [x] JSON 백업 가져오기
- [x] FCM 푸시 알림 (APNs 설정 후 iOS 실기기 동작)

### UX
- [x] 애니메이션 스플래시 (지구본 자전 + 별똥별 + 핀 낙하)
- [x] 플로팅 알약 네비게이션 (backdrop blur)
- [x] 테마 컬러 10종 + 커스텀 무제한
- [x] 배지 12종 + 칭호 5단계 시스템
- [x] 활동 화면 (통계, 히트맵 캘린더, 하루 카드)

---

## 11. 배포 전 필수 체크리스트

| 항목 | 상태 | 방법 |
|------|------|------|
| Supabase `pins` 테이블 | ✅ 완료 | SQL Editor에서 생성 |
| Supabase `scheduled_meetings` 테이블 | ✅ 완료 | SQL Editor에서 생성 |
| Supabase `users.fcm_token` 컬럼 | ✅ 완료 | ALTER TABLE |
| Firebase APNs 설정 | ⏳ 대기 | Apple Developer ($99/년) 등록 후 |
| Apple 로그인 구현 | ⏳ 대기 | App Store 배포 시 필수 |
| Mapbox 토큰 보안 | ⚠️ 확인 | `--dart-define` 또는 환경변수 처리 |
| Firestore 보안 규칙 | ⚠️ 확인 | 테스트 모드 만료일 확인 |

---

## 12. 환경 설정 파일 위치

| 파일 | 용도 | git 관리 |
|------|------|---------|
| `lib/core/secrets.dart` | Mapbox 토큰 | ❌ gitignore |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS 설정 | ❌ gitignore 권장 |
| `.env` (미사용) | — | — |

---

*작성: Claude Sonnet 4.6 · 2026-05-28*

---

---

## [기능 정리] 화면·서비스별 코드 위치 참조표

> 발표 자료 제작용 — 각 화면 파일에서 기능이 구현된 정확한 라인 범위  
> 기능 정리는 이 섹션(최하단)에 집중 관리한다.

---

### `lib/main.dart` (398줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| Firebase 초기화 | 36–37 | `Firebase.initializeApp()` — FCM 사용을 위한 초기화 |
| Supabase 초기화 | 39–42 | URL + anonKey 로 클라이언트 초기화 |
| Hive 초기화 | 44–47 | `initFlutter()` + settings/pins/profile/friends 박스 오픈 |
| Supabase 익명 로그인 | 54–58 | 세션 없을 때 자동 익명 로그인 |
| 소셜 서비스 동기화 | 60–66 | `SocialService.createOrUpdateUser()` — friendCode + nickname upsert |
| FCM 초기화 | 69 | `FCMService.instance.init()` — 실패해도 앱 계속 실행 |
| Mapbox 토큰 설정 | 72–79 | `MapboxOptions.setAccessToken()` |
| 시드 데이터 | 85–369 | 데모 핀 18개 + 테스트 경로 6개 + 사진 할당 4단계 |

---

### `lib/presentation/screens/splash/splash_screen.dart` (1,029줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| AnimationController 4개 선언 | 37–96 | progressCtrl / rotationCtrl / pinCtrl / fadeOutCtrl |
| 진행도 콜백 | 97–103 | `_onProgress()` — PINLOG 텍스트 shimmer + orbit ring 타이밍 |
| 핀 낙하 콜백 | 104–118 | `_onPinProgress()` — 핀 투명도 + 크기 + bounce |
| 화면 전환 | 125–168 | `_navigateOut()` — fade-out 후 SignInScreen 또는 MainShell 이동 |
| 메인 UI 빌드 | 169–391 | 지구본 + PINLOG ShaderMask 텍스트 + 태그라인 + 궤도 링 + 진행 바 |
| 별똥별 수학 | 392–464 | `_starLocal()` 타이밍 + `_drawStar()` 그라디언트 선 Canvas 그리기 |
| 배경 별똥별 | 528–550 | `_SplashBgPainter._drawBgShootingStars()` |
| 진행 바 | 555–596 | `_GlowProgressPainter` — 그라디언트 채움 + 글로우 후광 + 흰 점 |
| 궤도 링 | 601–637 | `_OrbitRingPainter` — 타원 궤도 + 마젠타 위성 점 |
| 대륙 좌표 데이터 | 638–757 | 7개 대륙 + 그린란드 실제 위경도 데이터 |
| 지구본 베이스 | 758–882 | `_GlobePainter.paint()` — 구체 + 위선 + 경선 + 대륙 + 별똥별 |
| 지구본 별똥별 | 865–882 | `_drawGlobeShootingStars()` — 구면 좌표에서 Canvas 좌표 변환 |
| 대륙 정사영 투영 | 931–958 | `_drawContinents()` — 위경도 → 2D 좌표 + 수평선 클리핑 |
| 남극 렌더링 | 959–991 | `_drawAntarctica()` — 위도 -70° 호 + 남극점 닫기 |
| 핀 낙하 펄스 | 996–1029 | `_RingPulsePainter` — 착지 시 방사형 확장 링 |

---

### `lib/presentation/screens/auth/sign_in_screen.dart` (713줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 토스트 알림 | 14–123 | `_ToastWidget` — Overlay 삽입 + 3.2초 후 fade out 자동 제거 |
| SignInScreen 진입 애니메이션 | 136–162 | fade + slide (700ms, easeOut) |
| Apple 데모 로그인 | 163–171 | `_handleAppleDemo()` — 토스트 표시 후 1.2초 딜레이 |
| Google OAuth | 174–179 | `_handleGoogle()` — Supabase OAuth 브라우저 열기 |
| Kakao OAuth | 182–187 | `_handleKakao()` — Supabase OAuth 브라우저 열기 |
| 메인 진입 | 189–201 | `_navigateToMain()` — fade transition → MainShell |
| 로그인 버튼 3개 (Apple/Google/Kakao) | 263–307 | `_AuthButton` 컴포넌트 재사용 |
| 이메일 로그인 버튼 | 309–360 | outline 스타일 버튼 → EmailSignInScreen push |
| 가입하기 텍스트 링크 | 361–389 | → SignUpScreen push |
| OAuth 대기 오버레이 | 370–499 | 보라 글로우 글래스 패널 "소셜 로그인 중..." |
| PINLOG 브랜딩 섹션 | 502–574 | `_BrandingSection` — 로고 + 태그라인 |
| 재사용 버튼 컴포넌트 | 579–658 | `_AuthButton` — dark/light/kakao 3가지 스타일 |
| 배경 페인터 | 661–713 | `_SignInBgPainter` — 성운 2개 + 별 65개 |

---

### `lib/presentation/screens/auth/email_sign_in_screen.dart` (487줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 진입 애니메이션 | 32–44 | fade + slide (400ms, easeOut) |
| 이메일 로그인 제출 | 52–59 | `_submit()` — validate + signInWithEmail 호출 |
| 메인 진입 (전체 스택 제거) | 61–68 | `_navigateToMain()` — `pushAndRemoveUntil` |
| 이메일 입력 필드 | 118–133 | 이메일 형식 정규식 검증 포함 |
| 비밀번호 입력 필드 | 134–144 | 빈 값 검사 + 눈 아이콘 토글 |
| 에러 메시지 표시 | 149–160 | `authState.error` → 빨간 텍스트 |
| 로그인 버튼 | 162–211 | 퍼플→마젠타 그라디언트 + 로딩 스피너 |
| 가입하기 링크 | 212–228 | → SignUpScreen `pushReplacement` |
| `_Field` 재사용 컴포넌트 | 267–380 | 라벨 + 아이콘 + 에러 스타일 TextFormField |
| 배경 페인터 | 453–487 | 성운 + 별 55개 |

---

### `lib/presentation/screens/auth/sign_up_screen.dart` (502줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 진입 애니메이션 | 33–44 | fade + slide (500ms, easeOut) |
| 폼 제출 | 56–64 | `_submit()` — validate + signUpWithEmail |
| 닉네임 필드 | 181–190 | 2자 이상 + trim() 검증 |
| 이메일 필드 | 192–205 | 정규식 형식 검증 |
| 비밀번호 필드 | 206–226 | 8자 + 영문 + 숫자 3중 조건 |
| 비밀번호 확인 필드 | 227–245 | 두 필드 일치 검사 |
| 시작하기 버튼 | 268–313 | 그라디언트 + 로딩 스피너 |
| `_SignUpField` 컴포넌트 | 360–453 | 재사용 스타일 TextFormField |
| 배경 페인터 | 457–500 | 성운 2개 + 별 65개 |

---

### `lib/presentation/screens/main_shell.dart` (388줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| `MainShell` 탭 관리 | 15–44 | IndexedStack 5탭 (지도/도감/활동/프로필) |
| 탭 전환 애니메이션 | 45–128 | `_AnimatedTabView` — fade + scale (0.96→1.0, easeOut) |
| 플로팅 네비게이션 바 | 129–239 | `_FloatingNav` — pill 배경 + BackdropFilter blur(24) |
| 탭 아이템 눌림 애니메이션 | 240–358 | `_NavItem` — scale 0.88 press + active dot indicator |
| + 생성 버튼 | 360–388 | `_CreateButton` — 중앙 56×56 검정 원, map에서 FAB 역할 |

---

### `lib/presentation/screens/map/map_screen.dart` (3,012줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 지구본 모드 상수 | 29–33 | `kGlobeZoomThreshold = 3.0`, `kClusterZoomThreshold = 13.0` |
| `_Cluster` 모델 | 36–67 | 위경도 중심 + 포함 핀 목록 + 대표 국가 코드 |
| **핀 마커 비트맵** | 68–269 | `_buildMarkerBitmap()` — 글로우 + 그림자 + 다크 바디 + 그라디언트 테두리 + SVG 아이콘 |
| 경로 번호 마커 | 270–380 | `_buildNumberedMarkerBitmap()` — 우상단 숫자 배지 |
| 클러스터 마커 | 381–450 | `_buildClusterMarkerBitmap()` — 검정 원 + 흰 숫자 |
| 지구본 국가 마커 | 451–560 | `_buildCountryMarkerBitmap()` — SVG 국기 + 국가명 |
| 약속 위치 업데이트 | 644–675 | `_updateMeetingScreenPositions()` — pixelForCoordinate |
| 클러스터 아이콘 순환 | 687–749 | `_cycleClusterIcons()` — 세대 카운터로 스테일 감지 |
| **클러스터 계산** | 750–827 | `_computeClusters()` — 그리드 기반 핀 그룹핑 |
| **마커 업데이트** | 828–1030 | `_updateMarkers()` — create먼저→delete나중 (잔상 방지) |
| 현재 위치 이동 | 1041–1096 | `_moveToCurrentLocation()` — GPS 권한 + flyTo |
| 지구본 모드 진입/종료 | 1097–1188 | `_enterGlobeMode()` / `_exitGlobeMode()` — projection 전환 |
| 경로 모드 | 1189–1367 | 폴리라인 그리기 + 날짜 그룹 선택 + 활성화/비활성화 |
| GPS 핀 생성 | 1368–1427 | `_createPinAtCurrentLocation()` → PinWizardScreen push |
| 지도 탭 핀 생성 | 1428–1448 | `_onMapTap()` → PinWizardScreen push |
| 지도 초기화 | 1475–1562 | `_onMapCreated()` — 스타일, 카메라, 어노테이션, 위치 아이콘 |
| 메인 빌드 | 1563–1836 | MapboxMap + 컨트롤 + 약속 오버레이 + 클러스터 애니메이션 |
| 지도 컨트롤 패널 | 1837–1986 | `_MapControls` — 글래스 버튼 6개 |
| 지구본 하단 패널 | 1987–2237 | `_GlobeBottomPanel` — 국가 정보 슬라이드업 패널 |
| 경로 날짜 시트 | 2238–2398 | `_RouteDateSheet` — 날짜별 핀 그룹 목록 |

---

### `lib/presentation/screens/feed/feed_screen.dart` (1,252줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| `_BadgeDef` / `_TitleDef` 모델 | 20–55 | 뱃지·칭호 데이터 모델 |
| 뱃지 12종 정의 | 57–307 | 카테고리 8종 + 마일스톤 4종, 각 뱃지 unlock 조건 |
| `FeedScreen` 탭 컨트롤러 | 317–350 | TabController 3탭 (핀도감/뱃지/칭호) |
| 메인 빌드 | 351–499 | CustomScrollView + SliverAppBar + TabBarView |
| 커스텀 탭 바 | 502–622 | `_TabBar` + `_TabChip` — 칩 스타일 탭 선택기 |
| 핀 도감 탭 | 626–728 | `_PinDogamTab` — 13종 카테고리 그리드 |
| 카테고리 아이템 | 731–838 | `_PinCategoryItem` — SVG 아이콘 + 수집 수/총 수 |
| 뱃지 도감 탭 | 841–932 | `_BadgeDogamTab` — 획득/미획득 그리드 |
| 칭호 카드 | 935–1042 | `_TitleCard` — 5단계 칭호 진행 표시 |
| 뱃지 카드 | 1090–1163 | `_BadgeCard` — 획득 파스텔 / 미획득 회색 |
| 뱃지 상세 시트 | 1166–1252 | `_BadgeDetailSheet` — 이름 + 설명 + 획득 날짜 |

---

### `lib/presentation/screens/activity/activity_screen.dart` (912줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| `ActivityScreen` 상태 | 18–49 | 핀 통계 계산 (국가 수, 동행자 수, 연속 일수 등) |
| 메인 빌드 | 50–330 | 파스텔 통계 카드 6개 + 히트맵 + 일별 카드 목록 |
| 파스텔 통계 카드 | 333–432 | `_PastelStatCard` — 핀수/국가/배지/칭호/연속/동행 |
| 히트맵 캘린더 | 435–639 | `_ActivityHeatmap` — 접이식 월별 컬러 그리드, 핀 빈도에 따른 색상 강도 |
| 일별 카드 | 640–912 | `_DayCard` — 날짜 + 핀 목록 + 감정/날씨 아이콘 |

---

### `lib/presentation/screens/profile/profile_screen.dart` (2,247줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 상태 초기화 | 42–67 | 알림/동기화 토글 + BackupService 참조 |
| 메인 빌드 | 68–265 | SliverAppBar(접이식 헤더) + 프레임 섹션 + 스탯 + 최근 핀 + 설정 |
| 로그아웃 다이얼로그 | 281–304 | 확인 후 `signOut()` + SignInScreen 이동 |
| 계정 탈퇴 다이얼로그 | 305–330 | 경고 후 `deleteAccount()` + SignInScreen 이동 |
| 약속 생성 시트 | 331–343 | MeetingCreateSheet 표시 |
| JSON 백업 가져오기 | 344–391 | FilePicker + `BackupService.importPins()` |
| 사진 선택 | 415–425 | `ImagePicker.pickImage()` → profile 저장 |
| 프로필 편집 시트 | 426–448 | 닉네임 + 부제목 편집 → Supabase 동기화 |
| 프레임 컬렉션 | 516–712 | `_FrameSection` — 가로 스크롤 10종 프레임 |
| 프로필 카드 | 713–940 | 아바타 + 닉네임 + 칭호 배지 + 핀/국가/배지 스탯 |
| 컬렉션 진행 링 | 1010–1149 | `_CollectionProgress` — 뱃지/칭호 원형 진행 표시 |
| 최근 핀 섹션 | 1235–1485 | `_RecentPinsSection` — 3열 그리드, 탭 시 상세 시트 |
| 테마 색상 섹션 | 1628–1778 | 프리셋 칩 10종 + 커스텀 색상 `+` 버튼 |
| 커스텀 색상 피커 | 1781–2247 | `_ColorPickerSheet` — HSL 슬라이더 3개 |
| 설정 섹션 | 1896–2055 | 알림/동기화 토글 + 약속/친구/백업/약관/로그아웃/탈퇴 |

---

### `lib/presentation/screens/pin_wizard/pin_wizard_screen.dart` (243줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 위자드 단계 관리 | 33–48 | `_currentStep` (0–4), 5단계 배열 |
| 다음 단계 / 뒤로 | 49–68 | `_goNext()` / `_goBack()` — 슬라이드 방향 제어 |
| **핀 저장** | 71–139 | `_save()` — 역지오코딩 → PinModel 생성 → `pinsProvider.add()` |
| 단계 전환 애니메이션 | 140–217 | `PageView` + 슬라이드/페이드 커스텀 전환 |
| 메인 빌드 | 218–243 | WizardScaffold + PageView |

---

### `lib/presentation/screens/social/friends_screen.dart` (805줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 친구 목록 표시 | 11–50 | Supabase 스트림 우선 + Hive 폴백 |
| 내 친구 코드 카드 | 30–100 | 6자리 코드 + 클립보드 복사 |
| 친구 삭제 | 175–185 | `socialServiceProvider.removeFriend()` → 로컬 + Supabase 동시 삭제 |
| 친구 추가 시트 | 580–624 | `_AddFriendSheet` — 코드 입력 → `getUserByCode()` → `addFriendship()` |

---

### `lib/application/providers/auth_provider.dart` (254줄)

> 상세 내용은 `SECURITY_LOG.md [기능 정리]` 참조

| 기능 | 라인 | 설명 |
|------|------|------|
| PinlogAuthState | 14–39 | 인증 상태 모델 |
| 세션 검증 (보안) | 58–78 | 앱 시작 시 실 세션 우선 확인 |
| JWT 만료 자동 로그아웃 | 79–89 | signedOut 이벤트 감지 |
| OAuth + Email 로그인 | 95–213 | 전체 로그인 수단 |
| 로그아웃 + 계정 탈퇴 | 194–248 | signOut() / deleteAccount() |

---

### `lib/application/services/social_service.dart` (104줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| `socialServiceProvider` | 6–7 | Riverpod Provider 등록 |
| 유저 upsert | 14–35 | `createOrUpdateUser()` — users 테이블 upsert |
| 코드로 유저 조회 | 37–44 | `getUserByCode()` — 친구 코드로 탐색 |
| 친구 추가 | 46–79 | `addFriendship()` — 양방향 friendships 행 생성 |
| 친구 실시간 스트림 | 81–97 | `friendsStream()` — Supabase Realtime 스트림 |
| 친구 삭제 | 99–107 | `removeFriend()` — 양방향 삭제 |

---

### `lib/application/services/fcm_service.dart` (81줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 백그라운드 핸들러 | 9–12 | `_firebaseMessagingBackgroundHandler()` — vm:entry-point 어노테이션 |
| FCM 초기화 | 20–39 | 권한 요청 + 리스너 등록 + 토큰 업로드 |
| 토큰 Supabase 저장 | 46–55 | `_saveToken()` — users.fcm_token upsert |
| 포그라운드 메시지 | 57–61 | `_handleForeground()` — 인앱 배너 (TODO) |
| 알림 ON/OFF 토글 | 67–74 | `setEnabled()` — 토큰 삭제 또는 재발급 |

---

### `lib/application/services/pin_sync_service.dart` (135줄)

| 기능 | 라인 | 설명 |
|------|------|------|
| 싱글턴 + 토글 | 34–50 | Hive 동기화 ON/OFF 상태 관리 |
| 핀 업로드 | 51–83 | `uploadPin()` / `uploadAll()` — Supabase pins upsert |
| 핀 다운로드 | 84–97 | `downloadAll()` — Supabase → Hive 전체 동기화 |
| 직렬화 | 98–135 | `_toMap()` / `_fromMap()` — PinModel ↔ JSON 변환 |
