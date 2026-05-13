import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/pin_provider.dart';
import '../../core/theme/app_theme.dart';
import 'activity/activity_screen.dart';
import 'feed/feed_screen.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeTabProvider);

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
      bottomNavigationBar: _FloatingNav(
        activeTab: activeTab,
        onTabChanged: (i) => ref.read(activeTabProvider.notifier).state = i,
        onCreateTap: () {
          ref.read(activeTabProvider.notifier).state = 0;
          ref.read(triggerCreatePinProvider.notifier).state = true;
        },
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

class _AnimatedTabViewState extends State<_AnimatedTabView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        final isActive = i == widget.activeTab;
        return IgnorePointer(
          ignoring: !isActive,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: Duration(milliseconds: isActive ? 250 : 120),
            curve: Curves.easeOutCubic,
            child: widget.children[i],
          ),
        );
      }),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // 하단 safe area에 딱 붙이는 기준값
    final bottomPad = bottomInset + 5.0;
    // 블러 스트립 전체 높이 = pill 높이 + 위 여백(+ 버튼 튀어나오는 공간) + 아래 여백
    final stripHeight = bottomPad + 72.0 + 20.0;

    return SizedBox(
      height: stripHeight,
      child: Stack(
        clipBehavior: Clip.none,
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
                      const SizedBox(width: 56),
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
          // ── + 버튼 (ClipRRect 바깥, 위로 튀어나오게) ──────────────
          Positioned(
            bottom: bottomPad + 20,
            left: 0,
            right: 0,
            child: Center(
              child: _CreateButton(onTap: onCreateTap),
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
                curve: Curves.easeOutBack,
                width: widget.isActive ? 46 : 30,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
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
                          ? AppColors.primary
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
                      ? AppColors.primaryDark
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
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}
