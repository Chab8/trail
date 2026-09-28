import 'package:flutter/material.dart';

import '../widgets/liquid_glass_bottom_bar.dart';
import '../widgets/trail_controls.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'badges_screen.dart';
import 'profile_tab_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Orden: 0 Mapa, 1 Mensajes, 2 Badges, 3 Perfil
  final List<Widget> _screens = const [
    HomeScreen(),
    MessagesScreen(),
    BadgesScreen(),
    ProfileTabScreen(),
  ];

  void _onItemSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;

    final nextIndex = velocity < 0 ? _currentIndex + 1 : _currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= _screens.length) return;

    _onItemSelected(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody: true hace que el mapa/contenido se vea "detrás"
      // de la barra flotante, para el efecto liquid glass.
      extendBody: true,
      body: _currentIndex == 0
          // El mapa reserva los gestos horizontales para navegarlo.
          ? IndexedStack(index: _currentIndex, children: _screens)
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentIndex == 0) ...[
                const TrailControlsRow(),
                const SizedBox(height: 8),
              ],
              LiquidGlassBottomBar(
                currentIndex: _currentIndex,
                onItemSelected: _onItemSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
