import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/cola_models.dart';
import '../../data/repositories/cola_repository_impl.dart';
import '../../domain/repositories/cola_repository.dart';

class ColaProvider with ChangeNotifier {
  final ColaRepository _repository;

  ColaProvider({ColaRepository? repository})
      : _repository = repository ?? ColaRepositoryImpl();

  MiTurnoModel? _miTurno;
  ColaOperativaModel? _cola;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  int? _pollingMedicoId;
  String? _pollingFecha;

  MiTurnoModel? get miTurno => _miTurno;
  ColaOperativaModel? get cola => _cola;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> cargarMiTurno({bool silencioso = false}) async {
    if (!silencioso) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      _miTurno = await _repository.getMiTurno();
      _errorMessage = null;
    } catch (e) {
      if (!silencioso) {
        _errorMessage = 'No se pudo consultar tu turno: ${e.toString()}';
      }
    } finally {
      if (!silencioso) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> cargarCola({int? idMedico, String? fecha, bool silencioso = false}) async {
    if (!silencioso) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      _cola = await _repository.getColaOperativa(idMedico: idMedico, fecha: fecha);
      _errorMessage = null;
    } catch (e) {
      if (!silencioso) {
        _errorMessage = 'No se pudo cargar la fila virtual: ${e.toString()}';
      }
    } finally {
      if (!silencioso) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void iniciarPollingMiTurno() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      cargarMiTurno(silencioso: true);
    });
  }

  void iniciarPollingCola({int? idMedico, String? fecha}) {
    _pollingMedicoId = idMedico;
    _pollingFecha = fecha;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      cargarCola(idMedico: _pollingMedicoId, fecha: _pollingFecha, silencioso: true);
    });
  }

  void detenerPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<bool> avanzar(int idCita) async {
    try {
      _cola = await _repository.avanzar(idCita);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo avanzar la fila: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> marcarPerdida(int idCita) async {
    try {
      _cola = await _repository.marcarPerdida(idCita);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo marcar el turno: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> registrarPausa({
    required int idMedico,
    required String fecha,
    required String horaInicio,
    required String horaFin,
    required String motivo,
  }) async {
    try {
      await _repository.registrarPausa(
        idMedico: idMedico,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        motivo: motivo,
      );
      await cargarCola(idMedico: idMedico, fecha: fecha, silencioso: true);
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo registrar la pausa: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    detenerPolling();
    super.dispose();
  }
}
