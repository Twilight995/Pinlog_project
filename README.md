# Pinlog — 개발 현황 문서

> 최종 업데이트: 2026-05-05
> 플랫폼: Flutter (iOS 우선 개발 중)
> 분석 모델: Claude Sonnet 4.6

---

## 1. 프로젝트 개요

**Pinlog**는 "기억을 지도에 핀으로 꽂는" 개인 위치 기반 라이프 로그 다이어리 앱이다.  
사용자가 방문한 장소를 지도 위에 핀으로 기록하고, 감정·날씨·동행자·사진 등의 메타데이터를 함께 저장한다.  
배지 시스템과 칭호 시스템으로 기록 행위 자체에 동기부여를 제공한다.

| 항목 | 값 |
|------|----|
| 앱 이름 | Pinlog |
| 버전 | 1.0.0+1 |
| 패키지명 | pinlog |
| Dart SDK | ^3.11.4 |
| 상태관리 | Riverpod (StateNotifierProvider) |
| 로컬 저장소 | Hive |
| 지도 | Mapbox (mapbox_maps_flutter 2.23.0) |

---

## 2. 디렉토리 구조

```
Pinlog/
├── pubspec.yaml
├── README.md
└── lib/
    ├── main.dart                             # 앱 진입점, Mapbox 토큰, 테스트 핀 시드
    ├── core/
    │   ├── constants/
    │   │   └── app_constants.dart            # 날씨·핀 모양·감정·공개범위 상수
    │   ├── theme/
    │   │   └── app_theme.dart                # 컬러 팔레트, Light/Dark 테마, AppThemeX 확장
    │   └── utils/
    │       └── sheet_utils.dart              # showAppSheet() 스프링 바텀시트 헬퍼
    ├── data/
    │   ├── models/
    │   │   ├── pin_model.dart                # Hive 데이터 모델 (HiveField 0~14)
    │   │   └── pin_model.g.dart              # Hive 어댑터 (수동 관리)
    │   └── repositories/
    │       ├── pin_repository.dart           # 핀 CRUD
    │       └── profile_repository.dart       # 닉네임·소개글·사진경로·프레임 저장
    ├── application/
    │   └── providers/
    │       ├── pin_provider.dart             # 핀·필터·선택·지도스타일 상태 (Riverpod)
    │       └── profile_provider.dart         # 프로필 상태 (photoPath, borderStyle 포함)
    └── presentation/
        ├── screens/
        │   ├── main_shell.dart               # 하단 플로팅 네비게이션 쉘
        │   ├── map/map_screen.dart           # 지도 화면 (Tab 0)
        │   ├── feed/feed_screen.dart         # 수집 도감 (Tab 1)
        │   ├── activity/activity_screen.dart # 활동 (Tab 2)
        │   └── profile/profile_screen.dart   # 프로필 (Tab 3)
        └── widgets/
            ├── common/
            │   ├── glass_button.dart         # 유리 효과 원형 버튼
            │   └── glass_sheet.dart          # 유리 효과 오버레이 패널
            └── map/
                ├── pin_create_sheet.dart     # 핀 생성/편집 폼
                ├── pin_detail_sheet.dart     # 핀 상세보기
                ├── filter_sheet.dart         # 감정·공개범위 필터
                └── cluster_anim_overlay.dart # Nebulous 클러스터 합체/분리 애니메이션
```

---

## 3. 의존성 패키지

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `mapbox_maps_flutter` | ^2.3.0 | Mapbox 네이티브 3D 지도 (지구본 프로젝션 포함) |
| `flutter_riverpod` | ^2.6.1 | 상태관리 |
| `hive_flutter` | ^1.1.0 | 로컬 NoSQL 저장소 |
| `geolocator` | ^13.0.4 | 현재 위치 조회 |
| `geocoding` | ^3.0.0 | 역지오코딩 (핀 저장 시 국가코드·주소 취득) |
| `image_picker` | ^1.1.2 | 핀 사진·프로필 사진 첨부 |
| `path_provider` | - | 프로필 사진 영구 저장 경로 |
| `uuid` | ^4.5.1 | 핀 ID 생성 |
| `intl` | ^0.19.0 | 날짜 포맷 |
| `latlong2` | ^0.9.1 | 위도/경도 타입 |
| `permission_handler` | ^11.4.0 | GPS 권한 요청 |

---

## 4. 핵심 데이터 모델 (`PinModel`)

Hive TypeId: **0** — 총 **15개** HiveField

| Field | 타입 | 설명 |
|-------|------|------|
| 0 | `String` | id (UUID v4) |
| 1 | `String` | title |
| 2 | `String` | description |
| 3 | `double` | latitude |
| 4 | `double` | longitude |
| 5 | `String` | emotion (`'좋아요'` \| `'별로에요'`) |
| 6 | `String` | weather |
| 7 | `List<String>` | companions |
| 8 | `int` | intensityLevel (1~5) |
| 9 | `String` | pinShape (`sprout`\|`chiikawa`\|`cherryBlossom`\|`moon`\|`cloud`\|`star`\|`sun`) |
| 10 | `String` | visibility |
| 11 | `List<String>` | photoPaths |
| 12 | `DateTime` | createdAt |
| 13 | `String?` | sharedMapId (미사용) |
| 14 | `String` | countryCode (ISO 3166-1 alpha-2, 예: `"KR"`) |

`pin_model.g.dart`는 수동 관리. Field 14는 `fields[14] as String? ?? ''`로 읽어 하위 호환성 유지.

---

## 5. 테마 시스템

### 컬러 팔레트 (`AppColors`)

| 토큰 | 값 | 용도 |
|------|----|------|
| `primary` | `#52B788` | 세이지 그린 — 메인 액센트 |
| `primaryLight` | `#B5E48C` | 밝은 그린 — 그라디언트 밝은 끝 |
| `primaryDark` | `#2D6A4F` | 딥 포레스트 — 그라디언트 어두운 끝 |
| `dark` | `#1C1C1E` | 기본 다크 |
| `blue` | `#4A90D9` | 블루 액센트 |
| `gold` | `#F5A623` | 골드 액센트 |

`AppEmotions`: 좋아요=`primary` 그린, 별로에요=`greyPale` 회색.

### `AppThemeX` 확장 토큰

`context.bgColor`, `context.cardBg`, `context.labelColor`, `context.subLabelColor` 등 모든 색상을 BuildContext 확장으로 접근. 하드코딩 색상 없음.

---

## 6. 상태관리 (`pin_provider.dart`)

```dart
final pinsProvider             // StateNotifierProvider<PinsNotifier, List<PinModel>>
final selectedPinIdProvider    // StateProvider<String?>
final filterProvider           // StateNotifierProvider<FilterNotifier, FilterState>
final filteredPinsProvider     // Provider<List<PinModel>> (파생)
final mapStyleProvider         // StateProvider<MapStyleOption>  { standard, satellite, outdoors, dark }
final triggerCreatePinProvider // StateProvider<bool>
```

---

## 7. 지도 화면 (`map_screen.dart`)

### 7-1. 지구본 모드

| 상수 | 값 |
|------|-----|
| `_kGlobeEnterZoom` | 4.5 |
| `_kGlobeExitZoom` | 5.8 (히스테리시스) |
| `_kGlobeTargetZoom` | 1.5 |

진입·퇴장 시 `Future.delayed`로 flyTo 타이밍 버그 방지 (flyTo future가 애니메이션 완료 전 resolve되는 SDK 이슈).

### 7-2. 마커 시스템

| 마커 종류 | 함수 | 크기 | 특징 |
|-----------|------|------|------|
| 단일 핀 | `_buildMarkerBitmap(isCluster: false)` | 46pt | 흰 원 + pinShape 이모지, `iconAnchor: CENTER` |
| 클러스터 | `_buildMarkerBitmap(isCluster: true)` | 52pt | 다크 원 + 숫자, `iconAnchor: CENTER` |
| 국가 클러스터 | `_buildCountryMarkerBitmap` | 58pt | 흰 원 + 국기 이모지 + 카운트 뱃지, `iconAnchor: CENTER` |
| 현재 위치 | `_buildLocationBitmap` | 26pt | iOS 파란 점 스타일, `iconAnchor: CENTER` |
| 경로 번호 | `_buildNumberedMarkerBitmap` | 48pt | 색상 파라미터화 (테마 대응), `iconAnchor: CENTER` |

모든 마커 `_markerCache`에 PNG 바이트로 캐시. **`iconAnchor: IconAnchor.CENTER` 모든 PointAnnotationOptions에 명시적으로 설정** (테마 변경 시에도 좌표 정밀도 일관성 보장).

### 7-3. 클러스터링 (`_computeClusters`)

| 줌 | 동작 |
|----|------|
| `< 4.5` | 국가별 그룹 → 국기 클러스터 |
| `>= 13` | 개별 핀 |
| `>= 11` | 그리드 0.025° |
| `>= 9` | 그리드 0.08° |
| `>= 6` | 그리드 0.3° |
| `< 6` | 그리드 1.5° |

### 7-4. Nebulous 클러스터 애니메이션 (`cluster_anim_overlay.dart`)

클러스터 수 변화 시(줌 변화) 트리거. 감쇠 스프링 물리 + Mercator 투영 좌표 변환.  
Phase1(기존→소멸) + Phase2(신규→생성) 2단 구조.

### 7-5. 경로 모드

- **활성화**: 경로 버튼 탭 → `_RouteDateSheet` (날짜별 그룹) → 날짜 선택
- **핀 2개 이상**: `cameraForCoordinateBounds`로 모든 핀이 화면에 들어오도록 자동 맞춤 (bottom inset 360px = 패널+네비 공간 확보)
- **폴리라인**: `PolylineAnnotationOptions` 실선 (점선은 LineLayer API 필요)
- **번호 마커**: `_buildNumberedMarkerBitmap` — 테마별 색상 자동 변경

**테마별 경로 색상:**
| 테마 | 선 색상 | 마커 |
|------|---------|------|
| standard | `#1B4332` 딥그린 | primary 그린 마커 |
| satellite | `#FFFFFF` 흰색 | 흰 마커 + 다크 텍스트 |
| dark | `#52B788` primary | primary 그린 마커 |
| outdoors | `#1565C0` 블루 | 블루 마커 |

- **_RoutePanel**: 플로팅 카드 (`borderRadius: 20`, 좌우 12px 마진, 네비 바 위 위치)
- `_lastClusters = []` guard: 경로 활성/비활성 시 stale 클러스터 애니메이션 방지

### 7-6. 지도 컨트롤 (`_MapControls`)

**항상 표시:**
- 경로 버튼 (활성 시 primary 초록 X)
- 필터 버튼
- 토글 버튼 (화살표 `AnimatedRotation` 180°)

**토글로 슬라이드 (`AnimatedSize` + `AnimatedOpacity`):**
- 지구본 버튼
- 지도 테마 버튼

**우측 하단 (`Positioned`):**
- 현재 위치 버튼 (`bottom: padding.bottom + 10`)

### 7-7. 바텀시트 (`sheet_utils.dart`)

`showAppSheet<T>()`: 모든 바텀시트에 사용. 스프링 물리 애니메이션 (`SpringSimulation`, damping 0.82, stiffness 380).

---

## 8. 핀 생성·편집 (`pin_create_sheet.dart`)

BackdropFilter(blur 30) + `context.sheetBg` 배경, 화면 최대 75%.

| 항목 | UI 타입 | 비고 |
|------|---------|------|
| 제목 | TextField | 필수 |
| 설명 | TextField (3줄) | 선택 |
| 감정 | 2칸 버튼 토글 | 좋아요 / 별로에요 |
| 날씨 | Wrap Chip | 5가지 |
| 핀 모양 | 가로 스크롤 | 7가지 이모지 |
| 감정 강도 | 원형 버튼 1~5 | |
| 동행자 | TextField + 태그 | |
| 사진 | 가로 스크롤 | 최대 5장 |
| 공개범위 | Wrap Chip | 3가지 |
| **날짜** | DatePicker | `firstDate: 2000`, `lastDate: 2100` (과거·미래 모두 가능) |
| **시간** | TimePicker | 날짜와 분리된 버튼, 선택 시 기존 날짜 유지 |

편집 모드: `editPin` 파라미터로 기존 값 pre-fill.

---

## 9. 활동 화면 (`activity_screen.dart`)

- 상단 통계 카드: 총 핀 / 이번 달 / 활동 일수
- 히트맵 캘린더: 이번 달 날짜별 밀도
- 날짜별 타임라인: 오늘·어제·이번 주·지난 주·이전
- **섹션당 5개 초과 시 "전체 보기" 버튼 표시** → `_SectionAllPinsSheet` 바텀시트

---

## 10. 프로필 화면 (`profile_screen.dart`)

- `SliverAppBar(expandedHeight: 100)` — activity 화면과 동일한 스타일
- **프레임 컬렉션**: LoL/Discord 스타일 수집형 아바타 프레임 6종 (`_FramePainter` CustomPainter)
  - basic(0핀), jade(3핀), explorer(5핀), traveler(10핀), nature(20핀), legend(50핀)
  - 잠금 해제 기준: 보유 핀 수
- 프로필 사진 변경: `image_picker` + `path_provider` (갤러리 오픈)
- **전체 보기**: 최근 기록 섹션 → `_AllPinsSheet` (불투명 배경)
- 통계 카드, 설정 섹션

---

## 11. 수집 도감 (`feed_screen.dart`)

### 칭호 (5단계)
여행 새내기(0) → 나들이 러버(5) → 여행자(15) → 탐험가(30) → 여행 달인(60)

### 뱃지 (12개)
`first_trip`, `five_trips`, `ten_trips`, `thirty_trips`, `intense_trip`, `solo_traveler`,
`group_traveler`, `all_weather`, `four_seasons`, `monthly_traveler`, `veteran_traveler`, `weekend_traveler`

---

## 12. 내비게이션 (`main_shell.dart`)

- 하단 플로팅 바: height 72, `context.navBg`, `BorderRadius.circular(40)`
- 탭 전환: `AnimatedOpacity`만 사용 (Mapbox 네이티브 뷰 scale 간섭 방지)
- 가운데 **+** 버튼: `triggerCreatePinProvider = true` → MapScreen 현재 위치 핀 생성

---

## 13. 테스트 시드 데이터 (`main.dart`)

`_seedTestRouteIfNeeded()` — 최초 1회만 실행 (sentinel ID `test_route_001` 체크).

| 번호 | 장소 | 시간 |
|------|------|------|
| 1 | 잠실 롯데타워 | 10:00 |
| 2 | 잠실 한강공원 | 11:30 |
| 3 | 뚝섬 한강공원 | 13:00 |
| 4 | 성수동 카페거리 | 14:30 |
| 5 | 경복궁 돌담길 | 16:00 |
| 6 | 광화문광장 | 17:30 |

날짜: 2026-04-28 / 경로 모드 테스트용

---

## 14. 구현 완료 기능

- [x] Mapbox 지도 (4가지 스타일)
- [x] 핀 생성/편집/삭제 (전체 폼)
- [x] **날짜·시간 직접 선택** (과거~미래 자유롭게)
- [x] 핀 상세보기 (슬라이드+페이드 팝업)
- [x] 줌 기반 자동 클러스터링
- [x] Nebulous 클러스터 합체/분리 애니메이션
- [x] 지구본 모드 (국가별 클러스터, 패널)
- [x] **경로 모드** (날짜별 핀 연결, 번호 마커, 폴리라인, 자동 bounds fit)
- [x] **테마별 경로 색상** (standard/satellite/dark/outdoors 각각 다른 색)
- [x] 스프링 바텀시트 애니메이션 (전체 시트 공통)
- [x] 지도 컨트롤 토글 (경로+필터 항상, 지구본+테마 슬라이드)
- [x] 현재 위치 버튼 (우측 하단)
- [x] **iconAnchor: CENTER 명시** (테마 변경 시 좌표 정밀도 보장)
- [x] 감정/공개범위 필터
- [x] 사진 첨부 (최대 5장)
- [x] 수집 도감 (12배지, 5칭호)
- [x] 활동 화면 (통계, 히트맵, 타임라인, **섹션 전체 보기**)
- [x] 프로필 화면 (**LoL식 프레임 컬렉션**, 사진 변경, 전체 보기)
- [x] 세이지 그린 컬러 시스템 (`#52B788`)
- [x] 다크/라이트 모드 자동 대응
- [x] Hive 로컬 저장

---

## 15. 미구현 / 추후 과제

| 항목 | 우선순위 | 비고 |
|------|---------|------|
| 핀 이미지 에셋화 | 🔴 높음 | 이모지 → 실제 PNG 아이콘 (다음 작업) |
| countryCode 저장 검증 | 🔴 높음 | 실기기 테스트 필요 |
| 알림 시스템 | 🟡 중간 | 토글 UI만 존재, `flutter_local_notifications` 필요 |
| 공유 지도 버튼 | 🟡 중간 | `onTap: {}` 빈 상태 |
| 검색 기능 | 🟢 낮음 | 핀 제목/설명/위치 검색 없음 |
| 백업/복원 | 🟢 낮음 | JSON 내보내기/가져오기 |
| Mapbox 토큰 보안 | 🔴 배포 전 | `main.dart` 평문 → `--dart-define` 처리 필요 |
| photoPaths 영구화 | 🟡 중간 | image_picker 임시 경로 → Documents 복사 필요 |

---

## 16. 핵심 기술 결정 사항

- **Mapbox viewport prop 제거**: `setCamera()`로 일회성 초기화 (viewport로 하면 setState마다 리셋)
- **flyTo future 타이밍 버그**: `await flyTo` 후 `Future.delayed(duration+여유)`로 전환 플래그 유지
- **Mapbox + scale 애니메이션 충돌**: `AnimatedOpacity`만 사용
- **Hive 하위 호환**: Field 14 `as String? ?? ''` nullable 읽기
- **핀 상세보기 팝업**: `showGeneralDialog` + `Stack([PinDetailSheet()])` 구조
- **하단 바 붙이기 기준값**: `bottom: MediaQuery.of(context).padding.bottom + 10`

---

*이 문서는 Claude Sonnet 4.6이 2026-05-05 기준 소스코드 전체를 분석하여 작성했습니다.*
# PinLog
