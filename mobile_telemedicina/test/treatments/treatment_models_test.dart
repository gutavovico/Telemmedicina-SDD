import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/adherencia_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/aviso_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/cronograma_dia_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/dosis_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/medicamento_plan_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/operacion_idempotencia_model.dart';
import 'package:mobile_telemedicina/features/treatments/data/models/treatment_plan_model.dart';

void main() {
  group('AdherenciaModel', () {
    test('fromJson y toJson con datos completos', () {
      final json = {
        'numerador_puntual': 4,
        'denominador_programado': 5,
        'porcentaje': 80.0,
        'nivel': 'OPTIMA',
        'calculado_en': '2026-11-01T20:00:00Z',
      };
      final model = AdherenciaModel.fromJson(json);
      expect(model.numeradorPuntual, 4);
      expect(model.denominadorProgramado, 5);
      expect(model.porcentaje, 80.0);
      expect(model.nivel, 'OPTIMA');
      expect(model.calculadoEn, '2026-11-01T20:00:00Z');

      final serialized = model.toJson();
      expect(serialized, equals(json));

      final entity = model.toEntity();
      expect(entity.esOptima, isTrue);
      expect(entity.sinDatos, isFalse);
    });

    test('fromJson tolera nulos en porcentaje y calculado_en', () {
      final json = {
        'numerador_puntual': 0,
        'denominador_programado': 0,
        'porcentaje': null,
        'nivel': 'SIN_DATOS',
        'calculado_en': null,
      };
      final model = AdherenciaModel.fromJson(json);
      expect(model.porcentaje, isNull);
      expect(model.calculadoEn, isNull);
      expect(model.toEntity().sinDatos, isTrue);
    });
  });

  group('MedicamentoPlanModel', () {
    test('fromJson y toJson preservan horas y cálculo de intervalo', () {
      final json = {
        'id_medicamento_plan': 12,
        'id_receta_detalle': 101,
        'medicamento_nombre': 'Amoxicilina 500mg',
        'dosis': '1 comprimido',
        'via_administracion': 'ORAL',
        'frecuencia_texto_receta': 'cada 8 horas',
        'duracion_texto_receta': '7 días',
        'indicaciones': 'Tomar con alimentos',
        'fecha_inicio': '2026-11-01',
        'fecha_fin': '2026-11-07',
        'horas_locales': ['06:00', '14:00', '22:00'],
        'intervalo_horas': 8,
        'estado': 'ACTIVO',
      };
      final model = MedicamentoPlanModel.fromJson(json);
      expect(model.idMedicamentoPlan, 12);
      expect(model.horasLocales, ['06:00', '14:00', '22:00']);
      expect(model.intervaloHoras, 8);
      expect(model.toEntity().estaActivo, isTrue);

      expect(model.toJson(), equals(json));
    });
  });

  group('DosisModel', () {
    test('fromJson y toJson con campos de ingesta nulos y efectivos', () {
      final jsonPending = {
        'id_dosis': 501,
        'id_medicamento_plan': 12,
        'programada_en': '2026-11-01T10:00:00Z',
        'programada_hora_local': '06:00',
        'zona_horaria': 'America/La_Paz',
        'estado': 'PENDIENTE',
        'vencida': false,
        'efectiva_en': null,
        'registrada_en': null,
        'puntual': null,
        'nota': null,
      };
      final modelPending = DosisModel.fromJson(jsonPending);
      expect(modelPending.toEntity().esPendiente, isTrue);
      expect(modelPending.toEntity().esPuntual, isFalse);
      expect(modelPending.toJson(), equals(jsonPending));

      final jsonIngested = {
        'id_dosis': 502,
        'id_medicamento_plan': 12,
        'programada_en': '2026-11-01T10:00:00Z',
        'programada_hora_local': '06:00',
        'zona_horaria': 'America/La_Paz',
        'estado': 'INGERIDA',
        'vencida': false,
        'efectiva_en': '2026-11-01T09:55:00Z',
        'registrada_en': '2026-11-01T09:56:00Z',
        'puntual': true,
        'nota': 'Sin novedades',
      };
      final modelIngested = DosisModel.fromJson(jsonIngested);
      expect(modelIngested.toEntity().esIngerida, isTrue);
      expect(modelIngested.toEntity().esPuntual, isTrue);
      expect(modelIngested.nota, 'Sin novedades');
    });
  });

  group('TreatmentPlanModel', () {
    test('fromJson y toJson con diagnóstico y medicamentos anidados', () {
      final json = {
        'id_tratamiento': 77,
        'id_clinica': 1,
        'id_consulta': 45,
        'id_receta': 81,
        'id_diagnostico': 54,
        'diagnostico': {
          'codigo_cie': 'J00',
          'descripcion': 'Rinofaringitis aguda',
        },
        'id_paciente': 10,
        'id_medico': 21,
        'fecha_inicio': '2026-11-01',
        'fecha_fin': '2026-11-15',
        'zona_horaria': 'America/La_Paz',
        'estado': 'ACTIVO',
        'notas': 'Plan de seguimiento ambulatorio',
        'motivo_cierre': null,
        'medicamentos': [
          {
            'id_medicamento_plan': 1,
            'id_receta_detalle': 121,
            'medicamento_nombre': 'Paracetamol 500mg',
            'dosis': '500 mg',
            'via_administracion': 'ORAL',
            'frecuencia_texto_receta': 'cada 8 horas',
            'duracion_texto_receta': '7 días',
            'indicaciones': 'Si hay dolor',
            'fecha_inicio': '2026-11-01',
            'fecha_fin': '2026-11-07',
            'horas_locales': ['08:00', '16:00', '00:00'],
            'intervalo_horas': 8,
            'estado': 'ACTIVO',
          }
        ],
        'created_at': '2026-11-01T08:00:00Z',
        'updated_at': '2026-11-01T08:00:00Z',
        'adherencia': {
          'numerador_puntual': 0,
          'denominador_programado': 0,
          'porcentaje': null,
          'nivel': 'SIN_DATOS',
          'calculado_en': '2026-11-01T08:00:00Z',
        },
      };

      final model = TreatmentPlanModel.fromJson(json);
      expect(model.idTratamiento, 77);
      expect(model.diagnostico?.codigoCie, 'J00');
      expect(model.medicamentos.length, 1);
      expect(model.medicamentos.first.medicamentoNombre, 'Paracetamol 500mg');
      expect(model.adherencia?.nivel, 'SIN_DATOS');

      final entity = model.toEntity();
      expect(entity.estaActivo, isTrue);
      expect(entity.medicamentos.first.horasLocales.length, 3);
    });

    test('TreatmentPlanListResponse deserializa items y total', () {
      final json = {
        'items': [
          {
            'id_tratamiento': 77,
            'id_clinica': 1,
            'id_consulta': 45,
            'id_receta': null,
            'id_diagnostico': null,
            'diagnostico': null,
            'id_paciente': 10,
            'id_medico': 21,
            'fecha_inicio': '2026-11-01',
            'fecha_fin': '2026-11-15',
            'zona_horaria': 'America/La_Paz',
            'estado': 'FINALIZADO',
            'notas': null,
            'motivo_cierre': 'Tratamiento completado',
            'medicamentos': [],
            'created_at': null,
            'updated_at': null,
            'adherencia': null,
          }
        ],
        'total': 1,
      };

      final response = TreatmentPlanListResponse.fromJson(json);
      expect(response.total, 1);
      expect(response.items.length, 1);
      expect(response.items.first.motivoCierre, 'Tratamiento completado');
    });
  });

  group('CronogramaDiaModel', () {
    test('fromJson y toJson mapea dosis del día', () {
      final json = {
        'id_tratamiento': 77,
        'fecha': '2026-11-01',
        'zona_horaria': 'America/La_Paz',
        'dosis': [
          {
            'id_dosis': 100,
            'id_medicamento_plan': 1,
            'programada_en': '2026-11-01T12:00:00Z',
            'programada_hora_local': '08:00',
            'zona_horaria': 'America/La_Paz',
            'estado': 'PENDIENTE',
            'vencida': false,
            'efectiva_en': null,
            'registrada_en': null,
            'puntual': null,
            'nota': null,
          }
        ],
        'adherencia': null,
      };

      final model = CronogramaDiaModel.fromJson(json);
      expect(model.dosis.length, 1);
      expect(model.dosis.first.programadaHoraLocal, '08:00');

      final entity = model.toEntity();
      expect(entity.dosis.first.idDosis, 100);
    });
  });

  group('AvisoModel', () {
    test('fromJson y toJson para avisos de dosis', () {
      final json = {
        'id_aviso': 301,
        'id_tratamiento': 77,
        'id_dosis': 100,
        'tipo': 'RECORDATORIO_PREVIO',
        'canal': 'WEB',
        'titulo': 'Recordatorio de toma',
        'mensaje': 'Recuerde tomar su dosis en 30 minutos',
        'estado': 'ENVIADO',
        'programada_en': '2026-11-01T11:30:00Z',
        'enviada_en': '2026-11-01T11:30:05Z',
        'leida_en': null,
      };

      final model = AvisoModel.fromJson(json);
      expect(model.idAviso, 301);
      expect(model.tipo, 'RECORDATORIO_PREVIO');
      expect(model.toEntity().estaLeido, isFalse);

      final listResponse = AvisoListResponse.fromJson({
        'items': [json],
        'total': 1,
      });
      expect(listResponse.total, 1);
      expect(listResponse.items.first.idAviso, 301);
    });
  });

  group('OperacionIdempotenciaModel', () {
    test('fromJson y toJson para operación confirmada con dosis embebida', () {
      final json = {
        'id_dosis': 100,
        'idempotency_key': 'key-idemp-1234',
        'estado': 'CONFIRMADA',
        'confirmado': true,
        'en_curso': false,
        'rechazado': false,
        'dosis': {
          'id_dosis': 100,
          'id_medicamento_plan': 1,
          'programada_en': '2026-11-01T12:00:00Z',
          'programada_hora_local': '08:00',
          'zona_horaria': 'America/La_Paz',
          'estado': 'INGERIDA',
          'vencida': false,
          'efectiva_en': '2026-11-01T12:05:00Z',
          'registrada_en': '2026-11-01T12:06:00Z',
          'puntual': true,
          'nota': 'Dosis ingerida con agua',
        },
        'mensaje': null,
        'generacion': 1,
      };

      final model = OperacionIdempotenciaModel.fromJson(json);
      expect(model.confirmado, isTrue);
      expect(model.enCurso, isFalse);
      expect(model.rechazado, isFalse);
      expect(model.dosis?.estado, 'INGERIDA');

      final entity = model.toEntity();
      expect(entity.confirmado, isTrue);
      expect(entity.dosis?.esIngerida, isTrue);
    });

    test('fromJson para operación EN_CURSO', () {
      final json = {
        'id_dosis': 100,
        'idempotency_key': 'key-en-curso',
        'estado': 'EN_CURSO',
        'confirmado': false,
        'en_curso': true,
        'rechazado': false,
        'dosis': null,
        'mensaje': 'Operación en curso',
        'generacion': 1,
      };

      final model = OperacionIdempotenciaModel.fromJson(json);
      expect(model.enCurso, isTrue);
      expect(model.dosis, isNull);
    });

    test('fromRegistroDosisResponse interpreta respuesta Dosis directa como confirmada', () {
      final directDosisJson = {
        'id_dosis': 505,
        'id_medicamento_plan': 31,
        'programada_en': '2026-11-01T14:00:00Z',
        'programada_hora_local': '10:00',
        'zona_horaria': 'America/La_Paz',
        'estado': 'INGERIDA',
        'vencida': false,
        'efectiva_en': '2026-11-01T14:00:00Z',
        'registrada_en': '2026-11-01T14:01:00Z',
        'puntual': true,
        'nota': 'Sin efectos secundarios',
      };

      final model = OperacionIdempotenciaModel.fromRegistroDosisResponse(
        directDosisJson,
        idempotencyKey: 'key-direct-dose',
        generacion: 2,
      );

      expect(model.idDosis, equals(505));
      expect(model.idempotencyKey, equals('key-direct-dose'));
      expect(model.estado, equals('CONFIRMADA'));
      expect(model.confirmado, isTrue);
      expect(model.enCurso, isFalse);
      expect(model.rechazado, isFalse);
      expect(model.generacion, equals(2));
      expect(model.dosis, isNotNull);
      expect(model.dosis!.estado, equals('INGERIDA'));
      expect(model.dosis!.puntual, isTrue);
      expect(model.dosis!.nota, equals('Sin efectos secundarios'));
    });
  });
}
