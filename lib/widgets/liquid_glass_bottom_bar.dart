import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) {
              return IconButton(
                onPressed: () => onItemSelected(index),
                icon: Icon(
                  [
                    Icons.map_outlined,
                    Icons.chat_bubble_outline,
                    Icons.emoji_events_outlined,
                    Icons.person_outline,
                  ][index],
                  color: index == currentIndex ? Colors.deepPurple : Colors.white,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
