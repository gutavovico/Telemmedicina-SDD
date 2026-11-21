import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/core/theme/app_theme.dart';
import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/communications/presentation/providers/notificacion_provider.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/home_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/mis_recetas_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/receta_detail_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/services/prescription_pdf_sharer.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/widgets/prescription_status_badge.dart';

class _TestAuthController extends AuthController {
  final UserModel user;

  _TestAuthController(String role)
    : user = UserModel(
        idUsuario: 1,
        nombres: 'Usuario',
        apellidos: 'Prueba',
        correo: 'usuario@hospital.com',
        rolNombre: role,
      );

  @override
  UserModel? get currentUser => user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isPatient => user.isPatient;
}

PrescriptionDetalle _detalle({
  int posicion = 1,
  String nombre = 'Amoxicilina',
  String? principio = 'Amoxicilina',
  String? concentracion = '500 mg',
}) {
  return PrescriptionDetalle(
    idRecetaDetalle: posicion,
    medicamentoNombre: nombre,
    principioActivo: principio,
    concentracion: concentracion,
    dosis: '500 mg',
    frecuencia: 'Cada 8 horas',
    duracion: '7 días',
    viaAdministracion: 'ORAL',
    cantidad: 21,
    indicaciones: 'Tomar después de las comidas',
    posicion: posicion,
  );
}

Prescription _receta({
  int id = 58,
  String folio = 'REC-2026-000058',
  EstadoReceta estado = EstadoReceta.emitida,
  bool vencida = false,
  String? especialidad = 'Medicina General',
  List<PrescriptionDetalle>? detalles,
}) {
  return Prescription(
    idReceta: id,
    idClinica: 1,
    idConsulta: 45,
    idPaciente: 10,
    idMedico: 3,
    idDocumento: 210,
    folio: folio,
    pdfUrl: '/api/v1/recetas/$id/pdf',
    indicacionesGenerales: 'Mantener hidratación y reposo.',
    algoritmoFirma: 'ED25519',
    keyId: 'prescriptions-2026-01',
    versionPayload: 1,
    hashPdf: 'abc123',
    fechaEmision: '2026-09-22T22:30:00Z',
    fechaVencimiento: '2026-10-22',
    estaVencida: vencida,
    estado: estado,
    motivoAnulacion: estado == EstadoReceta.anulada
        ? 'Error de prescripción'
        : null,
    observacionesAnulacion: estado == EstadoReceta.anulada
        ? 'Se emitirá nueva receta'
        : null,
    fechaAnulacion: estado == EstadoReceta.anulada
        ? '2026-09-23T10:00:00Z'
        : null,
    medico: PrescriptionMedico(
      idMedico: 3,
      nombreCompleto: 'Dr. Carlos Fernández Mendoza',
      matriculaProfesional: 'MP-84920-SC',
      especialidad: especialidad,
    ),
    paciente: const PrescriptionPaciente(
      idPaciente: 10,
      nombreCompleto: 'María Reneé Morales',
    ),
    detalles: detalles ?? [_detalle()],
  );
}

class FakeRepo implements PrescriptionRepository {
  List<Prescription> listItems = [];
  int total = 0;
  Prescription? detail;
  Object? listError;
  Object? detailError;
  Uint8List downloadBytes = Uint8List.fromList([37, 80, 68, 70]);

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) async {
    if (listError != null) throw listError!;
    return PrescriptionPage(
      items: listItems,
      total: total,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) async {
    if (detailError != null) throw detailError!;
    return detail ?? _receta(id: idReceta);
  }

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) async =>
      downloadBytes;
}

PrescriptionProvider _providerWith(FakeRepo repo) => PrescriptionProvider(
  getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
  getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
  downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
);

Widget _wrap(Widget child, PrescriptionProvider provider) {
  return ChangeNotifierProvider<PrescriptionProvider>.value(
    value: provider,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  group('MisRecetasScreen widgets', () {
    testWidgets('listado con datos muestra folio/medico/fechas/badge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = FakeRepo()
        ..listItems = [_receta(), _receta(id: 59, folio: 'REC-2026-000059')]
        ..total = 2;
      final provider = _providerWith(repo);

      await tester.pumpWidget(_wrap(const MisRecetasScreen(), provider));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('REC-2026-000058'), findsOneWidget);
      expect(find.text('REC-2026-000059'), findsOneWidget);
      expect(find.text('Dr. Carlos Fernández Mendoza'), findsWidgets);
      expect(find.text('Medicina General'), findsWidgets);
      expect(find.text('22/09/2026'), findsWidgets);
      expect(find.text('22/10/2026'), findsWidgets);
      expect(find.text('Vigente'), findsWidgets);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('estado vacío informativo', (tester) async {
      final repo = FakeRepo()
        ..listItems = []
        ..total = 0;
      final provider = _providerWith(repo);

      await tester.pumpWidget(_wrap(const MisRecetasScreen(), provider));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aún no tienes recetas registradas.'), findsOneWidget);
    });

    testWidgets('estado de error recuperable con reintentar', (tester) async {
      final repo = FakeRepo()..listError = Exception('fallo de red simulado');
      final provider = _providerWith(repo);

      await tester.pumpWidget(_wrap(const MisRecetasScreen(), provider));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('badge vencida usa texto e icono', (tester) async {
      final repo = FakeRepo()
        ..listItems = [_receta(vencida: true)]
        ..total = 1;
      final provider = _providerWith(repo);

      await tester.pumpWidget(_wrap(const MisRecetasScreen(), provider));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Vencida'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byType(PrescriptionStatusBadge), findsOneWidget);
    });

    testWidgets('sin overflow en pantalla pequeña 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = FakeRepo()
        ..listItems = [_receta()]
        ..total = 1;
      final provider = _providerWith(repo);

      await tester.pumpWidget(_wrap(const MisRecetasScreen(), provider));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // Accesibilidad: tarjetas anunciables.
      expect(
        find.bySemanticsLabel(RegExp('Receta REC-2026-000058')),
        findsOneWidget,
      );
    });
  });

  group('RecetaDetailScreen widgets', () {
    testWidgets('detalle estructurado con medicamentos y descarga', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = FakeRepo()
        ..detail = _receta(
          detalles: [
            _detalle(posicion: 2, nombre: 'Ibuprofeno'),
            _detalle(posicion: 1, nombre: 'Amoxicilina'),
          ],
        );
      final provider = _providerWith(repo);

      await tester.pumpWidget(
        _wrap(
          RecetaDetailScreen(
            idReceta: 58,
            sharer: InMemoryPrescriptionPdfSharer(),
          ),
          provider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('REC-2026-000058'), findsOneWidget);
      expect(find.text('Vigente'), findsOneWidget);
      expect(find.text('MP-84920-SC'), findsOneWidget);
      expect(find.text('Medicina General'), findsOneWidget);
      // Orden ascendente por posicion: Amoxicilina (1) antes que Ibuprofeno (2).
      final amox = tester.getTopLeft(find.text('Amoxicilina'));
      final ibu = tester.getTopLeft(find.text('Ibuprofeno'));
      expect(amox.dy < ibu.dy, true);
      expect(find.textContaining('Dosis: 500 mg'), findsWidgets);
      expect(find.textContaining('Cada 8 horas'), findsWidgets);
      expect(find.textContaining('Cantidad: 21'), findsWidgets);
      expect(find.textContaining('Mantener hidratación'), findsOneWidget);
      expect(find.text('Descargar PDF'), findsOneWidget);
      // Integridad colapsable presente.
      expect(find.text('Datos de integridad'), findsOneWidget);
      // Sin acciones de mutación.
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Anular'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);
    });

    testWidgets('receta anulada muestra motivo y observaciones', (
      tester,
    ) async {
      final repo = FakeRepo()..detail = _receta(estado: EstadoReceta.anulada);
      final provider = _providerWith(repo);

      await tester.pumpWidget(
        _wrap(
          RecetaDetailScreen(
            idReceta: 58,
            sharer: InMemoryPrescriptionPdfSharer(),
          ),
          provider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Anulada'), findsWidgets);
      expect(find.text('Receta anulada'), findsOneWidget);
      expect(find.text('Error de prescripción'), findsOneWidget);
      expect(find.text('Se emitirá nueva receta'), findsOneWidget);
    });

    testWidgets('descarga fallida conserva el detalle visible', (tester) async {
      final repo = FakeRepo()
        ..detail = _receta()
        ..downloadBytes = Uint8List(0);
      final provider = _providerWith(repo);

      await tester.pumpWidget(
        _wrap(
          RecetaDetailScreen(
            idReceta: 58,
            sharer: InMemoryPrescriptionPdfSharer(),
          ),
          provider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('REC-2026-000058'), findsOneWidget);

      await tester.tap(find.text('Descargar PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El detalle sigue visible y aparece el error recuperable.
      expect(find.text('REC-2026-000058'), findsOneWidget);
      expect(find.textContaining('vacío'), findsWidgets);
    });

    testWidgets('botón descarga tiene área táctil mínima y semántica', (
      tester,
    ) async {
      final repo = FakeRepo()..detail = _receta();
      final provider = _providerWith(repo);

      await tester.pumpWidget(
        _wrap(
          RecetaDetailScreen(
            idReceta: 58,
            sharer: InMemoryPrescriptionPdfSharer(),
          ),
          provider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.getSize(find.byType(ElevatedButton).first);
      expect(button.height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel('Descargar PDF de la receta REC-2026-000058'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Navegación desde Home', () {
    testWidgets('Home expone tarjeta Mis recetas hacia /recetas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 2560);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(
              create: (_) => _TestAuthController('PACIENTE'),
            ),
            ChangeNotifierProvider(
              create: (_) => NotificacionProvider(habilitarPolling: false),
            ),
            ChangeNotifierProvider(
              create: (_) => _providerWith(
                FakeRepo()
                  ..listItems = []
                  ..total = 0,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
            routes: {'/recetas': (context) => const MisRecetasScreen()},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mis recetas'), findsOneWidget);
      expect(find.text('Documentos'), findsOneWidget);
      await tester.tap(find.text('Mis recetas'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mis recetas'), findsWidgets);
    });

    testWidgets('Home oculta recetas y documentos para ADMIN y MEDICO', (
      tester,
    ) async {
      for (final role in ['ADMIN', 'MEDICO']) {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>(
                create: (_) => _TestAuthController(role),
              ),
              ChangeNotifierProvider(
                create: (_) => NotificacionProvider(habilitarPolling: false),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        expect(find.text('Mis recetas'), findsNothing);
        expect(find.text('Documentos'), findsNothing);
        expect(find.text('Mi Expediente'), findsNothing);
      }
    });
  });
}
