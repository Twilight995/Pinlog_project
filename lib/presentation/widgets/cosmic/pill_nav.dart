import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';

/// 하단 알약 네비게이션 — 라이트/다크 모드 완전 대응.
///
/// 다크: 블랙 알약 + 흰 활성 탭 (액센트 아이콘)
/// 라이트: 흰 알약 + 블랙 활성 탭 (액센트 아이콘)
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
    final isDark = context.isDark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 8),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: isDark
              ? Border.all(color: const Color(0xFF1C1C1C), width: 0.5)
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                svgPath: 'lib/img/place/map-pin.svg',
                label: '지도',
                isActive: activeIndex == 0,
                accentColor: TabTheme.map.accent,
                onTap: () => onTabChanged(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.collections_bookmark_outlined,
                activeIcon: Icons.collections_bookmark,
                label: '도감',
                isActive: activeIndex == 1,
                accentColor: TabTheme.pinCollection.accent,
                onTap: () => onTabChanged(1),
              ),
            ),
            Expanded(child: _CreateButton(onTap: onCreateTap)),
            Expanded(
              child: _NavItem(
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt,
                label: '활동',
                isActive: activeIndex == 2,
                accentColor: TabTheme.activity.accent,
                onTap: () => onTabChanged(2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: '프로필',
                isActive: activeIndex == 3,
                accentColor: TabTheme.profile.accent,
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
  final IconData? icon;
  final IconData? activeIcon;
  final String? svgPath;
  final String label;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavItem({
    this.icon,
    this.activeIcon,
    this.svgPath,
    required this.label,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // 활성 알약: 다크=흰색, 라이트=블랙
    final activePillColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    // 활성 텍스트: 알약 위에서 대비 확보
    final activeTextColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    // 비활성 아이콘/텍스트
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuart,
        decoration: BoxDecoration(
          color: isActive ? activePillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(isActive ? accentColor : inactiveColor, isActive),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeTextColor : inactiveColor,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color color, bool active) {
    if (svgPath != null) {
      return SvgPicture.asset(
        svgPath!,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(
      active ? (activeIcon ?? icon) : icon,
      size: 20,
      color: color,
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242424) : const Color(0xFF0A0A0A),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
