import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/settings_header.dart';
import 'account_management_screen.dart';
import 'settings_section_screen.dart';
import 'welcome_screen.dart';

/// Qué hace cada fila al tocarla.
enum _ItemKind {
  /// Abre una pantalla vacía con el nombre de la sección.
  section,

  /// Abre "Manejo de la cuenta" (la configuración que ya existía).
  account,

  /// Cierra la sesión.
  logout,
}

class _SettingsItem {
  const _SettingsItem(
    this.title, {
    required this.iconAsset,
    this.kind = _ItemKind.section,
  });

  final String title;
  final _ItemKind kind;

  /// Ruta del ícono (ej: 'assets/icons/edit white icon.svg').
  final String iconAsset;
}

class _SettingsGroup {
  const _SettingsGroup(this.title, this.items);

  final String title;
  final List<_SettingsItem> items;
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ── Medidas de tu diseño ──────────────────────────────────────────────
  static const double _sideMargin = 21;
  static const double _textLeft = 71; // distancia del texto al borde izquierdo
  static const double _rowHeight = 50; // alto de cada fila (texto + espacio)

  /// Eje común de TODOS los íconos: cada uno se centra en [_iconCenter],
  /// así que arrancan y terminan en lugares distintos según su ancho, pero
  /// forman una columna centrada. [_iconCenter] se elige para que el ícono más
  /// ancho ("id white icon", 25px) quede a ~23px del texto; los más angostos
  /// dejan más hueco (hasta ~30px para "phone white icon", 11px).
  static const double _iconCenter = 35.5;
  static const double _iconHeight = 17; // alto fijo, el ancho sale del SVG

  /// Ubica el centro del ícono en [_iconCenter] dentro del slot de la fila,
  /// que va de [_sideMargin] a [_textLeft].
  static const Alignment _iconAlignment = Alignment(
    (_iconCenter - _sideMargin) / (_textLeft - _sideMargin),
    0,
  );

  static const Color _colorMain = Color(0xFFFEFEFE);
  static const Color _colorSub = Color(0xFF9C9C9C);
  static const Color _colorDanger = Color(0xFFE01414);

  static const List<_SettingsGroup> _groups = [
    _SettingsGroup('Cuenta', [
      _SettingsItem(
        'Manejo de la cuenta',
        iconAsset: 'assets/icons/person icon.svg',
        kind: _ItemKind.account,
      ),
      _SettingsItem(
        'Editar perfil',
        iconAsset: 'assets/icons/edit white icon.svg',
      ),
      _SettingsItem(
        'Información personal',
        iconAsset: 'assets/icons/id white icon.svg',
      ),
      _SettingsItem(
        'Suscripción y pagos',
        iconAsset: 'assets/icons/star white icon.svg',
      ),
      _SettingsItem(
        'Invitar amigos',
        iconAsset: 'assets/icons/add person white icon.svg',
      ),
      _SettingsItem(
        'Aplicaciones conectadas',
        iconAsset: 'assets/icons/puzzle white icon.svg',
      ),
      _SettingsItem(
        'Cambiar contraseña',
        iconAsset: 'assets/icons/change password white icon.svg',
      ),
      _SettingsItem(
        'Desactivar cuenta',
        iconAsset: 'assets/icons/off white icon.svg',
      ),
    ]),
    _SettingsGroup('Privacidad', [
      _SettingsItem(
        'Privacidad del perfil',
        iconAsset: 'assets/icons/lock white icon.svg',
      ),
      _SettingsItem(
        'Privacidad de los trails',
        iconAsset: 'assets/icons/private trail white icon.svg',
      ),
      _SettingsItem(
        'Zonas privadas',
        iconAsset: 'assets/icons/home white icon.svg',
      ),
      _SettingsItem(
        'Datos y permisos',
        iconAsset: 'assets/icons/data white icon.svg',
      ),
      _SettingsItem(
        'Visibilidad de actividad',
        iconAsset: 'assets/icons/view icon.svg',
      ),
      _SettingsItem(
        'Mensajes y solicitudes',
        iconAsset: 'assets/icons/message.svg',
      ),
      _SettingsItem(
        'Comentarios y menciones',
        iconAsset: 'assets/icons/@ white icon.svg',
      ),
      _SettingsItem(
        'Usuarios bloqueados y silenciados',
        iconAsset: 'assets/icons/blocked user white icon.svg',
      ),
    ]),
    _SettingsGroup('Seguridad', [
      _SettingsItem(
        'Verificación',
        iconAsset: 'assets/icons/verification white icon.svg',
      ),
      _SettingsItem(
        'Factor de doble autentificación',
        iconAsset: 'assets/icons/2fa white icon.svg',
      ),
      _SettingsItem(
        'Sesiones activas',
        iconAsset: 'assets/icons/computer white icon.svg',
      ),
    ]),
    _SettingsGroup('Preferencias', [
      _SettingsItem(
        'Preferencias de la app',
        iconAsset: 'assets/icons/phone white icon.svg',
      ),
      _SettingsItem('Idioma', iconAsset: 'assets/icons/public white icon.svg'),
    ]),
    _SettingsGroup('Notificaciones', [
      _SettingsItem(
        'Notificaciones',
        iconAsset: 'assets/icons/notification.svg',
      ),
    ]),
    _SettingsGroup('Ayuda y soporte', [
      _SettingsItem(
        'Centro de ayuda',
        iconAsset: 'assets/icons/help white icon.svg',
      ),
      _SettingsItem(
        'Reportar un problema',
        iconAsset: 'assets/icons/error white icon.svg',
      ),
      _SettingsItem(
        'Mis reportes',
        iconAsset: 'assets/icons/folder white icon.svg',
      ),
      _SettingsItem(
        'Moderación y restricciones',
        iconAsset: 'assets/icons/shield white icon.svg',
      ),
      _SettingsItem(
        'Acerca de Trail',
        iconAsset: 'assets/icons/information white icon.svg',
      ),
      _SettingsItem('Legal', iconAsset: 'assets/icons/legal white icon.svg'),
    ]),
    _SettingsGroup('Gestión de contenido', [
      _SettingsItem(
        'Trails eliminados',
        iconAsset: 'assets/icons/delete white icon.svg',
      ),
      _SettingsItem(
        'Co-Trails',
        iconAsset: 'assets/icons/chain white icon.svg',
      ),
    ]),
    _SettingsGroup('Salir', [
      _SettingsItem(
        'Cerrar sesión',
        iconAsset: 'assets/icons/exit red icon.svg',
        kind: _ItemKind.logout,
      ),
    ]),
  ];

  void _onItemTap(BuildContext context, _SettingsItem item) {
    switch (item.kind) {
      case _ItemKind.account:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
        );
      case _ItemKind.section:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsSectionScreen(title: item.title),
          ),
        );
      case _ItemKind.logout:
        _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final group in _groups) {
      children.add(_buildDivider(group.title));
      for (final item in group.items) {
        children.add(_buildRow(context, item));
      }
    }

    return Scaffold(
      backgroundColor: SettingsHeader.backgroundColor,
      body: Column(
        children: [
          const SettingsHeader(title: 'Configuración'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
              ),
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Texto divisor de sección (no se puede tocar).
  Widget _buildDivider(String title) {
    return SizedBox(
      height: _rowHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: _sideMargin),
          child: Text(
            title,
            style: const TextStyle(
              color: _colorSub,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Fila tocable: [ícono centrado en _iconCenter] [texto a _textLeft]
  /// [flecha a la derecha].
  Widget _buildRow(BuildContext context, _SettingsItem item) {
    final isLogout = item.kind == _ItemKind.logout;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTap(context, item),
      child: SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
          child: Row(
            children: [
              // Slot fijo que termina justo en _textLeft: mantiene el texto
              // siempre en el mismo lugar aunque el SVG aún no haya cargado.
              // El ícono se pega a _iconCenter, así que todos comparten el
              // mismo centro (no el mismo borde) y toma su ancho natural.
              SizedBox(
                width: _textLeft - _sideMargin,
                child: Align(
                  alignment: _iconAlignment,
                  child: SvgPicture.asset(item.iconAsset, height: _iconHeight),
                ),
              ),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLogout ? _colorDanger : _colorMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isLogout)
                SvgPicture.asset(
                  'assets/icons/right arrow.svg',
                  width: 10,
                  height: 17,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
