import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/pin_model.dart';

const _kLastShownKey = 'recap_last_shown_date';
const _kProximityMeters = 300.0;

// ── On This Day ──────────────────────────────────────────────────────────────

class RecapMemory {
  final PinModel pin;
  final int yearsAgo;
  const RecapMemory({required this.pin, required this.yearsAgo});
}

// ── 위치 기반 리캡 ─────────────────────────────────────────────────────────────

enum RecapMilestone { oneMonth, threeMonths, sixMonths, oneYear, multiYear }

class ProximityMemory {
  final PinModel pin;
  final RecapMilestone milestone;

  const ProximityMemory({required this.pin, required this.milestone});

  /// "1개월" / "3개월" / "6개월" / "1년" / "N년"
  String get timeLabel {
    switch (milestone) {
      case RecapMilestone.oneMonth:
        return '1개월';
      case RecapMilestone.threeMonths:
        return '3개월';
      case RecapMilestone.sixMonths:
        return '6개월';
      case RecapMilestone.oneYear:
        return '1년';
      case RecapMilestone.multiYear:
        final years = DateTime.now().year - pin.createdAt.year;
        return '$years년';
    }
  }

  /// 동행자가 있으면 "X 전 [이름]와 함께한 추억이 있네요!"
  /// 없으면 "X 전 이곳을 지나가셨네요!"
  String get bannerBody {
    if (pin.companions.isNotEmpty) {
      final name = pin.companions.first;
      final extra = pin.companions.length > 1
          ? ' 외 ${pin.companions.length - 1}명'
          : '';
      return '$timeLabel 전 $name$extra와 함께한 추억이 있네요!';
    }
    return '$timeLabel 전 이곳을 지나가셨네요!';
  }
}

// ── 서비스 ────────────────────────────────────────────────────────────────────

class RecapService {
  RecapService._();
  static final RecapService instance = RecapService._();

  Box<dynamic> get _box => Hive.box<dynamic>('settings');

  // ── On This Day ────────────────────────────────────────────────────────────

  /// 오늘과 같은 월/일에 생성된 1~10년 전 핀 반환 (가까운 연도 순)
  List<RecapMemory> getMemoriesForToday(List<PinModel> pins) {
    final now = DateTime.now();
    final results = <RecapMemory>[];
    for (int y = 1; y <= 10; y++) {
      final matches = pins.where((p) =>
          p.createdAt.year == now.year - y &&
          p.createdAt.month == now.month &&
          p.createdAt.day == now.day);
      for (final p in matches) {
        results.add(RecapMemory(pin: p, yearsAgo: y));
      }
    }
    results.sort((a, b) => a.yearsAgo.compareTo(b.yearsAgo));
    return results;
  }

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

  // ── Proximity (마일스톤 기반) ────────────────────────────────────────────────

  /// 현재 위치 근처(300m) 핀 중 마일스톤(1개월/3개월/6개월/1년/N년) 도래한 핀 반환.
  /// ±3일 오차 허용. 이미 보여준 핀은 shownIds로 제외.
  List<ProximityMemory> getMemoriesNear(
    List<PinModel> pins,
    double lat,
    double lng, {
    required Set<String> shownIds,
  }) {
    final now = DateTime.now();
    final results = <ProximityMemory>[];

    for (final pin in pins) {
      if (shownIds.contains(pin.id)) continue;
      if (distanceMeters(lat, lng, pin.latitude, pin.longitude) > _kProximityMeters) {
        continue;
      }

      final milestone = _detectMilestone(pin.createdAt, now);
      if (milestone == null) continue;

      results.add(ProximityMemory(pin: pin, milestone: milestone));
    }

    // 가장 최근에 생성된 핀 우선
    results.sort((a, b) => b.pin.createdAt.compareTo(a.pin.createdAt));
    return results;
  }

  /// 마일스톤 감지 (±3일 오차 허용)
  /// null = 해당 없음
  RecapMilestone? _detectMilestone(DateTime createdAt, DateTime now) {
    final days = now.difference(createdAt).inDays;
    if (days < 25) return null; // 너무 최근

    // 1개월 (28~35일)
    if (days >= 28 && days <= 35) return RecapMilestone.oneMonth;

    // 3개월 (88~95일)
    if (days >= 88 && days <= 95) return RecapMilestone.threeMonths;

    // 6개월 (178~188일)
    if (days >= 178 && days <= 188) return RecapMilestone.sixMonths;

    // 연 단위 기념일: 창작일 기준 ±3일 이내
    final yearsSince = now.year - createdAt.year;
    for (int y = 1; y <= 10; y++) {
      if (y > yearsSince + 1) break;
      try {
        final anniversary = DateTime(
          createdAt.year + y,
          createdAt.month,
          createdAt.day,
        );
        if (now.difference(anniversary).inDays.abs() <= 3) {
          return y == 1 ? RecapMilestone.oneYear : RecapMilestone.multiYear;
        }
      } catch (_) {}
    }

    return null;
  }

  // ── Utils ──────────────────────────────────────────────────────────────────

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

  static int yearsAgo(DateTime date) => DateTime.now().year - date.year;
}
