import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Encabezado compartido por todas las pantallas de Configuración:
/// botón de volver (39x39) a la izquierda y título en bold tamaño 20.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key, required this.title});

  final String title;

  /// Color de fondo de todas las pantallas de Configuración.
  static const Color backgroundColor = Color(0xFF09080B);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(21, 4, 21, 0),
        child: SizedBox(
          height: 39,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                behavior: HitTestBehavior.opaque,
                child: const _BackButtonSvg(),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFEFEFE),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Espacio del mismo ancho que el botón, para que el título
              // quede perfectamente centrado.
              const SizedBox(width: 39),
            ],
          ),
        ),
      ),
    );
  }
}

/// El SVG del botón trae espacio extra para su sombra. Acá se recorta
/// el círculo visible a exactamente 39x39 px (igual que en el resto de la app).
class _BackButtonSvg extends StatelessWidget {
  const _BackButtonSvg();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 39,
        height: 39,
        child: OverflowBox(
          maxWidth: 119,
          maxHeight: 119,
          alignment: const Alignment(0.0, -0.2),
          child: SvgPicture.asset(
            'assets/buttons/back button.svg',
            width: 119,
            height: 119,
          ),
        ),
      ),
    );
  }
}