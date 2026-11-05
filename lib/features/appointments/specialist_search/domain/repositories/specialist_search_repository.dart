import '../../domain/entities/specialist_search_entities.dart';
import '../../data/models/specialist_search_models.dart';

abstract class SpecialistSearchRepository {
  Future<List<SpecialistSpecialtyOptionEntity>> getSpecialties();

  Future<SpecialistSearchResponseEntity> searchSpecialists(
    SpecialistSearchFilterParams filters,
  );

  Future<SpecialistEntity> getSpecialistAvailability(
    int idMedico,
    String fechaInicio,
    String fechaFin, {
    int? idServicio,
  });
}
