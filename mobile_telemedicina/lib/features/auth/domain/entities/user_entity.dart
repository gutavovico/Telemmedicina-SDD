class UserEntity {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String correo;
  final String? telefono;
  final int? idRol;
  final int? idClinica;
  final String? rolNombre;
  final String? tenantId;
  final String? estado;
  final bool notificacionesPush;

  bool get isPatient => rolNombre?.trim().toUpperCase() == 'PACIENTE';

  const UserEntity({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.telefono,
    this.idRol,
    this.idClinica,
    this.rolNombre,
    this.tenantId,
    this.estado,
    this.notificacionesPush = true,
  });
}
