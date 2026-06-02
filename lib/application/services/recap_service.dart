import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/pin_model.dart';

const _kLastShownKey = 'recap_last_shown_date';
const _kProximityMeters = 300.0;

class RecapMemory {
  final PinModel pin;
  final int yearsAgo;
  const RecapMemory({required this.pin, required this.yearsAgo});
}

class RecapService {
  RecapService._();
  static final RecapService instance = RecapService._();

  Box<dynamic> get _box => Hive.box<dynamic>('settings');

  // ── On This Day ──────────────────────────────────────────────────────────

  /// 오늘과 같은 월/일에 생성된 1~3년 전 핀 반환 (최신 연도 순)
  List<RecapMemory> getMemoriesForToday(List<PinModel> pins) {
    final now = DateTime.now();
    final results = <RecapMemory>[];

    for (int y = 1; y <= 10; y++) {
      final targetYear = now.year - y;
      final matches = pins.where((p) =>
          p.createdAt.year == targetYear &&
          p.createdAt.month == now.month &&
          p.createdAt.day == now.day);
      for (final p in matches) {
        results.add(RecapMemory(pin: p, yearsAgo: y));
      }
    }

    results.sort((a, b) => a.yearsAgo.compareTo(b.yearsAgo));
    return results;
  }

  /// 오늘 이미 On This Day 팝업을 보여줬으면 true
  bool alreadyShownToday() {
    final stored = _box.get(_kLastShownKey) as String?;
    if (stored == null) return false;
    final storedDate = DateTime.tryParse(stored);
    if (storedDate == null) return false;
    final now = DateTime.now();
    return storedDate.year == now.year &&
        storedDate.month == now.month &&
        storedDate.day == now.day;
  }

  void markTodayShown() {
    _box.put(_kLastShownKey, DateTime.now().toIso8601String());
  }

  // ── Proximity ─────────────────────────────────────────────────────────────

  /// 현재 위치 근처(300m 이내) 1년 이상 된 핀 반환.
  /// 이미 이 세션에서 보여준 ID는 shownIds 로 걸러냄.
  List<PinModel> getMemoriesNear(
    List<PinModel> pins,
    double lat,
    double lng, {
    required Set<String> shownIds,
  }) {
    final now = DateTime.now();
    return pins.where((p) {
      if (shownIds.contains(p.id)) return false;
      if (now.difference(p.createdAt).inDays < 365) return false;
      return distanceMeters(lat, lng, p.latitude, p.longitude) <=
          _kProximityMeters;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLam = (lng2 - lng1) * math.pi / 180;
    final sinHalf = math.sin(dPhi / 2);
    final sinHalfLam = math.sin(dLam / 2);
    final a = sinHalf * sinHalf +
        math.cos(phi1) * math.cos(phi2) * sinHalfLam * sinHalfLam;
    return 2 * r * math.asin(math.sqrt(a));
  }

  static int yearsAgo(DateTime date) {
    final now = DateTime.now();
    return now.year - date.year;
  }
}
