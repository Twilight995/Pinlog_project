# Mapbox 핀 잔상 이슈 — 조사 결과

## 현상
줌 인/아웃 시 핀 마커가 잠깐 겹쳐 보이거나 구 마커가 사라지기 전 잔상이 남는 현상.

## 원인: 구조적 문제

### 1. Platform Channel 비동기 레이턴시
`PointAnnotationManager`의 `deleteAll()` / `createMulti()`는 모두
**Dart → Platform Channel → Native Mapbox GL thread** 경로를 거침.

```
deleteAll()    → 채널 큐에 올라감
createMulti()  → 채널 큐에 올라감
               ↓
GL thread이 자체 프레임 사이클로 두 명령을 순차 처리
→ 명령 도달 전에 GL이 한두 프레임 더 렌더링 가능
→ "구 마커 + 새 마커 동시 표시" 프레임 발생
```

### 2. `_buildMarkerBitmap` async 지연
마커 재생성 시 Flutter Canvas로 PNG를 만들고 SVG를 로드하는 과정이 async.
이 대기 시간 동안 지도는 줌 애니메이션을 계속하고,
구 마커는 아직 GL layer에 살아 있어서 화면에서 "둥둥 떠다니는" 느낌을 줌.

### 3. 심볼 충돌 감지 버퍼
Mapbox Symbol Layer는 내부적으로 충돌 감지 알고리즘을 비동기 실행함.
`deleteAll()` 이후에도 삭제 예정 심볼이 충돌 버퍼에 잠시 남아
새 심볼이 표시되지 않거나 구 심볼이 한 프레임 더 보일 수 있음.

---

## 현재 코드의 완화 조치 (`map_screen.dart`)

| 조치 | 코드 위치 | 설명 |
|------|-----------|------|
| `_isUpdatingMarkers` 뮤텍스 | line 649, 1029 | 동시 `_updateMarkers` 실행 차단 |
| `_tryUpdateInPlace` | line 1108~1115 | 클러스터 수 동일 시 `deleteAll` 없이 제자리 업데이트 |
| `crossedBoundary` 조건 | line 1928~1930 | 정수 줌 경계 통과 시에만 업데이트 트리거 |
| 300ms 디바운스 | line 1232 | 연속 줌 중 중간 업데이트 방지 |
| `_pendingUpdatePins` 큐 | line 1166~1169 | 업데이트 중 들어온 요청 큐잉 후 즉시 재실행 |
| `_isGlobeTransitioning` 가드 | line 1920~1923 | 지구본 전환 중 마커 업데이트 완전 차단 |

---

## 추가 완화 가능한 방법

### 옵션 A — `onMapIdle` 사용 (가장 효과적)
현재 `onCameraChangeListener`(카메라 이동 중 계속 발동) 대신,
카메라가 완전히 멈춘 후 발동하는 `onMapIdle` 콜백을 사용하면
줌 중 마커 업데이트 자체가 발생하지 않아 잔상이 사라짐.

**트레이드오프:** 클러스터 경계 통과 시 마커 재계산이 줌 완료 후로 지연됨.

```dart
// onMapCreated에서:
mapboxMap.setOnMapIdleListener(() {
  _scheduleUpdate(_currentPins.isEmpty
      ? ref.read(filteredPinsProvider)
      : _currentPins);
});
// onCameraChangeListener에서 _scheduleUpdate 호출 제거
```

### 옵션 B — 새 마커 투명 생성 후 구 마커 삭제 (atomic swap)
`deleteAll`이 관리자 전체를 지우므로 현 구조에서 선택적 삭제 불가.
**관리자를 두 개로 나누어** A/B 교대 방식으로 구현해야 적용 가능.
구현 복잡도가 높아 발표 전 적용 비권장.

---

## 결론

- **구조적 문제 맞음** — `mapbox_maps_flutter` SDK의 Platform Channel 비동기 특성과 GL 렌더 타이밍 불일치가 근본 원인
- **완전 해결 불가** — SDK 레벨 한계. Mapbox Native 직접 연동(PlatformView) 수준이어야 해결 가능
- **현재 구현은 이 SDK로 할 수 있는 최선에 가까움**
- **발표 전 개선 우선순위 낮음** — 잔상이 짧고 사용자 경험에 치명적이지 않음
- **여유 있으면 옵션 A (`onMapIdle`) 적용 권장** — 코드 변경 최소, 효과 확실
