import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

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
        final marks = await placemarkFromCoordinates(pin.latitude, pin.longitude);
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
enum MapStyleOption { standard, satellite, outdoors, dark }

final mapStyleProvider =
    StateProvider<MapStyleOption>((ref) => MapStyleOption.standard);

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
