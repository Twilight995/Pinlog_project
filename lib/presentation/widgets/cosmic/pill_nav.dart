import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// 글래스 필 네비게이션 — 하단 떠있는 알약 컨테이너 안에 4개 탭 + 중앙 + 버튼.
/// 활성 탭은 흰 → 연한 테마 컬러 그라디언트 + 테마 컬러 보더.
class PillNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onCreateTap;

  const PillNav({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(21, 12, 21, bottomInset + 8),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgWarmDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: '지도',
                isActive: activeIndex == 0,
                theme: TabTheme.map,
                onTap: () => onTabChanged(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.collections_bookmark_outlined,
                activeIcon: Icons.collections_bookmark,
                label: '도감',
                isActive: activeIndex == 1,
                theme: TabTheme.pinCollection,
                onTap: () => onTabChanged(1),
              ),
            ),
            Expanded(
              child: _CreateButton(onTap: onCreateTap),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt,
                label: '활동',
                isActive: activeIndex == 2,
                theme: TabTheme.activity,
                onTap: () => onTabChanged(2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: '프로필',
                isActive: activeIndex == 3,
                theme: TabTheme.profile,
                onTap: () => onTabChanged(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final TabTheme theme;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? AppColors.textOnPastel : AppOverlays.w50;
    final textColor = isActive ? AppColors.textOnPastel : AppOverlays.w50;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [theme.bgStart, theme.bgEnd],
                )
              : null,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: isActive
              ? Border.all(color: theme.accent, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
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
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.bgDeepBlack,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
