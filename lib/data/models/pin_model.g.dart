// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_model.dart';

class PinModelAdapter extends TypeAdapter<PinModel> {
  @override
  final int typeId = 0;

  @override
  PinModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PinModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      emotion: fields[5] as String,
      weather: fields[6] as String,
      companions: (fields[7] as List).cast<String>(),
      intensityLevel: fields[8] as int,
      pinShape: fields[9] as String,
      visibility: fields[10] as String,
      photoPaths: (fields[11] as List).cast<String>(),
      createdAt: fields[12] as DateTime,
      sharedMapId: fields[13] as String?,
      countryCode: fields[14] as String? ?? '',
      taggedFriendCodes: (fields[15] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, PinModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.emotion)
      ..writeByte(6)
      ..write(obj.weather)
      ..writeByte(7)
      ..write(obj.companions)
      ..writeByte(8)
      ..write(obj.intensityLevel)
      ..writeByte(9)
      ..write(obj.pinShape)
      ..writeByte(10)
      ..write(obj.visibility)
      ..writeByte(11)
      ..write(obj.photoPaths)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.sharedMapId)
      ..writeByte(14)
      ..write(obj.countryCode)
      ..writeByte(15)
      ..write(obj.taggedFriendCodes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
