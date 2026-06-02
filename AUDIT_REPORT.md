# Pinlog 코드 감사 리포트
**기준일: 2026-06-01 | `flutter analyze`: 0 issues**

---

## CRITICAL (2건)

### C-01 · 전화번호 OTP 목업 — 보안 우회 가능
**파일:** `sign_up_screen.dart:124–148`  
**상태:** FIXED — 가입 흐름에서 전화번호 OTP 단계 제거, 선택 입력으로 전환

```dart
// 이전: 0.7초 지연 후 _phoneVerified = true (실제 검증 없음)
// 수정: 전화번호 옵션 필드만 남기고 OTP 단계 제거 (Twilio 연동 전까지)
```

---

### C-02 · 계정 탈퇴 시 로컬 Hive 데이터 미삭제
**파일:** `auth_provider.dart:668–692`  
**상태:** FIXED

```dart
// 수정: deleteAccount()에서 PinRepository.clearAll() + ProfileRepository.clearAll() + settings box 초기화 추가
```

---

## HIGH (5건)

### H-01 · 시드 핀 visibility 불일치 → 공유 지도 미표시
**파일:** `main.dart:192,207,222...` (test_route_001~006)  
**상태:** FIXED

```dart
// 이전: visibility: 'public'
// 수정: visibility: '🌐 전체 공개'
```

---

### H-02 · 백업 가져오기 — createdAt 누락 시 런타임 크래시
**파일:** `backup_service.dart:77`  
**상태:** FIXED

```dart
// 이전: DateTime.parse(m['createdAt'] as String)  → null 이면 TypeError
// 수정: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now()
```

---

### H-03 · 동기화 OFF 중 핀 삭제 → 재활성화 시 유령 핀 복구
**파일:** `pin_sync_service.dart:54–64`  
**상태:** FIXED

```dart
// 수정: uploadAll() 실행 전 서버 핀과 로컬 핀 비교 → 고아 핀 서버에서 삭제
```

---

### H-04 · 약속 추적 종료 — unawaited Future
**파일:** `meeting_provider.dart:165`  
**상태:** FIXED

```dart
// 이전: _stopLiveTracking();
// 수정: unawaited(_stopLiveTracking());
```

---

### H-05 · 친구 목록 — Supabase 빈 배열이 Hive 폴백 차단
**파일:** `friends_screen.dart:17–18`  
**상태:** FIXED

```dart
// 이전: firestoreFriends.valueOrNull ?? localFriends
// 수정: (supaFriends != null && supaFriends.isNotEmpty) ? supaFriends : localFriends
```

---

## MEDIUM (7건)

### M-01 · GPS 권한 미처리 — 약속 추적 중 silent fail
**파일:** `meeting_provider.dart:176–183`  
**상태:** FIXED — 추적 시작 전 권한 확인 + 거부 시 에러 상태 반환

---

### M-02 · secrets.dart git 커밋 여부
**파일:** `lib/core/secrets.dart`  
**상태:** `.gitignore` 49번째 줄에 이미 등록됨 — 처리 불필요

---

### M-03 · 앱 버전 하드코딩
**파일:** `profile_screen.dart:2107`  
**상태:** FIXED — `package_info_plus` 추가 후 동적 버전 표시

---

### M-04 · 공유 지도 — null UID 친구 필터 칩 오작동
**파일:** `shared_map_screen.dart:390–398`  
**상태:** FIXED — `supabaseUid == null` 친구는 칩 목록에서 제외

---

### M-05 · FCM 알림 탭 → 친구 화면 딥링크 없음
**파일:** `fcm_service.dart:115–116`  
**상태:** FIXED — 탭 전환 후 FriendsScreen push

---

### M-06 · 약속 생성 — 지오코딩 실패 시 무음 fallback
**파일:** `meeting_create_sheet.dart:85–93`  
**상태:** FIXED — 실패 시 에러 반환, 사용자에게 재입력 요청

---

### M-07 · RecapService — 3년 초과 기억 누락
**파일:** `recap_service.dart:29`  
**상태:** FIXED — `y <= 3` → `y <= 10`

---

## LOW (4건)

### L-01 · _friendColor / _colorFor 중복 구현
**파일:** `shared_map_screen.dart:188, 496`  
**상태:** FIXED — top-level 함수 `_colorForUid`로 추출

---

### L-02 · main.dart — AuthException 전체 삼킴
**파일:** `main.dart:37–40`  
**상태:** FIXED — PKCE 관련 에러만 필터링 (pkce, code verifier, invalid_grant, expired)

---

### L-03 · 프로필 카드 — `List<dynamic>` 런타임 캐스트
**파일:** `profile_screen.dart:1249`  
**상태:** FIXED — `List<PinModel>`으로 교체

---

### L-04 · 약속 overlay — 친구 아바타 URL 미사용
**파일:** `meeting_overlay.dart:261–269`  
**상태:** 오탐 — 실제로는 `meeting.friendAvatarUrl` 사용 중. 수정 불필요.

---

## 수정 이력

| 일자 | 수정 건수 | 내용 |
|------|-----------|------|
| 2026-06-01 | 14건 | 전체 감사 후 일괄 수정 완료 (L-04 오탐 제외) |
