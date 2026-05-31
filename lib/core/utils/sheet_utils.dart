import 'package:flutter/material.dart';

/// 앱 전역 바텀시트 — iOS 네이티브 느낌의 슬라이드업 애니메이션
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  Color barrierColor = const Color(0x40000000),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    isDismissible: isDismissible,
    builder: (ctx) => _SpringSheetWrapper(child: builder(ctx)),
  );
}

class _SpringSheetWrapper extends StatefulWidget {
  final Widget child;
  const _SpringSheetWrapper({required this.child});

  @override
  State<_SpringSheetWrapper> createState() => _SpringSheetWrapperState();
}

class _SpringSheetWrapperState extends State<_SpringSheetWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    // 슬라이드: 아래 → 제자리, easeOutQuart — 오버슈트 없이 빠르고 부드럽게
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart),
    );

    // 페이드: 앞 55% 구간에서 완료 (슬라이드보다 먼저 불투명해져 선명하게 등장)
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => FractionalTranslation(
        translation: Offset(0, _slideAnim.value * 0.30),
        child: Opacity(
          opacity: _fadeAnim.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
