import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/pin_provider.dart';
import '../widgets/cosmic/cosmic_background.dart';
import '../widgets/cosmic/pill_nav.dart';
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 전역 코스믹 배경 — 모든 탭 공유 (탭 전환 시 매번 그려지지 않음)
          const RepaintBoundary(child: CosmicBackground()),
          _AnimatedTabView(
            activeTab: activeTab,
            children: const [
              MapScreen(),
              FeedScreen(),
              ActivityScreen(),
              ProfileScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: PillNav(
        activeIndex: activeTab,
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

