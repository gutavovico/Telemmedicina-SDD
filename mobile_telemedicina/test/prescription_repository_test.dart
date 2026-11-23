import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/features/medical_records/data/datasources/prescription_remote_datasource.dart';
import 'package:mobile_telemedicina/features/medical_records/data/models/prescription_model.dart';
import 'package:mobile_telemedicina/features/medical_records/data/repositories/prescription_repository_impl.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';

class FakeApiClient implements ApiClientInterface {
  dynamic getResponse;
  Uint8List downloadResponse = Uint8List(0);
  Object? getError;
  Object? downloadError;

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    if (getError != null) throw getError!;
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    return null;
  }

  @override
  Future<dynamic> patch(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<dynamic> delete(
    String url, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async {
    if (downloadError != null) throw downloadError!;
    return downloadResponse;
  }
}

Map<String, dynamic> recetaJson({int posicion = 1, String nombre = 'A'}) => {
  'id_receta': 1,
  'id_clinica': 1,
  'id_consulta': 1,
  'id_paciente': 10,
  'id_medico': 3,
  'id_documento': null,
  'id_receta_sustituta': null,
  'folio': 'REC-2026-000001',
  'pdf_url': '/api/v1/recetas/1/pdf',
  'indicaciones_generales': null,
  'algoritmo_firma': 'ED25519',
  'key_id': 'k1',
  'version_payload': 1,
  'hash_pdf': 'h',
  'fecha_emision': '2026-09-22T22:30:00Z',
  'fecha_vencimiento': '2026-10-22',
  'esta_vencida': false,
  'estado': 'EMITIDA',
  'motivo_anulacion': null,
  'observaciones_anulacion': null,
  'fecha_anulacion': null,
  'medico': {
    'id_medico': 3,
    'nombre_completo': 'Dr. Test',
    'matricula_profesional': 'MP-1',
    'especialidad': 'Clínica',
  },
  'paciente': {'id_paciente': 10, 'nombre_completo': 'Pac Test'},
  'detalles': [
    {
      'id_receta_detalle': posicion,
      'id_medicamento': null,
      'nombre_medicamento_manual': nombre,
      'medicamento_nombre': nombre,
      'principio_activo': null,
      'concentracion': null,
      'forma_farmaceutica': null,
      'dosis': 'd',
      'frecuencia': 'f',
      'duracion': 'du',
      'via_administracion': 'ORAL',
      'cantidad': 1,
      'indicaciones': null,
      'posicion': posicion,
    },
  ],
};

void main() {
  group('PrescriptionRepositoryImpl mapeo', () {
    test('mapea modelo a entidad con todos los campos', () async {
      final fake = FakeApiClient()..getResponse = recetaJson();
      final repo = PrescriptionRepositoryImpl(
        datasource: PrescriptionRemoteDatasource(apiClient: fake),
      );

      final entity = await repo.getPrescriptionById(1);

      expect(entity, isA<Prescription>());
      expect(entity.folio, 'REC-2026-000001');
      expect(entity.medico.nombreCompleto, 'Dr. Test');
      expect(entity.medico.especialidad, 'Clínica');
      expect(entity.paciente.nombreCompleto, 'Pac Test');
      expect(entity.estado, EstadoReceta.emitida);
      expect(entity.estadoVisual, EstadoVisualReceta.vigente);
      expect(entity.detalles, hasLength(1));
    });

    test('ordena detalles ascendentemente por posicion', () async {
      final model = PrescriptionModel.fromJson({
        ...recetaJson(),
        'detalles': [
          {
            'id_receta_detalle': 3,
            'id_medicamento': null,
            'nombre_medicamento_manual': 'C',
            'medicamento_nombre': 'C',
            'principio_activo': null,
            'concentracion': null,
            'forma_farmaceutica': null,
            'dosis': 'd',
            'frecuencia': 'f',
            'duracion': 'du',
            'via_administracion': 'ORAL',
            'cantidad': 1,
            'indicaciones': null,
            'posicion': 3,
          },
          {
            'id_receta_detalle': 1,
            'id_medicamento': null,
            'nombre_medicamento_manual': 'A',
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
          {
            'id_receta_detalle': 2,
            'id_medicamento': null,
            'nombre_medicamento_manual': 'B',
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
        ],
      });

      final entity = PrescriptionRepositoryImpl.mapEntity(model);
      expect(entity.detalles.map((e) => e.posicion).toList(), [1, 2, 3]);
      expect(entity.detallesOrdenados.map((e) => e.posicion).toList(), [
        1,
        2,
        3,
      ]);
    });

    test('rechaza bytes vacíos en descarga', () async {
      final fake = FakeApiClient()..downloadResponse = Uint8List(0);
      final repo = PrescriptionRepositoryImpl(
        datasource: PrescriptionRemoteDatasource(apiClient: fake),
      );

      expect(() => repo.downloadPrescriptionPdf(1), throwsStateError);
    });

    test('descarga exitosa retorna bytes no vacíos', () async {
      final fake = FakeApiClient()
        ..downloadResponse = Uint8List.fromList([37, 80, 68, 70]);
      final repo = PrescriptionRepositoryImpl(
        datasource: PrescriptionRemoteDatasource(apiClient: fake),
      );

      final bytes = await repo.downloadPrescriptionPdf(1);
      expect(bytes.isNotEmpty, true);
    });
  });
}
