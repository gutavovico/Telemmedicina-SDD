class SpecialistSpecialtyEntity {
  final int idEspecialidad;
  final String nombre;
  final bool esPrincipal;

  const SpecialistSpecialtyEntity({
    required this.idEspecialidad,
    required this.nombre,
    this.esPrincipal = false,
  });
}

class SpecialistServiceEntity {
  final int idServicio;
  final String nombre;
  final String? descripcion;
  final String modalidad;
  final double costo;
  final String moneda;
  final int duracionMinutos;
  final String horaInicio;
  final String horaFin;

  const SpecialistServiceEntity({
    required this.idServicio,
    required this.nombre,
    this.descripcion,
    required this.modalidad,
    required this.costo,
    required this.moneda,
    required this.duracionMinutos,
    required this.horaInicio,
    required this.horaFin,
  });
}

class SpecialistSlotEntity {
  final String horaInicio;
  final String horaFin;
  final bool disponible;

  const SpecialistSlotEntity({
    required this.horaInicio,
    required this.horaFin,
    required this.disponible,
  });
}

class SpecialistDayAvailabilityEntity {
  final String fecha;
  final List<SpecialistSlotEntity> slots;

  const SpecialistDayAvailabilityEntity({
    required this.fecha,
    required this.slots,
  });
}

class SpecialistEntity {
  final int idMedico;
  final String nombreCompleto;
  final String? fotoUrl;
  final String matriculaProfesional;
  final String? descripcionProfesional;
  final String? experiencia;
  final List<SpecialistSpecialtyEntity> especialidades;
  final List<SpecialistServiceEntity> servicios;
  final List<SpecialistDayAvailabilityEntity> disponibilidad;

  const SpecialistEntity({
    required this.idMedico,
    required this.nombreCompleto,
    this.fotoUrl,
    required this.matriculaProfesional,
    this.descripcionProfesional,
    this.experiencia,
    required this.especialidades,
    required this.servicios,
    required this.disponibilidad,
  });
}

class SpecialistSpecialtyOptionEntity {
  final int idEspecialidad;
  final String nombre;

  const SpecialistSpecialtyOptionEntity({
    required this.idEspecialidad,
    required this.nombre,
  });
}

class SpecialistSearchResponseEntity {
  final int total;
  final int page;
  final int perPage;
  final List<SpecialistEntity> items;

  const SpecialistSearchResponseEntity({
    required this.total,
    required this.page,
    required this.perPage,
    required this.items,
  });
}
