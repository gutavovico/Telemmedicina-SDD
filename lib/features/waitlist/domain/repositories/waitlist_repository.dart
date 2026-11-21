import '../../data/models/waitlist_models.dart';

abstract class WaitlistRepository {
  Future<List<InscripcionEsperaModel>> getMisInscripciones();

  Future<InscripcionEsperaModel> inscribirse({
    int? idMedico,
    int? idEspecialidad,
    String? fechaDeseada,
    String? motivo,
  });

  Future<InscripcionEsperaModel> salir(int id);

  Future<InscripcionEsperaModel> confirmar(int id);

  Future<InscripcionEsperaModel> rechazar(int id);
}
