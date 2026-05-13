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
    );
  }
}
