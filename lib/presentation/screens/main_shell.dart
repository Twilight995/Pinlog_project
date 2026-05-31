import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/nav_provider.dart';
import '../../application/providers/pin_provider.dart';
import '../../application/services/recap_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/recap/recap_popup.dart';
import 'activity/activity_screen.dart';
import 'feed/feed_screen.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // 첫 빌드 완료 후 On This Day 팝업 검사
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecap());
  }

  Future<void> _checkRecap() async {
    final svc = RecapService.instance;
    if (svc.alreadyShownToday()) return;
    final pins = ref.read(pinsProvider);
    final memories = svc.getMemoriesForToday(pins);
    if (memories.isEmpty) return;
    if (!mounted) return;
    svc.markTodayShown();
    await RecapPopup.show(context, memories);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final isGlobeMode = ref.watch(globeModeProvider);

    return Scaffold(
      extendBody: true,
      body: _AnimatedTabView(
        activeTab: activeTab,
        children: const [
          MapScreen(),
          FeedScreen(),
          ActivityScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AnimatedOpacity(
        opacity: isGlobeMode ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: isGlobeMode,
          child: _FloatingNav(
            activeTab: activeTab,
            onTabChanged: (i) => ref.read(activeTabProvider.notifier).state = i,
            onCreateTap: () {
              ref.read(activeTabProvider.notifier).state = 0;
              ref.read(triggerCreatePinProvider.notifier).state = true;
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedTabView extends StatefulWidget {
  final int activeTab;
  final List<Widget> children;

  const _AnimatedTabView({required this.activeTab, required this.children});

  @override
  State<_AnimatedTabView> createState() => _AnimatedTabViewState();
}

class _AnimatedTabViewState extends State<_AnimatedTabView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _curr = 0;
  int _prev = 0;
  int _dir = 1;

  // 들어오는 탭: 위치 + 스케일 + 페이드
  static final _inSlide = CurveTween(curve: Curves.easeOutCubic);
  static final _inFade  = CurveTween(curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
  static final _inScale = CurveTween(curve: Curves.easeOutCubic);

  // 나가는 탭: 뒤로 살짝 밀리며 어두워짐
  static final _outSlide = CurveTween(curve: Curves.easeInCubic);
  static final _outFade  = CurveTween(curve: const Interval(0.0, 0.55, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _curr = widget.activeTab;
    _prev = widget.activeTab;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedTabView old) {
    super.didUpdateWidget(old);
    if (old.activeTab != widget.activeTab) {
      _prev = old.activeTab;
      _curr = widget.activeTab;
      _dir = _curr > _prev ? 1 : -1;
      _ctrl.forward(from: 0.0);
    }
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
      builder: (ctx, _) {
        final raw = _ctrl.value;
        final tSlideIn  = _inSlide.transform(raw);
        final tFadeIn   = _inFade.transform(raw);
        final tScaleIn  = _inScale.transform(raw);
        final tSlideOut = _outSlide.transform(raw);
        final tFadeOut  = _outFade.transform(raw);
        final w = MediaQuery.sizeOf(ctx).width;

        return Stack(
          fit: StackFit.expand,
          children: [
            // MapWidget 같은 native platform view가 Opacity(0)를 무시하고
            // 배경으로 show-through되는 것을 막기 위한 배경 레이어
            ColoredBox(color: Theme.of(ctx).scaffoldBackgroundColor),
            ...List.generate(widget.children.length, (i) {
            if (i == _curr) {
              // 들어오는 탭: 25% 이동 슬라이드 + 0.94→1.0 스케일 + 페이드
              final dx = w * _dir * 0.25 * (1.0 - tSlideIn);
              final scale = 0.94 + 0.06 * tScaleIn;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: tFadeIn.clamp(0.0, 1.0),
                    child: widget.children[i],
                  ),
                ),
              );
            }
            if (i == _prev && _prev != _curr) {
              // 나가는 탭: 반대 방향 10% 밀림 + 1.0→0.96 스케일 + 페이드
              final dx = -w * _dir * 0.10 * tSlideOut;
              final scale = 1.0 - 0.04 * tSlideOut;
              return IgnorePointer(
                child: Transform.translate(
                  offset: Offset(dx, 0),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: (1.0 - tFadeOut).clamp(0.0, 1.0),
                      child: widget.children[i],
                    ),
                  ),
                ),
              );
            }
            return IgnorePointer(
              child: Opacity(opacity: 0.0, child: widget.children[i]),
            );
          }),
          ],
        );
      },
    );
  }
}

class _FloatingNav extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onCreateTap;

  const _FloatingNav({
    required this.activeTab,
    required this.onTabChanged,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    // iOS 26 시뮬레이터에서 padding.bottom이 비정상적으로 큰 값을 반환하는 버그 방어
    final bottomInset = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);
    // 하단 safe area에 딱 붙이는 기준값
    final bottomPad = bottomInset + 5.0;
    // 블러 스트립 전체 높이 = pill 높이 + 위 여백 + 아래 여백
    final stripHeight = bottomPad + 72.0 + 0.0;

    return SizedBox(
      height: stripHeight,
      child: Stack(
        children: [
          // ── 하단 그라디언트 페이드 (경계 없이 자연스럽게) ──────────
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                    colors: [
                      context.bgColor.withValues(alpha: 0.95),
                      context.bgColor.withValues(alpha: 0.80),
                      context.bgColor.withValues(alpha: 0.45),
                      context.bgColor.withValues(alpha: 0.12),
                      context.bgColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 떠있는 pill 네비게이션 ────────────────────────────────
          Positioned(
            bottom: bottomPad,
            left: 24,
            right: 24,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.navBg,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: context.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: context.primaryColor.withValues(alpha: 0.13),
                        blurRadius: 28,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.map_outlined,
                        activeIcon: Icons.map,
                        label: '지도',
                        isActive: activeTab == 0,
                        onTap: () => onTabChanged(0),
                      ),
                      _NavItem(
                        icon: Icons.collections_bookmark_outlined,
                        activeIcon: Icons.collections_bookmark,
                        label: '도감',
                        isActive: activeTab == 1,
                        onTap: () => onTabChanged(1),
                      ),
                      _CreateButton(onTap: onCreateTap),
                      _NavItem(
                        icon: Icons.bolt_outlined,
                        activeIcon: Icons.bolt,
                        label: '활동',
                        isActive: activeTab == 2,
                        onTap: () => onTabChanged(2),
                      ),
                      _NavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: '프로필',
                        isActive: activeTab == 3,
                        onTap: () => onTabChanged(3),
                      ),
                    ],
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

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.82,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressCtrl.forward();
  void _onTapUp(_) {
    _pressCtrl.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _pressCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 슬라이딩 pill 배경 + 아이콘
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                width: widget.isActive ? 46 : 30,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? context.primaryColor.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: context.primaryColor.withValues(alpha: 0.38),
                            blurRadius: 14,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      widget.isActive ? widget.activeIcon : widget.icon,
                      key: ValueKey(widget.isActive),
                      size: 22,
                      color: widget.isActive
                          ? context.primaryColor
                          : AppColors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isActive
                      ? context.primaryDarkColor
                      : AppColors.grey,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: context.primaryColor.withValues(alpha: 0.22),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
    );
  }
}
