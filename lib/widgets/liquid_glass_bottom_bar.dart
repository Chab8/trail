import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'liquid_glass.dart';

class LiquidGlassBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  State<LiquidGlassBottomBar> createState() => _LiquidGlassBottomBarState();
}

class _LiquidGlassBottomBarState extends State<LiquidGlassBottomBar> {
  double? _draggedIndicatorLeft;

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
            const indicatorHorizontalInset = 4.0;
            const indicatorHeight = 56.0;
            final itemWidth = constraints.maxWidth / _icons.length;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                final selectedLeft =
                    (itemWidth * widget.currentIndex) +
                    indicatorHorizontalInset;
                final selectedRight =
                    selectedLeft + itemWidth - (indicatorHorizontalInset * 2);
                final isOnIndicator =
                    details.localPosition.dx >= selectedLeft &&
                    details.localPosition.dx <= selectedRight &&
                    details.localPosition.dy >= (64 - indicatorHeight) / 2 &&
                    details.localPosition.dy <= (64 + indicatorHeight) / 2;

                if (isOnIndicator) {
                  setState(() => _draggedIndicatorLeft = selectedLeft);
                }
              },
              onHorizontalDragUpdate: (details) {
                final draggedLeft = _draggedIndicatorLeft;
                if (draggedLeft == null) return;

                final maxLeft =
                    constraints.maxWidth - itemWidth + indicatorHorizontalInset;
                setState(() {
                  _draggedIndicatorLeft = (draggedLeft + details.delta.dx)
                      .clamp(indicatorHorizontalInset, maxLeft)
                      .toDouble();
                });
              },
              onHorizontalDragEnd: (_) {
                final draggedLeft = _draggedIndicatorLeft;
                if (draggedLeft == null) return;

                final selectedIndex =
                    ((draggedLeft + (itemWidth / 2)) / itemWidth).floor().clamp(
                      0,
                      _icons.length - 1,
                    );
                setState(() => _draggedIndicatorLeft = null);

                if (selectedIndex != widget.currentIndex) {
                  widget.onItemSelected(selectedIndex);
                }
              },
              onHorizontalDragCancel: () {
                if (_draggedIndicatorLeft != null) {
                  setState(() => _draggedIndicatorLeft = null);
                }
              },
              child: Stack(
                children: [
                  // Una sola píldora se desliza por debajo de los íconos. Así
                  // no desaparece ni reaparece al cambiar de pantalla.
                  AnimatedPositioned(
                    duration: _draggedIndicatorLeft == null
                        ? const Duration(milliseconds: 320)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    left:
                        _draggedIndicatorLeft ??
                        (itemWidth * widget.currentIndex) +
                            indicatorHorizontalInset,
                    top: (64 - indicatorHeight) / 2,
                    width: itemWidth - (indicatorHorizontalInset * 2),
                    height: indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_icons.length, (index) {
                      final isSelected = index == widget.currentIndex;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onItemSelected(index),
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
              ),
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
