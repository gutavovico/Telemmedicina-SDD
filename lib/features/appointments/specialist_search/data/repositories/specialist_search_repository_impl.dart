import '../../domain/entities/specialist_search_entities.dart';
import '../../domain/repositories/specialist_search_repository.dart';
import '../datasources/specialist_search_remote_datasource.dart';
import '../models/specialist_search_models.dart';

class SpecialistSearchRepositoryImpl implements SpecialistSearchRepository {
  final SpecialistSearchRemoteDataSource _remoteDataSource;

  SpecialistSearchRepositoryImpl({
    SpecialistSearchRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ?? SpecialistSearchRemoteDataSource();

  @override
  Future<List<SpecialistSpecialtyOptionEntity>> getSpecialties() {
    return _remoteDataSource.getSpecialties();
  }

  @override
  Future<SpecialistSearchResponseEntity> searchSpecialists(
    SpecialistSearchFilterParams filters,
  ) {
    return _remoteDataSource.searchSpecialists(filters);
  }

  @override
  Future<SpecialistEntity> getSpecialistAvailability(
    int idMedico,
    String fechaInicio,
    String fechaFin, {
    int? idServicio,
  }) {
    return _remoteDataSource.getSpecialistAvailability(
      idMedico,
      fechaInicio,
      fechaFin,
      idServicio: idServicio,
    );
  }
}
