import 'package:flutter/material.dart';

import '../models/completed_trail.dart';

/// Muestra una lista de trails agrupados por mes, con un encabezado
/// (ej. "Septiembre 2026") antes del primer trail de cada mes.
///
/// Si en un mes no hubo trails, ese mes simplemente no aparece: no se
/// genera ningún encabezado vacío.
///
/// Es intencionalmente genérico (no sabe cómo dibujar cada trail): cada
/// pantalla le pasa su propio `itemBuilder`, para poder usarlo tanto en
/// el perfil propio como en el de otro usuario.
class TrailMonthList extends StatelessWidget {
  const TrailMonthList({
    super.key,
    required this.trails,
    required this.itemBuilder,
  });

  final List<CompletedTrail> trails;
  final Widget Function(CompletedTrail trail) itemBuilder;

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    if (trails.isEmpty) return const SizedBox.shrink();

    // Ordenamos del trail más reciente al más antiguo, para que los
    // trails de un mismo mes queden agrupados uno al lado del otro.
    final sorted = [...trails]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final children = <Widget>[];
    int? lastYear;
    int? lastMonth;

    for (final trail in sorted) {
      final date = trail.completedAt;
      final isNewMonth = date.year != lastYear || date.month != lastMonth;

      if (isNewMonth) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 20,
              bottom: 10,
            ),
            child: Text(
              '${_months[date.month - 1]} ${date.year}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
        lastYear = date.year;
        lastMonth = date.month;
      }

      children.add(itemBuilder(trail));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}