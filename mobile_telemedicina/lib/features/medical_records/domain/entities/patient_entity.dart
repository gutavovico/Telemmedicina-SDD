class PatientEntity {
  final int idPaciente;
  final int? idUsuario;
  final String nombres;
  final String apellidos;
  final String ci;
  final String? complemento;
  final String fechaNacimiento;
  final String genero;
  final String telefono;
  final String? correo;
  final String? direccion;
  final String? ciudad;
  final String? tipoSangre;
  final String? alergias;
  final String? antecedentesPatologicos;
  final String? contactoEmergenciaNombre;
  final String? contactoEmergenciaTelefono;
  final String? contactoEmergenciaParentesco;
  final String? seguroMedico;
  final String? numeroSeguro;
  final String estado;
  final String? createdAt;
  final String? updatedAt;

  const PatientEntity({
    required this.idPaciente,
    this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.ci,
    this.complemento,
    required this.fechaNacimiento,
    required this.genero,
    required this.telefono,
    this.correo,
    this.direccion,
    this.ciudad,
    this.tipoSangre,
    this.alergias,
    this.antecedentesPatologicos,
    this.contactoEmergenciaNombre,
    this.contactoEmergenciaTelefono,
    this.contactoEmergenciaParentesco,
    this.seguroMedico,
    this.numeroSeguro,
    required this.estado,
    this.createdAt,
    this.updatedAt,
  });

  String get fullName => '$nombres $apellidos'.trim();

  int get age {
    try {
      final birth = DateTime.parse(fechaNacimiento);
      final today = DateTime.now();
      int calculatedAge = today.year - birth.year;
      if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) {
        calculatedAge--;
      }
      return calculatedAge > 0 ? calculatedAge : 0;
    } catch (_) {
      return 0;
    }
  }
}
