import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/laboratory_result.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/failures/lab_result_failure.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/laboratory_result_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_lab_result_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_lab_results_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/lab_result_file_controller.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/laboratory_results_provider.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/lab_result_viewer_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/lab_results_list_screen.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/services/lab_result_temp_storage.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/widgets/lab_result_status_badge.dart';

// 1x1 PNG válido.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
final Uint8List _pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);

LaboratoryResult _result({
  int id = 1,
  String estudio = 'Hemograma completo',
  LabResultStatus estado = LabResultStatus.incorporado,
  String contentType = 'application/pdf',
  String? observaciones,
}) =>
    LaboratoryResult(
      idResultado: id,
      estado: estado,
      origen: 'MANUAL',
      codigoExamen: 'HEM-01',
      nombreExamen: estudio,
      laboratorioOrigen: 'Laboratorio Central',
      fechaRealizacion: '2026-05-10',
      nombreArchivo: 'resultado_$id.pdf',
      contentType: contentType,
      tamanoBytes: 2048,
      observaciones: observaciones,
    );

LaboratoryResultPage _page(List<LaboratoryResult> items, {int page = 1, int totalPages = 1}) =>
    LaboratoryResultPage(
      items: items,
      total: items.length,
      page: page,
      pageSize: 10,
      totalPages: totalPages,
    );

class _FakeRepo implements LaboratoryResultRepository {
  Future<LaboratoryResultPage> Function(int page)? onList;
  Future<Uint8List> Function(int id)? onDownload;
  final List<int> pagesRequested = [];
  final List<int> downloads = [];

  @override
  Future<LaboratoryResultPage> getMyResults({
    int page = 1,
    int pageSize = 10,
    String? codigoExamen,
    String? fechaDesde,
    String? fechaHasta,
  }) {
    pagesRequested.add(page);
    return onList!(page);
  }

  @override
  Future<Uint8List> downloadFile(int idResultado) {
    downloads.add(idResultado);
    return onDownload!(idResultado);
  }
}

class _FakeStorage implements LabResultTempStorage {
  final List<String> written = [];
  final List<String> deleted = [];
  bool failWrite = false;

  @override
  Future<String> write(Uint8List bytes, String extension) async {
    if (failWrite) throw Exception('disco lleno');
    final path = 'fake_${written.length}.$extension';
    written.add(path);
    return path;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

LaboratoryResultsProvider _provider(_FakeRepo repo) =>
    LaboratoryResultsProvider(getMyResults: GetMyLabResultsUseCase(repository: repo));

LabResultFileController _controller(
  _FakeRepo repo,
  _FakeStorage storage, {
  String? contentType,
}) =>
    LabResultFileController(
      idResultado: 1,
      declaredContentType: contentType,
      download: DownloadLabResultUseCase(repository: repo),
      storage: storage,
    );

void main() {
  group('LaboratoryResultsProvider', () {
    test('estados: initial -> loading -> success con datos', () async {
      final repo = _FakeRepo();
      final completer = Completer<LaboratoryResultPage>();
      repo.onList = (_) => completer.future;
      final provider = _provider(repo);
      expect(provider.status, LabResultsStatus.initial);

      final future = provider.load();
      expect(provider.status, LabResultsStatus.loading);

      completer.complete(_page([_result()]));
      await future;
      expect(provider.status, LabResultsStatus.success);
      expect(provider.items, hasLength(1));
      expect(provider.isEmpty, isFalse);
    });

    test('vacío: success sin items', () async {
      final repo = _FakeRepo()..onList = (_) async => _page([]);
      final provider = _provider(repo);
      await provider.load();
      expect(provider.status, LabResultsStatus.success);
      expect(provider.isEmpty, isTrue);
    });

    test('error: conserva el mensaje del failure y permite reintentar', () async {
      final repo = _FakeRepo()
        ..onList = (_) async => throw const LabResultFailure(
              kind: LabResultFailureKind.network,
              message: 'Sin conexión',
            );
      final provider = _provider(repo);
      await provider.load();
      expect(provider.status, LabResultsStatus.error);
      expect(provider.errorMessage, 'Sin conexión');
      expect(provider.errorKind, LabResultFailureKind.network);

      repo.onList = (_) async => _page([_result()]);
      await provider.load();
      expect(provider.status, LabResultsStatus.success);
      expect(provider.errorMessage, isNull);
    });

    test('error inesperado usa mensaje genérico', () async {
      final repo = _FakeRepo()..onList = (_) async => throw StateError('x');
      final provider = _provider(repo);
      await provider.load();
      expect(provider.status, LabResultsStatus.error);
      expect(provider.errorMessage, isNotEmpty);
    });

    test('paginación: loadMore agrega la siguiente página', () async {
      final repo = _FakeRepo()
        ..onList = (page) async => page == 1
            ? _page([_result(id: 1)], page: 1, totalPages: 2)
            : _page([_result(id: 2)], page: 2, totalPages: 2);
      final provider = _provider(repo);
      await provider.load();
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.items.map((e) => e.idResultado), [1, 2]);
      expect(provider.hasMore, isFalse);
      expect(repo.pagesRequested, [1, 2]);

      await provider.loadMore(); // sin más páginas: no vuelve a llamar
      expect(repo.pagesRequested, [1, 2]);
    });

    test('loadMore con error conserva la lista y expone el error', () async {
      final repo = _FakeRepo()
        ..onList = (page) async => page == 1
            ? _page([_result(id: 1)], page: 1, totalPages: 2)
            : throw const LabResultFailure(kind: LabResultFailureKind.network, message: 'Red caída');
      final provider = _provider(repo);
      await provider.load();
      await provider.loadMore();
      expect(provider.status, LabResultsStatus.success);
      expect(provider.items, hasLength(1));
      expect(provider.loadMoreError, 'Red caída');
    });

    test('respuesta obsoleta de una carga anterior se descarta', () async {
      final repo = _FakeRepo();
      final first = Completer<LaboratoryResultPage>();
      final second = Completer<LaboratoryResultPage>();
      var calls = 0;
      repo.onList = (_) => (++calls == 1) ? first.future : second.future;
      final provider = _provider(repo);

      final f1 = provider.load();
      final f2 = provider.load();
      second.complete(_page([_result(id: 2)]));
      await f2;
      first.complete(_page([_result(id: 1)]));
      await f1;

      expect(provider.items.single.idResultado, 2);
    });
  });

  group('detectLabResultFileKind', () {
    test('detecta PDF, PNG y JPEG por contenido', () {
      expect(detectLabResultFileKind(_pdf), LabResultFileKind.pdf);
      expect(detectLabResultFileKind(_png), LabResultFileKind.image);
      expect(
        detectLabResultFileKind(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])),
        LabResultFileKind.image,
      );
    });

    test('usa content_type declarado como respaldo y rechaza desconocidos', () {
      final raw = Uint8List.fromList([1, 2, 3]);
      expect(detectLabResultFileKind(raw, declaredContentType: 'application/pdf'), LabResultFileKind.pdf);
      expect(detectLabResultFileKind(raw, declaredContentType: 'image/jpeg'), LabResultFileKind.image);
      expect(detectLabResultFileKind(raw, declaredContentType: 'text/html'), LabResultFileKind.unsupported);
      expect(detectLabResultFileKind(raw), LabResultFileKind.unsupported);
    });

    test('el contenido real manda sobre el content_type declarado', () {
      expect(
        detectLabResultFileKind(_png, declaredContentType: 'application/pdf'),
        LabResultFileKind.image,
      );
    });
  });

  group('LabResultFileController', () {
    test('PDF: descarga, guarda temporal y queda ready', () async {
      final repo = _FakeRepo()..onDownload = (_) async => _pdf;
      final storage = _FakeStorage();
      final c = _controller(repo, storage);
      await c.load();
      expect(c.status, LabResultFileStatus.ready);
      expect(c.kind, LabResultFileKind.pdf);
      expect(storage.written.single, endsWith('.pdf'));
      expect(c.filePath, storage.written.single);
      c.dispose();
    });

    test('imagen PNG se guarda con extensión png', () async {
      final repo = _FakeRepo()..onDownload = (_) async => _png;
      final storage = _FakeStorage();
      final c = _controller(repo, storage);
      await c.load();
      expect(c.kind, LabResultFileKind.image);
      expect(storage.written.single, endsWith('.png'));
      c.dispose();
    });

    test('dispose borra el archivo temporal', () async {
      final repo = _FakeRepo()..onDownload = (_) async => _pdf;
      final storage = _FakeStorage();
      final c = _controller(repo, storage);
      await c.load();
      c.dispose();
      expect(storage.deleted, [storage.written.single]);
    });

    test('sin disco: se muestra desde memoria sin fallar', () async {
      final repo = _FakeRepo()..onDownload = (_) async => _pdf;
      final storage = _FakeStorage()..failWrite = true;
      final c = _controller(repo, storage);
      await c.load();
      expect(c.status, LabResultFileStatus.ready);
      expect(c.filePath, isNull);
      expect(c.bytes, isNotNull);
      c.dispose();
    });

    test('error 403 de descarga expone mensaje y tipo', () async {
      final repo = _FakeRepo()
        ..onDownload = (_) async => throw const LabResultFailure(
              kind: LabResultFailureKind.downloadForbidden,
              message: 'Sin permiso de archivo',
            );
      final c = _controller(repo, _FakeStorage());
      await c.load();
      expect(c.status, LabResultFileStatus.error);
      expect(c.errorKind, LabResultFailureKind.downloadForbidden);
      expect(c.errorMessage, 'Sin permiso de archivo');
      c.dispose();
    });

    test('formato no soportado -> error sin escribir archivo', () async {
      final repo = _FakeRepo()..onDownload = (_) async => Uint8List.fromList([1, 2, 3, 4]);
      final storage = _FakeStorage();
      final c = _controller(repo, storage, contentType: 'text/plain');
      await c.load();
      expect(c.status, LabResultFileStatus.error);
      expect(storage.written, isEmpty);
      c.dispose();
    });

    test('descarga que termina tras salir del visor no deja temporales', () async {
      final completer = Completer<Uint8List>();
      final repo = _FakeRepo()..onDownload = (_) => completer.future;
      final storage = _FakeStorage();
      final c = _controller(repo, storage);
      final future = c.load();
      c.dispose(); // el usuario sale antes de que termine
      completer.complete(_pdf);
      await future;
      expect(storage.written, isEmpty);
    });

    test('reintentar tras error descarga de nuevo', () async {
      var attempts = 0;
      final repo = _FakeRepo()
        ..onDownload = (_) async {
          attempts++;
          if (attempts == 1) {
            throw const LabResultFailure(kind: LabResultFailureKind.timeout, message: 'Interrumpida');
          }
          return _pdf;
        };
      final c = _controller(repo, _FakeStorage());
      await c.load();
      expect(c.status, LabResultFileStatus.error);
      await c.load();
      expect(c.status, LabResultFileStatus.ready);
      c.dispose();
    });
  });

  group('LabResultStatusBadge', () {
    testWidgets('muestra texto visible por estado', (tester) async {
      for (final entry in {
        LabResultStatus.incorporado: 'Incorporado',
        LabResultStatus.pendienteRevision: 'Pendiente de revisión',
        LabResultStatus.anulado: 'Anulado',
      }.entries) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: LabResultStatusBadge(status: entry.key))));
        expect(find.text(entry.value), findsOneWidget);
      }
    });
  });

  group('LabResultsListScreen', () {
    Future<void> pumpList(WidgetTester tester, _FakeRepo repo) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LabResultsListScreen(
            repository: repo,
            tempStorage: _FakeStorage(),
            pdfViewerBuilder: (_, _) => const Text('VISOR_PDF'),
          ),
        ),
      );
    }

    testWidgets('loading -> lista con estudio, laboratorio y badge', (tester) async {
      final completer = Completer<LaboratoryResultPage>();
      final repo = _FakeRepo()..onList = (_) => completer.future;
      await pumpList(tester, repo);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_page([_result(), _result(id: 2, estudio: 'Glucosa')]));
      await tester.pumpAndSettle();
      expect(find.text('Hemograma completo'), findsOneWidget);
      expect(find.text('Glucosa'), findsOneWidget);
      expect(find.text('Incorporado'), findsNWidgets(2));
      expect(find.text('10/05/2026'), findsNWidgets(2));
    });

    testWidgets('vacío muestra mensaje y botón Actualizar', (tester) async {
      final repo = _FakeRepo()..onList = (_) async => _page([]);
      await pumpList(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes resultados de laboratorio disponibles.'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
    });

    testWidgets('error muestra mensaje y Reintentar recarga', (tester) async {
      var fail = true;
      final repo = _FakeRepo()
        ..onList = (_) async {
          if (fail) {
            throw const LabResultFailure(
              kind: LabResultFailureKind.sessionExpired,
              message: 'Tu sesión venció.',
            );
          }
          return _page([_result()]);
        };
      await pumpList(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Tu sesión venció.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Hemograma completo'), findsOneWidget);
    });

    testWidgets('pull-to-refresh recarga el listado', (tester) async {
      final repo = _FakeRepo()..onList = (_) async => _page([_result()]);
      await pumpList(tester, repo);
      await tester.pumpAndSettle();
      expect(repo.pagesRequested, [1]);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.pagesRequested.length, 2);
    });

    testWidgets('tocar un resultado abre el visor y descarga su archivo', (tester) async {
      final repo = _FakeRepo();
      repo.onList = (_) async => _page([_result(id: 5)]);
      repo.onDownload = (_) async => _pdf;
      await pumpList(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hemograma completo'));
      await tester.pumpAndSettle();
      expect(repo.downloads, [5]);
      expect(find.text('VISOR_PDF'), findsOneWidget);
    });
  });

  group('LabResultViewerScreen', () {
    Future<void> pumpViewer(
      WidgetTester tester,
      _FakeRepo repo,
      _FakeStorage storage, {
      LaboratoryResult? result,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LabResultViewerScreen(
            result: result ?? _result(observaciones: 'Valores normales'),
            repository: repo,
            tempStorage: storage,
            pdfViewerBuilder: (_, _) => const Text('VISOR_PDF'),
          ),
        ),
      );
    }

    testWidgets('PDF: muestra metadatos, badge y visor', (tester) async {
      final repo = _FakeRepo()..onDownload = (_) async => _pdf;
      await pumpViewer(tester, repo, _FakeStorage());
      await tester.pumpAndSettle();
      expect(find.text('VISOR_PDF'), findsOneWidget);
      expect(find.text('Incorporado'), findsOneWidget);
      expect(find.textContaining('Laboratorio Central'), findsOneWidget);
      expect(find.textContaining('Valores normales'), findsOneWidget);
    });

    testWidgets('sin observaciones (campo oculto) no muestra la línea', (tester) async {
      final repo = _FakeRepo()..onDownload = (_) async => _pdf;
      await pumpViewer(tester, repo, _FakeStorage(), result: _result());
      await tester.pumpAndSettle();
      expect(find.textContaining('Observaciones'), findsNothing);
    });

    testWidgets('imagen PNG se muestra con widget Image (según contenido real)', (tester) async {
      final repo = _FakeRepo()..onDownload = (_) async => _png;
      final storage = _FakeStorage()..failWrite = true; // fuerza Image.memory
      await pumpViewer(tester, repo, storage, result: _result(contentType: 'image/png'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('loading mientras descarga', (tester) async {
      final completer = Completer<Uint8List>();
      final repo = _FakeRepo()..onDownload = (_) => completer.future;
      await pumpViewer(tester, repo, _FakeStorage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Descargando archivo…'), findsOneWidget);
      completer.complete(_pdf);
      await tester.pumpAndSettle();
      expect(find.text('VISOR_PDF'), findsOneWidget);
    });

    testWidgets('403 sin permiso de archivo: mensaje claro y datos del resultado siguen visibles', (tester) async {
      final repo = _FakeRepo()
        ..onDownload = (_) async => throw const LabResultFailure(
              kind: LabResultFailureKind.downloadForbidden,
              message: 'Puedes ver los datos de este resultado, pero tu perfil no tiene permiso para ver ni descargar el archivo.',
            );
      await pumpViewer(tester, repo, _FakeStorage());
      await tester.pumpAndSettle();
      expect(find.textContaining('no tiene permiso para ver ni descargar'), findsOneWidget);
      expect(find.text('Hemograma completo'), findsWidgets);
    });

    testWidgets('404: mensaje y Reintentar descarga de nuevo', (tester) async {
      var attempts = 0;
      final repo = _FakeRepo()
        ..onDownload = (_) async {
          attempts++;
          if (attempts == 1) {
            throw const LabResultFailure(
              kind: LabResultFailureKind.notFound,
              message: 'El resultado o su archivo ya no está disponible.',
            );
          }
          return _pdf;
        };
      await pumpViewer(tester, repo, _FakeStorage());
      await tester.pumpAndSettle();
      expect(find.text('El resultado o su archivo ya no está disponible.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('VISOR_PDF'), findsOneWidget);
    });

    testWidgets('al salir del visor se borra el archivo temporal', (tester) async {
      final repo = _FakeRepo()..onDownload = (_) async => _pdf;
      final storage = _FakeStorage();
      await pumpViewer(tester, repo, storage);
      await tester.pumpAndSettle();
      expect(storage.written, hasLength(1));
      expect(storage.deleted, isEmpty);

      await tester.pumpWidget(const MaterialApp(home: SizedBox())); // sale del visor
      await tester.pumpAndSettle();
      expect(storage.deleted, storage.written);
    });
  });

  group('formatos', () {
    test('formatLabDate y formatLabSize', () {
      expect(formatLabDate('2026-05-10'), '10/05/2026');
      expect(formatLabDate('no-fecha'), 'no-fecha');
      expect(formatLabSize(0), '—');
      expect(formatLabSize(500), '500 B');
      expect(formatLabSize(2048), '2.0 KB');
      expect(formatLabSize(3 * 1024 * 1024), '3.0 MB');
    });
  });
}
