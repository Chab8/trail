import 'package:shared_preferences/shared_preferences.dart';

/// Guarda por trail qué canciones se ocultaron del trazado en este dispositivo.
class TrailVisibilityService {
  TrailVisibilityService._();

  static final TrailVisibilityService instance = TrailVisibilityService._();

  String _keyFor(String trailId) => 'trail_hidden_song_indexes_$trailId';

  Future<Set<int>> getHiddenSongIndexes(String trailId) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_keyFor(trailId)) ?? const [];
    return stored
        .map(int.tryParse)
        .whereType<int>()
        .where((index) => index >= 0)
        .toSet();
  }

  Future<void> saveHiddenSongIndexes(
    String trailId,
    Set<int> hiddenIndexes,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final indexes = hiddenIndexes.toList()..sort();
    await preferences.setStringList(
      _keyFor(trailId),
      indexes.map((index) => index.toString()).toList(growable: false),
    );
  }
}
