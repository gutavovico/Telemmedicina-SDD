import '../../data/models/cola_models.dart';

abstract class ColaRepository {
  Future<MiTurnoModel> getMiTurno();
  Future<ColaOperativaModel> getColaOperativa({int? idMedico, String? fecha});
  Future<ColaOperativaModel> avanzar(int idCita);
  Future<ColaOperativaModel> marcarPerdida(int idCita);
  Future<void> registrarPausa({
    required int idMedico,
    required String fecha,
    required String horaInicio,
    required String horaFin,
    required String motivo,
  });
}
