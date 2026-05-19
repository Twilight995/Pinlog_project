import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 핀 카테고리별 파스텔 팔레트.
///
/// 각 카테고리에 어울리는 무드의 파스텔 그라디언트(흰→파스텔) +
/// 텍스트·아이콘에 쓸 진한 액센트 컬러를 묶어 제공.
class CategoryPalette {
  final Color start;
  final Color end;
  final Color accent;

  const CategoryPalette({
    required this.start,
    required this.end,
    required this.accent,
  });

  static const _lavender = CategoryPalette(
    start: Colors.white,
    end: AppColors.pastelLavender,
    accent: Color(0xFF5B21B6),
  );
  static const _yellow = CategoryPalette(
    start: Colors.white,
    end: AppColors.pastelYellow,
    accent: Color(0xFFB45309),
  );
  static const _pink = CategoryPalette(
    start: Colors.white,
    end: AppColors.pastelPink,
    accent: Color(0xFF9D174D),
  );
  static const _mint = CategoryPalette(
    start: Colors.white,
    end: AppColors.pastelMint,
    accent: Color(0xFF0F766E),
  );
  static const _peach = CategoryPalette(
    start: Colors.white,
    end: AppColors.pastelPeach,
    accent: Color(0xFFC2410C),
  );

  /// 핀 카테고리 shape 키로 팔레트 조회.
  static CategoryPalette forShape(String shape) {
    switch (shape) {
      case 'cafe':
      case 'selfdev':
      case 'tech':
        return _lavender;
      case 'drinking':
      case 'reading':
        return _yellow;
      case 'shopping':
      case 'gym':
        return _pink;
      case 'drive':
      case 'soccer':
      case 'game':
        return _mint;
      case 'running':
      case 'basketball':
        return _peach;
      default:
        return _lavender;
    }
  }
}
