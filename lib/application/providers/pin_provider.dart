import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/pin_model.dart';
import '../../data/repositories/pin_repository.dart';
import '../services/pin_sync_service.dart';

final pinRepositoryProvider = Provider<PinRepository>((ref) => PinRepository());

// 지구본 모드 여부 — map_screen ↔ main_shell 공유
final globeModeProvider = StateProvider<bool>((ref) => false);

final pinsProvider = StateNotifierProvider<PinsNotifier, List<PinModel>>((ref) {
  return PinsNotifier(ref.read(pinRepositoryProvider));
});

class PinsNotifier extends StateNotifier<List<PinModel>> {
  final PinRepository _repo;

  PinsNotifier(this._repo) : super([]) {
    load();
    // 로그인 상태면 Supabase에서 핀 다운로드 (서버가 primary)
    _initFromServer();
    Future.microtask(_backfillCountryCodes);
  }

  void load() {
    state = _repo.getAll();
  }

  /// Supabase에서 핀을 다운로드해 Hive에 저장 후 상태 갱신
  Future<void> loadFromServer() async {
    try {
      final serverPins = await PinSyncService.instance.downloadAll();
      await _repo.clearAll();
      for (final pin in serverPins) {
        await _repo.save(pin);
      }
      if (mounted) load();
      debugPrint('[PinSync] loaded ${serverPins.length} pins from Supabase');
    } catch (e) {
      debugPrint('[PinSync] loadFromServer error: $e');
    }
  }

  Future<void> _initFromServer() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await loadFromServer();
  }

  Future<void> add(PinModel pin) async {
    await _repo.save(pin);
    load();
    PinSyncService.instance.uploadPin(pin).ignore();
  }

  Future<void> update(PinModel pin) async {
    await _repo.save(pin);
    load();
    PinSyncService.instance.uploadPin(pin).ignore();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    load();
    PinSyncService.instance.deletePin(id).ignore();
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
  final String pinShape;

  const FilterState({this.emotion = 'all', this.visibility = 'all', this.pinShape = 'all'});

  FilterState copyWith({String? emotion, String? visibility, String? pinShape}) {
    return FilterState(
      emotion: emotion ?? this.emotion,
      visibility: visibility ?? this.visibility,
      pinShape: pinShape ?? this.pinShape,
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
  void setVisibility(String visibility) => state = state.copyWith(visibility: visibility);
  void setPinShape(String pinShape) => state = state.copyWith(pinShape: pinShape);
  void reset() => state = const FilterState();
}

// + 버튼 → 현재 위치에서 핀 생성 트리거
final triggerCreatePinProvider = StateProvider<bool>((ref) => false);

// 지도 스타일
enum MapStyleOption { auto, standard, satellite, outdoors, dark, light, streets }

final mapStyleProvider = StateProvider<MapStyleOption>(
  (ref) => MapStyleOption.standard,
);

final filteredPinsProvider = Provider<List<PinModel>>((ref) {
  final pins = ref.watch(pinsProvider);
  final filter = ref.watch(filterProvider);

  return pins.where((pin) {
    final emotionMatch = filter.emotion == 'all' || pin.emotion == filter.emotion;
    final visibilityMatch = filter.visibility == 'all' || pin.visibility == filter.visibility;
    final shapeMatch = filter.pinShape == 'all' || pin.pinShape == filter.pinShape;
    return emotionMatch && visibilityMatch && shapeMatch;
  }).toList();
});
