import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/pin_provider.dart';
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
      body: _AnimatedTabView(
        activeTab: activeTab,
        children: const [
          MapScreen(),
          FeedScreen(),
          ActivityScreen(),
          ProfileScreen(),
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

