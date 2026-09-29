import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda por trail qué canciones se ocultaron del trazado en este dispositivo.
class TrailVisibilityService {
  TrailVisibilityService._();

  static final TrailVisibilityService instance = TrailVisibilityService._();

  String _keyFor(String trailId) => 'trail_hidden_song_indexes_$trailId';

  Future<Set<int>> getHiddenSongIndexes(String trailId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList(_keyFor(trailId)) ?? const [];
      return stored
          .map(int.tryParse)
          .whereType<int>()
          .where((index) => index >= 0)
          .toSet();
    } catch (error) {
      debugPrint('No se pudieron leer las canciones ocultas: $error');
      return <int>{};
    }
  }

  Future<void> saveHiddenSongIndexes(
    String trailId,
    Set<int> hiddenIndexes,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final indexes = hiddenIndexes.toList()..sort();
      await preferences.setStringList(
        _keyFor(trailId),
        indexes.map((index) => index.toString()).toList(growable: false),
      );
    } catch (error) {
      debugPrint('No se pudieron guardar las canciones ocultas: $error');
    }
  }
}