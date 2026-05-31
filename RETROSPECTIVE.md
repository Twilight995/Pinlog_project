# Pinlog — 개발 회고록

> 작성일: 2026-05-28  
> 기간: 2026-05 초 ~ 2026-05-28  
> 작성자: daoule_ee

---

## 프로젝트를 한 마디로

지도에 핀을 심어 삶을 기록하는 앱. 기술적으로는 Flutter 입문 + 풀스택 경험을 겸한 프로젝트였다.

---

## 1. 기술 선택 이유 — 왜 이 도구를 썼나

### 지도: Mapbox

Flutter의 공식 지도 패키지인 `google_maps_flutter`도 있지만, Mapbox를 선택한 이유는 하나다.  
**지구본 모드(Globe Projection)** — zoom을 끝까지 줄이면 평면 지도가 아닌 3D 구체가 나온다.  
Apple의 Find My 앱과 같은 시각적 감각이 앱의 정체성에 맞았다.  
대신 단점도 있다: 네이티브 iOS/Android SDK를 브릿지하는 구조라 캔버스 마커를 직접 비트맵으로 구워서 넘겨야 한다. Flutter의 Widget을 마커로 쓸 수 없다.

### 상태관리: Riverpod

`setState`, `Provider`, `Bloc` 중 Riverpod을 선택했다.  
이유는 **컴파일 타임 안전성** — `ref.watch(provider)` 를 잘못 쓰면 빌드 에러가 난다.  
`BlocBuilder<Bloc, State>` 같은 보일러플레이트 없이 `ref.watch()` 한 줄로 UI 리빌드가 되고,  
`ref.read(notifier).method()` 로 단방향 데이터 흐름을 깔끔하게 유지할 수 있었다.

### 로컬 저장소: Hive

SQLite(`sqflite`)는 스키마 마이그레이션을 직접 관리해야 한다.  
Hive는 Dart 객체를 그대로 직렬화하는 NoSQL이라 `PinModel`에 `@HiveType` 어노테이션만 달면 끝이다.  
오프라인 우선 설계에서 핵심 — 네트워크 없이도 핀 CRUD가 동작해야 해서 로컬 저장소가 필수였다.

### 인증 + DB: Supabase

처음에는 **Firebase(Firestore + Auth)** 로 시작했다.  
Firebase는 NoSQL이고 한국 개발 튜토리얼이 많아 진입장벽이 낮았다.

그러나 친구와 교수님의 조언으로 **Supabase로 전면 이전**했다.

이전 이유를 정리하면:

| 항목 | Firebase | Supabase |
|------|---------|---------|
| 데이터베이스 | NoSQL (Firestore) | PostgreSQL (관계형) |
| 쿼리 | 단순 필터 위주 | JOIN, 서브쿼리, 복잡 쿼리 가능 |
| 오픈소스 | ❌ (Google 독점) | ✅ (셀프호스팅 가능) |
| 인증 방식 | Firebase UID 기반 | Supabase UUID (auth.users 테이블) |
| 보안 규칙 | Firestore Security Rules (별도 언어) | PostgreSQL RLS (SQL로 작성) |
| 가격 | 도큐먼트 read 수 과금 | row/storage 기준, 무료 tier 넉넉 |
| 트렌드 | 성숙한 기술 | 최근 개발자 커뮤니티에서 빠르게 확산 |

특히 **RLS(Row Level Security)** 가 강력했다 — "본인 핀만 쓰기 가능, 친구의 공개 핀은 읽기 가능"  
이런 접근 규칙을 SQL 한 줄로 표현할 수 있다. Firebase의 Rules 문법보다 훨씬 직관적이다.

이전 과정에서 잔재가 남았다: `firestore_service.dart` 라는 파일이 실제로는 Supabase를 쓰고 있었다.  
(→ 이 회고를 쓰는 시점에 `social_service.dart` 로 정리 완료)

### 푸시 알림: Firebase FCM (유지)

Supabase로 전부 옮겼지만 FCM은 Firebase에서 계속 쓴다.  
iOS APNs, Android GCM 인프라에 직접 연결되는 건 현재 FCM밖에 없기 때문이다.  
Supabase에는 푸시 알림 서비스가 없다.  
결국 "로그인/DB → Supabase, 알림 → Firebase FCM" 구조가 가장 합리적인 분업이다.

---

## 2. 새롭게 알게 된 것들

### Flutter Canvas로 마커 비트맵 만들기

Mapbox는 Flutter Widget을 마커로 쓸 수 없다. 대신 `ui.Image`(비트맵)를 넘겨야 한다.  
`PictureRecorder` → `Canvas` → `endRecording()` → `toImage()` 순서로 비트맵을 직접 그린다.  
SVG를 마커에 쓰려면 `vector_graphics` 패키지로 `vg.loadPicture()`한 뒤 `canvas.drawPicture()`로 그려 넣어야 한다.

#### 마커 고스팅(ghosting) 버그 분석

마커 업데이트 시 빈 프레임(잔상)이 생기는 문제가 있었다.  
원인은 **delete → create 순서** 였다. 기존 마커를 지우고 새 마커를 만드는 사이에 빈 프레임이 생긴다.  
해결: **create 먼저, 그 다음 delete** — 새 마커가 화면에 올라온 다음 구 마커를 지운다.  
Mapbox annotation API는 `createMulti()` 이후 `Future.wait(stale.map(delete))`로 처리했다.

### 지구본 위에 대륙 그리기 (직교 투영)

스플래시 지구본에 대륙을 그릴 때 처음엔 임의의 타원 6개로 흉내냈다.  
이후 실제 위도/경도 좌표 데이터로 교체하면서 **정사영법(Orthographic Projection)** 을 배웠다.

```
z = cos(lon * π/180) * cos(lat * π/180)   → z > 0 이면 앞면(보이는 반구)
x = sin(lon * π/180) * cos(lat * π/180) * r
y = -sin(lat * π/180) * r
```

구의 앞면과 뒷면 경계(수평선)에서 폴리곤을 자르는 것도 직접 구현했다:  
보이는 꼭짓점 → 숨겨지는 꼭짓점으로 넘어갈 때 z=0 지점에서 선형 보간해 경계점을 구한다.

### Flutter Canvas 선 그라디언트

별똥별 꼬리를 구현할 때 Canvas의 `Paint`에 그라디언트 선을 넣어야 했다.  
Widget의 `LinearGradient`는 Canvas에 직접 쓸 수 없다.  
`dart:ui`의 `ui.Gradient.linear(Offset start, Offset end, [colors])` 를 써서 `Paint.shader`에 넣어야 한다.

### Supabase RLS (Row Level Security)

Supabase의 모든 테이블은 기본적으로 `RLS: DISABLED` 상태로 생성된다.  
`ENABLE ROW LEVEL SECURITY`를 실행해야 보안이 활성화되고,  
이후 `CREATE POLICY`로 허용 규칙을 명시해야 한다.  
처음에 이걸 몰라서 앱에서 아무것도 조회가 안 되는 상황을 겪었다.  
(→ 규칙 없이 RLS가 켜지면 모든 접근이 차단된다)

### Supabase Realtime Presence

약속 기능에서 친구와 실시간 위치를 공유할 때 사용했다.  
WebSocket 채널 하나를 열고 `track({lat, lng})`를 주기적으로 브로드캐스트하면  
같은 채널에 있는 모든 참가자의 위치를 `presenceStateStream`으로 받을 수 있다.  
서버에 별도 코드 없이 Flutter에서만 구현된다는 게 강점이었다.

### SVG 캐시 문제

`flutter_svg`는 파일 경로를 캐시 키로 사용한다.  
파일 내용을 교체해도 경로가 같으면 hot restart 후에도 이전 파싱 결과를 사용한다.  
→ 파일 이름 자체를 바꿔야 캐시가 무효화된다.

### ShaderMask로 텍스트 그라디언트

Flutter에서 텍스트에 그라디언트를 적용하려면 `ShaderMask` 위젯을 쓴다.  
`blendMode: BlendMode.srcIn`으로 설정하면 텍스트 형태대로 그라디언트가 마스킹된다.

---

## 3. 실수와 교훈

### Firebase Auth를 쓸 필요가 없었다

처음 설계에서 Firebase Auth(익명 로그인)으로 UID를 만들고 그걸 Supabase에서도 그대로 썼다.  
그러나 Supabase Auth 자체도 익명 로그인(`signInAnonymously()`)을 지원한다.  
Firebase Auth를 유지한 건 마이그레이션 당시 Supabase의 anonymous auth를 몰랐기 때문이다.  
→ 이 회고 작성 시점에 `firebase_auth` 의존성 제거 및 `AuthService`를 Supabase 기반으로 교체 완료.

### 파일 이름은 내용을 반영해야 한다

`firestore_service.dart` 라는 파일이 실제로는 Supabase를 쓰고 있었다.  
이름이 잘못된 파일은 코드를 읽는 사람(과 미래의 나)을 혼란스럽게 만든다.  
→ `social_service.dart` 로 이름 변경.

### 마커를 지우고 만들면 깜박인다

처음 구현에서 `deleteAll()` → `createMulti()` 순서였다.  
지도 위에서 핀이 잠깐 사라지는 1프레임이 생겨 눈에 보였다.  
"만들고 지우는" 순서가 맞다는 걸 디버깅으로 알게 됐다.

---

## 4. 아직 못 한 것들 (앞으로 할 것들)

| 항목 | 이유 |
|------|------|
| Apple 로그인 | Apple Developer 계정($99/년) 필요 — 아직 미등록 |
| FCM APNs 설정 | 위와 동일 — 실기기 테스트 불가 |
| 핀 클라우드 동기화 (public 핀) | 공유 지도에 핀 표시 기능 미완성 |
| 앱 스토어 배포 | Apple Developer 등록 후 진행 예정 |

---

## 5. 가장 잘 한 것

**오프라인 우선 설계** — Hive 로컬 저장소를 기반으로 하고 Supabase를 동기화 레이어로 쓴 것.  
네트워크 없이도 앱이 완전히 동작하고, 연결되면 자동으로 클라우드에 올라간다.  
이 구조 덕분에 Supabase 마이그레이션이 UI에 영향을 주지 않았다.

**배지 + 칭호 시스템** — 기록 동기부여를 앱 내에서 해결.  
핀 개수에 따라 칭호가 오르고, 특정 행동(솔로 여행, 비오는 날 방문 등)에 배지가 달린다.  
순수하게 로컬 데이터로 계산되므로 서버 의존성이 없다.

---

*작성: daoule_ee · 2026-05-28*

---

---

## [기능 정리] 핵심 기술 결정 — 파일별 구현 위치

> 발표 자료 제작용 — 회고에서 언급한 각 기술 결정이 실제로 코드 어느 위치에 구현됐는지  
> 기능 정리는 이 섹션(최하단)에 집중 관리한다.

---

### 지도 — Mapbox 선택 이유와 구현

| 결정 사항 | 파일 | 라인 | 이유 |
|-----------|------|------|------|
| 지구본 모드 (Globe Projection) | `map_screen.dart` | 1097–1188 | `_enterGlobeMode()` — zoom < 3.0 시 구체 투영으로 전환 |
| 마커 비트맵 직접 그리기 | `map_screen.dart` | 68–560 | Mapbox는 Widget 마커 불가 → Canvas로 직접 렌더링 |
| Create-before-Delete 마커 교체 | `map_screen.dart` | 828–1030 | 잔상 방지: `createMulti()` 먼저, 구 마커 삭제 나중 |
| 마커 캐시 키 = SVG경로+테마색 | `map_screen.dart` | 68–110 | 테마 변경 시 자동 캐시 무효화 |

---

### 상태관리 — Riverpod 선택 이유와 구현

| 결정 사항 | 파일 | 라인 | 이유 |
|-----------|------|------|------|
| `pinsProvider` (StateNotifier) | `pin_provider.dart` | 전체 | 핀 목록 단방향 흐름 |
| `pinlogAuthProvider` (StateNotifier) | `auth_provider.dart` | 43–254 | 인증 상태 중앙 관리 |
| `friendsStreamProvider` (StreamProvider) | `social_service.dart` | 100–104 | Supabase Realtime → UI 자동 리빌드 |
| `themePresetProvider` | `theme_provider.dart` | 전체 | 테마 전역 공유 |

---

### Supabase 마이그레이션 — 전/후 비교

| 항목 | Firebase (이전) | Supabase (이후) | 구현 위치 |
|------|----------------|----------------|-----------|
| 인증 UID 소스 | Firebase Anonymous Auth | Supabase Auth | `auth_service.dart:14–29` |
| 유저 저장 | Firestore `users/{uid}` | Supabase `users` 테이블 | `social_service.dart:14–35` |
| 친구 관계 | Firestore `friendships` 서브컬렉션 | Supabase `friendships` 테이블 | `social_service.dart:46–79` |
| 파일명 잔재 | `firestore_service.dart` (오명) | `social_service.dart` (수정) | — |
| 푸시 알림 | Firebase FCM (유지) | Firebase FCM (유지) | `fcm_service.dart:14–81` |

---

### 새로 배운 기술 — 구현 위치

| 배운 것 | 파일 | 라인 | 핵심 코드 |
|---------|------|------|----------|
| Canvas 비트맵 마커 생성 | `map_screen.dart` | 68–269 | `PictureRecorder → Canvas → toImage()` |
| 별똥별 그라디언트 선 | `splash_screen.dart` | 415–464 | `ui.Gradient.linear()` → `Paint.shader` |
| 정사영법 투영 | `splash_screen.dart` | 931–991 | `z = cos(lon)*cos(lat)`, `x = sin(lon)*cos(lat)*r` |
| 수평선 클리핑 | `splash_screen.dart` | 931–958 | `t = prevZ / (prevZ - z)` 선형 보간 |
| ShaderMask 텍스트 그라디언트 | `splash_screen.dart` | 169–391 | `BlendMode.srcIn` + `LinearGradient.createShader` |
| Supabase RLS | Supabase SQL | — | `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY` |
| Supabase Realtime Presence | `meeting_repository.dart` | 전체 | `channel.track({lat, lng})` |
| SVG 캐시 무효화 | `map_screen.dart` | 68–110 | 파일 경로를 캐시 키로 사용 → 경로 변경으로 무효화 |

---

### 실수 수정 — 구현 위치

| 실수 | 수정 파일 | 수정 라인 | 내용 |
|------|-----------|-----------|------|
| Hive auth_mode 세션 우회 | `auth_provider.dart` | 58–78 | Supabase 실 세션 먼저 확인 |
| `firestore_service.dart` 오명 | `social_service.dart` | 전체 | 파일명 + 클래스명 + 프로바이더명 변경 |
| 마커 깜박임 (delete→create 순서) | `map_screen.dart` | 828–1030 | create 먼저, delete 나중 |
| Firebase Auth 불필요 잔존 | `auth_service.dart` | 전체 | Supabase anonymous auth로 교체 |
