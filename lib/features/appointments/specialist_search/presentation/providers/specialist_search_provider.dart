import 'package:flutter/foundation.dart';
import '../../data/models/specialist_search_models.dart';
import '../../domain/entities/specialist_search_entities.dart';
import '../../domain/repositories/specialist_search_repository.dart';

enum SpecialistSearchStatus { initial, loading, success, error }

class SpecialistSearchProvider extends ChangeNotifier {
  final SpecialistSearchRepository _repository;

  SpecialistSearchStatus _status = SpecialistSearchStatus.initial;
  SpecialistSearchResponseEntity? _response;
  List<SpecialistSpecialtyOptionEntity> _specialties = [];
  String? _errorMessage;
  SpecialistSearchFilterParams? _currentFilters;
  int _latestRequestId = 0;

  SpecialistSearchProvider({required SpecialistSearchRepository repository})
    : _repository = repository;

  SpecialistSearchStatus get status => _status;
  SpecialistSearchResponseEntity? get response => _response;
  List<SpecialistEntity> get items => _response?.items ?? [];
  List<SpecialistSpecialtyOptionEntity> get specialties => _specialties;
  int get total => _response?.total ?? 0;
  String? get errorMessage => _errorMessage;
  SpecialistSearchFilterParams? get currentFilters => _currentFilters;

  bool get isInitial => _status == SpecialistSearchStatus.initial;
  bool get isLoading => _status == SpecialistSearchStatus.loading;
  bool get isSuccess => _status == SpecialistSearchStatus.success;
  bool get isError => _status == SpecialistSearchStatus.error;

  Future<void> loadSpecialties() async {
    try {
      _specialties = await _repository.getSpecialties();
      notifyListeners();
    } catch (_) {
      // El filtro de especialidad es opcional; la búsqueda principal no depende de él.
    }
  }

  Future<void> search(SpecialistSearchFilterParams filters) async {
    _currentFilters = filters;
    _status = SpecialistSearchStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final requestId = ++_latestRequestId;

    try {
      final res = await _repository.searchSpecialists(filters);
      if (requestId == _latestRequestId) {
        _response = res;
        _status = SpecialistSearchStatus.success;
        notifyListeners();
      }
    } catch (e) {
      if (requestId == _latestRequestId) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _status = SpecialistSearchStatus.error;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    if (_currentFilters != null) {
      await search(_currentFilters!);
    }
  }

  void clear() {
    _status = SpecialistSearchStatus.initial;
    _response = null;
    _errorMessage = null;
    _currentFilters = null;
    _latestRequestId++;
    notifyListeners();
  }
}
