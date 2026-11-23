import '../../data/repositories/prescription_repository_impl.dart';
import '../entities/prescription.dart';
import '../repositories/prescription_repository.dart';

/// Caso de uso: consultar el detalle estructurado de una receta propia.
class GetPrescriptionDetailUseCase {
  final PrescriptionRepository _repository;

  GetPrescriptionDetailUseCase({PrescriptionRepository? repository})
    : _repository = repository ?? PrescriptionRepositoryImpl();

  Future<Prescription> call(int idReceta) {
    return _repository.getPrescriptionById(idReceta);
  }
}
