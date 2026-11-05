import '../../domain/entities/specialist_search_entities.dart';

class SpecialistSpecialtyModel extends SpecialistSpecialtyEntity {
  const SpecialistSpecialtyModel({
    required super.idEspecialidad,
    required super.nombre,
    required super.esPrincipal,
  });

  factory SpecialistSpecialtyModel.fromJson(Map<String, dynamic> json) {
    return SpecialistSpecialtyModel(
      idEspecialidad:
          (json['id_especialidad'] ?? json['idEspecialidad'] ?? 0) as int,
      nombre: (json['nombre'] ?? json['name'] ?? '') as String,
      esPrincipal:
          (json['es_principal'] ?? json['esPrincipal'] ?? false) as bool,
    );
  }
}

class SpecialistServiceModel extends SpecialistServiceEntity {
  const SpecialistServiceModel({
    required super.idServicio,
    required super.nombre,
    required super.descripcion,
    required super.modalidad,
    required super.costo,
    required super.moneda,
    required super.duracionMinutos,
    required super.horaInicio,
    required super.horaFin,
  });

  factory SpecialistServiceModel.fromJson(Map<String, dynamic> json) {
    final rawCosto = json['costo'] ?? json['price'] ?? 0;
    final costo = rawCosto is num
        ? rawCosto.toDouble()
        : double.tryParse(rawCosto.toString()) ?? 0.0;

    return SpecialistServiceModel(
      idServicio: (json['id_servicio'] ?? json['idServicio'] ?? 0) as int,
      nombre: (json['nombre'] ?? json['name'] ?? '') as String,
      descripcion: (json['descripcion'] ?? json['description']) as String?,
      modalidad:
          (json['modalidad'] ?? json['modality'] ?? 'PRESENCIAL') as String,
      costo: costo,
      moneda: (json['moneda'] ?? json['currency'] ?? 'BOB') as String,
      duracionMinutos:
          (json['duracion_minutos'] ?? json['duracionMinutos'] ?? 30) as int,
      horaInicio:
          (json['hora_inicio'] ??
                  json['horaInicio'] ??
                  json['start_time'] ??
                  '')
              as String,
      horaFin:
          (json['hora_fin'] ?? json['horaFin'] ?? json['end_time'] ?? '')
              as String,
    );
  }
}

class SpecialistSlotModel extends SpecialistSlotEntity {
  const SpecialistSlotModel({
    required super.horaInicio,
    required super.horaFin,
    required super.disponible,
  });

  factory SpecialistSlotModel.fromJson(Map<String, dynamic> json) {
    return SpecialistSlotModel(
      horaInicio:
          (json['hora_inicio'] ??
                  json['horaInicio'] ??
                  json['start_time'] ??
                  '')
              as String,
      horaFin:
          (json['hora_fin'] ?? json['horaFin'] ?? json['end_time'] ?? '')
              as String,
      disponible:
          (json['disponible'] ??
                  json['is_available'] ??
                  json['available'] ??
                  false)
              as bool,
    );
  }
}

class SpecialistDayAvailabilityModel extends SpecialistDayAvailabilityEntity {
  const SpecialistDayAvailabilityModel({
    required super.fecha,
    required super.slots,
  });

  factory SpecialistDayAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    return SpecialistDayAvailabilityModel(
      fecha: (json['fecha'] ?? json['date'] ?? '') as String,
      slots: rawSlots
          .map((s) => SpecialistSlotModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpecialistItemModel extends SpecialistEntity {
  const SpecialistItemModel({
    required super.idMedico,
    required super.nombreCompleto,
    super.fotoUrl,
    required super.matriculaProfesional,
    super.descripcionProfesional,
    super.experiencia,
    required super.especialidades,
    required super.servicios,
    required super.disponibilidad,
  });

  factory SpecialistItemModel.fromJson(Map<String, dynamic> json) {
    final rawEsp =
        json['especialidades'] ?? json['specialties'] as List<dynamic>? ?? [];
    final rawServ =
        json['servicios'] ?? json['services'] as List<dynamic>? ?? [];
    final rawDisp =
        json['disponibilidad'] ?? json['availability'] as List<dynamic>? ?? [];

    return SpecialistItemModel(
      idMedico:
          (json['id_medico'] ?? json['idMedico'] ?? json['id'] ?? 0) as int,
      nombreCompleto:
          (json['nombre_completo'] ??
                  json['nombreCompleto'] ??
                  json['full_name'] ??
                  '')
              as String,
      fotoUrl:
          (json['foto_url'] ?? json['fotoUrl'] ?? json['photo_url']) as String?,
      matriculaProfesional:
          (json['matricula_profesional'] ?? json['matriculaProfesional'] ?? '')
              as String,
      descripcionProfesional:
          (json['descripcion_profesional'] ??
                  json['descripcionProfesional'] ??
                  json['professional_description'])
              as String?,
      experiencia: (json['experiencia'] ?? json['experience']) as String?,
      especialidades: (rawEsp as List<dynamic>)
          .map(
            (e) => SpecialistSpecialtyModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      servicios: (rawServ as List<dynamic>)
          .map(
            (s) => SpecialistServiceModel.fromJson(s as Map<String, dynamic>),
          )
          .toList(),
      disponibilidad: (rawDisp as List<dynamic>)
          .map(
            (d) => SpecialistDayAvailabilityModel.fromJson(
              d as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class SpecialistSpecialtyOptionModel extends SpecialistSpecialtyOptionEntity {
  const SpecialistSpecialtyOptionModel({
    required super.idEspecialidad,
    required super.nombre,
  });

  factory SpecialistSpecialtyOptionModel.fromJson(Map<String, dynamic> json) {
    return SpecialistSpecialtyOptionModel(
      idEspecialidad:
          (json['id_especialidad'] ?? json['idEspecialidad'] ?? 0) as int,
      nombre: (json['nombre'] ?? json['name'] ?? '') as String,
    );
  }
}

class SpecialistSearchResponseModel extends SpecialistSearchResponseEntity {
  const SpecialistSearchResponseModel({
    required super.total,
    required super.page,
    required super.perPage,
    required super.items,
  });

  factory SpecialistSearchResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return SpecialistSearchResponseModel(
      total: (json['total'] ?? 0) as int,
      page: (json['page'] ?? 1) as int,
      perPage: (json['per_page'] ?? json['perPage'] ?? 20) as int,
      items: rawItems
          .map((i) => SpecialistItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpecialistSearchFilterParams {
  final String? nombre;
  final int? idEspecialidad;
  final String modalidad;
  final double? costoMin;
  final double? costoMax;
  final String fechaInicio;
  final String fechaFin;
  final int page;
  final int perPage;

  const SpecialistSearchFilterParams({
    this.nombre,
    this.idEspecialidad,
    this.modalidad = 'AMBAS',
    this.costoMin,
    this.costoMax,
    required this.fechaInicio,
    required this.fechaFin,
    this.page = 1,
    this.perPage = 20,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'modalidad': modalidad,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (nombre != null && nombre!.trim().isNotEmpty) {
      params['nombre'] = nombre!.trim();
    }
    if (idEspecialidad != null && idEspecialidad! > 0) {
      params['especialidad_id'] = idEspecialidad.toString();
    }
    if (costoMin != null) {
      params['costo_min'] = costoMin.toString();
    }
    if (costoMax != null) {
      params['costo_max'] = costoMax.toString();
    }
    return params;
  }
}
