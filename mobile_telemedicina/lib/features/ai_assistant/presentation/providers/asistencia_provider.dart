import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../domain/entities/asistencia_tratamiento.dart';
import '../../domain/repositories/asistencia_repository.dart';
import '../../data/repositories/asistencia_repository_impl.dart';

/// Estado atómico de la solicitud de evaluación asistida bajo demanda.
enum AsistenciaStatus { initial, loading, success, error }

/// Estado atómico del listado histórico de evaluaciones.
enum AsistenciaHistoryStatus { initial, loading, loaded, empty, error }

/// Estado atómico de la consulta de detalle de una evaluación previa.
enum AsistenciaDetailStatus { initial, loading, loaded, error }

/// Provider de gestión de estado para la Asistencia Inteligente de Tratamiento (CU18).
class AsistenciaProvider extends ChangeNotifier {
  final AsistenciaRepository _repository;

  AsistenciaProvider({AsistenciaRepository? repository})
      : _repository = repository ?? AsistenciaRepositoryImpl();

  // --- Evaluación actual ---
  AsistenciaStatus _status = AsistenciaStatus.initial;
  EvaluacionTratamiento? _evaluacionActual;
  String? _errorMessage;
  String? _errorCode;
  int? _retryAfterSeconds;
  bool _isEvaluating = false;

  // --- Historial de evaluaciones ---
  AsistenciaHistoryStatus _historyStatus = AsistenciaHistoryStatus.initial;
  List<EvaluacionResumen> _historialItems = const [];
  int _historialTotal = 0;
  int _historialPage = 1;
  final int _historialLimit = 10;
  int _historialTotalPaginas = 1;
  String? _historyErrorMessage;
  bool _isLoadingMoreHistory = false;

  // --- Detalle de evaluación histórica ---
  AsistenciaDetailStatus _detailStatus = AsistenciaDetailStatus.initial;
  EvaluacionTratamiento? _selectedEvaluacion;
  String? _detailErrorMessage;

  // Getters para la vista
  AsistenciaStatus get status => _status;
  bool get isLoading => _status == AsistenciaStatus.loading;
  EvaluacionTratamiento? get evaluacionActual => _evaluacionActual;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  int? get retryAfterSeconds => _retryAfterSeconds;
  bool get isRateLimited => _errorCode == 'RATE_LIMIT_EXCEEDED';

  AsistenciaHistoryStatus get historyStatus => _historyStatus;
  bool get isLoadingHistory => _historyStatus == AsistenciaHistoryStatus.loading;
  bool get isLoadingMoreHistory => _isLoadingMoreHistory;
  List<EvaluacionResumen> get historialItems => List.unmodifiable(_historialItems);
  int get historialTotal => _historialTotal;
  int get historialPage => _historialPage;
  int get historialTotalPaginas => _historialTotalPaginas;
  bool get hasMoreHistory => _historialPage < _historialTotalPaginas;
  String? get historyErrorMessage => _historyErrorMessage;

  AsistenciaDetailStatus get detailStatus => _detailStatus;
  bool get isLoadingDetail => _detailStatus == AsistenciaDetailStatus.loading;
  EvaluacionTratamiento? get selectedEvaluacion => _selectedEvaluacion;
  String? get detailErrorMessage => _detailErrorMessage;

  /// Solicita la evaluación asistida del tratamiento activo bajo demanda.
  ///
  /// Evita doble envío si ya hay una evaluación en curso.
  /// Conserva la última evaluación visible ante errores de red o 429.
  Future<void> solicitarEvaluacion({bool forzarRecalculo = false}) async {
    if (_isEvaluating) return;

    _isEvaluating = true;
    _status = AsistenciaStatus.loading;
    _errorMessage = null;
    _errorCode = null;
    _retryAfterSeconds = null;
    notifyListeners();

    try {
      final resultado = await _repository.evaluarTratamiento(
        forzarRecalculo: forzarRecalculo,
      );
      _evaluacionActual = resultado;
      _status = AsistenciaStatus.success;

      // Al evaluar con éxito, refrescar silenciosamente el historial
      unawaited(cargarHistorial(refresh: true));
    } on ApiException catch (e) {
      _status = AsistenciaStatus.error;
      _errorMessage = e.message;
      if (e.statusCode == 429) {
        _errorCode = 'RATE_LIMIT_EXCEEDED';
        _retryAfterSeconds = 3600;
      }
      if (e.details is Map<String, dynamic>) {
        final code = e.details['code'];
        if (code is String) _errorCode = code;
      }
      // Conserva _evaluacionActual visible
    } catch (e) {
      _status = AsistenciaStatus.error;
      _errorMessage = 'Ocurrió un error inesperado al procesar la asistencia: $e';
    } finally {
      _isEvaluating = false;
      notifyListeners();
    }
  }

  /// Carga la primera página del historial de evaluaciones.
  Future<void> cargarHistorial({bool refresh = false}) async {
    if (_historyStatus == AsistenciaHistoryStatus.loading && !refresh) return;

    _historyStatus = AsistenciaHistoryStatus.loading;
    _historyErrorMessage = null;
    notifyListeners();

    try {
      final historial = await _repository.getHistorial(
        page: 1,
        limit: _historialLimit,
      );

      _historialItems = historial.items;
      _historialTotal = historial.total;
      _historialPage = historial.page;
      _historialTotalPaginas = historial.totalPaginas;

      _historyStatus = _historialItems.isEmpty
          ? AsistenciaHistoryStatus.empty
          : AsistenciaHistoryStatus.loaded;
    } on ApiException catch (e) {
      _historyStatus = AsistenciaHistoryStatus.error;
      _historyErrorMessage = e.message;
    } catch (e) {
      _historyStatus = AsistenciaHistoryStatus.error;
      _historyErrorMessage = 'Error al consultar historial: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Carga la siguiente página del historial de evaluaciones.
  Future<void> cargarMasHistorial() async {
    if (_isLoadingMoreHistory || !hasMoreHistory) return;

    _isLoadingMoreHistory = true;
    notifyListeners();

    try {
      final nextPage = _historialPage + 1;
      final historial = await _repository.getHistorial(
        page: nextPage,
        limit: _historialLimit,
      );

      _historialItems = [..._historialItems, ...historial.items];
      _historialTotal = historial.total;
      _historialPage = historial.page;
      _historialTotalPaginas = historial.totalPaginas;
    } catch (_) {
      // Ignora error silencioso en scroll infinito
    } finally {
      _isLoadingMoreHistory = false;
      notifyListeners();
    }
  }

  /// Obtiene y selecciona el detalle completo de una evaluación.
  Future<void> verDetalleEvaluacion(int idEvaluacion) async {
    _detailStatus = AsistenciaDetailStatus.loading;
    _detailErrorMessage = null;
    _selectedEvaluacion = null;
    notifyListeners();

    try {
      final evaluacion = await _repository.getEvaluacionById(idEvaluacion);
      _selectedEvaluacion = evaluacion;
      _detailStatus = AsistenciaDetailStatus.loaded;
    } on ApiException catch (e) {
      _detailStatus = AsistenciaDetailStatus.error;
      _detailErrorMessage = e.message;
    } catch (e) {
      _detailStatus = AsistenciaDetailStatus.error;
      _detailErrorMessage = 'Error al obtener detalle de la evaluación: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Limpia la evaluación seleccionada en el detalle.
  void limpiarDetalle() {
    _selectedEvaluacion = null;
    _detailStatus = AsistenciaDetailStatus.initial;
    _detailErrorMessage = null;
    notifyListeners();
  }
}
