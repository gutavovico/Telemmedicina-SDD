class DoctorSpecialtyEntity {
  final int idEspecialidad;
  final String nombre;
  final bool esPrincipal;

  const DoctorSpecialtyEntity({
    required this.idEspecialidad,
    required this.nombre,
    required this.esPrincipal,
  });
}

class DoctorEntity {
  final int idMedico;
  final String? tenantId;
  final int idUsuario;
  final String matriculaProfesional;
  final String? descripcionProfesional;
  final int? aniosExperiencia;
  final String? fotoProfesional;
  final String estado;
  final String nombres;
  final String apellidos;
  final String correo;
  final String? telefono;
  final List<DoctorSpecialtyEntity> especialidades;
  final String? createdAt;
  final String? updatedAt;

  const DoctorEntity({
    required this.idMedico,
    this.tenantId,
    required this.idUsuario,
    required this.matriculaProfesional,
    this.descripcionProfesional,
    this.aniosExperiencia,
    this.fotoProfesional,
    required this.estado,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.telefono,
    this.especialidades = const [],
    this.createdAt,
    this.updatedAt,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  DoctorSpecialtyEntity? get especialidadPrincipal {
    try {
      return especialidades.firstWhere((e) => e.esPrincipal);
    } catch (_) {
      return especialidades.isNotEmpty ? especialidades.first : null;
    }
  }
}
