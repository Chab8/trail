import 'package:flutter/material.dart';
import '../widgets/liquid_glass_bottom_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody: true hace que el mapa/contenido se vea "detrás"
      // de la barra flotante, para el efecto liquid glass.
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LiquidGlassBottomBar(
            currentIndex: _currentIndex,
            onItemSelected: _onItemSelected,
          ),
        ),
      ),
    );
  }
}