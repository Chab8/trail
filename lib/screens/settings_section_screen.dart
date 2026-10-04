import 'package:flutter/material.dart';

import '../widgets/settings_header.dart';

/// Pantalla vacía que abren las secciones de Configuración que todavía no
/// están implementadas. Solo muestra el encabezado con el nombre.
class SettingsSectionScreen extends StatelessWidget {
  const SettingsSectionScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsHeader.backgroundColor,
      body: Column(
        children: [
          SettingsHeader(title: title),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}