import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_theme.dart';

class ThemeNotifier extends StateNotifier<AppThemePreset> {
  ThemeNotifier() : super(_load());

  static AppThemePreset _load() {
    try {
      final box = Hive.box<dynamic>('settings');
      final idx = box.get('themeColorIndex', defaultValue: 0) as int;
      if (idx == -1) {
        // 커스텀 색상 복원
        final colorInt = box.get('customThemeColor') as int?;
        if (colorInt != null) {
          return AppThemePreset.fromColor(Color(colorInt));
        }
      }
      return AppThemePreset.presets[idx.clamp(0, AppThemePreset.presets.length - 1)];
    } catch (_) {
      return AppThemePreset.presets.first;
    }
  }

  void setPreset(AppThemePreset preset) {
    final box = Hive.box<dynamic>('settings');
    if (preset.isCustom) {
      box.put('themeColorIndex', -1);
      box.put('customThemeColor', preset.primary.toARGB32());
    } else {
      final idx = AppThemePreset.presets.indexOf(preset);
      box.put('themeColorIndex', idx >= 0 ? idx : 0);
    }
    state = preset;
  }

  void setCustomColor(Color color) => setPreset(AppThemePreset.fromColor(color));
}

final themePresetProvider =
    StateNotifierProvider<ThemeNotifier, AppThemePreset>((_) => ThemeNotifier());
