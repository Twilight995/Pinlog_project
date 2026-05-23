# Pinlog 디자인 노트

## 표준 배경 패턴 (펜 작업 시 모든 메인 화면 기본값)

### 컨셉
검은 배경 + 두 개의 은은한 핑크 광원 (대각선 반대 방향).
레퍼런스 톤: 코스 앱 (Java Developing / Welcome back / Your Progress) 시리즈와 같은 분위기.

### 정확한 스펙

```js
// frame 사이즈에 따라 height 비율 조정 필요
// (size width:height = 원에 가깝게)
//   430×950 → height = 0.9
//   430×1080 → height = 0.8
//   430×800 → height = 1.07

fill: [
  "#0A0612",  // 베이스 다크
  // 광원 1: 왼쪽 위 (꼭짓점 안쪽으로 살짝)
  { type: "gradient", gradientType: "radial",
    center: { x: 0.25, y: 0.32 },
    size: { width: 2.0, height: 0.9 },  // ← frame 비율에 맞춰 조정
    colors: [
      { color: "#FF80B04D", position: 0 },     // 30% alpha, 강한 핑크
      { color: "#FF80B040", position: 0.1 },   // 25% (plateau — hotspot 방지)
      { color: "#FF8FB833", position: 0.22 },  // 20%
      { color: "#FFA0C224", position: 0.38 },  // 14%
      { color: "#FFB0CC18", position: 0.54 },  // 9%
      { color: "#FFC0D60E", position: 0.7 },   // 5%
      { color: "#FFD0E006", position: 0.85 },  // 2%
      { color: "#FFD0E001", position: 0.95 },  // 0.4%
      { color: "#FFD0E000", position: 1 }      // 0%
    ] },
  // 광원 2: 오른쪽 아래 (대각선 반대)
  { type: "gradient", gradientType: "radial",
    center: { x: 0.75, y: 0.78 },
    size: { width: 2.0, height: 0.9 },  // ← frame 비율에 맞춰 조정
    colors: [
      { color: "#FF80B04D", position: 0 },
      { color: "#FF80B040", position: 0.1 },
      { color: "#FF8FB833", position: 0.22 },
      { color: "#FFA0C224", position: 0.38 },
      { color: "#FFB0CC18", position: 0.54 },
      { color: "#FFC0D60E", position: 0.7 },
      { color: "#FFD0E006", position: 0.85 },
      { color: "#FFD0E001", position: 0.95 },
      { color: "#FFD0E000", position: 1 }
    ] }
]
```

### 설계 원칙

1. **베이스 색**: `#0A0612` (거의 검정에 미세한 자주)
2. **광원 두 개만** — 추가 액센트 글로우는 넣지 않음
3. **광원 위치**: 꼭짓점 안쪽으로 살짝 들여서 (좌상 0.25/0.32, 우하 0.75/0.78)
4. **광원 사이즈**:
   - 펜의 radial gradient size는 프레임 너비/높이에 정규화됨
   - 원 모양 유지하려면 `height = width × (frame_width / frame_height)`
   - 430×950 → `height = 2.0 × 0.45 = 0.9`
5. **색 흐름** (hue 340도 유지):
   - 시작: `#FF80B0` (R=255, G=128, B=176) — 강한 핑크
   - 중간: G/B만 점진적으로 증가
   - 끝: `#FFD0E0` (R=255, G=208, B=224) — 라이트 핑크
   - ❌ 절대 `#9D5C9D` 같은 보라/마젠타 fade 사용 금지 (자주색으로 보임)
6. **알파 패턴** (9단계 평탄 감소):
   - center 30% → 즉시 plateau 25% → 점진 감소 (20→14→9→5→2→0.4→0)
   - center alpha를 너무 낮추면 ring/halo 효과 → hotspot 방지하면서도 plateau 짧게 유지
7. **계산 검증**:
   - center 결과 색 = `0.3 × #FF80B0 + 0.7 × #0A0612` = `#542A41` (어두운 핑크-로즈)
   - R/G/B 차이가 R > B > G 순으로 유지돼야 핑크답게 보임

### 펜에서 다음 화면 만들 때

새 스크린 frame을 만든 후, 위 fill 배열을 그대로 적용. height 값만 프레임 비율에 맞게 조정.
