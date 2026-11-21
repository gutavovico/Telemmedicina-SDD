import 'package:flutter/material.dart';
import '../../data/models/waitlist_models.dart';
import '../../data/repositories/waitlist_repository_impl.dart';
import '../../domain/repositories/waitlist_repository.dart';

enum WaitlistStatus { initial, loading, success, error }

class WaitlistProvider with ChangeNotifier {
  final WaitlistRepository _repository;

  WaitlistProvider({WaitlistRepository? repository})
      : _repository = repository ?? WaitlistRepositoryImpl();

  List<InscripcionEsperaModel> _inscripciones = [];
  WaitlistStatus _status = WaitlistStatus.initial;
  String? _errorMessage;
  bool _accionEnCurso = false;

  // Datos precargados desde la búsqueda de especialistas (CU06).
  int? _idMedico;
  int? _idEspecialidad;
  String? _nombreMedico;

  List<InscripcionEsperaModel> get inscripciones => List.unmodifiable(_inscripciones);
  WaitlistStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == WaitlistStatus.loading;
  bool get accionEnCurso => _accionEnCurso;
  int? get idMedico => _idMedico;
  int? get idEspecialidad => _idEspecialidad;
  String? get nombreMedico => _nombreMedico;

  void prepararInscripcion({
    int? idMedico,
    int? idEspecialidad,
    String? nombreMedico,
  }) {
    _idMedico = idMedico;
    _idEspecialidad = idEspecialidad;
    _nombreMedico = nombreMedico;
    notifyListeners();
  }

  void limpiarSeleccion() {
    _idMedico = null;
    _idEspecialidad = null;
    _nombreMedico = null;
    notifyListeners();
  }

  Future<void> cargar() async {
    _status = WaitlistStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _inscripciones = await _repository.getMisInscripciones();
      _status = WaitlistStatus.success;
    } catch (e) {
      _status = WaitlistStatus.error;
      _errorMessage = 'No se pudo consultar tu lista de espera: ${e.toString()}';
    }
    notifyListeners();
  }

  Future<bool> inscribirse({
    int? idMedico,
    int? idEspecialidad,
    String? fechaDeseada,
    String? motivo,
  }) async {
    final medico = idMedico ?? _idMedico;
    final especialidad = idEspecialidad ?? _idEspecialidad;
    if (medico == null && especialidad == null) {
      _status = WaitlistStatus.error;
      _errorMessage = 'Selecciona un médico o una especialidad.';
      notifyListeners();
      return false;
    }
    _accionEnCurso = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.inscribirse(
        idMedico: medico,
        idEspecialidad: especialidad,
        fechaDeseada: fechaDeseada?.trim().isEmpty == true ? null : fechaDeseada,
        motivo: motivo?.trim().isEmpty == true ? null : motivo,
      );
      _accionEnCurso = false;
      limpiarSeleccion();
      await cargar();
      return true;
    } catch (e) {
      _accionEnCurso = false;
      _status = WaitlistStatus.error;
      _errorMessage = 'No se pudo inscribirte: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> salir(int id) => _ejecutar(() => _repository.salir(id));

  Future<bool> confirmar(int id) => _ejecutar(() => _repository.confirmar(id));

  Future<bool> rechazar(int id) => _ejecutar(() => _repository.rechazar(id));

  Future<bool> _ejecutar(Future<dynamic> Function() accion) async {
    _accionEnCurso = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await accion();
      _accionEnCurso = false;
      await cargar();
      return true;
    } catch (e) {
      _accionEnCurso = false;
      _status = WaitlistStatus.error;
      _errorMessage = 'No se pudo completar la operación: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    _errorMessage = null;
    if (_status == WaitlistStatus.error) {
      _status = WaitlistStatus.initial;
    }
    notifyListeners();
  }
}
