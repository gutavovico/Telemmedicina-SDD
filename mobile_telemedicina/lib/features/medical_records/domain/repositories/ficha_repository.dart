import '../entities/ficha_entity.dart';

abstract class FichaRepository {
  Future<List<FichaEntity>> getFichas({int? idPaciente, String? fecha, String? estado});
  Future<FichaEntity> getFichaById(String idFicha);
  Future<FichaEntity> createFicha(Map<String, dynamic> data);
  Future<FichaEntity> cancelFicha(String idFicha, String motivo);
}
