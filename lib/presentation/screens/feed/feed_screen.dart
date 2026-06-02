import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';

// AppColors.primary/accent → 앱 테마 색상으로 동적 매핑
Color _resolveColor(Color defined, BuildContext context) {
  if (defined.toARGB32() == AppColors.primary.toARGB32()) {
    return context.primaryColor;
  }
  if (defined.toARGB32() == AppColors.accent.toARGB32()) {
    return context.primaryLightColor;
  }
  return defined;
}

// ─── 뱃지 모델 ────────────────────────────────────────────────────────────────

class _BadgeDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(List<PinModel> pins) earned;

  const _BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });
}

// ─── 종목 마일스톤 모델 ──────────────────────────────────────────────────────────

class _CatMilestone {
  final String id;
  final String category;
  final String name;
  final String description;
  final int requiredCount;
  final Color color;
  final IconData icon;

  const _CatMilestone({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.requiredCount,
    required this.color,
    required this.icon,
  });

  bool earned(List<PinModel> pins) =>
      pins.where((p) => p.pinShape == category).length >= requiredCount;
}

const _catMilestones = <_CatMilestone>[
  // ── 런닝 ────────────────────────────────────────────────────────────────────
  _CatMilestone(
    id: 'run_tier1',
    category: 'running',
    name: '첫 런닝',
    description: '런닝 1회 기록',
    requiredCount: 1,
    color: Color(0xFF4CAF50),
    icon: Icons.directions_run_rounded,
  ),
  _CatMilestone(
    id: 'run_tier2',
    category: 'running',
    name: '5km 돌파',
    description: '런닝 5회 기록',
    requiredCount: 5,
    color: Color(0xFF2E7D32),
    icon: Icons.directions_run_rounded,
  ),
  _CatMilestone(
    id: 'run_tier3',
    category: 'running',
    name: '하프 마라토너',
    description: '런닝 15회 기록',
    requiredCount: 15,
    color: Color(0xFF1B5E20),
    icon: Icons.directions_run_rounded,
  ),
  _CatMilestone(
    id: 'run_tier4',
    category: 'running',
    name: '울트라 러너',
    description: '런닝 30회 기록',
    requiredCount: 30,
    color: Color(0xFF004D00),
    icon: Icons.directions_run_rounded,
  ),

  // ── 산책 ────────────────────────────────────────────────────────────────────
  _CatMilestone(
    id: 'walk_tier1',
    category: 'walk',
    name: '동네 첫 산책',
    description: '산책 1회 기록',
    requiredCount: 1,
    color: Color(0xFF8BC34A),
    icon: Icons.nature_people_rounded,
  ),
  _CatMilestone(
    id: 'walk_tier2',
    category: 'walk',
    name: '동네 탐험가',
    description: '산책 5회 기록',
    requiredCount: 5,
    color: Color(0xFF558B2F),
    icon: Icons.nature_people_rounded,
  ),
  _CatMilestone(
    id: 'walk_tier3',
    category: 'walk',
    name: '만보 생활자',
    description: '산책 15회 기록',
    requiredCount: 15,
    color: Color(0xFF33691E),
    icon: Icons.nature_people_rounded,
  ),
  _CatMilestone(
    id: 'walk_tier4',
    category: 'walk',
    name: '걷는 사람',
    description: '산책 30회 기록',
    requiredCount: 30,
    color: Color(0xFF1B5E20),
    icon: Icons.nature_people_rounded,
  ),

  // ── 운동 ────────────────────────────────────────────────────────────────────
  _CatMilestone(
    id: 'gym_tier1',
    category: 'gym',
    name: '헬스 입문',
    description: '운동 1회 기록',
    requiredCount: 1,
    color: Color(0xFFEF5350),
    icon: Icons.fitness_center_rounded,
  ),
  _CatMilestone(
    id: 'gym_tier2',
    category: 'gym',
    name: '3일은 해봤어',
    description: '운동 5회 기록',
    requiredCount: 5,
    color: Color(0xFFC62828),
    icon: Icons.fitness_center_rounded,
  ),
  _CatMilestone(
    id: 'gym_tier3',
    category: 'gym',
    name: '근육의 고통',
    description: '운동 15회 기록',
    requiredCount: 15,
    color: Color(0xFFB71C1C),
    icon: Icons.fitness_center_rounded,
  ),
  _CatMilestone(
    id: 'gym_tier4',
    category: 'gym',
    name: '자기관리 완성',
    description: '운동 30회 기록',
    requiredCount: 30,
    color: Color(0xFF7F0000),
    icon: Icons.fitness_center_rounded,
  ),

  // ── 여행 ────────────────────────────────────────────────────────────────────
  _CatMilestone(
    id: 'travel_tier1',
    category: 'travel',
    name: '첫 여행 기록',
    description: '여행 1회 기록',
    requiredCount: 1,
    color: Color(0xFF42A5F5),
    icon: Icons.flight_rounded,
  ),
  _CatMilestone(
    id: 'travel_tier2',
    category: 'travel',
    name: '여행자',
    description: '여행 5회 기록',
    requiredCount: 5,
    color: Color(0xFF1565C0),
    icon: Icons.flight_rounded,
  ),
  _CatMilestone(
    id: 'travel_tier3',
    category: 'travel',
    name: '여행 중독자',
    description: '여행 15회 기록',
    requiredCount: 15,
    color: Color(0xFF0D47A1),
    icon: Icons.flight_rounded,
  ),
  _CatMilestone(
    id: 'travel_tier4',
    category: 'travel',
    name: '떠돌이',
    description: '여행 30회 기록',
    requiredCount: 30,
    color: Color(0xFF002171),
    icon: Icons.flight_rounded,
  ),

  // ── 축구 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'soccer_tier1', category: 'soccer', name: '첫 킥오프', description: '축구 1회 기록', requiredCount: 1, color: Color(0xFF43A047), icon: Icons.sports_soccer_rounded),
  _CatMilestone(id: 'soccer_tier2', category: 'soccer', name: '주말 리거', description: '축구 5회 기록', requiredCount: 5, color: Color(0xFF2E7D32), icon: Icons.sports_soccer_rounded),
  _CatMilestone(id: 'soccer_tier3', category: 'soccer', name: '필드의 지배자', description: '축구 15회 기록', requiredCount: 15, color: Color(0xFF1B5E20), icon: Icons.sports_soccer_rounded),
  _CatMilestone(id: 'soccer_tier4', category: 'soccer', name: '축구 중독', description: '축구 30회 기록', requiredCount: 30, color: Color(0xFF004D00), icon: Icons.sports_soccer_rounded),

  // ── 농구 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'bball_tier1', category: 'basketball', name: '첫 골인', description: '농구 1회 기록', requiredCount: 1, color: Color(0xFFE65100), icon: Icons.sports_basketball_rounded),
  _CatMilestone(id: 'bball_tier2', category: 'basketball', name: '코트의 신입', description: '농구 5회 기록', requiredCount: 5, color: Color(0xFFBF360C), icon: Icons.sports_basketball_rounded),
  _CatMilestone(id: 'bball_tier3', category: 'basketball', name: '농구 마니아', description: '농구 15회 기록', requiredCount: 15, color: Color(0xFF8D1A00), icon: Icons.sports_basketball_rounded),
  _CatMilestone(id: 'bball_tier4', category: 'basketball', name: '코트의 지배자', description: '농구 30회 기록', requiredCount: 30, color: Color(0xFF5C1100), icon: Icons.sports_basketball_rounded),

  // ── 야구 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'base_tier1', category: 'baseball', name: '시구 완료', description: '야구 1회 기록', requiredCount: 1, color: Color(0xFFD32F2F), icon: Icons.sports_baseball_rounded),
  _CatMilestone(id: 'base_tier2', category: 'baseball', name: '다이아몬드 입문', description: '야구 5회 기록', requiredCount: 5, color: Color(0xFFC62828), icon: Icons.sports_baseball_rounded),
  _CatMilestone(id: 'base_tier3', category: 'baseball', name: '홈런 예고', description: '야구 15회 기록', requiredCount: 15, color: Color(0xFFB71C1C), icon: Icons.sports_baseball_rounded),
  _CatMilestone(id: 'base_tier4', category: 'baseball', name: '야구장 단골', description: '야구 30회 기록', requiredCount: 30, color: Color(0xFF7F0000), icon: Icons.sports_baseball_rounded),

  // ── 카페 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'cafe_tier1', category: 'cafe', name: '첫 카페 체크인', description: '카페 1회 기록', requiredCount: 1, color: Color(0xFF8B5E3C), icon: Icons.local_cafe_rounded),
  _CatMilestone(id: 'cafe_tier2', category: 'cafe', name: '카페 단골', description: '카페 10회 기록', requiredCount: 10, color: Color(0xFF6D4C41), icon: Icons.local_cafe_rounded),
  _CatMilestone(id: 'cafe_tier3', category: 'cafe', name: '카페인 의존자', description: '카페 30회 기록', requiredCount: 30, color: Color(0xFF5D4037), icon: Icons.local_cafe_rounded),
  _CatMilestone(id: 'cafe_tier4', category: 'cafe', name: '카페 마스터', description: '카페 50회 기록', requiredCount: 50, color: Color(0xFF4E342E), icon: Icons.local_cafe_rounded),

  // ── 술자리 ──────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'drink_tier1', category: 'drinking', name: '건배!', description: '술자리 1회 기록', requiredCount: 1, color: Color(0xFFE8962E), icon: Icons.sports_bar_rounded),
  _CatMilestone(id: 'drink_tier2', category: 'drinking', name: '소맥 달인', description: '술자리 5회 기록', requiredCount: 5, color: Color(0xFFE65100), icon: Icons.sports_bar_rounded),
  _CatMilestone(id: 'drink_tier3', category: 'drinking', name: '술이 밥이라면', description: '술자리 10회 기록', requiredCount: 10, color: Color(0xFFBF360C), icon: Icons.sports_bar_rounded),
  _CatMilestone(id: 'drink_tier4', category: 'drinking', name: '주량 전설', description: '술자리 20회 기록', requiredCount: 20, color: Color(0xFF8D1A00), icon: Icons.sports_bar_rounded),

  // ── 쇼핑 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'shop_tier1', category: 'shopping', name: '첫 장바구니', description: '쇼핑 1회 기록', requiredCount: 1, color: Color(0xFFE91E8C), icon: Icons.shopping_bag_rounded),
  _CatMilestone(id: 'shop_tier2', category: 'shopping', name: '쇼핑 취미인', description: '쇼핑 5회 기록', requiredCount: 5, color: Color(0xFFC2185B), icon: Icons.shopping_bag_rounded),
  _CatMilestone(id: 'shop_tier3', category: 'shopping', name: '텅장 전문가', description: '쇼핑 15회 기록', requiredCount: 15, color: Color(0xFF880E4F), icon: Icons.shopping_bag_rounded),
  _CatMilestone(id: 'shop_tier4', category: 'shopping', name: '쇼핑 중독자', description: '쇼핑 30회 기록', requiredCount: 30, color: Color(0xFF560027), icon: Icons.shopping_bag_rounded),

  // ── 드라이브 ────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'drive_tier1', category: 'drive', name: '시동 ON', description: '드라이브 1회 기록', requiredCount: 1, color: Color(0xFF1976D2), icon: Icons.directions_car_rounded),
  _CatMilestone(id: 'drive_tier2', category: 'drive', name: '주말 드라이버', description: '드라이브 5회 기록', requiredCount: 5, color: Color(0xFF1565C0), icon: Icons.directions_car_rounded),
  _CatMilestone(id: 'drive_tier3', category: 'drive', name: '로드트립 마니아', description: '드라이브 15회 기록', requiredCount: 15, color: Color(0xFF0D47A1), icon: Icons.directions_car_rounded),
  _CatMilestone(id: 'drive_tier4', category: 'drive', name: '도로 위의 자유인', description: '드라이브 30회 기록', requiredCount: 30, color: Color(0xFF002171), icon: Icons.directions_car_rounded),

  // ── 독서 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'read_tier1', category: 'reading', name: '책장 입장', description: '독서 1회 기록', requiredCount: 1, color: Color(0xFF7B1FA2), icon: Icons.menu_book_rounded),
  _CatMilestone(id: 'read_tier2', category: 'reading', name: '활자 중독', description: '독서 5회 기록', requiredCount: 5, color: Color(0xFF6A1B9A), icon: Icons.menu_book_rounded),
  _CatMilestone(id: 'read_tier3', category: 'reading', name: '책 덕후', description: '독서 15회 기록', requiredCount: 15, color: Color(0xFF4A148C), icon: Icons.menu_book_rounded),
  _CatMilestone(id: 'read_tier4', category: 'reading', name: '살아있는 도서관', description: '독서 30회 기록', requiredCount: 30, color: Color(0xFF2D0065), icon: Icons.menu_book_rounded),

  // ── 자기개발 ────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'self_tier1', category: 'selfdev', name: '성장의 시작', description: '자기개발 1회 기록', requiredCount: 1, color: Color(0xFF6A1B9A), icon: Icons.psychology_rounded),
  _CatMilestone(id: 'self_tier2', category: 'selfdev', name: '진취적 인간', description: '자기개발 5회 기록', requiredCount: 5, color: Color(0xFF4A148C), icon: Icons.psychology_rounded),
  _CatMilestone(id: 'self_tier3', category: 'selfdev', name: '자기계발 덕후', description: '자기개발 15회 기록', requiredCount: 15, color: Color(0xFF38006B), icon: Icons.psychology_rounded),
  _CatMilestone(id: 'self_tier4', category: 'selfdev', name: '내 일 한번 저질러보겠소', description: '자기개발 30회 기록', requiredCount: 30, color: Color(0xFF220038), icon: Icons.psychology_rounded),

  // ── 오락 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'game_tier1', category: 'game', name: '1P 입장', description: '오락 1회 기록', requiredCount: 1, color: Color(0xFF1565C0), icon: Icons.sports_esports_rounded),
  _CatMilestone(id: 'game_tier2', category: 'game', name: '인싸 게이머', description: '오락 5회 기록', requiredCount: 5, color: Color(0xFF0D47A1), icon: Icons.sports_esports_rounded),
  _CatMilestone(id: 'game_tier3', category: 'game', name: '게임 광', description: '오락 15회 기록', requiredCount: 15, color: Color(0xFF002171), icon: Icons.sports_esports_rounded),
  _CatMilestone(id: 'game_tier4', category: 'game', name: '전설의 레이더', description: '오락 30회 기록', requiredCount: 30, color: Color(0xFF00007F), icon: Icons.sports_esports_rounded),

  // ── 자연 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'nature_tier1', category: 'nature', name: '자연인 입문', description: '자연 1회 기록', requiredCount: 1, color: Color(0xFF388E3C), icon: Icons.park_rounded),
  _CatMilestone(id: 'nature_tier2', category: 'nature', name: '숲속의 사람', description: '자연 5회 기록', requiredCount: 5, color: Color(0xFF2E7D32), icon: Icons.park_rounded),
  _CatMilestone(id: 'nature_tier3', category: 'nature', name: '자연 탐험가', description: '자연 15회 기록', requiredCount: 15, color: Color(0xFF1B5E20), icon: Icons.park_rounded),
  _CatMilestone(id: 'nature_tier4', category: 'nature', name: '자연의 화신', description: '자연 30회 기록', requiredCount: 30, color: Color(0xFF004D00), icon: Icons.park_rounded),

  // ── 사진 ────────────────────────────────────────────────────────────────────
  _CatMilestone(id: 'photo_tier1', category: 'photo', name: '셔터 누름', description: '사진 1회 기록', requiredCount: 1, color: Color(0xFF00838F), icon: Icons.camera_alt_rounded),
  _CatMilestone(id: 'photo_tier2', category: 'photo', name: '감성 사진가', description: '사진 5회 기록', requiredCount: 5, color: Color(0xFF00695C), icon: Icons.camera_alt_rounded),
  _CatMilestone(id: 'photo_tier3', category: 'photo', name: '필름 덕후', description: '사진 15회 기록', requiredCount: 15, color: Color(0xFF004D40), icon: Icons.camera_alt_rounded),
  _CatMilestone(id: 'photo_tier4', category: 'photo', name: '사진 아티스트', description: '사진 30회 기록', requiredCount: 30, color: Color(0xFF002520), icon: Icons.camera_alt_rounded),
];

// ─── 종목 카드 정의 ──────────────────────────────────────────────────────────────

class _CatTrackDef {
  final String category;
  final String label;
  final IconData icon;
  final Color color;
  const _CatTrackDef({required this.category, required this.label, required this.icon, required this.color});
}

const _catTrackDefs = <_CatTrackDef>[
  _CatTrackDef(category: 'running',    label: '런닝',    icon: Icons.directions_run_rounded,  color: Color(0xFF4CAF50)),
  _CatTrackDef(category: 'walk',       label: '산책',    icon: Icons.nature_people_rounded,   color: Color(0xFF8BC34A)),
  _CatTrackDef(category: 'gym',        label: '운동',    icon: Icons.fitness_center_rounded,  color: Color(0xFFEF5350)),
  _CatTrackDef(category: 'travel',     label: '여행',    icon: Icons.flight_rounded,          color: Color(0xFF42A5F5)),
  _CatTrackDef(category: 'soccer',     label: '축구',    icon: Icons.sports_soccer_rounded,   color: Color(0xFF43A047)),
  _CatTrackDef(category: 'basketball', label: '농구',    icon: Icons.sports_basketball_rounded, color: Color(0xFFE65100)),
  _CatTrackDef(category: 'baseball',   label: '야구',    icon: Icons.sports_baseball_rounded, color: Color(0xFFD32F2F)),
  _CatTrackDef(category: 'cafe',       label: '카페',    icon: Icons.local_cafe_rounded,      color: Color(0xFF8B5E3C)),
  _CatTrackDef(category: 'drinking',   label: '술자리',  icon: Icons.sports_bar_rounded,      color: Color(0xFFE8962E)),
  _CatTrackDef(category: 'shopping',   label: '쇼핑',    icon: Icons.shopping_bag_rounded,    color: Color(0xFFE91E8C)),
  _CatTrackDef(category: 'drive',      label: '드라이브', icon: Icons.directions_car_rounded,  color: Color(0xFF1976D2)),
  _CatTrackDef(category: 'reading',    label: '독서',    icon: Icons.menu_book_rounded,       color: Color(0xFF7B1FA2)),
  _CatTrackDef(category: 'selfdev',    label: '자기개발', icon: Icons.psychology_rounded,      color: Color(0xFF6A1B9A)),
  _CatTrackDef(category: 'game',       label: '오락',    icon: Icons.sports_esports_rounded,  color: Color(0xFF1565C0)),
  _CatTrackDef(category: 'nature',     label: '자연',    icon: Icons.park_rounded,            color: Color(0xFF388E3C)),
  _CatTrackDef(category: 'photo',      label: '사진',    icon: Icons.camera_alt_rounded,      color: Color(0xFF00838F)),
];

// ─── 칭호 모델 ────────────────────────────────────────────────────────────────

class _TitleDef {
  final String title;
  final String subtitle;
  final int minPins;
  final Color color;

  const _TitleDef({
    required this.title,
    required this.subtitle,
    required this.minPins,
    required this.color,
  });
}

// ─── 정의 목록 ────────────────────────────────────────────────────────────────

final _badges = <_BadgeDef>[
  // ── 카테고리 뱃지 ──────────────────────────────────────────────────────────
  _BadgeDef(
    id: 'cafe_addict',
    name: '카페 못 가면 일상생활 불가',
    description: '카페 기록 5회 이상',
    icon: Icons.local_cafe_rounded,
    color: const Color(0xFF8B5E3C),
    earned: (p) => p.where((pin) => pin.pinShape == 'cafe').length >= 5,
  ),
  _BadgeDef(
    id: 'drinking_pro',
    name: '술이 보약, 이론 말고 실천',
    description: '술자리 기록 5회 이상',
    icon: Icons.sports_bar_rounded,
    color: const Color(0xFFE8962E),
    earned: (p) => p.where((pin) => pin.pinShape == 'drinking').length >= 5,
  ),
  _BadgeDef(
    id: 'shopping_lover',
    name: '텅장이 부른다',
    description: '쇼핑 기록 5회 이상',
    icon: Icons.shopping_bag_rounded,
    color: const Color(0xFFE91E8C),
    earned: (p) => p.where((pin) => pin.pinShape == 'shopping').length >= 5,
  ),
  _BadgeDef(
    id: 'driver',
    name: '도로 위의 자유인',
    description: '드라이브 기록 5회 이상',
    icon: Icons.directions_car_rounded,
    color: AppColors.blue,
    earned: (p) => p.where((pin) => pin.pinShape == 'drive').length >= 5,
  ),
  _BadgeDef(
    id: 'runner',
    name: '전생에 이봉주',
    description: '런닝 기록 5회 이상',
    icon: Icons.directions_run_rounded,
    color: const Color(0xFF4CAF50),
    earned: (p) => p.where((pin) => pin.pinShape == 'running').length >= 5,
  ),
  _BadgeDef(
    id: 'gym_rat',
    name: '자기 관리 시작',
    description: '운동 기록 5회 이상',
    icon: Icons.fitness_center_rounded,
    color: AppColors.danger,
    earned: (p) => p.where((pin) => pin.pinShape == 'gym').length >= 5,
  ),
  _BadgeDef(
    id: 'soccer_king',
    name: '축린이',
    description: '축구 기록 5회 이상',
    icon: Icons.sports_soccer_rounded,
    color: const Color(0xFF43A047),
    earned: (p) => p.where((pin) => pin.pinShape == 'soccer').length >= 5,
  ),
  _BadgeDef(
    id: 'basketball_king',
    name: '코트의 지배자',
    description: '농구 기록 5회 이상',
    icon: Icons.sports_basketball_rounded,
    color: const Color(0xFFE65100),
    earned: (p) => p.where((pin) => pin.pinShape == 'basketball').length >= 5,
  ),
  _BadgeDef(
    id: 'bookworm',
    name: '책 덮으면 기억 안 나지만',
    description: '독서 기록 5회 이상',
    icon: Icons.menu_book_rounded,
    color: AppColors.primary,
    earned: (p) => p.where((pin) => pin.pinShape == 'reading').length >= 5,
  ),
  _BadgeDef(
    id: 'self_dev_addict',
    name: '내 일 한번 저질러보겠소',
    description: '자기개발 기록 5회 이상',
    icon: Icons.psychology_rounded,
    color: const Color(0xFF7B1FA2),
    earned: (p) => p.where((pin) => pin.pinShape == 'selfdev').length >= 5,
  ),
  _BadgeDef(
    id: 'gamer',
    name: '게임 광',
    description: '오락 기록 5회 이상',
    icon: Icons.sports_esports_rounded,
    color: const Color(0xFF1565C0),
    earned: (p) => p.where((pin) => pin.pinShape == 'game').length >= 5,
  ),
  _BadgeDef(
    id: 'tech_freak',
    name: '언박싱이 취미인 사람',
    description: '전자기기 기록 5회 이상',
    icon: Icons.devices_rounded,
    color: AppColors.blue,
    earned: (p) => p.where((pin) => pin.pinShape == 'tech').length >= 5,
  ),

  // ── 마일스톤 뱃지 ──────────────────────────────────────────────────────────
  _BadgeDef(
    id: 'first_pin',
    name: '기록의 시작',
    description: '처음으로 핀을 심었어요',
    icon: Icons.flag_rounded,
    color: AppColors.primary,
    earned: (p) => p.isNotEmpty,
  ),
  _BadgeDef(
    id: 'five_pins',
    name: '이제 좀 된다',
    description: '기록 5개 달성',
    icon: Icons.looks_5_rounded,
    color: AppColors.blue,
    earned: (p) => p.length >= 5,
  ),
  _BadgeDef(
    id: 'fifteen_pins',
    name: '진심인 사람',
    description: '기록 15개 달성',
    icon: Icons.emoji_events_rounded,
    color: AppColors.accent,
    earned: (p) => p.length >= 15,
  ),
  _BadgeDef(
    id: 'thirty_pins',
    name: '기록 중독자',
    description: '기록 30개 달성',
    icon: Icons.workspace_premium_rounded,
    color: AppColors.danger,
    earned: (p) => p.length >= 30,
  ),
  _BadgeDef(
    id: 'intense_moment',
    name: '감동의 도가니',
    description: '감동 강도 5점 기록 3회 이상',
    icon: Icons.star_rounded,
    color: AppColors.accent,
    earned: (p) => p.where((pin) => pin.intensityLevel == 5).length >= 3,
  ),
  _BadgeDef(
    id: 'lone_wolf',
    name: '고독한 미식가',
    description: '혼자 기록한 활동 5회 이상',
    icon: Icons.person_rounded,
    color: AppColors.primary,
    earned: (p) => p.where((pin) => pin.companions.isEmpty).length >= 5,
  ),
  _BadgeDef(
    id: 'social_butterfly',
    name: '혼자는 재미없어',
    description: '동행자와 함께한 기록 5회 이상',
    icon: Icons.group_rounded,
    color: AppColors.blue,
    earned: (p) => p.where((pin) => pin.companions.isNotEmpty).length >= 5,
  ),
  _BadgeDef(
    id: 'all_weather',
    name: '천재지변이 와도 기록은 한다',
    description: '3가지 이상 날씨에서 활동',
    icon: Icons.wb_cloudy_rounded,
    color: AppColors.blue,
    earned: (p) => p.map((pin) => pin.weather).toSet().length >= 3,
  ),
  _BadgeDef(
    id: 'four_seasons',
    name: '사계절 챌린저',
    description: '봄·여름·가을·겨울 모두 기록',
    icon: Icons.ac_unit_rounded,
    color: AppColors.primary,
    earned: (p) {
      final months = p.map((pin) => pin.createdAt.month).toSet();
      final spring = months.any((m) => m >= 3 && m <= 5);
      final summer = months.any((m) => m >= 6 && m <= 8);
      final fall = months.any((m) => m >= 9 && m <= 11);
      final winter = months.any((m) => m == 12 || m <= 2);
      return spring && summer && fall && winter;
    },
  ),
  _BadgeDef(
    id: 'thirty_days',
    name: '30일 생존 기념',
    description: '첫 기록으로부터 30일 이상 경과',
    icon: Icons.military_tech_rounded,
    color: AppColors.accent,
    earned: (p) {
      if (p.isEmpty) return false;
      final first = p.reduce(
        (a, b) => a.createdAt.isBefore(b.createdAt) ? a : b,
      );
      return DateTime.now().difference(first.createdAt).inDays >= 30;
    },
  ),
  _BadgeDef(
    id: 'weekend_warrior',
    name: '주말의 왕',
    description: '주말(토·일) 기록 5회 이상',
    icon: Icons.weekend_rounded,
    color: AppColors.primary,
    earned: (p) =>
        p
            .where(
              (pin) =>
                  pin.createdAt.weekday == DateTime.saturday ||
                  pin.createdAt.weekday == DateTime.sunday,
            )
            .length >=
        5,
  ),
];

const _titles = <_TitleDef>[
  _TitleDef(
    title: '핀 초보',
    subtitle: '아직 지도가 비어있어요. 첫 핀을 심어볼까요?',
    minPins: 0,
    color: AppColors.greyPale,
  ),
  _TitleDef(
    title: '일상 탐색가',
    subtitle: '조금씩 기록이 쌓이고 있어요',
    minPins: 5,
    color: AppColors.blue,
  ),
  _TitleDef(
    title: '기록 마니아',
    subtitle: '이 정도면 진심인 거 맞죠?',
    minPins: 15,
    color: AppColors.primary,
  ),
  _TitleDef(
    title: '라이프 큐레이터',
    subtitle: '나만의 지도가 완성되어 가고 있어요',
    minPins: 30,
    color: AppColors.accent,
  ),
  _TitleDef(
    title: '핀 레전드',
    subtitle: '이 지도는 완전히 당신의 이야기예요',
    minPins: 60,
    color: AppColors.danger,
  ),
];

_TitleDef _currentTitle(int pinCount) {
  _TitleDef result = _titles.first;
  for (final t in _titles) {
    if (pinCount >= t.minPins) result = t;
  }
  return result;
}

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _sc = [ScrollController(), ScrollController()];

  static const _collapseRange = 100.0;

  double get _t {
    final idx = _tabController.index.clamp(0, 1);
    final c = _sc[idx];
    if (!c.hasClients) return 0.0;
    return (c.offset / _collapseRange).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    for (final c in _sc) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _sc) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(pinsProvider);
    final earnedBadges = _badges.where((b) => b.earned(pins)).toList();
    final currentTitle = _currentTitle(pins.length);
    final nextTitle = _titles.firstWhere(
      (t) => t.minPins > pins.length,
      orElse: () => _titles.last,
    );
    final toNext = nextTitle.minPins > pins.length
        ? nextTitle.minPins - pins.length
        : 0;

    final Map<String, int> pinCountByShape = {};
    for (final shape in AppConstants.pinShapes) {
      pinCountByShape[shape] = pins.where((p) => p.pinShape == shape).length;
    }
    final unlockedCount = pinCountByShape.values.where((c) => c > 0).length;

    final t = _t;
    final topPad = MediaQuery.of(context).padding.top;

    // 큰 타이틀: 0→70% 구간에서 페이드아웃
    final largeOp =
        1.0 - Curves.easeInCubic.transform((t / 0.70).clamp(0.0, 1.0));
    // 작은 타이틀: 55→100% 구간에서 페이드인
    final smallOp = Curves.easeOutCubic.transform(
      ((t - 0.55) / 0.45).clamp(0.0, 1.0),
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 safe area
              SizedBox(height: topPad),
              // 작은 타이틀 (고정 44px, 스크롤 시 페이드인)
              SizedBox(
                height: 44,
                child: Center(
                  child: Opacity(
                    opacity: smallOp,
                    child: Text(
                      '수집 도감',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.labelColor,
                      ),
                    ),
                  ),
                ),
              ),
              // 큰 타이틀 영역 (높이가 줄어듦)
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  heightFactor: 1.0 - t,
                  child: Opacity(
                    opacity: largeOp,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '수집 도감',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: context.labelColor,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '나의 순간들을 모아보세요',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.labelColor.withValues(alpha: 0.38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 탭바 (고정)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _TabBar(controller: _tabController),
              ),
              // 콘텐츠
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PinDogamTab(
                      pinCountByShape: pinCountByShape,
                      unlockedCount: unlockedCount,
                      totalCount: AppConstants.pinShapes.length,
                      controller: _sc[0],
                    ),
                    _BadgeDogamTab(
                      pins: pins,
                      earnedBadges: earnedBadges,
                      currentTitle: currentTitle,
                      nextTitle: nextTitle,
                      toNext: toNext,
                      controller: _sc[1],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 하단 페이드
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.bgColor.withValues(alpha: 0),
                      context.bgColor.withValues(alpha: 0.92),
                      context.bgColor,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 커스텀 탭바 ──────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabChip(
            icon: Icons.location_on_rounded,
            label: '핀 도감',
            isActive: controller.index == 0,
            onTap: () => controller.animateTo(0),
          ),
          _TabChip(
            icon: Icons.military_tech_rounded,
            label: '칭호 도감',
            isActive: controller.index == 1,
            onTap: () => controller.animateTo(1),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    // 선택된 탭: 라이트모드=흰 카드 + 그림자, 다크모드=밝은 다크 카드 + 그림자
    final activeCardColor = isDark ? AppColors.surface : Colors.white;
    final activeTextColor = isDark ? Colors.white : AppColors.dark;
    final inactiveTextColor = context.subLabelColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isActive ? activeCardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.10,
                      ),
                      blurRadius: 10,
                      offset: const Offset(3, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey(isActive),
                    size: 14,
                    color: isActive ? activeTextColor : inactiveTextColor,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? activeTextColor : inactiveTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 핀 도감 탭 ───────────────────────────────────────────────────────────────

class _PinDogamTab extends StatelessWidget {
  final Map<String, int> pinCountByShape;
  final int unlockedCount;
  final int totalCount;
  final ScrollController controller;

  const _PinDogamTab({
    required this.pinCountByShape,
    required this.unlockedCount,
    required this.totalCount,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── 수집 현황 헤더 ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  '$unlockedCount / $totalCount 수집',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.subLabelColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(unlockedCount / totalCount * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 전체 도감 컨테이너 (카드 하나로) ───────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.88,
                ),
                itemCount: AppConstants.pinShapes.length,
                itemBuilder: (context, i) {
                  final shape = AppConstants.pinShapes[i];
                  final count = pinCountByShape[shape] ?? 0;
                  final unlocked = count > 0;
                  final svgPath = AppConstants.pinShapeSvgs[shape] ?? '';
                  final name = AppConstants.pinShapeNames[shape] ?? shape;
                  return _PinCategoryItem(
                    svgPath: svgPath,
                    name: name,
                    count: count,
                    unlocked: unlocked,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 핀 카테고리 아이템 (컨테이너 없이, 전체 그리드가 하나의 카드) ──────────

class _PinCategoryItem extends StatelessWidget {
  final String svgPath;
  final String name;
  final int count;
  final bool unlocked;

  const _PinCategoryItem({
    required this.svgPath,
    required this.name,
    required this.count,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            children: [
              // 원형 배경 + 아이콘
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? (context.isDark
                            ? const Color(0xFF2D2D2D)
                            : Colors.white)
                      : Colors.white.withValues(alpha: 0.60),
                  border: Border.all(
                    color: unlocked
                        ? context.primaryColor
                        : Colors.black.withValues(alpha: 0.10),
                    width: unlocked ? 2.5 : 1.2,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: context.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: svgPath.isNotEmpty
                      ? Opacity(
                          opacity: unlocked ? 1.0 : 0.25,
                          child: SvgPicture.asset(
                            svgPath,
                            width: 30,
                            height: 30,
                          ),
                        )
                      : const Icon(
                          Icons.place_rounded,
                          size: 28,
                          color: Color(0xFFFFCC00),
                        ),
                ),
              ),
              // 잠금 배지 (우하단)
              if (!unlocked)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: unlocked ? context.labelColor : AppColors.grey,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          unlocked ? '$count곳' : '미수집',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: unlocked ? context.primaryColor : AppColors.greyPale,
          ),
        ),
      ],
    );
  }
}

// ─── 뱃지 도감 탭 ─────────────────────────────────────────────────────────────

class _BadgeDogamTab extends StatefulWidget {
  final List<PinModel> pins;
  final List<_BadgeDef> earnedBadges;
  final _TitleDef currentTitle;
  final _TitleDef nextTitle;
  final int toNext;
  final ScrollController controller;

  const _BadgeDogamTab({
    required this.pins,
    required this.earnedBadges,
    required this.currentTitle,
    required this.nextTitle,
    required this.toNext,
    required this.controller,
  });

  @override
  State<_BadgeDogamTab> createState() => _BadgeDogamTabState();
}

class _BadgeDogamTabState extends State<_BadgeDogamTab> {
  bool _catExpanded = false;

  void _showDetail(BuildContext context, _BadgeDef badge, bool earned) {
    showAppSheet<void>(
      context,
      builder: (_) => _BadgeDetailSheet(badge: badge, earned: earned),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    final earnedBadges = widget.earnedBadges;
    final lockedBadges = _badges.where((b) => !b.earned(pins)).toList();

    int catCount(String cat) => pins.where((p) => p.pinShape == cat).length;

    const primaryCount = 4;
    final primaryDefs = _catTrackDefs.take(primaryCount).toList();
    final extraDefs   = _catTrackDefs.skip(primaryCount).toList();

    return CustomScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TitleCard(
              titleDef: widget.currentTitle,
              nextTitle: widget.toNext > 0 ? widget.nextTitle : null,
              toNext: widget.toNext,
              pinCount: pins.length,
            ),
          ),
        ),

        // ── 종목 기록 ────────────────────────────────────────────────────────
        _SectionHeader(label: '종목 기록', count: null),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // 기본 4개
                ...primaryDefs.map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CatTrackCard(
                    label: def.label,
                    icon: def.icon,
                    color: def.color,
                    count: catCount(def.category),
                    milestones: _catMilestones.where((m) => m.category == def.category).toList(),
                  ),
                )),
                // 더보기 — AnimatedSize로 부드럽게 확장
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _catExpanded
                      ? Column(
                          children: extraDefs.map((def) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CatTrackCard(
                              label: def.label,
                              icon: def.icon,
                              color: def.color,
                              count: catCount(def.category),
                              milestones: _catMilestones.where((m) => m.category == def.category).toList(),
                            ),
                          )).toList(),
                        )
                      : const SizedBox.shrink(),
                ),
                // 더보기 / 접기 버튼
                _MoreToggleButton(
                  expanded: _catExpanded,
                  extraCount: extraDefs.length,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _catExpanded = !_catExpanded);
                  },
                ),
              ],
            ),
          ),
        ),

        if (earnedBadges.isNotEmpty) ...[
          _SectionHeader(label: '획득한 뱃지', count: earnedBadges.length),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _BadgeCard(
                  badge: earnedBadges[i],
                  earned: true,
                  onTap: () => _showDetail(ctx, earnedBadges[i], true),
                ),
                childCount: earnedBadges.length,
              ),
            ),
          ),
        ],
        if (lockedBadges.isNotEmpty) ...[
          _SectionHeader(label: '미획득 뱃지', count: lockedBadges.length),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _BadgeCard(
                  badge: lockedBadges[i],
                  earned: false,
                  onTap: () => _showDetail(ctx, lockedBadges[i], false),
                ),
                childCount: lockedBadges.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 칭호 카드 ────────────────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  final _TitleDef titleDef;
  final _TitleDef? nextTitle;
  final int toNext;
  final int pinCount;

  const _TitleCard({
    required this.titleDef,
    required this.nextTitle,
    required this.toNext,
    required this.pinCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(titleDef.color, context);
    final nextColor = nextTitle != null
        ? _resolveColor(nextTitle!.color, context)
        : color;
    final progress = nextTitle != null && nextTitle!.minPins > 0
        ? (pinCount - titleDef.minPins) /
              (nextTitle!.minPins - titleDef.minPins)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '현재 칭호',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            titleDef.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titleDef.subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.grey),
          ),
          if (nextTitle != null && toNext > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '다음 칭호까지 여행 $toNext회',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
                Text(
                  nextTitle!.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: nextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: context.progressBg,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 섹션 헤더 ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.labelColor,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.countBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greyLight,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 더보기 토글 버튼 ─────────────────────────────────────────────────────────

class _MoreToggleButton extends StatelessWidget {
  final bool expanded;
  final int extraCount;
  final VoidCallback onTap;

  const _MoreToggleButton({
    required this.expanded,
    required this.extraCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expanded ? '접기' : '더보기 (+$extraCount)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              duration: const Duration(milliseconds: 260),
              turns: expanded ? 0.5 : 0.0,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 종목 트랙 카드 ───────────────────────────────────────────────────────────

class _CatTrackCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final List<_CatMilestone> milestones;

  const _CatTrackCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    // 현재 달성 단계 (0~4)
    final earnedCount = milestones
        .where((m) => count >= m.requiredCount)
        .length;
    final currentMilestone = earnedCount > 0
        ? milestones[earnedCount - 1]
        : null;
    final nextMilestone = earnedCount < milestones.length
        ? milestones[earnedCount]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: context.glassCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.labelColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (currentMilestone != null)
                      Text(
                        currentMilestone.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(milestones.length, (i) {
                    final unlocked = i < earnedCount;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < milestones.length - 1 ? 4 : 0,
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 4,
                              decoration: BoxDecoration(
                                color: unlocked ? color : context.chipBorder,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${milestones[i].requiredCount}회',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: unlocked ? color : context.subLabelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                if (nextMilestone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '다음: ${nextMilestone.name} (${nextMilestone.requiredCount - count}회 남음)',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.subLabelColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count회',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: earnedCount > 0 ? color : context.subLabelColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 뱃지 카드 ────────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final _BadgeDef badge;
  final bool earned;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.badge,
    required this.earned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(badge.color, context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: earned ? 1.0 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: earned
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: earned
                      ? color.withValues(alpha: 0.12)
                      : context.emptyStateBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  earned ? badge.icon : Icons.lock_rounded,
                  size: 26,
                  color: earned ? color : AppColors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: earned ? context.labelColor : AppColors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 뱃지 상세 시트 ───────────────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  final _BadgeDef badge;
  final bool earned;

  const _BadgeDetailSheet({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(badge.color, context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: earned
                  ? color.withValues(alpha: 0.12)
                  : context.emptyStateBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              earned ? badge.icon : Icons.lock_rounded,
              size: 40,
              color: earned ? color : AppColors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.labelColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: earned
                  ? color.withValues(alpha: 0.08)
                  : context.emptyStateBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  earned
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: earned ? color : AppColors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  earned ? '획득 완료' : '아직 획득하지 못했어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: earned ? badge.color : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
