import 'package:flutter/material.dart';

/// Un numerito grande + una etiqueta chica abajo (por ejemplo "128" arriba
/// y "Followers" abajo).
///
/// Se usa tanto en "Mi perfil" (ProfileScreen) como en el perfil de otro
/// usuario (UserProfileScreen), para que ambas pantallas se vean
/// exactamente iguales y no tengamos que repetir el mismo diseño dos veces.
class ProfileCounter extends StatelessWidget {
  final String label;
  final int value;

  const ProfileCounter({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}