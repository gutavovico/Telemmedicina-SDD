import 'package:flutter/material.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../data/repositories/doctor_repository_impl.dart';
import '../../domain/entities/doctor_entity.dart';
import '../../domain/entities/specialty_entity.dart';
import '../../domain/usecases/get_doctors_usecase.dart';
import '../../domain/usecases/get_specialties_usecase.dart';

class DoctorController extends ChangeNotifier {
  final GetDoctorsUseCase _getDoctorsUseCase;
  final GetSpecialtiesUseCase _getSpecialtiesUseCase;

  DoctorController({
    GetDoctorsUseCase? getDoctorsUseCase,
    GetSpecialtiesUseCase? getSpecialtiesUseCase,
  })  : _getDoctorsUseCase =
            getDoctorsUseCase ?? GetDoctorsUseCase(DoctorRepositoryImpl()),
        _getSpecialtiesUseCase =
            getSpecialtiesUseCase ?? GetSpecialtiesUseCase(DoctorRepositoryImpl());

  List<DoctorEntity> _doctors = [];
  List<SpecialtyEntity> _specialties = [];
  int? _selectedSpecialtyId;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  DoctorEntity? _selectedDoctor;

  List<DoctorEntity> get doctors => _doctors;
  List<SpecialtyEntity> get specialties => _specialties;
  int? get selectedSpecialtyId => _selectedSpecialtyId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DoctorEntity? get selectedDoctor => _selectedDoctor;

  Future<void> loadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _getSpecialtiesUseCase(),
        _getDoctorsUseCase(
          nombre: _searchQuery.isNotEmpty ? _searchQuery : null,
          idEspecialidad: _selectedSpecialtyId,
        ),
      ]);

      _specialties = results[0] as List<SpecialtyEntity>;
      _doctors = results[1] as List<DoctorEntity>;
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'No se pudo cargar el catálogo de médicos.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectSpecialty(int? specialtyId) async {
    if (_selectedSpecialtyId == specialtyId) {
      _selectedSpecialtyId = null;
    } else {
      _selectedSpecialtyId = specialtyId;
    }
    await filterDoctors();
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    await filterDoctors();
  }

  Future<void> filterDoctors() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _doctors = await _getDoctorsUseCase(
        nombre: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        idEspecialidad: _selectedSpecialtyId,
      );
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Error al filtrar médicos.';
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedDoctor(DoctorEntity doctor) {
    _selectedDoctor = doctor;
    notifyListeners();
  }
}
