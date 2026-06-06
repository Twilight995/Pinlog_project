import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/providers/nav_provider.dart';
import '../../application/providers/pin_provider.dart';
import '../../application/services/notification_service.dart';
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
  // 스플래시 오버레이 뒤에서 로딩되므로 크롬은 처음부터 visible
  final bool _chromeVisible = true;

  late final _authSub = Supabase.instance.client.auth.onAuthStateChange
      .listen(_onAuthStateChange);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecap());
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  void _onAuthStateChange(AuthState state) {
    if (state.event == AuthChangeEvent.signedIn) {
      ref.read(pinsProvider.notifier).loadFromServer();
    }
  }

  Future<void> _checkRecap() async {
    final svc = RecapService.instance;
    if (svc.alreadyShownToday()) return;
    final pins = ref.read(pinsProvider);
    final memories = svc.getMemoriesForToday(pins);
    if (memories.isEmpty) return;
    if (!mounted) return;
    svc.markTodayShown();
    final first = memories.first;
    await NotificationService.instance.showRecapNotification(
      pinTitle: first.pin.title,
      yearsAgo: first.yearsAgo,
    );
    if (!mounted) return;
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
        opacity: (_chromeVisible && !isGlobeMode) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !_chromeVisible || isGlobeMode,
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

  // tab 0(MapScreen/PlatformView)에 GlobalKey 부여.
  // Stack 내 위치가 바뀌어도 Flutter가 element를 이동(move)하므로
  // 언마운트/리마운트 없이 onMapCreated 중복 호출을 방지.
  final _mapKey = GlobalKey();

  // 들어오는 탭: 페이드 + 미세 스케일 (슬라이드 없음 — 탭 전환은 방향감이 불필요)
  static final _inFade  = CurveTween(curve: Curves.easeOut);
  static final _inScale = CurveTween(curve: Curves.easeOutCubic);

  // 나가는 탭: 빠르게 cover
  static final _outFade = CurveTween(curve: const Interval(0.0, 0.4, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _curr = widget.activeTab;
    _prev = widget.activeTab;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedTabView old) {
    super.didUpdateWidget(old);
    if (old.activeTab != widget.activeTab) {
      _prev = old.activeTab;
      _curr = widget.activeTab;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Opacity 대신 ColoredBox 오버레이로 페이드 처리.
  // Mapbox 같은 PlatformView는 Flutter의 Opacity(0~1)를 무시하고
  // full opacity로 렌더링하여 다른 탭 위에 비침 — 오버레이 방식으로 우회.
  Widget _withCover(Widget child, double coverAlpha) {
    if (coverAlpha <= 0.0) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: ColoredBox(
            color: Color.fromRGBO(5, 11, 26, coverAlpha.clamp(0.0, 1.0)),
          ),
        ),
      ],
    );
  }

  // tab i의 실제 child 위젯 (tab 0만 GlobalKey로 래핑)
  Widget _child(int i) {
    if (i == 0) {
      return KeyedSubtree(key: _mapKey, child: widget.children[0]);
    }
    return widget.children[i];
  }

  Widget _buildSlot(
    int i,
    double tFadeIn,
    double tScaleIn,
    double tCoverOut,
  ) {
    if (i == _curr) {
      // MapScreen(PlatformView): Opacity 무시 → 즉시 표시 (cover 기반 reveal)
      if (i == 0) {
        final revealCover = (1.0 - tFadeIn).clamp(0.0, 1.0);
        return _withCover(_child(i), revealCover);
      }
      // 일반 Flutter 탭: 페이드인 + 미세 스케일 (슬라이드 없음)
      return Transform.scale(
        scale: 0.97 + 0.03 * tScaleIn,
        child: Opacity(
          opacity: tFadeIn.clamp(0.0, 1.0),
          child: _child(i),
        ),
      );
    }
    // 나가는 탭: 빠르게 cover (PlatformView 호환)
    if (i == _prev && _prev != _curr) {
      return IgnorePointer(
        child: _withCover(_child(i), tCoverOut.clamp(0.0, 1.0)),
      );
    }
    // 비활성: PlatformView(map)는 cover, 나머지는 Offstage
    if (i == 0) {
      return IgnorePointer(child: _withCover(_child(0), 1.0));
    }
    return Offstage(offstage: true, child: _child(i));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final raw      = _ctrl.value;
        final tFadeIn   = _inFade.transform(raw);
        final tScaleIn  = _inScale.transform(raw);
        final tCoverOut = _outFade.transform(raw);

        // _curr를 항상 마지막(최상위 z)에 배치
        // GlobalKey 덕에 MapScreen이 다른 위치로 이동해도 리마운트 없음
        final indices = [
          for (int i = 0; i < widget.children.length; i++)
            if (i != _curr) i,
          _curr,
        ];

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF050B1A)),
            for (final i in indices)
              _buildSlot(i, tFadeIn, tScaleIn, tCoverOut),
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
                duration: const Duration(milliseconds: 200),
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
                    duration: const Duration(milliseconds: 160),
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
                duration: const Duration(milliseconds: 180),
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
