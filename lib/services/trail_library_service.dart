import 'package:flutter/foundation.dart';

import '../models/completed_trail.dart';
import '../models/trail_song.dart';

/// Biblioteca de trails finalizados de la sesión actual.
///
/// Este primer paso mantiene únicamente el resumen solicitado en el perfil.
/// El servicio centraliza el estado para que el perfil se actualice aunque ya
/// esté montado dentro del [IndexedStack] de la navegación principal.
class TrailLibraryService extends ChangeNotifier {
  TrailLibraryService._internal();
  static final TrailLibraryService instance = TrailLibraryService._internal();

  final List<CompletedTrail> _trails = [];

  List<CompletedTrail> get trails => List<CompletedTrail>.unmodifiable(_trails);
  int get count => _trails.length;
  String get nextDefaultName => 'Trail #${_trails.length + 1}';

  void addTrail({required String name, required List<TrailSong> songs}) {
    _trails.insert(
      0,
      CompletedTrail(
        name: name.trim().isEmpty ? nextDefaultName : name.trim(),
        songs: List<TrailSong>.unmodifiable(songs),
        completedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
