import 'package:flutter/material.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../data/repositories/ficha_repository_impl.dart';
import '../../domain/entities/ficha_entity.dart';
import '../../domain/usecases/cancel_ficha_usecase.dart';
import '../../domain/usecases/create_ficha_usecase.dart';
import '../../domain/usecases/get_patient_fichas_usecase.dart';

class FichaProvider extends ChangeNotifier {
  final GetPatientFichasUseCase _getPatientFichasUseCase;
  final CreateFichaUseCase _createFichaUseCase;
  final CancelFichaUseCase _cancelFichaUseCase;

  FichaProvider({
    GetPatientFichasUseCase? getPatientFichasUseCase,
    CreateFichaUseCase? createFichaUseCase,
    CancelFichaUseCase? cancelFichaUseCase,
  })  : _getPatientFichasUseCase =
            getPatientFichasUseCase ?? GetPatientFichasUseCase(FichaRepositoryImpl()),
        _createFichaUseCase =
            createFichaUseCase ?? CreateFichaUseCase(FichaRepositoryImpl()),
        _cancelFichaUseCase =
            cancelFichaUseCase ?? CancelFichaUseCase(FichaRepositoryImpl());

  List<FichaEntity> _fichas = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isConflict = false;
  String _statusFilter = 'TODOS';
  String _searchQuery = '';

  List<FichaEntity> get fichas => _fichas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isConflict => _isConflict;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<FichaEntity> get filteredFichas {
    return _fichas.where((f) {
      final matchesStatus = _statusFilter == 'TODOS' || f.estado == _statusFilter;
      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          f.correlativo.toLowerCase().contains(q) ||
          (f.medicoNombre?.toLowerCase().contains(q) ?? false) ||
          (f.especialidadNombre?.toLowerCase().contains(q) ?? false) ||
          f.motivoConsulta.toLowerCase().contains(q);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _isConflict = false;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchFichas({int? idPaciente, String? fecha, String? estado}) async {
    _isLoading = true;
    _errorMessage = null;
    _isConflict = false;
    notifyListeners();

    try {
      _fichas = await _getPatientFichasUseCase(
        idPaciente: idPaciente,
        fecha: fecha,
        estado: estado,
      );
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado al cargar las fichas clínicas.';
      notifyListeners();
    }
  }

  Future<FichaEntity?> createFicha(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _isConflict = false;
    notifyListeners();

    try {
      final nuevaFicha = await _createFichaUseCase(data);
      _fichas.insert(0, nuevaFicha);
      _isLoading = false;
      _successMessage = 'Ficha clínica #${nuevaFicha.correlativo} emitida con éxito.';
      notifyListeners();
      return nuevaFicha;
    } on ConflictException catch (e) {
      _isLoading = false;
      _isConflict = true;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      _isLoading = false;
      if (e.statusCode == 409) {
        _isConflict = true;
      }
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error al emitir la ficha: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancelFicha(String idFicha, String motivo) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _cancelFichaUseCase(idFicha, motivo);
      final index = _fichas.indexWhere((f) => f.idFicha == idFicha);
      if (index != -1) {
        _fichas[index] = updated;
      }
      _isLoading = false;
      _successMessage = 'Ficha cancelada correctamente.';
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error al cancelar la ficha.';
      notifyListeners();
      return false;
    }
  }
}
