/// Categorías de badges. El [title] es el texto que se muestra en la app.
enum BadgeCategory {
  walking('Walking badges'),
  time('Time badges'),
  song('Song badges'),
  artist('Artist badges'),
  genre('Genre badges'),
  hour('Hour badges'),
  social('Social badges'),
  match('Match badges'),
  health('Health badges'),
  secret('Secret badges');

  const BadgeCategory(this.title);
  final String title;
}

/// Una misión/logro. Todavía no tiene lógica de desbloqueo: por ahora
/// solo guarda el nombre y la descripción para mostrarlos en pantalla.
class BadgeDefinition {
  const BadgeDefinition({
    required this.category,
    required this.name,
    required this.description,
    this.isExtra = false,
  });

  final BadgeCategory category;
  final String name;
  final String description;

  /// true si pertenece a la sección "Extras" de su categoría.
  final bool isExtra;
}

/// Devuelve las misiones de una categoría, en el orden en que están abajo.
List<BadgeDefinition> badgesForCategory(BadgeCategory category) =>
    allBadgeDefinitions.where((b) => b.category == category).toList();

const List<BadgeDefinition> allBadgeDefinitions = [
  // ───────────────────────── WALKING ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: 'Primer paso',
    description: 'Crea tu primer trail.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: 'Medio kilómetro',
    description: 'Acumula 500 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: 'Primer kilómetro',
    description: 'Acumula 1.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '3 kilómetros',
    description: 'Acumula 3.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '5 kilómetros',
    description: 'Acumula 5.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '10 kilómetros',
    description: 'Acumula 10.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '20 kilómetros',
    description: 'Acumula 20.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '50 kilómetros',
    description: 'Acumula 50.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '100 kilómetros',
    description: 'Acumula 100.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '250 kilómetros',
    description: 'Acumula 250.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '500 kilómetros',
    description: 'Acumula 500.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: '1000 kilómetros',
    description: 'Acumula 1.000.000 metros de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: 'Sin descanso',
    description: 'Camina 1.000 metros en un solo trail.',
    isExtra: true,
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: 'Sin descanso II',
    description: 'Camina 5.000 metros en un solo trail.',
    isExtra: true,
  ),
  BadgeDefinition(
    category: BadgeCategory.walking,
    name: 'Sin descanso III',
    description: 'Camina 10.000 metros en un solo trail.',
    isExtra: true,
  ),

  // ───────────────────────── TIME ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Calentando',
    description: 'Acumula 10 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Media hora',
    description: 'Acumula 30 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Una hora',
    description: 'Acumula 60 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Dos horas',
    description: 'Acumula 120 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Cinco horas',
    description: 'Acumula 300 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Diez horas',
    description: 'Acumula 600 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Un día',
    description: 'Acumula 1.440 minutos de trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Sin cortes',
    description: 'Escucha 1 hora de música en un solo trail.',
    isExtra: true,
  ),
  BadgeDefinition(
    category: BadgeCategory.time,
    name: 'Sin cortes II',
    description: 'Escucha 3 horas de música en un solo trail.',
    isExtra: true,
  ),

  // ───────────────────────── SONG ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.song,
    name: 'Mismo artista',
    description: 'Escucha al mismo artista durante un trail entero.',
  ),
  BadgeDefinition(
    category: BadgeCategory.song,
    name: 'Fan',
    description: 'Escucha solo a un mismo artista durante 3 trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.song,
    name: 'Stan',
    description: 'Escucha solo a un mismo artista durante 10 trails.',
  ),
  BadgeDefinition(
    category: BadgeCategory.song,
    name: 'Seguidor',
    description: 'Escucha 50 canciones de un mismo artista en varios trails.',
    isExtra: true,
  ),
  BadgeDefinition(
    category: BadgeCategory.song,
    name: 'Seguidor II',
    description: 'Escucha 100 canciones de un mismo artista en varios trails.',
    isExtra: true,
  ),

  // ───────────────────────── ARTIST ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.artist,
    name: 'Explorador',
    description: 'Escucha 15 artistas distintos en un mismo trail.',
  ),
  BadgeDefinition(
    category: BadgeCategory.artist,
    name: 'Explorador II',
    description: 'Escucha 30 artistas distintos en un mismo trail.',
  ),
  BadgeDefinition(
    category: BadgeCategory.artist,
    name: 'Explorador III',
    description: 'Escucha 50 artistas distintos en un mismo trail.',
  ),

  // ───────────────────────── GENRE ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.genre,
    name: 'Mix',
    description: 'Escucha 3 géneros de música en un mismo trail.',
  ),
  BadgeDefinition(
    category: BadgeCategory.genre,
    name: 'Mix II',
    description: 'Escucha 5 géneros de música en un mismo trail.',
  ),
  BadgeDefinition(
    category: BadgeCategory.genre,
    name: 'Mix III',
    description: 'Escucha 10 géneros de música en un mismo trail.',
  ),

  // ───────────────────────── HOUR ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.hour,
    name: 'Amanecer',
    description: 'Completa un trail entre las 6:00 y las 8:00.',
  ),
  BadgeDefinition(
    category: BadgeCategory.hour,
    name: 'Mediodía',
    description: 'Completa un trail entre las 12:00 y las 14:00.',
  ),
  BadgeDefinition(
    category: BadgeCategory.hour,
    name: 'Atardecer',
    description: 'Completa un trail entre las 18:00 y las 20:00.',
  ),
  BadgeDefinition(
    category: BadgeCategory.hour,
    name: 'Trasnochando',
    description: 'Completa un trail entre las 00:00 y las 4:00.',
  ),

  // ───────────────────────── SOCIAL ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.social,
    name: 'Sociable',
    description: 'Comparte un trail por chat.',
  ),
  BadgeDefinition(
    category: BadgeCategory.social,
    name: 'Camino a la fama',
    description: 'Consigue 10 seguidores.',
  ),
  BadgeDefinition(
    category: BadgeCategory.social,
    name: 'Camino a la fama II',
    description: 'Consigue 50 seguidores.',
  ),
  BadgeDefinition(
    category: BadgeCategory.social,
    name: 'Camino a la fama III',
    description: 'Consigue 100 seguidores.',
  ),

  // ───────────────────────── MATCH ─────────────────────────
  // (vacío por ahora)

  // ───────────────────────── HEALTH ─────────────────────────
  // (vacío por ahora)

  // ───────────────────────── SECRET ─────────────────────────
  BadgeDefinition(
    category: BadgeCategory.secret,
    name: 'Pegada en la cabeza',
    description: 'Escucha la misma canción 5 veces seguidas en un trail.',
  ),
  BadgeDefinition(
    category: BadgeCategory.secret,
    name: 'Clavado',
    description: 'Haz un trail de exactamente 1 kilómetro.',
  ),
  BadgeDefinition(
    category: BadgeCategory.secret,
    name: 'Momento de descanso',
    description: 'Pausa un trail exactamente 5 veces.',
  ),
];