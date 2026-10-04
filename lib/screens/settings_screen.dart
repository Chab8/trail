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
    this.kind = _ItemKind.section,
    this.iconAsset,
  });

  final String title;
  final _ItemKind kind;

  /// Ruta del ícono (ej: 'assets/icons/mi_icono.svg'). Por ahora es null:
  /// el espacio del ícono queda reservado y vacío hasta que lo definamos.
  final String? iconAsset;
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
  static const double _iconLeftPadding = 12;

  static const Color _colorMain = Color(0xFFFEFEFE);
  static const Color _colorSub = Color(0xFF9C9C9C);
  static const Color _colorDanger = Color(0xFFE01414);

  static const List<_SettingsGroup> _groups = [
    _SettingsGroup('Cuenta', [
      _SettingsItem('Manejo de la cuenta', kind: _ItemKind.account),
      _SettingsItem('Editar perfil'),
      _SettingsItem('Información personal'),
      _SettingsItem('Suscripción y pagos'),
      _SettingsItem('Invitar amigos'),
      _SettingsItem('Aplicaciones conectadas'),
      _SettingsItem('Cambiar contraseña'),
      _SettingsItem('Desactivar cuenta'),
    ]),
    _SettingsGroup('Privacidad', [
      _SettingsItem('Privacidad del perfil'),
      _SettingsItem('Privacidad de los trails'),
      _SettingsItem('Zonas privadas'),
      _SettingsItem('Datos y permisos'),
      _SettingsItem('Visibilidad de actividad'),
      _SettingsItem('Mensajes y solicitudes'),
      _SettingsItem('Comentarios y menciones'),
      _SettingsItem('Usuarios bloqueados y silenciados'),
    ]),
    _SettingsGroup('Seguridad', [
      _SettingsItem('Verificación'),
      _SettingsItem('Factor de doble autentificación'),
      _SettingsItem('Sesiones activas'),
    ]),
    _SettingsGroup('Preferencias', [
      _SettingsItem('Preferencias de la app'),
      _SettingsItem('Idioma'),
    ]),
    _SettingsGroup('Notificaciones', [
      _SettingsItem('Notificaciones'),
    ]),
    _SettingsGroup('Ayuda y soporte', [
      _SettingsItem('Centro de ayuda'),
      _SettingsItem('Reportar un problema'),
      _SettingsItem('Mis reportes'),
      _SettingsItem('Moderación y restricciones'),
      _SettingsItem('Acerca de Trail'),
      _SettingsItem('Legal'),
    ]),
    _SettingsGroup('Gestión de contenido', [
      _SettingsItem('Trails eliminados'),
      _SettingsItem('Co-Trails'),
    ]),
    _SettingsGroup('Salir', [
      _SettingsItem('Cerrar sesión', kind: _ItemKind.logout),
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

  /// Fila tocable: [espacio del ícono] [texto a 71px] [flecha a la derecha].
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
              // Espacio reservado para el ícono (llega justo hasta los 71px).
              SizedBox(
                width: _textLeft - _sideMargin,
                child: Padding(
                  padding: const EdgeInsets.only(left: _iconLeftPadding),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: item.iconAsset == null
                        ? const SizedBox.shrink()
                        : SvgPicture.asset(
                            item.iconAsset!,
                            width: 24,
                            height: 24,
                          ),
                  ),
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