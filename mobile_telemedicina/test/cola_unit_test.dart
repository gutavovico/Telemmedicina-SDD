import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/cola_virtual/data/models/cola_models.dart';

void main() {
  group('CU08 ColaModel Serialization Suite', () {
    test('MiTurnoModel tolera snake_case del backend', () {
      final turno = MiTurnoModel.fromJson({
        'id_cita': 102,
        'hora': '09:20',
        'estado': 'PENDIENTE',
        'posicion': 2,
        'eta_minutos': 20,
        'delante': 1,
        'proximo': true,
        'estado_cola': 'NORMAL',
        'mensaje_cola': null,
        'medico_nombre': 'Roberto Gómez',
        'fecha': '2026-10-04',
      });

      expect(turno.idCita, 102);
      expect(turno.posicion, 2);
      expect(turno.etaMinutos, 20);
      expect(turno.proximo, isTrue);
      expect(turno.toJson()['posicion'], 2);
    });

    test('ColaOperativaModel mapea entradas y pausa', () {
      final cola = ColaOperativaModel.fromJson({
        'id_medico': 20,
        'medico_nombre': 'Roberto Gómez',
        'fecha': '2026-10-04',
        'estado_cola': 'PAUSADA',
        'mensaje_cola': 'Atención pausada hasta las 09:30 por Limpieza',
        'duracion_promedio_min': 20,
        'total_pendientes': 2,
        'entradas': [
          {
            'id_cita': 101,
            'hora': '09:00',
            'estado': 'EN_CURSO',
            'posicion': 1,
            'eta_minutos': 0,
            'paciente_nombre': 'Ana Perez',
            'check_in': null,
          },
        ],
      });

      expect(cola.estadoCola, 'PAUSADA');
      expect(cola.entradas, hasLength(1));
      expect(cola.entradas.first.posicion, 1);
      expect(cola.toJson()['totalPendientes'], 2);
    });

    test('ColaOperativaModel tolera entradas ausentes', () {
      final cola = ColaOperativaModel.fromJson({
        'id_medico': 20,
        'medico_nombre': 'Roberto Gómez',
        'fecha': '2026-10-04',
        'estado_cola': 'SIN_TURNOS',
        'mensaje_cola': 'No hay turnos pendientes para esta fecha.',
        'duracion_promedio_min': 20,
        'total_pendientes': 0,
      });

      expect(cola.entradas, isEmpty);
    });
  });
}
