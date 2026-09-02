import 'package:flutter_test/flutter_test.dart';
import 'package:trail/services/trail_service.dart';

void main() {
  test('un Trail nuevo empieza sin recorrido registrado', () {
    final trail = TrailService.instance;

    expect(trail.status, TrailStatus.idle);
    expect(trail.segments, isEmpty);
  });
}
