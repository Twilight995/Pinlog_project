import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppConstants {
  // 반응 목록 (좋아요 / 별로에요)
  static const emotions = [
    '좋아요',
    '별로에요',
  ];

  // 날씨 목록
  static const weathers = ['맑음', '비', '흐림', '눈', '바람'];

  // 핀 카테고리 key 목록 (도감 수집 단위)
  static const pinShapes = [
    'cafe',      // ☕ 카페
    'drinking',  // 🍺 술자리
    'shopping',  // 🛍️ 쇼핑
    'drive',     // 🚗 드라이브
    'running',   // 🏃 런닝
    'gym',       // 💪 운동
    'soccer',    // ⚽ 축구
    'basketball',// 🏀 농구
    'baseball',  // ⚾ 야구
    'reading',   // 📚 독서
    'selfdev',   // 🧠 자기개발
    'game',      // 🎮 오락
    'tech',      // 📱 전자기기
    'palace',    // 🏯 문화재
  ];

  // 핀 카테고리 한국어 이름
  static const pinShapeNames = <String, String>{
    'cafe':       '카페',
    'drinking':   '술자리',
    'shopping':   '쇼핑',
    'drive':      '드라이브',
    'running':    '런닝',
    'gym':        '운동',
    'soccer':     '축구',
    'basketball': '농구',
    'baseball':   '야구',
    'reading':    '독서',
    'selfdev':    '자기개발',
    'game':       '오락',
    'tech':       '전자기기',
    'palace':     '문화재',
    // 구버전 호환
    'sprout':        '새싹',
    'cherryBlossom': '벚꽃',
    'moon':          '달',
    'star':          '별',
    'sun':           '해',
    'food':          '맛집',
    'nature':        '자연',
    'culture':       '문화',
    'daily':         '일상',
    'travel':        '여행',
    'chiikawa':      '캐릭터',
    'cloud':         '구름',
  };

  // 핀 카테고리 이모지
  static const pinShapeEmojis = <String, String>{
    'cafe':       '☕',
    'drinking':   '🍺',
    'shopping':   '🛍️',
    'drive':      '🚗',
    'running':    '🏃',
    'gym':        '💪',
    'soccer':     '⚽',
    'basketball': '🏀',
    'baseball':   '⚾',
    'reading':    '📚',
    'selfdev':    '🧠',
    'game':       '🎮',
    'tech':       '📱',
    'palace':     '🏯',
    // 구버전 호환
    'sprout':        '🌱',
    'cherryBlossom': '🌸',
    'moon':          '🌙',
    'star':          '⭐',
    'sun':           '☀️',
    'food':          '🍽️',
    'nature':        '🏔️',
    'culture':       '🎨',
    'daily':         '🏠',
    'travel':        '✈️',
    'chiikawa':      '🐾',
    'cloud':         '☁️',
  };

  // 핀 카테고리 SVG 아이콘 경로
  static const pinShapeSvgs = <String, String>{
    'cafe':       'lib/img/food/coffee-cup-svgrepo-com.svg',
    'drinking':   'lib/img/food/beer-mug-full-svgrepo-com.svg',
    'shopping':   'lib/img/life/shopping-card-svgrepo-com.svg',
    'drive':      'lib/img/life/car-wheel-svgrepo-com.svg',
    'running':    'lib/img/sports/running-svgrepo-com.svg',
    'gym':        'lib/img/sports/muscle-svgrepo-com.svg',
    'soccer':     'lib/img/sports/soccer-ball-svgrepo-com.svg',
    'basketball': 'lib/img/sports/basketball-svgrepo-com.svg',
    'baseball':   'lib/img/sports/baseball-svgrepo-com.svg',
    'reading':    'lib/img/life/book-svgrepo-com.svg',
    'selfdev':    'lib/img/emotion/brain-illustration-12-svgrepo-com.svg',
    'game':       'lib/img/sports/game-control-2-svgrepo-com.svg',
    'tech':       'lib/img/life/macbook-pro-svgrepo-com.svg',
    'palace':     'lib/img/place/gyeongbokgung-palace-svgrepo-com (1).svg',
    // 구버전 호환 SVG
    'nature':        'lib/img/nature/tree-svgrepo-com.svg',
    'travel':        'lib/img/place/plane.svg',
    'star':          'lib/img/badge/star.svg',
    'sprout':        'lib/img/nature/flower.svg',
    'cherryBlossom': 'lib/img/nature/flower3-svgrepo-com.svg',
    'moon':          'lib/img/nature/snowflake.svg',
    'cloud':         'lib/img/nature/cloud-sun-rain.svg',
    'sun':           'lib/img/nature/sun.svg',
    'food':          'lib/img/food/coffee-cup-svgrepo-com.svg',
    'culture':       'lib/img/place/palace.svg',
    'daily':         'lib/img/life/pencil-svgrepo-com.svg',
  };

  // 공개 범위
  static const visibilities = ['🌐 전체 공개', '👥 친구 공개', '🔒 나만 보기'];

  // 감정 강도 레이블
  static const intensityLabels = ['', '약해요', '조금요', '보통', '강해요', '최고조'];

  // Hive box 이름
  static const pinsBox = 'pins';

  /// 카테고리별 자동 색상 — 테마 primary의 hue를 기준으로 14단계 분배
  /// 테마가 바뀌면 전체 팔레트가 함께 이동해 항상 어울리는 색이 나온다.
  static Color categoryColor(String shape, AppThemePreset theme) {
    final index = pinShapes.indexOf(shape);
    if (index == -1) return theme.primary;

    final base = HSLColor.fromColor(theme.primary);
    final step = 360.0 / pinShapes.length; // ≈ 25.7°
    final hue = (base.hue + index * step) % 360;

    return HSLColor.fromAHSL(
      1.0,
      hue,
      base.saturation.clamp(0.50, 0.88),
      base.lightness.clamp(0.45, 0.62),
    ).toColor();
  }
}
