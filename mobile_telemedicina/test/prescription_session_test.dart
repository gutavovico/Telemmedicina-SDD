import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/network/api_exceptions.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/entities/prescription.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/repositories/prescription_repository.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/download_prescription_pdf_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_my_prescriptions_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/domain/usecases/get_prescription_detail_usecase.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/providers/prescription_provider.dart';

Prescription receta(int id) {
  return Prescription(
    idReceta: id,
    idClinica: 1,
    idConsulta: 1,
    idPaciente: 10,
    idMedico: 3,
    folio: 'REC-$id',
    pdfUrl: '/api/v1/recetas/$id/pdf',
    algoritmoFirma: 'ED25519',
    keyId: 'k1',
    versionPayload: 1,
    hashPdf: 'h',
    fechaEmision: '2026-09-22T22:30:00Z',
    fechaVencimiento: '2026-10-22',
    estaVencida: false,
    estado: EstadoReceta.emitida,
    medico: const PrescriptionMedico(
      idMedico: 3,
      nombreCompleto: 'Dr. Test',
      matriculaProfesional: 'MP-1',
    ),
    paciente: const PrescriptionPaciente(idPaciente: 10, nombreCompleto: 'Pac'),
    detalles: const [],
  );
}

class FakeRepo implements PrescriptionRepository {
  Future<PrescriptionPage> Function()? listHandler;
  Future<Prescription> Function(int id)? detailHandler;
  Future<Uint8List> Function(int id)? downloadHandler;

  @override
  Future<PrescriptionPage> getMyPrescriptions({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) {
    return listHandler!();
  }

  @override
  Future<Prescription> getPrescriptionById(int idReceta) {
    return detailHandler!(idReceta);
  }

  @override
  Future<Uint8List> downloadPrescriptionPdf(int idReceta) {
    return downloadHandler!(idReceta);
  }
}

PrescriptionProvider providerWith(
  FakeRepo repo, {
  Future<void> Function()? onSessionExpired,
}) {
  return PrescriptionProvider(
    getMyPrescriptionsUseCase: GetMyPrescriptionsUseCase(repository: repo),
    getDetailUseCase: GetPrescriptionDetailUseCase(repository: repo),
    downloadUseCase: DownloadPrescriptionPdfUseCase(repository: repo),
    onSessionExpired: onSessionExpired,
  );
}

void main() {
  group('Sesión expirada 401 (evento desacoplado)', () {
    test('401 en listado marca sessionExpired e invoca callback', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.listHandler = () async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await p.loadPrescriptions(refresh: true);
      expect(p.listStatus, PrescriptionListStatus.error);
      expect(p.listError, contains('sesión'));
      expect(p.sessionExpired, true);
      expect(calls, 1);
    });

    test('401 en detalle marca sessionExpired', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.detailHandler = (id) async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await p.loadDetail(99);
      expect(p.detailStatus, PrescriptionDetailStatus.error);
      expect(p.detailError, contains('sesión'));
      expect(p.sessionExpired, true);
      expect(calls, 1);
    });

    test('401 en descarga marca sessionExpired y conserva detalle', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.detailHandler = (id) async => receta(id);
      repo.downloadHandler = (id) async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await p.loadDetail(5);
      expect(p.detailStatus, PrescriptionDetailStatus.loaded);
      await p.downloadPdf(5);
      expect(p.downloadStatus, PrescriptionDownloadStatus.error);
      expect(p.downloadError, contains('sesión'));
      expect(p.sessionExpired, true);
      expect(calls, 1);
      expect(p.selected?.idReceta, 5);
      expect(p.detailStatus, PrescriptionDetailStatus.loaded);
    });

    test('una sola invalidación ante 401 concurrentes', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.listHandler = () async {
        throw UnauthorizedException();
      };
      repo.detailHandler = (id) async {
        throw UnauthorizedException();
      };
      repo.downloadHandler = (id) async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await Future.wait([
        p.loadPrescriptions(refresh: true),
        p.loadDetail(1),
        p.downloadPdf(1),
      ]);
      expect(calls, 1);
      expect(p.sessionExpired, true);
    });

    test('403 y 404 no disparan logout ni sessionExpired', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.detailHandler = (id) async {
        throw ForbiddenException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await p.loadDetail(1);
      expect(p.sessionExpired, false);
      expect(calls, 0);

      final repo2 = FakeRepo();
      repo2.detailHandler = (id) async {
        throw NotFoundException();
      };
      final p2 = providerWith(repo2, onSessionExpired: () async => calls++);
      await p2.loadDetail(999);
      expect(p2.detailError, 'La receta solicitada no fue encontrada.');
      expect(p2.sessionExpired, false);
      expect(calls, 0);

      final repo3 = FakeRepo();
      repo3.listHandler = () async {
        throw ForbiddenException();
      };
      final p3 = providerWith(repo3, onSessionExpired: () async => calls++);
      await p3.loadPrescriptions(refresh: true);
      expect(p3.sessionExpired, false);
      expect(calls, 0);
    });

    test('error de red no dispara sesión expirada', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.listHandler = () async {
        throw NetworkException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await p.loadPrescriptions(refresh: true);
      expect(p.sessionExpired, false);
      expect(calls, 0);
      expect(p.listError, contains('conectar'));
    });

    test('coordinador limpia sesión y redirige una sola vez', () async {
      var logoutCalls = 0;
      var navCalls = 0;
      Future<void> fakeInvalidator() async {
        logoutCalls++;
        navCalls++;
      }

      final repo = FakeRepo();
      repo.listHandler = () async {
        throw UnauthorizedException();
      };
      repo.detailHandler = (id) async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: fakeInvalidator);
      await Future.wait([p.loadPrescriptions(refresh: true), p.loadDetail(2)]);
      expect(logoutCalls, 1);
      expect(navCalls, 1);
    });

    test('tres 401 concurrentes generan una sola invalidación', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.listHandler = () async {
        throw UnauthorizedException();
      };
      repo.detailHandler = (id) async {
        throw UnauthorizedException();
      };
      repo.downloadHandler = (id) async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await Future.wait([
        p.loadPrescriptions(refresh: true),
        p.loadDetail(7),
        p.downloadPdf(7),
      ]);
      expect(calls, 1);
      expect(p.sessionExpired, true);
    });

    test(
      '401, éxito concurrente y otro 401 de la misma sesión: sin segunda invalidación',
      () async {
        var calls = 0;
        final repo = FakeRepo();
        repo.listHandler = () async {
          throw UnauthorizedException();
        };
        repo.detailHandler = (id) async => receta(11);
        repo.downloadHandler = (id) async {
          throw UnauthorizedException();
        };
        final p = providerWith(repo, onSessionExpired: () async => calls++);
        // 401 (listado) + éxito (detalle) + 401 (descarga) concurrentes.
        await Future.wait([
          p.loadPrescriptions(refresh: true),
          p.loadDetail(11),
          p.downloadPdf(11),
        ]);
        expect(p.sessionExpired, true);
        expect(calls, 1);
        // El éxito concurrente no limpió el ciclo: el detalle cargó.
        expect(p.detailStatus, PrescriptionDetailStatus.loaded);
        // Otro 401 de la misma sesión no genera una segunda invalidación.
        await p.loadDetail(12);
        repo.detailHandler = (id) async {
          throw UnauthorizedException();
        };
        await p.loadDetail(12);
        expect(calls, 1);
        expect(p.sessionExpired, true);
      },
    );

    test('timeout no dispara sesión expirada', () async {
      var calls = 0;
      final repo = FakeRepo();
      repo.listHandler = () async {
        throw TimeoutException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      await p.loadPrescriptions(refresh: true);
      expect(p.sessionExpired, false);
      expect(calls, 0);
    });

    test(
      'logout + login inicia un nuevo ciclo y el 401 re-invalida una vez',
      () async {
        var calls = 0;
        final repo = FakeRepo();
        repo.listHandler = () async {
          throw UnauthorizedException();
        };
        final p = providerWith(repo, onSessionExpired: () async => calls++);
        await p.loadPrescriptions(refresh: true);
        expect(calls, 1);
        expect(p.sessionExpired, true);

        // Logout: el ciclo se marca no autenticado pero no re-arma el evento.
        p.syncAuthSession(isAuthenticated: false);
        expect(p.sessionExpired, true);
        expect(calls, 1);

        // Login exitoso: evidencia explícita de nueva sesión, re-arma el ciclo.
        p.syncAuthSession(isAuthenticated: true);
        expect(p.sessionExpired, false);

        // Nuevo 401 de la nueva sesión vuelve a limpiar y notificar una vez.
        await p.loadPrescriptions(refresh: true);
        expect(calls, 2);
        expect(p.sessionExpired, true);
      },
    );

    test(
      'nuevo 401 tras login usa detalle+descarga y notifica una sola vez',
      () async {
        var calls = 0;
        final repo = FakeRepo();
        repo.listHandler = () async {
          throw UnauthorizedException();
        };
        repo.detailHandler = (id) async {
          throw UnauthorizedException();
        };
        repo.downloadHandler = (id) async {
          throw UnauthorizedException();
        };
        final p = providerWith(repo, onSessionExpired: () async => calls++);
        await p.loadPrescriptions(refresh: true);
        expect(calls, 1);

        p.syncAuthSession(isAuthenticated: false);
        p.syncAuthSession(isAuthenticated: true);
        expect(p.sessionExpired, false);

        await Future.wait([p.loadDetail(9), p.downloadPdf(9)]);
        expect(calls, 2);
        expect(p.sessionExpired, true);
      },
    );

    test('401 después de dispose no notifica ni invoca callback', () async {
      var calls = 0;
      var notifies = 0;
      final repo = FakeRepo();
      repo.listHandler = () async {
        throw UnauthorizedException();
      };
      final p = providerWith(repo, onSessionExpired: () async => calls++);
      p.addListener(() => notifies++);
      p.dispose();
      final notifiesAtDispose = notifies;
      await p.loadPrescriptions(refresh: true);
      p.syncAuthSession(isAuthenticated: true);
      expect(calls, 0);
      expect(notifies, notifiesAtDispose);
      expect(p.sessionExpired, false);
    });
  });
}
