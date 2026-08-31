import 'package:flutter/material.dart';
import 'liquid_glass.dart';

class LiquidGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  static const List<IconData> _icons = [
    Icons.map_outlined,
    Icons.chat_bubble_outline,
    Icons.emoji_events_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 68,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (index) {
            final isSelected = index == currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onItemSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.deepPurple.withValues(alpha: 0.35)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.transparent,
                  ),
                ),
                child: Icon(
                  _icons[index],
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                  size: 24,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}