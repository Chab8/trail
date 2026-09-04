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
      // La barra deja ver el mapa y apenas conserva el borde del vidrio.
      blurSigma: 16,
      tintOpacity: 0.055,
      borderOpacity: 0.10,
      shadowOpacity: 0.10,
      highlightOpacity: 0.16,
      bottomShadeOpacity: 0.025,
      child: SizedBox(
        height: 64,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const indicatorInset = 6.0;
            final itemWidth = constraints.maxWidth / _icons.length;

            return Stack(
              children: [
                // Una sola píldora se desliza por debajo de los íconos. Así
                // no desaparece ni reaparece al cambiar de pantalla.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: (itemWidth * currentIndex) + indicatorInset,
                  top: indicatorInset,
                  width: itemWidth - (indicatorInset * 2),
                  height: 64 - (indicatorInset * 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_icons.length, (index) {
                    final isSelected = index == currentIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onItemSelected(index),
                        child: Center(
                          child: SvgPicture.asset(
                            isSelected
                                ? _icons[index].selectedIcon
                                : _icons[index].icon,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
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
