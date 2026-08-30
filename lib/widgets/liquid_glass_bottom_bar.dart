import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LiquidGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  // Orden: 0 Mapa, 1 Mensajes, 2 Badges, 3 Perfil
  static const List<String> _unselectedIcons = [
    'assets/icons/map_icon.svg',
    'assets/icons/messages.svg',
    'assets/icons/badges.svg',
    'assets/icons/profile.svg',
  ];

  static const List<String> _selectedIcons = [
    'assets/icons/map_icon_selected.svg',
    'assets/icons/messages_selected.svg',
    'assets/icons/badges_selected.svg',
    'assets/icons/profile_selected.svg',
  ];

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
              final isSelected = index == currentIndex;
              final iconPath =
                  isSelected ? _selectedIcons[index] : _unselectedIcons[index];
              return IconButton(
                onPressed: () => onItemSelected(index),
                icon: SvgPicture.asset(
                  iconPath,
                  height: 24,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}