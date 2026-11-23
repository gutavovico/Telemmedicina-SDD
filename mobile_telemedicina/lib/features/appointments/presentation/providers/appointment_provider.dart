import 'package:flutter/material.dart';
import '../../data/datasources/appointment_remote_datasource.dart';
import '../../data/models/appointment_model.dart';

class AppointmentProvider with ChangeNotifier {
  final AppointmentRemoteDataSource _dataSource = AppointmentRemoteDataSource();

  List<AppointmentModel> _appointments = [];
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'TODOS';
  String? _dateFilter;

  List<AppointmentModel> get appointments => _appointments;
  List<Map<String, dynamic>> get doctors => _doctors;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String? get dateFilter => _dateFilter;

  // Lista filtrada en tiempo real
  List<AppointmentModel> get filteredAppointments {
    return _appointments.where((cita) {
      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery =
          q.isEmpty ||
          cita.pacienteNombre.toLowerCase().contains(q) ||
          cita.pacienteCi.toLowerCase().contains(q) ||
          cita.medicoNombre.toLowerCase().contains(q) ||
          cita.especialidadNombre.toLowerCase().contains(q) ||
          (cita.motivo?.toLowerCase().contains(q) ?? false);

      final matchesStatus =
          _statusFilter == 'TODOS' ||
          cita.estado.toUpperCase() == _statusFilter.toUpperCase();

      final matchesDate = _dateFilter == null || cita.fechaCita == _dateFilter;

      return matchesQuery && matchesStatus && matchesDate;
    }).toList();
  }

  Future<void> fetchAppointments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final remoteList = await _dataSource.getAppointments();
      _appointments = remoteList;
    } catch (e) {
      _errorMessage = 'Error al cargar citas: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDoctors() async {
    try {
      _doctors = await _dataSource.getDoctors();
      notifyListeners();
    } catch (_) {}
  }


  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void filterByStatus(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void toggleFilterByToday() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_dateFilter == today) {
      _dateFilter = null;
    } else {
      _dateFilter = today;
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = 'TODOS';
    _dateFilter = null;
    notifyListeners();
  }

  Future<bool> createAppointment(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newAppointment = await _dataSource.createAppointment(data);
      _appointments.insert(0, newAppointment);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPatient(Map<String, dynamic> data) {
    return _dataSource.createPatient(data);
  }

  Future<bool> updateAppointment(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _dataSource.updateAppointment(id, data);
      final index = _appointments.indexWhere((c) => c.idCita == id);
      if (index != -1) {
        _appointments[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Fallback local
      final index = _appointments.indexWhere((c) => c.idCita == id);
      if (index != -1) {
        final current = _appointments[index];
        _appointments[index] = current.copyWith(
          fechaCita: data['fecha_cita'] ?? current.fechaCita,
          horaInicio: data['hora_inicio'] ?? current.horaInicio,
          motivo: data['motivo'] ?? current.motivo,
          estado: data['estado'] ?? current.estado,
          tipoConsulta: data['tipo_consulta'] ?? current.tipoConsulta,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> deleteAppointment(int id) async {
    try {
      await _dataSource.deleteAppointment(id);
    } catch (_) {}

    _appointments.removeWhere((c) => c.idCita == id);
    notifyListeners();
    return true;
  }
}
