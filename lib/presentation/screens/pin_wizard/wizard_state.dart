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

  /// Step 4 — 동행자
  List<String> companions;

  /// Step 5 — 공개 범위
  String visibility;

  /// 위치 (시작 시 주입됨)
  LatLng location;
  String? locationName;

  /// 날짜·시간
  DateTime createdAt;

  WizardData({
    required this.location,
    this.locationName,
    this.photoPaths = const [],
    this.title = '',
    String? emotion,
    this.intensityLevel = 3,
    String? weather,
    this.companions = const [],
    String? visibility,
    DateTime? createdAt,
  })  : emotion = emotion ?? AppConstants.emotions.first,
        weather = weather ?? AppConstants.weathers.first,
        visibility = visibility ?? AppConstants.visibilities.first,
        createdAt = createdAt ?? DateTime.now();

  bool get isTitleValid => title.trim().isNotEmpty;
}
