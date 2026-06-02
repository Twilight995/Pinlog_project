import 'package:hive_flutter/hive_flutter.dart';

import '../models/pin_model.dart';

class PinRepository {
  static const _boxName = 'pins';

  Box<PinModel> get _box => Hive.box<PinModel>(_boxName);

  static Future<void> init() async {
    Hive.registerAdapter(PinModelAdapter());
    await Hive.openBox<PinModel>(_boxName);
    await _seedIfEmpty();
  }

  static Future<void> _seedIfEmpty() async {
    final box = Hive.box<PinModel>(_boxName);
    if (box.isNotEmpty) return;

    final now = DateTime.now();
    final seeds = [
      PinModel(
        id: 'seed-1',
        title: '홍대 연남동 골목 카페',
        description: '좁은 골목 안에 숨어있는 브루잉 카페. 오후 햇살이 창문으로 들어오는 시간이 최고다.',
        latitude: 37.5584,
        longitude: 126.9240,
        emotion: '좋아요',
        weather: '맑음',
        companions: ['혼자'],
        intensityLevel: 4,
        pinShape: 'sprout',
        visibility: '🌐 전체 공개',
        photoPaths: [],
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
      PinModel(
        id: 'seed-2',
        title: '이태원 경리단길 야경',
        description: '남산타워를 배경으로 보이는 야경. 여름 밤 바람이 완벽했다.',
        latitude: 37.5340,
        longitude: 126.9950,
        emotion: '좋아요',
        weather: '바람',
        companions: ['친구'],
        intensityLevel: 5,
        pinShape: 'moon',
        visibility: '🌐 전체 공개',
        photoPaths: [],
        createdAt: now.subtract(const Duration(days: 5, hours: 6)),
      ),
      PinModel(
        id: 'seed-3',
        title: '강남 코엑스 별마당 도서관',
        description: '높은 책장과 자연광. 책 향기와 커피 향이 섞이는 공간.',
        latitude: 37.5126,
        longitude: 127.0590,
        emotion: '좋아요',
        weather: '흐림',
        companions: ['혼자'],
        intensityLevel: 3,
        pinShape: 'star',
        visibility: '🌐 전체 공개',
        photoPaths: [],
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      PinModel(
        id: 'seed-4',
        title: '한강 뚝섬 유원지',
        description: '치킨이랑 맥주, 한강 노을. 이보다 완벽한 저녁은 없다.',
        latitude: 37.5296,
        longitude: 127.0691,
        emotion: '좋아요',
        weather: '맑음',
        companions: ['친구', '연인'],
        intensityLevel: 5,
        pinShape: 'sun',
        visibility: '🌐 전체 공개',
        photoPaths: [],
        createdAt: now.subtract(const Duration(days: 3, hours: 8)),
      ),
      PinModel(
        id: 'seed-5',
        title: '성수동 팝업 스토어',
        description: '줄이 너무 길었고 막상 들어가니 기대보다 별로였다.',
        latitude: 37.5446,
        longitude: 127.0564,
        emotion: '별로에요',
        weather: '흐림',
        companions: ['친구'],
        intensityLevel: 2,
        pinShape: 'cloud',
        visibility: '👥 친구 공개',
        photoPaths: [],
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      PinModel(
        id: 'seed-6',
        title: '북촌 한옥마을 산책',
        description: '좁은 골목길과 기와지붕. 외국인 관광객이 많아서 조용하진 않았지만 분위기는 좋았다.',
        latitude: 37.5814,
        longitude: 126.9845,
        emotion: '좋아요',
        weather: '맑음',
        companions: ['가족'],
        intensityLevel: 3,
        pinShape: 'cherryBlossom',
        visibility: '🌐 전체 공개',
        photoPaths: [],
        createdAt: now.subtract(const Duration(days: 14)),
      ),
    ];

    for (final pin in seeds) {
      await box.put(pin.id, pin);
    }
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
