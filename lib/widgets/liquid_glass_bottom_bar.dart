import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'liquid_glass.dart';

class LiquidGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  static const List<_NavigationIcon> _icons = [
    _NavigationIcon(
      icon: 'assets/icons/map_icon.svg',
      selectedIcon: 'assets/icons/map_icon_selected.svg',
    ),
    _NavigationIcon(
      icon: 'assets/icons/messages.svg',
      selectedIcon: 'assets/icons/messages_selected.svg',
    ),
    _NavigationIcon(
      icon: 'assets/icons/badges.svg',
      selectedIcon: 'assets/icons/badges_selected.svg',
    ),
    _NavigationIcon(
      icon: 'assets/icons/profile.svg',
      selectedIcon: 'assets/icons/profile_selected.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(36)),
      blurSigma: 20,
      tintOpacity: 0.10,
      child: SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_icons.length, (index) {
            final isSelected = index == currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onItemSelected(index),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                scale: isSelected ? 1.08 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.24)
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      isSelected
                          ? _icons[index].selectedIcon
                          : _icons[index].icon,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavigationIcon {
  final String icon;
  final String selectedIcon;

  const _NavigationIcon({required this.icon, required this.selectedIcon});
}
