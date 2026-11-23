import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/auth/data/models/auth_models.dart';
import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/clinical_document.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/clinical_document_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_documents_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_tenant_documents_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/clinical_documents_provider.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/documents_list_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/lab_results_list_screen.dart';
import 'package:provider/provider.dart';

/// Repositorio CU12 simulado: solo el listado, sin red.
class _FakeDocsRepo implements ClinicalDocumentRepository {
  final List<String?> tiposSolicitados = [];

  static const _vacio = DocumentoPaginado(
    items: [],
    total: 0,
    page: 1,
    pageSize: 20,
    totalPages: 1,
  );

  @override
  Future<DocumentoPaginado> getMyDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
  }) async {
    tiposSolicitados.add(tipoDocumento);
    return _vacio;
  }

  @override
  Future<DocumentoPaginado> getTenantDocuments({
    int page = 1,
    int pageSize = 20,
    String? tipoDocumento,
    String? q,
    int? idPaciente,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    tiposSolicitados.add(tipoDocumento);
    return _vacio;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PatientAuth extends AuthController {
  final UserModel user = UserModel(
    idUsuario: 1,
    nombres: 'Paciente',
    apellidos: 'Prueba',
    correo: 'paciente@hospital.com',
    rolNombre: 'PACIENTE',
  );

  @override
  UserModel? get currentUser => user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isPatient => true;
}

Future<_FakeDocsRepo> _pumpDocs(WidgetTester tester) async {
  final repo = _FakeDocsRepo();
  final provider = ClinicalDocumentsProvider(
    getMyDocumentsUseCase: GetMyDocumentsUseCase(repository: repo),
    getTenantDocumentsUseCase: GetTenantDocumentsUseCase(repository: repo),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: _PatientAuth()),
        ChangeNotifierProvider<ClinicalDocumentsProvider>.value(value: provider),
      ],
      child: const MaterialApp(home: DocumentsListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('chip "Resultados de Lab." navega a la pantalla CU11 y no filtra por CU12', (tester) async {
    final repo = await _pumpDocs(tester);
    final llamadasAntes = repo.tiposSolicitados.length;

    await tester.tap(find.text('Resultados de Lab.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LabResultsListScreen), findsOneWidget);
    expect(find.text('Resultados de Laboratorio'), findsOneWidget);
    // CU12 no cambió de filtro ni volvió a consultar con RESULTADO_LAB.
    expect(repo.tiposSolicitados.length, llamadasAntes);
    expect(repo.tiposSolicitados, isNot(contains('RESULTADO_LAB')));
  });

  testWidgets('los demás chips siguen filtrando como en CU12', (tester) async {
    final repo = await _pumpDocs(tester);

    await tester.tap(find.text('Recetas'));
    await tester.pumpAndSettle();

    expect(find.byType(LabResultsListScreen), findsNothing);
    expect(repo.tiposSolicitados.last, 'RECETA');
  });
}
