import 'package:flutter/foundation.dart';

/// Estados posibles de un Trail (recorrido musical).
enum TrailStatus { idle, active, paused }

/// Maneja el estado del Trail actual.
///
/// IMPORTANTE: por ahora esto es SOLO el manejo de estado para la UI
/// (play / pause / stop). Todavía no arranca el registro de ubicación
/// ni guarda nada en Supabase: es la base sobre la que vamos a conectar
/// esa lógica real en el próximo paso.
class TrailService extends ChangeNotifier {
  TrailService._internal();
  static final TrailService instance = TrailService._internal();

  TrailStatus _status = TrailStatus.idle;

  TrailStatus get status => _status;

  bool get isIdle => _status == TrailStatus.idle;
  bool get isActive => _status == TrailStatus.active;
  bool get isPaused => _status == TrailStatus.paused;

  /// Inicia un trail nuevo (si no había ninguno) o retoma uno pausado.
  void play() {
    if (_status == TrailStatus.active) return;
    // TODO: acá va a ir el arranque real de la geolocalización.
    _status = TrailStatus.active;
    notifyListeners();
  }

  /// Pausa el trail que está corriendo.
  void pause() {
    if (_status != TrailStatus.active) return;
    // TODO: acá va a ir la pausa real del registro de ubicación.
    _status = TrailStatus.paused;
    notifyListeners();
  }

  /// Finaliza el trail actual (esté activo o pausado) y vuelve al estado inicial.
  void stop() {
    if (_status == TrailStatus.idle) return;
    // TODO: acá va a ir el guardado/publicación real del trail.
    _status = TrailStatus.idle;
    notifyListeners();
  }
}