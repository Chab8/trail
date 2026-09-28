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
  late final PageController _pageController;

  // Orden: 0 Mapa, 1 Mensajes, 2 Badges, 3 Perfil
  final List<Widget> _screens = const [
    HomeScreen(),
    MessagesScreen(),
    BadgesScreen(),
    ProfileTabScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (index != _currentIndex) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody: true hace que el mapa/contenido se vea "detrás"
      // de la barra flotante, para el efecto liquid glass.
      extendBody: true,
      body: PageView(
        controller: _pageController,
        // El mapa reserva sus gestos horizontales. Desde cualquier otra
        // pestaña se puede arrastrar y ver la pantalla vecina en tiempo real.
        physics: _currentIndex == 0
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: _screens
            .map((screen) => _KeepAlivePage(child: screen))
            .toList(),
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

/// Evita reinicializar las pestañas —en especial el mapa— al quedar fuera de
/// la zona visible del PageView.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
