import 'package:flutter_test/flutter_test.dart';
import 'package:uniraite/models/models.dart';

void main() {
  test('Viaje.fromJson interpreta la respuesta de la API', () {
    final v = Viaje.fromJson({
      'id_viaje': 1,
      'id_chofer': 2,
      'id_vehiculo': 3,
      'punto_origen': 'Campus Central',
      'punto_destino': 'Villas de San Juan',
      'fecha_hora_salida': '2026-09-27 21:30:00',
      'asientos_disponibles': 4,
      'estado_viaje': 'Programado',
      'chofer_calificacion': '4.50',
      'mi_solicitud': {'id_solicitud': 9, 'estado_solicitud': 'Aceptada'},
    });
    expect(v.salida, DateTime(2026, 9, 27, 21, 30));
    expect(v.choferCalificacion, 4.5);
    expect(v.miSolicitudEstado, 'Aceptada');
  });
}
