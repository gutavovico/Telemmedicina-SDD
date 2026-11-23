import '../../domain/entities/doctor_entity.dart';
import '../../domain/entities/specialty_entity.dart';

class SpecialtyModel extends SpecialtyEntity {
  const SpecialtyModel({
    required super.idEspecialidad,
    required super.nombre,
    super.descripcion,
    required super.estado,
  });

  factory SpecialtyModel.fromJson(Map<String, dynamic> json) {
    return SpecialtyModel(
      idEspecialidad: json['id_especialidad'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      estado: json['estado'] as String? ?? 'activo',
    );
  }

  Map<String, dynamic> toJson() => {
    'id_especialidad': idEspecialidad,
    'nombre': nombre,
    'descripcion': descripcion,
    'estado': estado,
  };
}

class DoctorSpecialtyModel extends DoctorSpecialtyEntity {
  const DoctorSpecialtyModel({
    required super.idEspecialidad,
    required super.nombre,
    required super.esPrincipal,
  });

  factory DoctorSpecialtyModel.fromJson(Map<String, dynamic> json) {
    return DoctorSpecialtyModel(
      idEspecialidad: json['id_especialidad'] as int,
      nombre: json['nombre'] as String? ?? '',
      esPrincipal: json['es_principal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_especialidad': idEspecialidad,
    'nombre': nombre,
    'es_principal': esPrincipal,
  };
}

class DoctorModel extends DoctorEntity {
  const DoctorModel({
    required super.idMedico,
    super.tenantId,
    required super.idUsuario,
    required super.matriculaProfesional,
    super.descripcionProfesional,
    super.aniosExperiencia,
    super.fotoProfesional,
    required super.estado,
    required super.nombres,
    required super.apellidos,
    required super.correo,
    super.telefono,
    super.especialidades,
    super.createdAt,
    super.updatedAt,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    final especialidadesRaw = json['especialidades'] as List<dynamic>? ?? [];
    final especialidadesList = especialidadesRaw
        .map((e) => DoctorSpecialtyModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return DoctorModel(
      idMedico: json['id_medico'] as int,
      tenantId: json['tenant_id'] as String?,
      idUsuario: json['id_usuario'] as int? ?? 0,
      matriculaProfesional: json['matricula_profesional'] as String? ?? '',
      descripcionProfesional: json['descripcion_profesional'] as String?,
      aniosExperiencia: json['anios_experiencia'] as int?,
      fotoProfesional: json['foto_profesional'] as String?,
      estado: json['estado'] as String? ?? 'activo',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String?,
      especialidades: especialidadesList,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_medico': idMedico,
    'tenant_id': tenantId,
    'id_usuario': idUsuario,
    'matricula_profesional': matriculaProfesional,
    'descripcion_profesional': descripcionProfesional,
    'anios_experiencia': aniosExperiencia,
    'foto_profesional': fotoProfesional,
    'estado': estado,
    'nombres': nombres,
    'apellidos': apellidos,
    'correo': correo,
    'telefono': telefono,
    'especialidades': especialidades
        .map((e) => (e as DoctorSpecialtyModel).toJson())
        .toList(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
