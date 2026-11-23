import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/data/models/prescription_model.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';

Map<String, dynamic> recetaJson({
  String estado = 'EMITIDA',
  bool estaVencida = false,
  List<Map<String, dynamic>>? detalles,
}) {
  return {
    'id_receta': 58,
    'id_clinica': 1,
    'id_consulta': 45,
    'id_paciente': 10,
    'id_medico': 3,
    'id_documento': 210,
    'id_receta_sustituta': null,
    'folio': 'REC-2026-000058',
    'pdf_url': '/api/v1/recetas/58/pdf',
    'indicaciones_generales': 'Mantener hidratación y reposo.',
    'algoritmo_firma': 'ED25519',
    'key_id': 'prescriptions-2026-01',
    'version_payload': 1,
    'hash_pdf':
        'd8e8fca2dc0f896fd7cb4cb0031ba24900000000000000000000000000000000',
    'fecha_emision': '2026-09-22T22:30:00Z',
    'fecha_vencimiento': '2026-10-22',
    'esta_vencida': estaVencida,
    'estado': estado,
    'motivo_anulacion': null,
    'observaciones_anulacion': null,
    'fecha_anulacion': null,
    'medico': {
      'id_medico': 3,
      'nombre_completo': 'Dr. Carlos Fernández Mendoza',
      'matricula_profesional': 'MP-84920-SC',
      'especialidad': 'Medicina General',
    },
    'paciente': {'id_paciente': 10, 'nombre_completo': 'María Reneé Morales'},
    'detalles':
        detalles ??
        [
          {
            'id_receta_detalle': 101,
            'id_medicamento': 14,
            'nombre_medicamento_manual': null,
            'medicamento_nombre': 'Amoxicilina + Ácido Clavulánico',
            'principio_activo': 'Amoxicilina / Clavulanato',
            'concentracion': '500 mg / 125 mg',
            'forma_farmaceutica': 'Comprimido recubierto',
            'dosis': '500 mg',
            'frecuencia': 'Cada 8 horas',
            'duracion': '7 días',
            'via_administracion': 'ORAL',
            'cantidad': 21,
            'indicaciones': 'Tomar después de las comidas',
            'posicion': 1,
          },
        ],
  };
}

void main() {
  group('PrescriptionModel deserialización completa', () {
    test('deserializa RecetaResponse completa del contrato', () {
      final model = PrescriptionModel.fromJson(recetaJson());

      expect(model.idReceta, 58);
      expect(model.idClinica, 1);
      expect(model.idConsulta, 45);
      expect(model.idPaciente, 10);
      expect(model.idMedico, 3);
      expect(model.idDocumento, 210);
      expect(model.idRecetaSustituta, isNull);
      expect(model.folio, 'REC-2026-000058');
      expect(model.pdfUrl, '/api/v1/recetas/58/pdf');
      expect(model.indicacionesGenerales, 'Mantener hidratación y reposo.');
      expect(model.algoritmoFirma, 'ED25519');
      expect(model.keyId, 'prescriptions-2026-01');
      expect(model.versionPayload, 1);
      expect(model.hashPdf.isNotEmpty, true);
      expect(model.fechaEmision, '2026-09-22T22:30:00Z');
      expect(model.fechaVencimiento, '2026-10-22');
      expect(model.estaVencida, false);
      expect(model.estado, 'EMITIDA');
      expect(model.medico.nombreCompleto, 'Dr. Carlos Fernández Mendoza');
      expect(model.medico.matriculaProfesional, 'MP-84920-SC');
      expect(model.medico.especialidad, 'Medicina General');
      expect(model.paciente.nombreCompleto, 'María Reneé Morales');
      expect(model.detalles, hasLength(1));
      final d = model.detalles.first;
      expect(d.medicamentoNombre, 'Amoxicilina + Ácido Clavulánico');
      expect(d.principioActivo, 'Amoxicilina / Clavulanato');
      expect(d.concentracion, '500 mg / 125 mg');
      expect(d.dosis, '500 mg');
      expect(d.frecuencia, 'Cada 8 horas');
      expect(d.duracion, '7 días');
      expect(d.viaAdministracion, 'ORAL');
      expect(d.cantidad, 21);
      expect(d.posicion, 1);
    });

    test('soporta todos los campos anulables', () {
      final json = Map<String, dynamic>.from(recetaJson());
      json['id_documento'] = null;
      json['indicaciones_generales'] = null;
      json['motivo_anulacion'] = null;
      json['observaciones_anulacion'] = null;
      json['fecha_anulacion'] = null;
      final medico = Map<String, dynamic>.from(json['medico'] as Map);
      medico['especialidad'] = null;
      json['medico'] = medico;
      json['detalles'] = [
        {
          'id_receta_detalle': 1,
          'id_medicamento': null,
          'nombre_medicamento_manual': 'Paracetamol genérico',
          'medicamento_nombre': 'Paracetamol genérico',
          'principio_activo': null,
          'concentracion': null,
          'forma_farmaceutica': null,
          'dosis': '500 mg',
          'frecuencia': 'Cada 8 horas',
          'duracion': '3 días',
          'via_administracion': 'ORAL',
          'cantidad': 9,
          'indicaciones': null,
          'posicion': 1,
        },
      ];

      final model = PrescriptionModel.fromJson(json);
      expect(model.idDocumento, isNull);
      expect(model.indicacionesGenerales, isNull);
      expect(model.motivoAnulacion, isNull);
      expect(model.medico.especialidad, isNull);
      expect(model.detalles.first.idMedicamento, isNull);
      expect(model.detalles.first.principioActivo, isNull);
      expect(model.detalles.first.concentracion, isNull);
      expect(model.detalles.first.formaFarmaceutica, isNull);
      expect(model.detalles.first.indicaciones, isNull);
    });

    test('toJson conserva todos los campos incluyendo nulos', () {
      final model = PrescriptionModel.fromJson(recetaJson());
      final out = model.toJson();

      expect(out['id_receta'], 58);
      expect(out['id_receta_sustituta'], isNull);
      expect(out['indicaciones_generales'], isNotNull);
      expect(out['motivo_anulacion'], isNull);
      expect(out['fecha_anulacion'], isNull);
      expect((out['medico'] as Map)['especialidad'], 'Medicina General');
      expect((out['detalles'] as List), hasLength(1));
      expect((out['detalles'] as List).first['posicion'], 1);
      // Round-trip sin pérdida.
      final again = PrescriptionModel.fromJson(out);
      expect(again.folio, model.folio);
      expect(again.hashPdf, model.hashPdf);
      expect(
        again.detalles.first.medicamentoNombre,
        model.detalles.first.medicamentoNombre,
      );
    });

    test('PrescriptionListResponse deserializa items y total', () {
      final list = PrescriptionListModel.fromJson({
        'items': [recetaJson()],
        'total': 1,
      });
      expect(list.items, hasLength(1));
      expect(list.total, 1);
    });
  });

  group('Estado visual clínico', () {
    test('EMITIDA + esta_vencida=false => VIGENTE', () {
      expect(
        estadoVisualDe(estado: EstadoReceta.emitida, estaVencida: false),
        EstadoVisualReceta.vigente,
      );
    });

    test('EMITIDA + esta_vencida=true => VENCIDA', () {
      expect(
        estadoVisualDe(estado: EstadoReceta.emitida, estaVencida: true),
        EstadoVisualReceta.vencida,
      );
    });

    test('ANULADA siempre => ANULADA aunque esta_vencida=true', () {
      expect(
        estadoVisualDe(estado: EstadoReceta.anulada, estaVencida: true),
        EstadoVisualReceta.anulada,
      );
      expect(
        estadoVisualDe(estado: EstadoReceta.anulada, estaVencida: false),
        EstadoVisualReceta.anulada,
      );
    });

    test('entidad expone estadoVisual y detallesOrdenados por posicion', () {
      final model = PrescriptionModel.fromJson(
        recetaJson(
          detalles: [
            {
              'id_receta_detalle': 2,
              'id_medicamento': 2,
              'nombre_medicamento_manual': null,
              'medicamento_nombre': 'B',
              'principio_activo': null,
              'concentracion': null,
              'forma_farmaceutica': null,
              'dosis': 'd',
              'frecuencia': 'f',
              'duracion': 'du',
              'via_administracion': 'ORAL',
              'cantidad': 1,
              'indicaciones': null,
              'posicion': 2,
            },
            {
              'id_receta_detalle': 1,
              'id_medicamento': 1,
              'nombre_medicamento_manual': null,
              'medicamento_nombre': 'A',
              'principio_activo': null,
              'concentracion': null,
              'forma_farmaceutica': null,
              'dosis': 'd',
              'frecuencia': 'f',
              'duracion': 'du',
              'via_administracion': 'ORAL',
              'cantidad': 1,
              'indicaciones': null,
              'posicion': 1,
            },
          ],
        ),
      );
      // El modelo conserva el orden crudo; el ordenamiento vive en dominio.
      expect(model.detalles.first.posicion, 2);
      expect(model.detalles.last.posicion, 1);
    });
  });

  group('Paginación hasMore', () {
    test('calcula hasMore desde skip/limit/items/total', () {
      expect(
        PrescriptionPage.calcHasMore(
          skip: 0,
          limit: 20,
          itemsLength: 20,
          total: 45,
        ),
        true,
      );
      expect(
        PrescriptionPage.calcHasMore(
          skip: 40,
          limit: 20,
          itemsLength: 5,
          total: 45,
        ),
        false,
      );
      expect(
        PrescriptionPage.calcHasMore(
          skip: 0,
          limit: 20,
          itemsLength: 0,
          total: 0,
        ),
        false,
      );
      expect(
        PrescriptionPage.calcHasMore(
          skip: 0,
          limit: 20,
          itemsLength: 20,
          total: 20,
        ),
        false,
      );
      final page = PrescriptionPage(items: [], total: 45, skip: 20, limit: 20);
      expect(page.page, 2);
      expect(page.hasMore, true);
    });
  });

  group('Nombre seguro del PDF', () {
    test('deriva nombre desde folio sin rutas del servidor', () {
      expect(
        prescriptionPdfFilename('REC-2026-000058'),
        'receta_REC-2026-000058.pdf',
      );
      expect(prescriptionPdfFilename('REC/2026:000058'), isNot(contains('/')));
      expect(prescriptionPdfFilename('REC/2026:000058'), isNot(contains(':')));
      expect(prescriptionPdfFilename(''), 'receta_receta.pdf');
    });
  });

  group('Estado JSON nunca deriva a vigente por fallback', () {
    EstadoVisualReceta visualDeJson(Map<String, dynamic> json) {
      final model = PrescriptionModel.fromJson(json);
      final estado = estadoRecetaFromString(model.estado);
      return estadoVisualDe(estado: estado, estaVencida: model.estaVencida);
    }

    test('"estado": "EMITIDA" => vigente (esta_vencida=false)', () {
      expect(
        visualDeJson(recetaJson(estado: 'EMITIDA', estaVencida: false)),
        EstadoVisualReceta.vigente,
      );
    });

    test('"estado": "ANULADA" => anulada', () {
      expect(
        visualDeJson(recetaJson(estado: 'ANULADA')),
        EstadoVisualReceta.anulada,
      );
    });

    test('"estado": "PENDIENTE" => desconocido, nunca vigente', () {
      final visual = visualDeJson(recetaJson(estado: 'PENDIENTE'));
      expect(visual, EstadoVisualReceta.desconocido);
      expect(visual, isNot(EstadoVisualReceta.vigente));
    });

    test('"estado": "" => desconocido, nunca vigente', () {
      final visual = visualDeJson(recetaJson(estado: ''));
      expect(visual, EstadoVisualReceta.desconocido);
      expect(visual, isNot(EstadoVisualReceta.vigente));
    });

    test('"estado": null => desconocido, nunca vigente', () {
      final json = recetaJson();
      json['estado'] = null;
      final visual = visualDeJson(json);
      expect(visual, EstadoVisualReceta.desconocido);
      expect(visual, isNot(EstadoVisualReceta.vigente));
    });

    test('campo estado ausente => desconocido, nunca vigente', () {
      final json = recetaJson();
      json.remove('estado');
      final visual = visualDeJson(json);
      expect(visual, EstadoVisualReceta.desconocido);
      expect(visual, isNot(EstadoVisualReceta.vigente));
    });

    test('tolerancia a espacios y minúsculas en dominio', () {
      expect(estadoRecetaFromString(' emitida '), EstadoReceta.emitida);
      expect(estadoRecetaFromString('anulada'), EstadoReceta.anulada);
      expect(estadoRecetaFromString('pendiente'), EstadoReceta.desconocido);
    });
  });
}
