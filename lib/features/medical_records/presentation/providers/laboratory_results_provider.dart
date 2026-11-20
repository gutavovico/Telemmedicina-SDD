import 'package:flutter/foundation.dart';

import '../../domain/entities/laboratory_result.dart';
import '../../domain/failures/lab_result_failure.dart';
import '../../domain/usecases/get_my_lab_results_usecase.dart';

enum LabResultsStatus { initial, loading, success, error }

/// Estado de la lista de resultados de laboratorio del paciente (CU11, solo lectura).
/// Provider propio: no comparte estado con `ClinicalDocumentsProvider` (CU12).
class LaboratoryResultsProvider extends ChangeNotifier {
  final GetMyLabResultsUseCase _getMyResults;
  final int pageSize;

  LaboratoryResultsProvider({GetMyLabResultsUseCase? getMyResults, this.pageSize = 10})
      : _getMyResults = getMyResults ?? GetMyLabResultsUseCase();

  LabResultsStatus _status = LabResultsStatus.initial;
  List<LaboratoryResult> _items = const [];
  String? _errorMessage;
  LabResultFailureKind? _errorKind;
  int _page = 0;
  int _totalPages = 0;
  int _total = 0;
  bool _isLoadingMore = false;
  String? _loadMoreError;
  int _requestToken = 0;
  bool _disposed = false;

  LabResultsStatus get status => _status;
  List<LaboratoryResult> get items => _items;
  String? get errorMessage => _errorMessage;
  LabResultFailureKind? get errorKind => _errorKind;
  int get total => _total;
  bool get isLoading => _status == LabResultsStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  String? get loadMoreError => _loadMoreError;
  bool get hasMore => _page > 0 && _page < _totalPages;
  bool get isEmpty => _status == LabResultsStatus.success && _items.isEmpty;

  /// Carga la primera página (también usada por pull-to-refresh y "Reintentar").
  Future<void> load() async {
    final token = ++_requestToken;
    _status = LabResultsStatus.loading;
    _errorMessage = null;
    _errorKind = null;
    _loadMoreError = null;
    _isLoadingMore = false;
    _notify();

    try {
      final result = await _getMyResults(page: 1, pageSize: pageSize);
      if (token != _requestToken) return; // respuesta obsoleta
      _items = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
      _total = result.total;
      _status = LabResultsStatus.success;
    } catch (error) {
      if (token != _requestToken) return;
      _applyError(error);
      _items = const [];
      _page = 0;
      _totalPages = 0;
      _total = 0;
      _status = LabResultsStatus.error;
    }
    _notify();
  }

  /// Carga la página siguiente y la agrega a la lista.
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore || _status != LabResultsStatus.success) return;
    final token = _requestToken;
    _isLoadingMore = true;
    _loadMoreError = null;
    _notify();

    try {
      final result = await _getMyResults(page: _page + 1, pageSize: pageSize);
      if (token != _requestToken) return;
      _items = [..._items, ...result.items];
      _page = result.page;
      _totalPages = result.totalPages;
      _total = result.total;
    } catch (error) {
      if (token != _requestToken) return;
      _loadMoreError = error is LabResultFailure
          ? error.message
          : 'No se pudo cargar más resultados.';
    }
    _isLoadingMore = false;
    _notify();
  }

  void _applyError(Object error) {
    if (error is LabResultFailure) {
      _errorMessage = error.message;
      _errorKind = error.kind;
    } else {
      _errorMessage = 'No se pudieron cargar tus resultados de laboratorio.';
      _errorKind = LabResultFailureKind.unknown;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
