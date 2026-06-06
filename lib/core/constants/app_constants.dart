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
    'cafe',      // 카페
    'drinking',  // 술자리
    'shopping',  // 쇼핑
    'drive',     // 드라이브
    'running',   // 런닝
    'gym',       // 운동
    'soccer',    // 축구
    'basketball',// 농구
    'baseball',  // 야구
    'reading',   // 독서
    'selfdev',   // 자기개발
    'game',      // 오락
    'tech',      // 전자기기
    'palace',    // 문화재
    'walk',      // 산책
    'travel',    // 여행
    'nature',    // 자연
    'photo',     // 사진
    'transit',   // 대중교통
    'flower',    // 꽃길
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
    'walk':       '산책',
    'travel':     '여행',
    'nature':     '자연',
    'photo':      '사진',
    'transit':    '대중교통',
    'flower':     '꽃길',
    // 구버전 호환
    'sprout':        '새싹',
    'cherryBlossom': '벚꽃',
    'moon':          '달',
    'star':          '별',
    'sun':           '해',
    'food':          '맛집',
    'culture':       '문화',
    'daily':         '일상',
    'chiikawa':      '캐릭터',
    'cloud':         '구름',
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
    'walk':       'lib/img/walk-svgrepo-com.svg',
    'travel':     'lib/img/place/plane.svg',
    'nature':     'lib/img/nature/tree-svgrepo-com.svg',
    'photo':      'lib/img/life/camera.svg',
    'transit':    'lib/img/bus-svgrepo-com.svg',
    'flower':     'lib/img/nature/flower-2.svg',
    // 구버전 호환 SVG
    'star':          'lib/img/badge/star.svg',
    'sprout':        'lib/img/nature/flower.svg',
    'cherryBlossom': 'lib/img/nature/flower3-svgrepo-com.svg',
    'moon':          'lib/img/nature/snowflake.svg',
    'cloud':         'lib/img/nature/cloud-sun-rain.svg',
    'sun':           'lib/img/nature/sun.svg',
    'food':          'lib/img/food/coffee-cup-svgrepo-com.svg',
    'culture':       'lib/img/place/palace.svg',
    'daily':         'lib/img/life/pencil-svgrepo-com.svg',
    'chiikawa':      'lib/img/badge/star.svg',
  };

  // 공개 범위
  static const visibilities = ['🌐 전체 공개', '👥 친구 공개', '🔒 나만 보기'];

  // 감정 강도 레이블
  static const intensityLabels = ['', '약해요', '조금요', '보통', '강해요', '최고조'];

  // Hive box 이름
  static const pinsBox = 'pins';

  // 국가코드 → 국기 SVG 경로
  static const flagSvgs = <String, String>{
    'KR': 'lib/img/flag/flag-for-south-korea-svgrepo-com.svg',
    'US': 'lib/img/flag/flag-usa-solid-svgrepo-com.svg',
    'CN': 'lib/img/flag/flag-china-solid-svgrepo-com.svg',
    'JP': 'lib/img/flag/flag-for-japan-svgrepo-com.svg',
    'TW': 'lib/img/flag/flag-for-taiwan-svgrepo-com.svg',
    'GB': 'lib/img/flag/flag-for-united-kingdom-svgrepo-com.svg',
    'FR': 'lib/img/flag/flag-for-france-svgrepo-com.svg',
    'DE': 'lib/img/flag/flag-for-germany-svgrepo-com.svg',
    'IT': 'lib/img/flag/flag-for-italy-svgrepo-com.svg',
    'ES': 'lib/img/flag/flag-for-spain-svgrepo-com.svg',
    'TH': 'lib/img/flag/flag-for-thailand-svgrepo-com.svg',
    'VN': 'lib/img/flag/flag-for-vietnam-svgrepo-com.svg',
    'SG': 'lib/img/flag/flag-for-singapore-svgrepo-com.svg',
    'MY': 'lib/img/flag/flag-for-malaysia-svgrepo-com.svg',
    'ID': 'lib/img/flag/flag-for-indonesia-svgrepo-com.svg',
    'PH': 'lib/img/flag/flag-for-philippines-svgrepo-com.svg',
    'AU': 'lib/img/flag/flag-for-australia-svgrepo-com.svg',
    'CA': 'lib/img/flag/canada-maple-leaf-svgrepo-com.svg',
    'AT': 'lib/img/flag/flag-for-flag-austria-svgrepo-com.svg',
    'BR': 'lib/img/flag/flag-for-flag-brazil-svgrepo-com.svg',
    'KH': 'lib/img/flag/flag-for-flag-cambodia-svgrepo-com.svg',
    'DK': 'lib/img/flag/flag-for-flag-denmark-svgrepo-com.svg',
    'EG': 'lib/img/flag/flag-for-flag-egypt-svgrepo-com.svg',
    'GR': 'lib/img/flag/flag-for-flag-greece-svgrepo-com.svg',
    'HK': 'lib/img/flag/flag-for-flag-hong-kong-sar-china-svgrepo-com.svg',
    'HU': 'lib/img/flag/flag-for-flag-hungary-svgrepo-com.svg',
    'IN': 'lib/img/flag/flag-for-flag-india-svgrepo-com.svg',
    'LA': 'lib/img/flag/flag-for-flag-laos-svgrepo-com.svg',
    'MV': 'lib/img/flag/flag-for-flag-maldives-svgrepo-com.svg',
    'MX': 'lib/img/flag/flag-for-flag-mexico-svgrepo-com.svg',
    'MM': 'lib/img/flag/flag-for-flag-myanmar-burma-svgrepo-com.svg',
    'NP': 'lib/img/flag/flag-for-flag-nepal-svgrepo-com.svg',
    'NL': 'lib/img/flag/flag-for-flag-netherlands-svgrepo-com.svg',
    'NZ': 'lib/img/flag/flag-for-flag-new-zealand-svgrepo-com.svg',
    'NO': 'lib/img/flag/flag-for-flag-norway-svgrepo-com.svg',
    'PT': 'lib/img/flag/flag-for-flag-portugal-svgrepo-com.svg',
    'QA': 'lib/img/flag/flag-for-flag-qatar-svgrepo-com.svg',
    'LK': 'lib/img/flag/flag-for-flag-sri-lanka-svgrepo-com.svg',
    'SE': 'lib/img/flag/flag-for-flag-sweden-svgrepo-com.svg',
    'CH': 'lib/img/flag/flag-for-flag-switzerland-svgrepo-com.svg',
    'TR': 'lib/img/flag/flag-for-flag-turkey-svgrepo-com.svg',
    'AE': 'lib/img/flag/united-arab-emirates-svgrepo-com.svg',
  };

  static String? flagSvgPath(String? countryCode) =>
      countryCode != null ? flagSvgs[countryCode.toUpperCase()] : null;

  // 감정 → SVG 경로
  static const emotionSvgs = <String, String>{
    '좋아요':  'lib/img/emotion/hand-heart.svg',
    '별로에요': 'lib/img/emotion/sad-circle-svgrepo-com.svg',
  };

  static String? emotionSvgPath(String? emotion) =>
      emotion != null ? emotionSvgs[emotion] : null;

  /// 카테고리별 자동 색상 — 테마 primary의 hue를 기준으로 20단계 분배
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
