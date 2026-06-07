import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum MapControlId { filter, globe, layer, route, meeting, friends }

const _kKey = 'map_controls_enabled';

/// 각 버튼의 표시 정보 (설정 UI용)
const mapControlMeta = <MapControlId, (IconData, String, String)>{
  MapControlId.filter:  (Icons.tune,             '필터',   '감정·날씨·동행자 필터'),
  MapControlId.globe:   (Icons.public_rounded,    '지구본', '3D 지구본 모드'),
  MapControlId.layer:   (Icons.layers_outlined,   '레이어', '지도 스타일 변경'),
  MapControlId.route:   (Icons.route_rounded,     '경로',   '핀 연결 경로 보기'),
  MapControlId.meeting: (Icons.event_rounded,     '약속',   '약속 만들기·관리'),
  MapControlId.friends: (Icons.people_rounded,    '친구',   '친구 목록 보기'),
};

class MapControlsNotifier extends StateNotifier<Set<MapControlId>> {
  MapControlsNotifier() : super(_load());

  static Set<MapControlId> _load() {
    final saved = Hive.box<dynamic>('settings').get(_kKey) as List?;
    if (saved == null) return MapControlId.values.toSet();
    return saved
        .map((e) => MapControlId.values.firstWhere(
              (v) => v.name == e,
              orElse: () => MapControlId.filter,
            ))
        .toSet();
  }

  void toggle(MapControlId id) {
    final next = {...state};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    Hive.box<dynamic>('settings')
        .put(_kKey, next.map((e) => e.name).toList());
  }
}

final mapControlsProvider =
    StateNotifierProvider<MapControlsNotifier, Set<MapControlId>>(
  (_) => MapControlsNotifier(),
);
