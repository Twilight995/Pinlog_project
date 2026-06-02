import 'package:hive_flutter/hive_flutter.dart';

part 'pin_model.g.dart';

@HiveType(typeId: 0)
class PinModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final String emotion;

  @HiveField(6)
  final String weather;

  @HiveField(7)
  final List<String> companions;

  @HiveField(8)
  final int intensityLevel; // 1~5

  @HiveField(9)
  final String pinShape; // sprout, chiikawa, cherryBlossom, moon, cloud, star, sun

  @HiveField(10)
  final String visibility; // public, friends, private

  @HiveField(11)
  final List<String> photoPaths;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final String? sharedMapId;

  @HiveField(14)
  final String countryCode; // ISO 3166-1 alpha-2, 예: "KR", "JP"

  @HiveField(15)
  final List<String> taggedFriendCodes;

  /// 핀 외부 테두리/글로우 색상 (ARGB int). null = 테마 색 따라가기.
  @HiveField(16)
  final int? pinOuterColor;

  /// 핀 내부 바디 색상 (ARGB int). null = outer 색에서 자동 유도.
  @HiveField(17)
  final int? pinInnerColor;

  PinModel({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.emotion,
    required this.weather,
    required this.companions,
    required this.intensityLevel,
    required this.pinShape,
    required this.visibility,
    required this.photoPaths,
    required this.createdAt,
    this.sharedMapId,
    this.countryCode = '',
    this.taggedFriendCodes = const [],
    this.pinOuterColor,
    this.pinInnerColor,
  });

  PinModel copyWith({
    String? title,
    String? description,
    String? emotion,
    String? weather,
    List<String>? companions,
    int? intensityLevel,
    String? pinShape,
    String? visibility,
    List<String>? photoPaths,
    String? countryCode,
    List<String>? taggedFriendCodes,
    Object? pinOuterColor = _sentinel,
    Object? pinInnerColor = _sentinel,
  }) {
    return PinModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude,
      longitude: longitude,
      emotion: emotion ?? this.emotion,
      weather: weather ?? this.weather,
      companions: companions ?? this.companions,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      pinShape: pinShape ?? this.pinShape,
      visibility: visibility ?? this.visibility,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt,
      sharedMapId: sharedMapId,
      countryCode: countryCode ?? this.countryCode,
      taggedFriendCodes: taggedFriendCodes ?? this.taggedFriendCodes,
      pinOuterColor: identical(pinOuterColor, _sentinel) ? this.pinOuterColor : pinOuterColor as int?,
      pinInnerColor: identical(pinInnerColor, _sentinel) ? this.pinInnerColor : pinInnerColor as int?,
    );
  }
}

const _sentinel = Object();
