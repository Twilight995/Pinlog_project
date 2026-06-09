import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 모든 tap에 햅틱을 자동으로 추가하는 래퍼.
/// GestureDetector/InkWell 대신 이걸 쓰면 된다.
///
/// 사용법:
///   HapticTap(onTap: () => ..., child: Widget)
class HapticTap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final HapticFeedbackType type;
  final HitTestBehavior behavior;

  const HapticTap({
    super.key,
    required this.child,
    this.onTap,
    this.type = HapticFeedbackType.light,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: onTap == null
          ? null
          : () {
              switch (type) {
                case HapticFeedbackType.light:
                  HapticFeedback.lightImpact();
                case HapticFeedbackType.medium:
                  HapticFeedback.mediumImpact();
                case HapticFeedbackType.heavy:
                  HapticFeedback.heavyImpact();
                case HapticFeedbackType.selection:
                  HapticFeedback.selectionClick();
              }
              onTap!();
            },
      child: child,
    );
  }
}

enum HapticFeedbackType { light, medium, heavy, selection }
