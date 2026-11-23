import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_telemedicina/features/ai_assistant/data/models/asistencia_tratamiento_model.dart';
import 'package:mobile_telemedicina/features/ai_assistant/domain/entities/asistencia_tratamiento.dart';

void main() {
  group('AsistenciaTratamientoModel - Pruebas de Serialización y Deserialización', () {
    test('Escenario Principal 3C: Deserializa correctamente evaluación con interacción GRAVE (Ibuprofeno + Aspirina)', () {
      final json3C = {
        'id_evaluacion': 105,
        'id_paciente': 32,
        'fecha_evaluacion': '2026-11-04T08:30:00Z',
        'estado_evaluacion': 'COMPLETADA',
        'nivel_riesgo_global': 'ALTO',
        'total_medicamentos_analizados': 2,
        'total_alertas_detectadas': 1,
        'resumen_ejecutivo': 'Se detectó 1 interacción farmacológica de severidad grave.',
        'aviso_legal': 'Aviso mandatorio RF-25',
        'medicamentos_analizados': [
          {
            'id_medicamento': 14,
            'nombre': 'Ibuprofeno 400 mg',
            'principio_activo': 'ibuprofeno',
            'dosis': '400 mg',
            'frecuencia': 'Cada 8 horas',
            'via_administracion': 'ORAL',
          },
          {
            'id_medicamento': 8,
            'nombre': 'Aspirina 100 mg',
            'principio_activo': 'acido acetilsalicilico',
            'dosis': '100 mg',
            'frecuencia': 'Cada 24 horas',
            'via_administracion': 'ORAL',
          }
        ],
        'alertas': [
          {
            'id_alerta': 201,
            'principio_activo_1': 'acido acetilsalicilico',
            'principio_activo_2': 'ibuprofeno',
            'medicamento_1_nombre': 'Aspirina 100 mg',
            'medicamento_2_nombre': 'Ibuprofeno 400 mg',
            'severidad': 'GRAVE',
            'color_alerta': 'ROJO',
            'mensaje_alerta': 'Riesgo de interacción: aumento de riesgo de sangrado',
            'pauta_precaucion': 'El uso simultáneo incrementa significativamente el riesgo de hemorragia gastrointestinal.',
          }
        ],
        'recomendaciones': [
          {
            'id_recomendacion': 301,
            'categoria': 'ESTILO_VIDA',
            'titulo': 'Monitoreo tensional por hipertensión',
            'detalle': 'Controle su presión al menos una vez al día.',
            'origen': 'IA_GENERATIVA',
          }
        ],
      };

      final model = EvaluacionTratamientoModel.fromJson(json3C);

      expect(model.idEvaluacion, equals(105));
      expect(model.idPaciente, equals(32));
      expect(model.estadoEvaluacion, equals('COMPLETADA'));
      expect(model.estadoEnum, equals(EstadoEvaluacion.completada));
      expect(model.nivelRiesgoGlobal, equals('ALTO'));
      expect(model.hasHighRisk, isTrue);
      expect(model.totalMedicamentosAnalizados, equals(2));
      expect(model.totalAlertasDetectadas, equals(1));
      expect(model.medicamentosAnalizados.length, equals(2));
      expect(model.alertas.length, equals(1));

      final alerta = model.alertas.first;
      expect(alerta.severidad, equals('GRAVE'));
      expect(alerta.isGrave, isTrue);
      expect(alerta.isModerada, isFalse);
      expect(alerta.colorAlerta, equals('ROJO'));
      expect(alerta.mensajeAlerta, contains('aumento de riesgo de sangrado'));

      final rec = model.recomendaciones.first;
      expect(rec.isGeneradaPorIa, isTrue);
      expect(rec.isReglaPredefinida, isFalse);

      final serialized = model.toJson();
      expect(serialized['id_evaluacion'], equals(105));
      expect(serialized['alertas'][0]['severidad'], equals('GRAVE'));
    });

    test('Escenario Criterio 5: Deserializa tratamiento sin interacciones', () {
      final jsonSinRiesgo = {
        'id_evaluacion': 106,
        'id_paciente': 45,
        'fecha_evaluacion': '2026-11-04T08:35:00Z',
        'estado_evaluacion': 'COMPLETADA',
        'nivel_riesgo_global': 'SIN_RIESGO',
        'total_medicamentos_analizados': 1,
        'total_alertas_detectadas': 0,
        'resumen_ejecutivo': 'No se detectaron interacciones adversas entre sus medicamentos vigentes.',
        'aviso_legal': 'Aviso RF-25',
        'medicamentos_analizados': [
          {
            'id_medicamento': 22,
            'nombre': 'Paracetamol 500 mg',
            'principio_activo': 'paracetamol',
            'dosis': '500 mg',
            'frecuencia': 'Cada 8 horas',
            'via_administracion': 'ORAL',
          }
        ],
        'alertas': [],
        'recomendaciones': [],
      };

      final model = EvaluacionTratamientoModel.fromJson(jsonSinRiesgo);

      expect(model.idEvaluacion, equals(106));
      expect(model.hasNoRisk, isTrue);
      expect(model.totalAlertasDetectadas, equals(0));
      expect(model.alertas, isEmpty);
    });

    test('Escenario Sin Tratamiento Vigente: Soporta id_evaluacion null y estado SIN_TRATAMIENTO_VIGENTE', () {
      final jsonSinTratamiento = {
        'id_evaluacion': null,
        'id_paciente': 50,
        'fecha_evaluacion': '2026-11-04T08:40:00Z',
        'estado_evaluacion': 'SIN_TRATAMIENTO_VIGENTE',
        'nivel_riesgo_global': 'SIN_RIESGO',
        'total_medicamentos_analizados': 0,
        'total_alertas_detectadas': 0,
        'resumen_ejecutivo': 'No cuenta con recetas ni medicamentos vigentes registrados.',
        'aviso_legal': 'Aviso RF-25',
        'medicamentos_analizados': [],
        'alertas': [],
        'recomendaciones': [],
      };

      final model = EvaluacionTratamientoModel.fromJson(jsonSinTratamiento);

      expect(model.idEvaluacion, isNull);
      expect(model.hasNoActiveTreatment, isTrue);
      expect(model.totalMedicamentosAnalizados, equals(0));
    });

    test('Escenario Degradado: Deserializa estado DEGRADADO_REGLAS_BASE con origen REGLA_PREDEFINIDA', () {
      final jsonDegradado = {
        'id_evaluacion': 107,
        'id_paciente': 32,
        'fecha_evaluacion': '2026-11-04T08:45:00Z',
        'estado_evaluacion': 'DEGRADADO_REGLAS_BASE',
        'nivel_riesgo_global': 'ALTO',
        'total_medicamentos_analizados': 2,
        'total_alertas_detectadas': 1,
        'resumen_ejecutivo': 'Evaluación realizada con motor de reglas clínicas base.',
        'aviso_legal': 'Aviso RF-25',
        'medicamentos_analizados': [],
        'alertas': [
          {
            'id_alerta': 202,
            'principio_activo_1': 'acido acetilsalicilico',
            'principio_activo_2': 'ibuprofeno',
            'medicamento_1_nombre': 'Aspirina 100 mg',
            'medicamento_2_nombre': 'Ibuprofeno 400 mg',
            'severidad': 'GRAVE',
            'color_alerta': 'ROJO',
            'mensaje_alerta': 'Riesgo de interacción',
            'pauta_precaucion': 'Precaución',
          }
        ],
        'recomendaciones': [
          {
            'id_recomendacion': 305,
            'categoria': 'PRECAUCION_GENERAL',
            'titulo': 'Pauta de seguridad clínica base',
            'detalle': 'Siga las dosis prescritas.',
            'origen': 'REGLA_PREDEFINIDA',
          }
        ],
      };

      final model = EvaluacionTratamientoModel.fromJson(jsonDegradado);

      expect(model.isDegraded, isTrue);
      expect(model.recomendaciones.first.isReglaPredefinida, isTrue);
      expect(model.alertas.first.isGrave, isTrue);
    });

    test('HistorialEvaluacionModel: Deserializa listado paginado y resumen', () {
      final jsonHistorial = {
        'items': [
          {
            'id_evaluacion': 105,
            'id_paciente': 32,
            'fecha_evaluacion': '2026-11-04T08:30:00Z',
            'estado_evaluacion': 'COMPLETADA',
            'nivel_riesgo_global': 'ALTO',
            'total_medicamentos_analizados': 2,
            'total_alertas_detectadas': 1,
            'resumen_ejecutivo': 'Resumen evaluación',
          }
        ],
        'total': 1,
        'page': 1,
        'limit': 10,
        'total_paginas': 1,
      };

      final model = HistorialEvaluacionModel.fromJson(jsonHistorial);

      expect(model.total, equals(1));
      expect(model.items.length, equals(1));
      expect(model.items.first.idEvaluacion, equals(105));
      expect(model.items.first.isHighRisk, isTrue);
      expect(model.hasNextPage, isFalse);
    });
  });
}

