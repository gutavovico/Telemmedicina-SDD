import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_telemedicina/core/network/api_client_interface.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/core/theme/app_theme.dart';
import 'package:mobile_telemedicina/features/treatments/data/services/dose_operation_recovery_service.dart';
import 'package:mobile_telemedicina/features/treatments/domain/entities/treatment_entities.dart';
import 'package:mobile_telemedicina/features/treatments/domain/repositories/treatment_repository.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_adherencia_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_cronograma_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/domain/usecases/get_treatment_detail_usecase.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/providers/treatment_provider.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/screens/cronograma_screen.dart';
import 'package:mobile_telemedicina/features/treatments/presentation/widgets/dose_action_dialog.dart';

/// Fake ApiClient para capturar y controlar llamadas de red HTTP en el flujo real.
class MockRealApiClient implements ApiClientInterface {
  final List<Map<String, dynamic>> recordedCalls = [];
  dynamic Function(String url, {dynamic body, Map<String, String>? headers})? onPost;
  dynamic Function(String url, {Map<String, String>? headers})? onGet;

  @override
  Future<dynamic> post(
    String url, {
    dynamic body,
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({
      'method': 'POST',
      'url': url,
      'body': body,
      'headers': headers,
    });
    if (onPost != null) {
      return onPost!(url, body: body, headers: headers);
    }
    return {'estado': 'CONFIRMADA', 'confirmado': true};
  }

  @override
  Future<dynamic> get(
    String url, {
    bool includeAuth = true,
    String? authToken,
    Map<String, String>? headers,
  }) async {
    recordedCalls.add({
      'method': 'GET',
      'url': url,
      'headers': headers,
    });
    if (onGet != null) {
      return onGet!(url, headers: headers);
    }
    return {'estado': 'CONFIRMADA', 'confirmado': true};
  }

  @override
  Future<dynamic> patch(String url, {dynamic body, bool includeAuth = true, Map<String, String>? headers}) async => {};

  @override
  Future<dynamic> delete(String url, {bool includeAuth = true, Map<String, String>? headers}) async => {};

  @override
  Future<Uint8List> downloadBytes(String url, {bool includeAuth = true}) async => Uint8List(0);
}

/// Fake Repository para suministrar los datos de presentación del tratamiento y cronograma.
class MockRealTreatmentRepository implements TreatmentRepository {
  TreatmentPlan? detail;
  CronogramaDia? cronograma;
  Adherencia? adherencia;

  @override
  Future<TreatmentPlan> getTreatmentDetail(int idTratamiento) async {
    return detail ??
        const TreatmentPlan(
          idTratamiento: 10,
          idClinica: 5,
          idConsulta: 100,
          idPaciente: 1,
          idMedico: 2,
          fechaInicio: '2026-11-01',
          fechaFin: '2026-11-30',
          zonaHoraria: 'America/La_Paz',
          estado: 'ACTIVO',
          medicamentos: [
            MedicamentoPlan(
              idMedicamentoPlan: 1,
              idRecetaDetalle: 10,
              medicamentoNombre: 'Losartán 50mg',
              dosis: '1 tableta',
              viaAdministracion: 'ORAL',
              fechaInicio: '2026-11-01',
              fechaFin: '2026-11-30',
              horasLocales: ['08:00'],
              intervaloHoras: 24,
              estado: 'ACTIVO',
            ),
          ],
        );
  }

  @override
  Future<CronogramaDia> getCronograma(int idTratamiento, String fecha) async {
    return cronograma ??
        const CronogramaDia(
          idTratamiento: 10,
          fecha: '2026-11-02',
          zonaHoraria: 'America/La_Paz',
          dosis: [
            Dosis(
              idDosis: 100,
              idMedicamentoPlan: 1,
              programadaEn: '2026-11-02T12:00:00Z',
              programadaHoraLocal: '08:00',
              zonaHoraria: 'America/La_Paz',
              estado: 'PENDIENTE',
              vencida: false,
            ),
          ],
        );
  }

  @override
  Future<Adherencia> getAdherencia(int idTratamiento) async {
    return adherencia ??
        const Adherencia(
          numeradorPuntual: 8,
          denominadorProgramado: 10,
          porcentaje: 80.0,
          nivel: 'OPTIMA',
        );
  }

  @override
  Future<TreatmentPage> getTreatments({String? estado, int skip = 0, int limit = 20}) async =>
      const TreatmentPage(items: [], total: 0);

  @override
  Future<Dosis> registrarDosis(int idDosis, String idempotencyKey, Map<String, dynamic> body) async =>
      throw UnimplementedError('Protocolo en dos fases usa recoveryService');

  @override
  Future<AvisoPage> getAvisos({int skip = 0, int limit = 20, bool noLeidos = false}) async =>
      const AvisoPage(items: [], total: 0);

  @override
  Future<Aviso> leerAviso(int idAviso) async => throw UnimplementedError();

  @override
  Future<OperacionIdempotencia> consultarIdempotencia(int idDosis, String idempotencyKey) async =>
      throw UnimplementedError();

  @override
  Future<void> eliminarDispositivo(int idDispositivo) async {}

  @override
  Future<OperacionIdempotencia> iniciarIntentoDosis(int idDosis, String idempotencyKey, String requestHash) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> registrarDispositivo(String token, String plataforma) async => {};

  @override
  Future<OperacionIdempotencia> resolverOperacionAbandonada(int idDosis, String idempotencyKey) async =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRealApiClient fakeApi;
  late MockRealTreatmentRepository mockRepo;
  late DoseOperationRecoveryService recoveryService;
  late TreatmentProvider provider;

  Widget buildApp(TreatmentProvider prov) {
    return ChangeNotifierProvider<TreatmentProvider>.value(
      value: prov,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CronogramaScreen(idTratamiento: 10),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakeApi = MockRealApiClient();
    mockRepo = MockRealTreatmentRepository();
    recoveryService = DoseOperationRecoveryService(
      apiClient: fakeApi,
      prefs: prefs,
    );

    provider = TreatmentProvider(
      getDetailUseCase: GetTreatmentDetailUseCase(repository: mockRepo),
      getCronogramaUseCase: GetCronogramaUseCase(repository: mockRepo),
      getAdherenciaUseCase: GetAdherenciaUseCase(repository: mockRepo),
      recoveryService: recoveryService,
    );

    provider.syncAuthSession(
      isAuthenticated: true,
      userId: 1,
      clinicId: 5,
    );
  });

  group('CronogramaScreen Real Integration Flow CU17', () {
    testWidgets(
        '1. Flujo completo: POST /intentos (EN_CURSO) y POST /registros (Dosis directa fiel al backend)',
        (tester) async {
      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/intentos')) {
          expect(body['request_hash'], isNotNull);
          expect((body['request_hash'] as String).length, 64);
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'rechazado': false,
            'id_dosis': 100,
            'idempotency_key': headers?['Idempotency-Key'],
            'generacion': 1,
          };
        } else if (url.endsWith('/registros')) {
          expect(body['estado'], equals('INGERIDA'));
          expect(body['nota'], equals('Toma puntual con agua'));
          // Contrato real: POST /registros devuelve directamente el objeto Dosis serializado
          return {
            'id_dosis': 100,
            'id_medicamento_plan': 1,
            'programada_en': '2026-11-02T12:00:00Z',
            'programada_hora_local': '08:00',
            'zona_horaria': 'America/La_Paz',
            'estado': 'INGERIDA',
            'vencida': false,
            'efectiva_en': body['efectiva_en'],
            'registrada_en': '2026-11-02T12:06:00Z',
            'puntual': true,
            'nota': 'Toma puntual con agua',
          };
        }
        throw UnimplementedError('URL no esperada: $url');
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('Losartán 50mg'), findsOneWidget);
      expect(find.text('Registrar Toma'), findsOneWidget);

      // Abrir diálogo de toma
      await tester.tap(find.text('Registrar Toma'));
      await tester.pumpAndSettle();

      // Ingresar nota clínica
      final noteField = find.byType(TextField);
      expect(noteField, findsOneWidget);
      await tester.enterText(noteField, 'Toma puntual con agua');
      await tester.pumpAndSettle();

      // Confirmar registro en modal
      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      // Verificación 1: Orden de llamadas
      expect(fakeApi.recordedCalls.length, equals(2));
      final call1 = fakeApi.recordedCalls[0];
      expect(call1['method'], equals('POST'));
      expect(call1['url'], contains('/dosis/100/intentos'));
      final key1 = call1['headers']?['Idempotency-Key'] as String?;
      expect(key1, isNotNull);
      expect(key1!.isNotEmpty, isTrue);
      final hash1 = call1['body']?['request_hash'] as String?;
      expect(hash1, isNotNull);
      expect(hash1!.length, equals(64));

      // Verificación 2: Misma clave y mismo cuerpo en /registros
      final call2 = fakeApi.recordedCalls[1];
      expect(call2['method'], equals('POST'));
      expect(call2['url'], contains('/dosis/100/registros'));
      final key2 = call2['headers']?['Idempotency-Key'] as String?;
      expect(key2, equals(key1));
      expect(call2['body']?['estado'], equals('INGERIDA'));
      expect(call2['body']?['nota'], equals('Toma puntual con agua'));

      final calculatedHash = CanonicalJsonHasher.hashDoseRegistration(
        estado: call2['body']['estado'],
        efectivaEn: call2['body']['efectiva_en'],
        nota: call2['body']['nota'],
      );
      expect(hash1, equals(calculatedHash));

      // Verificación 3: Dosis mostrada fielmente en UI
      expect(find.text('Corregir Toma'), findsOneWidget);
      expect(find.text('Ingerida'), findsOneWidget);
      expect(find.text('Puntual'), findsOneWidget);
      expect(find.text('Nota: Toma puntual con agua'), findsOneWidget);
      expect(find.text('Toma registrada exitosamente.'), findsOneWidget);

      // Verificación 4: Marcador eliminado y desbloqueada
      expect(provider.isDoseLocked(100), isFalse);
      expect(provider.hasPendingMarkers, isFalse);
      expect(await recoveryService.getAllMarkers(), isEmpty);
    });

    testWidgets(
        '2. Si /intentos devuelve RECHAZADA: NUNCA se envía /registros, no hay éxito ni dosis fabricada en UI',
        (tester) async {
      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/intentos')) {
          // Fase 1 rechazada por el backend
          return {
            'estado': 'RECHAZADA',
            'confirmado': false,
            'en_curso': false,
            'rechazado': true,
            'id_dosis': 100,
            'idempotency_key': headers?['Idempotency-Key'],
            'mensaje': 'Intento rechazado por generación previa.',
          };
        } else if (url.endsWith('/registros')) {
          fail('CRÍTICO: /registros jamás debe invocarse si fase 1 fue rechazada.');
        }
        throw UnimplementedError('URL inesperada: $url');
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar Toma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      // Verificación 1: Se llamó a /intentos, pero NUNCA a /registros
      expect(fakeApi.recordedCalls.length, equals(1));
      expect(fakeApi.recordedCalls[0]['url'], contains('/intentos'));
      final calledRegistros = fakeApi.recordedCalls.any((c) => (c['url'] as String).contains('/registros'));
      expect(calledRegistros, isFalse);

      // Verificación 2: El modal NO se cierra con éxito y no muestra SnackBar de éxito
      expect(find.byType(DoseActionDialog), findsOneWidget);
      expect(find.text('Toma registrada exitosamente.'), findsNothing);
      expect(find.text('Operación confirmada exitosamente.'), findsNothing);

      // Cancelar el diálogo para regresar a la pantalla
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // La dosis permanece como PENDIENTE en la pantalla (sin fabricar estado INGERIDA)
      expect(find.byKey(const ValueKey('btn_registrar_100')), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
    });

    testWidgets(
        '3. Si /intentos devuelve NO_INICIADA o respuesta inválida: no hay /registros y permanece el bloqueo seguro',
        (tester) async {
      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/intentos')) {
          return {
            'estado': 'NO_INICIADA',
            'confirmado': false,
            'en_curso': false,
            'no_iniciada': true,
            'id_dosis': 100,
            'idempotency_key': headers?['Idempotency-Key'],
          };
        } else if (url.endsWith('/registros')) {
          fail('CRÍTICO: /registros jamás debe invocarse si fase 1 es NO_INICIADA.');
        }
        throw UnimplementedError();
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar Toma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      // No se llamó a /registros
      expect(fakeApi.recordedCalls.length, equals(1));
      expect(fakeApi.recordedCalls.any((c) => (c['url'] as String).contains('/registros')), isFalse);

      // Sin mensaje de éxito
      expect(find.text('Toma registrada exitosamente.'), findsNothing);

      // Cancelar diálogo modal para observar la pantalla
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Permanece el bloqueo seguro por resultado incierto
      expect(provider.isDoseLocked(100), isTrue);
      expect(find.byKey(const ValueKey('lock_banner_100')), findsOneWidget);
      expect(find.textContaining('resultado incierto'), findsOneWidget);
    });

    testWidgets(
        '4. Timeout en fase 2: marcador persistente, clave conservada, sin éxito, y recuperación posterior por consulta',
        (tester) async {
      String? capturedKey;
      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/intentos')) {
          capturedKey = headers?['Idempotency-Key'];
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'id_dosis': 100,
            'idempotency_key': capturedKey,
          };
        } else if (url.endsWith('/registros')) {
          throw TimeoutException('Timeout de red simulado en fase 2');
        }
        throw UnimplementedError();
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar Toma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      // Verificación: Dosis bloqueada por incertidumbre, sin mensaje de éxito
      expect(provider.isDoseLocked(100), isTrue);
      expect(find.text('Toma registrada exitosamente.'), findsNothing);

      // Marcador duradero en almacenamiento persistente con clave conservada
      final markers = await recoveryService.getAllMarkers();
      expect(markers.length, equals(1));
      expect(markers.first.idDosis, equals(100));
      expect(markers.first.idempotencyKey, equals(capturedKey));

      // Cancelar el diálogo modal para ver la tarjeta del cronograma
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lock_banner_100')), findsOneWidget);
      expect(find.textContaining('resultado incierto'), findsOneWidget);

      // Recuperación posterior vía consulta de idempotencia (GET /idempotencia/{key})
      fakeApi.onGet = (url, {headers}) {
        if (url.contains('/idempotencia/')) {
          expect(url, contains(capturedKey!));
          return {
            'estado': 'CONFIRMADA',
            'confirmado': true,
            'en_curso': false,
            'rechazado': false,
            'id_dosis': 100,
            'idempotency_key': capturedKey,
            'dosis': {
              'id_dosis': 100,
              'id_medicamento_plan': 1,
              'programada_en': '2026-11-02T12:00:00Z',
              'programada_hora_local': '08:00',
              'zona_horaria': 'America/La_Paz',
              'estado': 'INGERIDA',
              'vencida': false,
              'efectiva_en': '2026-11-02T12:05:00Z',
              'registrada_en': '2026-11-02T12:06:00Z',
              'puntual': true,
              'nota': 'Confirmada tras reconciliación',
            },
          };
        }
        throw UnimplementedError('GET no esperado: $url');
      };

      // Al confirmarse la operación, el repositorio backend devuelve la dosis actualizada
      mockRepo.cronograma = const CronogramaDia(
        idTratamiento: 10,
        fecha: '2026-11-02',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          Dosis(
            idDosis: 100,
            idMedicamentoPlan: 1,
            programadaEn: '2026-11-02T12:00:00Z',
            programadaHoraLocal: '08:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'INGERIDA',
            vencida: false,
            efectivaEn: '2026-11-02T12:05:00Z',
            registradaEn: '2026-11-02T12:06:00Z',
            puntual: true,
            nota: 'Confirmada tras reconciliación',
          ),
        ],
      );

      await provider.checkPendingMarkersAndReconcile();
      await tester.pumpAndSettle();

      // El marcador persistente fue eliminado y la dosis se desbloqueó
      expect(await recoveryService.getAllMarkers(), isEmpty);
      expect(provider.isDoseLocked(100), isFalse);
      expect(find.text('Corregir Toma'), findsOneWidget);
      expect(find.text('Ingerida'), findsOneWidget);
    });

    testWidgets(
        '5. Reintento con cuerpo disponible: responde Dosis directa y actualización exitosa',
        (tester) async {
      // 1. Simular fallo de red inicial en fase 2 (deja el cuerpo en memoria)
      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/intentos')) {
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'id_dosis': 100,
            'idempotency_key': headers?['Idempotency-Key'],
          };
        } else if (url.endsWith('/registros')) {
          throw TimeoutException('Falla de red inicial en fase 2');
        }
        throw UnimplementedError();
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar Toma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Registro'));
      await tester.pumpAndSettle();

      // Cancelar diálogo para ver el cronograma
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(provider.isDoseLocked(100), isTrue);
      expect(provider.hasPendingBodyForDose(100), isTrue);
      expect(find.text('Reintentar registro'), findsOneWidget);

      // 2. Configurar la respuesta exitosa para el reintento: Dosis directa
      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/registros')) {
          return {
            'id_dosis': 100,
            'id_medicamento_plan': 1,
            'programada_en': '2026-11-02T12:00:00Z',
            'programada_hora_local': '08:00',
            'zona_horaria': 'America/La_Paz',
            'estado': 'INGERIDA',
            'vencida': false,
            'efectiva_en': '2026-11-02T12:05:00Z',
            'registrada_en': '2026-11-02T12:06:00Z',
            'puntual': true,
            'nota': 'Reintento exitoso',
          };
        }
        throw UnimplementedError('URL inesperada: $url');
      };

      // Al reintentar exitosamente, el repositorio devuelve la dosis confirmada
      mockRepo.cronograma = const CronogramaDia(
        idTratamiento: 10,
        fecha: '2026-11-02',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          Dosis(
            idDosis: 100,
            idMedicamentoPlan: 1,
            programadaEn: '2026-11-02T12:00:00Z',
            programadaHoraLocal: '08:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'INGERIDA',
            vencida: false,
            efectivaEn: '2026-11-02T12:05:00Z',
            registradaEn: '2026-11-02T12:06:00Z',
            puntual: true,
            nota: 'Reintento exitoso',
          ),
        ],
      );

      // 3. Presionar «Reintentar registro»
      await tester.tap(find.byKey(const ValueKey('retry_btn_100')));
      await tester.pumpAndSettle();

      // Verificación: SnackBar de éxito mostrado, dosis actualizada y desbloqueada
      expect(find.text('Operación confirmada exitosamente.'), findsOneWidget);
      expect(provider.isDoseLocked(100), isFalse);
      expect(await recoveryService.getAllMarkers(), isEmpty);
      expect(find.text('Corregir Toma'), findsOneWidget);
      expect(find.text('Ingerida'), findsOneWidget);
    });

    testWidgets(
        '6. Dosis sin cuerpo permite «Resolver operación abandonada» (/resolver) y al responder RECHAZADA se desbloquea',
        (tester) async {
      const abandonedKey = 'abandoned-key-for-test-6';

      recoveryService.clearPendingClinicalData();
      await recoveryService.saveMarker(const DoseRecoveryMarker(
        userId: 1,
        clinicId: 5,
        idDosis: 100,
        idempotencyKey: abandonedKey,
        timestamp: '2026-11-02T12:00:00Z',
      ));
      recoveryService.lockDose(100);
      await provider.loadPendingMarkers();

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      expect(provider.hasPendingBodyForDose(100), isFalse);
      expect(find.textContaining('resultado incierto'), findsOneWidget);
      expect(find.text('Resolver operación abandonada'), findsOneWidget);
      expect(find.text('Reintentar registro'), findsNothing);

      fakeApi.onPost = (url, {body, headers}) {
        if (url.contains('/resolver')) {
          expect(url, contains(abandonedKey));
          return {
            'estado': 'RECHAZADA',
            'confirmado': false,
            'rechazado': true,
            'id_dosis': 100,
            'idempotency_key': abandonedKey,
          };
        }
        throw UnimplementedError('URL inesperada: $url');
      };

      await tester.tap(find.text('Resolver operación abandonada'));
      await tester.pumpAndSettle();

      expect(provider.isDoseLocked(100), isFalse);
      expect(provider.hasPendingMarkers, isFalse);
      expect(find.text('Registrar Toma'), findsOneWidget);
      expect(find.textContaining('resultado incierto'), findsNothing);
    });

    testWidgets('7. Corrección legítima genera una clave de idempotencia NUEVA y recibe Dosis directa', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Iniciar con dosis previamente ingerida
      mockRepo.cronograma = const CronogramaDia(
        idTratamiento: 10,
        fecha: '2026-10-01',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          Dosis(
            idDosis: 100,
            idMedicamentoPlan: 1,
            programadaEn: '2026-10-01T12:00:00Z',
            programadaHoraLocal: '08:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'INGERIDA',
            vencida: false,
            efectivaEn: '2026-10-01T12:05:00Z',
            puntual: true,
          ),
        ],
      );

      final capturedKeys = <String>[];
      fakeApi.onPost = (url, {body, headers}) {
        final key = headers?['Idempotency-Key'] as String;
        capturedKeys.add(key);
        if (url.endsWith('/intentos')) {
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'id_dosis': 100,
            'idempotency_key': key,
          };
        } else if (url.endsWith('/registros')) {
          // Contrato real: devuelve directamente el objeto Dosis serializado
          return {
            'id_dosis': 100,
            'id_medicamento_plan': 1,
            'programada_en': '2026-10-01T12:00:00Z',
            'programada_hora_local': '08:00',
            'zona_horaria': 'America/La_Paz',
            'estado': body['estado'],
            'vencida': false,
            'efectiva_en': body['efectiva_en'],
            'nota': body['nota'],
            'puntual': true,
          };
        }
        throw UnimplementedError();
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('Corregir Toma'), findsOneWidget);

      // Abrir modal de corrección
      await tester.tap(find.text('Corregir Toma'));
      await tester.pumpAndSettle();

      expect(find.text('CORRECCIÓN DE TOMA'), findsOneWidget);

      // Seleccionar POSPUESTA
      await tester.tap(find.text('Pospuesta'));
      await tester.pumpAndSettle();

      // Confirmar corrección
      await tester.tap(find.text('Confirmar Corrección'));
      await tester.pumpAndSettle();

      // Verificación: Se enviaron intentos y registros con una clave nueva
      expect(capturedKeys.length, equals(2));
      expect(capturedKeys[0], equals(capturedKeys[1]));
      final correctionKey = capturedKeys[0];
      expect(correctionKey.length, 36); // UUIDv4

      // Verificación adicional: Otra corrección produce OTRA clave distinta
      capturedKeys.clear();
      await tester.tap(find.text('Corregir Toma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Omitida'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Corrección'));
      await tester.pumpAndSettle();

      expect(capturedKeys.length, equals(2));
      final secondCorrectionKey = capturedKeys[0];
      expect(secondCorrectionKey, isNot(equals(correctionKey)));
    });

    testWidgets(
        '8. Cambio de sesión y logout durante operaciones: ninguna respuesta tardía modifica el estado visible de otra cuenta',
        (tester) async {
      final slowCallCompleter = Completer<dynamic>();
      late String userAKey;

      fakeApi.onPost = (url, {body, headers}) {
        if (url.endsWith('/intentos')) {
          userAKey = headers!['Idempotency-Key']!;
          return {
            'estado': 'EN_CURSO',
            'confirmado': false,
            'en_curso': true,
            'id_dosis': 100,
            'idempotency_key': userAKey,
          };
        } else if (url.endsWith('/registros')) {
          // Respuesta lenta retenida en completer
          return slowCallCompleter.future;
        }
        throw UnimplementedError();
      };

      await tester.pumpWidget(buildApp(provider));
      await tester.pumpAndSettle();

      // Usuario A (id: 1, clinica: 5) inicia registro
      await tester.tap(find.text('Registrar Toma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Registro'));
      await tester.pump();

      // Mientras la respuesta de red de Usuario A está pendiente en vuelo:
      // Ocurre cambio de sesión a Usuario B (id: 2, clinica: 9)
      provider.syncAuthSession(
        isAuthenticated: true,
        userId: 2,
        clinicId: 9,
      );

      // Ahora el backend responde tardíamente la petición original de Usuario A
      slowCallCompleter.complete({
        'id_dosis': 100,
        'id_medicamento_plan': 1,
        'programada_en': '2026-11-02T12:00:00Z',
        'programada_hora_local': '08:00',
        'zona_horaria': 'America/La_Paz',
        'estado': 'INGERIDA',
        'vencida': false,
        'efectiva_en': '2026-11-02T12:05:00Z',
        'registrada_en': '2026-11-02T12:06:00Z',
        'puntual': true,
      });

      // Simular que para el Usuario B el cronograma tiene otra toma (idDosis: 200)
      mockRepo.cronograma = const CronogramaDia(
        idTratamiento: 20,
        fecha: '2026-11-02',
        zonaHoraria: 'America/La_Paz',
        dosis: [
          Dosis(
            idDosis: 200,
            idMedicamentoPlan: 2,
            programadaEn: '2026-11-02T16:00:00Z',
            programadaHoraLocal: '12:00',
            zonaHoraria: 'America/La_Paz',
            estado: 'PENDIENTE',
            vencida: false,
          ),
        ],
      );
      await provider.loadCronograma(20);
      await tester.pumpAndSettle();

      // Verificar que los datos en memoria de la sesión anterior fueron descartados
      expect(recoveryService.hasPendingBody(userAKey), isFalse);

      // Verificación crítica: La pantalla del Usuario B NO contiene la dosis de Usuario A (100)
      expect(provider.cronograma?.idTratamiento, equals(20));
      expect(provider.cronograma?.dosis.any((d) => d.idDosis == 100), isFalse);
      expect(provider.cronograma?.dosis.any((d) => d.idDosis == 200), isTrue);
    });
  });
}
