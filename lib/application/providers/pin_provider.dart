import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/pin_model.dart';
import '../../data/repositories/pin_repository.dart';

final pinRepositoryProvider = Provider<PinRepository>((ref) => PinRepository());

final pinsProvider = StateNotifierProvider<PinsNotifier, List<PinModel>>((ref) {
  return PinsNotifier(ref.read(pinRepositoryProvider));
});

class PinsNotifier extends StateNotifier<List<PinModel>> {
  final PinRepository _repo;

  PinsNotifier(this._repo) : super([]) {
    load();
    Future.microtask(_backfillCountryCodes);
  }

  void load() {
    state = _repo.getAll();
  }

  /// 데모용 시드 핀들을 일괄 추가. 디자인 검증 / 첫 실행 분위기 셋업에 사용.
  ///
  /// 12개 카테고리 중 5개에 핀을 심어 "수집한 핀 / 미수집 핀" 두 섹션이
  /// 모두 보이도록 함.
  Future<void> seedDemoPins() async {
    if (state.isNotEmpty) return; // 이미 있으면 덮어쓰지 않음

    final now = DateTime.now();
    final uuid = const Uuid();

    final seeds =
        <
          ({
            String shape,
            String title,
            double lat,
            double lng,
            String emotion,
            int intensity,
            int daysAgo,
          })
        >[
          (
            shape: 'cafe',
            title: '성수동 블루보틀',
            lat: 37.5447,
            lng: 127.0557,
            emotion: '좋아요',
            intensity: 5,
            daysAgo: 0,
          ),
          (
            shape: 'cafe',
            title: '연남동 작은 카페',
            lat: 37.5654,
            lng: 126.9255,
            emotion: '좋아요',
            intensity: 4,
            daysAgo: 7,
          ),
          (
            shape: 'cafe',
            title: '망원동 골목 카페',
            lat: 37.5560,
            lng: 126.9015,
            emotion: '좋아요',
            intensity: 3,
            daysAgo: 14,
          ),
          (
            shape: 'drinking',
            title: '광장시장 육회골목',
            lat: 37.5703,
            lng: 126.9999,
            emotion: '좋아요',
            intensity: 5,
            daysAgo: 1,
          ),
          (
            shape: 'drinking',
            title: '을지로 노포',
            lat: 37.5667,
            lng: 126.9919,
            emotion: '좋아요',
            intensity: 4,
            daysAgo: 4,
          ),
          (
            shape: 'shopping',
            title: '성수 콘크리트',
            lat: 37.5447,
            lng: 127.0560,
            emotion: '좋아요',
            intensity: 4,
            daysAgo: 2,
          ),
          (
            shape: 'drive',
            title: '강변북로 야경',
            lat: 37.5443,
            lng: 127.0001,
            emotion: '좋아요',
            intensity: 5,
            daysAgo: 3,
          ),
          (
            shape: 'running',
            title: '서울숲 산책로',
            lat: 37.5443,
            lng: 127.0374,
            emotion: '별로에요',
            intensity: 2,
            daysAgo: 5,
          ),
        ];

    for (final s in seeds) {
      final pin = PinModel(
        id: uuid.v4(),
        title: s.title,
        description: '',
        latitude: s.lat,
        longitude: s.lng,
        emotion: s.emotion,
        weather: '☀️ 맑음',
        companions: const [],
        intensityLevel: s.intensity,
        pinShape: s.shape,
        visibility: '🌐 전체 공개',
        photoPaths: const [],
        createdAt: now.subtract(Duration(days: s.daysAgo)),
        countryCode: 'KR',
      );
      await _repo.save(pin);
    }
    load();
  }

  /// 모든 핀을 비움 (디자인 테스트용).
  Future<void> clearAll() async {
    final all = _repo.getAll();
    for (final p in all) {
      await _repo.delete(p.id);
    }
    load();
  }

  Future<void> add(PinModel pin) async {
    await _repo.save(pin);
    load();
  }

  Future<void> update(PinModel pin) async {
    await _repo.save(pin);
    load();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    load();
  }

  // 기존 핀 중 countryCode가 비어있는 핀들을 역지오코딩으로 일괄 보정
  Future<void> _backfillCountryCodes() async {
    final missing = _repo.getAll().where((p) => p.countryCode.isEmpty).toList();
    if (missing.isEmpty) return;

    var updated = false;
    for (final pin in missing) {
      try {
        final marks = await placemarkFromCoordinates(
          pin.latitude,
          pin.longitude,
        );
        final code = marks.firstOrNull?.isoCountryCode?.toUpperCase() ?? '';
        if (code.isNotEmpty) {
          await _repo.save(pin.copyWith(countryCode: code));
          updated = true;
        }
        // geocoding API rate limit 회피
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (_) {}
    }

    if (updated && mounted) load();
  }
}

// 선택된 핀 ID
final selectedPinIdProvider = StateProvider<String?>((ref) => null);

// 필터 상태
class FilterState {
  final String emotion;
  final String visibility;

  const FilterState({this.emotion = 'all', this.visibility = 'all'});

  FilterState copyWith({String? emotion, String? visibility}) {
    return FilterState(
      emotion: emotion ?? this.emotion,
      visibility: visibility ?? this.visibility,
    );
  }
}

final filterProvider = StateNotifierProvider<FilterNotifier, FilterState>((
  ref,
) {
  return FilterNotifier();
});

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void setEmotion(String emotion) => state = state.copyWith(emotion: emotion);
  void setVisibility(String visibility) =>
      state = state.copyWith(visibility: visibility);
  void reset() => state = const FilterState();
}

// + 버튼 → 현재 위치에서 핀 생성 트리거
final triggerCreatePinProvider = StateProvider<bool>((ref) => false);

// 지도 스타일
enum MapStyleOption { standard, satellite, outdoors, dark, light, streets }

final mapStyleProvider = StateProvider<MapStyleOption>(
  (ref) => MapStyleOption.standard,
);

final filteredPinsProvider = Provider<List<PinModel>>((ref) {
  final pins = ref.watch(pinsProvider);
  final filter = ref.watch(filterProvider);

  return pins.where((pin) {
    final emotionMatch =
        filter.emotion == 'all' || pin.emotion == filter.emotion;
    final visibilityMatch =
        filter.visibility == 'all' || pin.visibility == filter.visibility;
    return emotionMatch && visibilityMatch;
  }).toList();
});
