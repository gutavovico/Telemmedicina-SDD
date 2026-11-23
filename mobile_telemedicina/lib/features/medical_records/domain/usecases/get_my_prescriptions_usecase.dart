import '../../data/repositories/prescription_repository_impl.dart';
import '../entities/prescription.dart';
import '../repositories/prescription_repository.dart';

/// Caso de uso: listar recetas propias del paciente autenticado.
class GetMyPrescriptionsUseCase {
  final PrescriptionRepository _repository;

  GetMyPrescriptionsUseCase({PrescriptionRepository? repository})
    : _repository = repository ?? PrescriptionRepositoryImpl();

  Future<PrescriptionPage> call({
    String? estado,
    String? desde,
    String? hasta,
    int skip = 0,
    int limit = 20,
  }) {
    return _repository.getMyPrescriptions(
      estado: estado,
      desde: desde,
      hasta: hasta,
      skip: skip,
      limit: limit,
    );
  }
}
