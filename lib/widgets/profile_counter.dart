import 'package:flutter/material.dart';

/// Un numerito grande + una etiqueta chica abajo (por ejemplo "128" arriba
/// y "Followers" abajo).
///
/// Se usa tanto en "Mi perfil" (ProfileScreen) como en el perfil de otro
/// usuario (UserProfileScreen), para que ambas pantallas se vean
/// exactamente iguales y no tengamos que repetir el mismo diseño dos veces.
///
/// Si se le pasa [onTap], el contador se vuelve tocable (por ejemplo, para
/// abrir la lista de seguidores o seguidos). Si no se pasa nada, se ve
/// exactamente igual que antes pero no reacciona al toque.
class ProfileCounter extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const ProfileCounter({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: content,
      ),
    );
  }
}