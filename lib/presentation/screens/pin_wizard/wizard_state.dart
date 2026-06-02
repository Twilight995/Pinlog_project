import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';

/// 핀 생성 위자드의 단계별 입력값을 모아두는 가변 상태.
///
/// 5단계를 거치며 채워지고, 마지막에 `PinModel`로 변환해 저장.
class WizardData {
  /// Step 1 — 사진 (최대 5장)
  List<String> photoPaths;

  /// Step 2 — 제목 (필수)
  String title;

  /// Step 3 — 감정 ("좋아요" / "별로에요")
  String emotion;

  /// Step 3 — 감정 강도 (1~5)
  int intensityLevel;

  /// Step 4 — 날씨
  String weather;

  /// Step 4 — 동행자 (표시 이름)
  List<String> companions;

  /// Step 4 — 태그된 친구 코드 목록 (companions 의 부분집합)
  List<String> taggedFriendCodes;

  /// Step 5 — 공개 범위
  String visibility;

  /// Step 2 — 카테고리 (pinShape key)
  String pinShape;

  /// Step 2 — 한 줄 설명 (선택)
  String description;

  /// 위치 (시작 시 주입됨)
  LatLng location;
  String? locationName;

  /// 날짜·시간
  DateTime createdAt;

  /// 핀 외부 테두리/글로우 색 (ARGB int). null = 테마 색.
  int? pinOuterColor;

  /// 핀 내부 바디 색 (ARGB int). null = outer에서 자동 유도.
  int? pinInnerColor;

  WizardData({
    required this.location,
    this.locationName,
    this.photoPaths = const [],
    this.title = '',
    String? emotion,
    this.intensityLevel = 3,
    String? weather,
    this.companions = const [],
    this.taggedFriendCodes = const [],
    String? visibility,
    String? pinShape,
    this.description = '',
    DateTime? createdAt,
    this.pinOuterColor,
    this.pinInnerColor,
  })  : emotion = emotion ?? AppConstants.emotions.first,
        weather = weather ?? AppConstants.weathers.first,
        visibility = visibility ?? AppConstants.visibilities.first,
        pinShape = pinShape ?? AppConstants.pinShapes.first,
        createdAt = createdAt ?? DateTime.now();

  bool get isTitleValid => title.trim().isNotEmpty;
}
