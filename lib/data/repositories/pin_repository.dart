import 'package:hive_flutter/hive_flutter.dart';

import '../models/pin_model.dart';

class PinRepository {
  static const _boxName = 'pins';

  Box<PinModel> get _box => Hive.box<PinModel>(_boxName);

  static Future<void> init() async {
    Hive.registerAdapter(PinModelAdapter());
    await Hive.openBox<PinModel>(_boxName);
  }

  List<PinModel> getAll() =>
      _box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  PinModel? getById(String id) {
    try {
      return _box.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PinModel pin) async {
    await _box.put(pin.id, pin);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  List<PinModel> getByDate(DateTime date) {
    return _box.values.where((p) {
      return p.createdAt.month == date.month && p.createdAt.day == date.day;
    }).toList();
  }

  List<PinModel> filterByEmotion(String emotion) {
    if (emotion == 'all') return getAll();
    return _box.values.where((p) => p.emotion == emotion).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PinModel> filterByVisibility(String visibility) {
    if (visibility == 'all') return getAll();
    return _box.values.where((p) => p.visibility == visibility).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
