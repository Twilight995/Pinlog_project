class AppConstants {
  // 반응 목록 (좋아요 / 별로에요)
  static const emotions = [
    '좋아요',
    '별로에요',
  ];

  // 날씨 목록
  static const weathers = ['☀️ 맑음', '🌧 비', '☁️ 흐림', '🌨 눈', '🌬 바람'];

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
    'reading',   // 📚 독서
    'selfdev',   // 🧠 자기개발
    'game',      // 🎮 오락
    'tech',      // 📱 전자기기
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
    'reading':    '독서',
    'selfdev':    '자기개발',
    'game':       '오락',
    'tech':       '전자기기',
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
    'reading':    '📚',
    'selfdev':    '🧠',
    'game':       '🎮',
    'tech':       '📱',
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

  // 공개 범위
  static const visibilities = ['🌐 전체 공개', '👥 친구 공개', '🔒 나만 보기'];

  // 감정 강도 레이블
  static const intensityLabels = ['', '약해요', '조금요', '보통', '강해요', '최고조'];

  // Hive box 이름
  static const pinsBox = 'pins';
}
