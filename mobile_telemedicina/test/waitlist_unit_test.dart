import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/waitlist/data/models/waitlist_models.dart';
import 'package:mobile_telemedicina/features/waitlist/domain/repositories/waitlist_repository.dart';
import 'package:mobile_telemedicina/features/waitlist/presentation/providers/waitlist_provider.dart';

class _FakeWaitlistRepository implements WaitlistRepository {
  List<InscripcionEsperaModel> inscripciones;
  String? ultimoMedico;
  int? confirmado;
  int? rechazado;
  int? salido;

  _FakeWaitlistRepository(this.inscripciones);

  @override
  Future<List<InscripcionEsperaModel>> getMisInscripciones() async => inscripciones;

  @override
  Future<InscripcionEsperaModel> inscribirse({
    int? idMedico,
    int? idEspecialidad,
    String? fechaDeseada,
    String? motivo,
  }) async {
    ultimoMedico = idMedico?.toString();
    final nueva = InscripcionEsperaModel(
      idListaEspera: 99,
      idPaciente: 4,
      pacienteNombre: 'Ana Pérez',
      idMedico: idMedico,
      idEspecialidad: idEspecialidad,
      fechaDeseada: fechaDeseada,
      estado: 'EN_ESPERA',
      prioridad: 0,
      posicion: 2,
      motivo: motivo,
    );
    inscripciones = [...inscripciones, nueva];
    return nueva;
  }

  @override
  Future<InscripcionEsperaModel> salir(int id) async {
    salido = id;
    return InscripcionEsperaModel(
      idListaEspera: id,
      idPaciente: 4,
      pacienteNombre: 'Ana Pérez',
      estado: 'CANCELADO',
      prioridad: 0,
      posicion: 0,
    );
  }

  @override
  Future<InscripcionEsperaModel> confirmar(int id) async {
    confirmado = id;
    return InscripcionEsperaModel(
      idListaEspera: id,
      idPaciente: 4,
      pacienteNombre: 'Ana Pérez',
      estado: 'CONFIRMADO',
      prioridad: 0,
      posicion: 0,
    );
  }

  @override
  Future<InscripcionEsperaModel> rechazar(int id) async {
    rechazado = id;
    return InscripcionEsperaModel(
      idListaEspera: id,
      idPaciente: 4,
      pacienteNombre: 'Ana Pérez',
      estado: 'RECHAZADO',
      prioridad: 0,
      posicion: 0,
    );
  }
}

InscripcionEsperaModel _entrada({
  required int id,
  required String estado,
  int posicion = 1,
}) =>
    InscripcionEsperaModel(
      idListaEspera: id,
      idPaciente: 4,
      pacienteNombre: 'Ana Pérez',
      idMedico: 20,
      medicoNombre: 'Roberto Gómez',
      idEspecialidad: 10,
      especialidadNombre: 'Cardiología',
      estado: estado,
      prioridad: 0,
      posicion: posicion,
    );

void main() {
  group('CU07 WaitlistProvider', () {
    test('carga inscripciones desde el repositorio', () async {
      final repo = _FakeWaitlistRepository([_entrada(id: 1, estado: 'EN_ESPERA')]);
      final provider = WaitlistProvider(repository: repo);

      await provider.cargar();

      expect(provider.status, WaitlistStatus.success);
      expect(provider.inscripciones, hasLength(1));
      expect(provider.inscripciones.first.posicion, 1);
    });

    test('inscribirse usa los datos precargados de la búsqueda de especialistas', () async {
      final repo = _FakeWaitlistRepository([]);
      final provider = WaitlistProvider(repository: repo);
      provider.prepararInscripcion(
        idMedico: 20,
        idEspecialidad: 10,
        nombreMedico: 'Roberto Gómez',
      );

      final ok = await provider.inscribirse(fechaDeseada: '2026-12-01', motivo: 'Sin cupos');

      expect(ok, isTrue);
      expect(repo.ultimoMedico, '20');
      expect(provider.inscripciones, hasLength(1));
      expect(provider.idMedico, isNull);
    });

    test('rechaza inscribirse sin médico ni especialidad', () async {
      final provider = WaitlistProvider(repository: _FakeWaitlistRepository([]));
      final ok = await provider.inscribirse();
      expect(ok, isFalse);
      expect(provider.status, WaitlistStatus.error);
    });

    test('confirma y rechaza un turno ofrecido', () async {
      final repo = _FakeWaitlistRepository([_entrada(id: 5, estado: 'OFRECIDO')]);
      final provider = WaitlistProvider(repository: repo);

      expect(await provider.confirmar(5), isTrue);
      expect(repo.confirmado, 5);
      expect(await provider.rechazar(5), isTrue);
      expect(repo.rechazado, 5);
    });

    test('salir de la lista actualiza el estado', () async {
      final repo = _FakeWaitlistRepository([_entrada(id: 7, estado: 'EN_ESPERA')]);
      final provider = WaitlistProvider(repository: repo);

      expect(await provider.salir(7), isTrue);
      expect(repo.salido, 7);
    });

    test('el modelo tolera snake_case y expone etiquetas', () {
      final entrada = InscripcionEsperaModel.fromJson({
        'id_lista_espera': 10,
        'id_paciente': 4,
        'paciente_nombre': 'Ana Pérez',
        'id_medico': 20,
        'medico_nombre': 'Roberto Gómez',
        'id_especialidad': 10,
        'especialidad_nombre': 'Cardiología',
        'fecha_deseada': '2026-12-01',
        'estado': 'OFRECIDO',
        'prioridad': 0,
        'posicion': 1,
        'id_cita_ofrecida': 77,
      });
      expect(entrada.idListaEspera, 10);
      expect(entrada.idCitaOfrecida, 77);
      expect(entrada.fueOfrecido, isTrue);
      expect(entrada.etiquetaEstado, 'Turno ofrecido');
    });
  });
}
