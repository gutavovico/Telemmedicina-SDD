class FichaEntity {
  final String idFicha;
  final int idClinica;
  final String correlativo;
  final int idPaciente;
  final String? pacienteNombre;
  final String? pacienteCi;
  final int idMedico;
  final String? medicoNombre;
  final int? idServicio;
  final String? servicioNombre;
  final int? idEspecialidad;
  final String? especialidadNombre;
  final int? idCita;
  final DateTime fechaEmision;
  final String fechaAtencion;
  final String horaInicio;
  final String horaFin;
  final String motivoConsulta;
  final Map<String, dynamic> signosVitales;
  final Map<String, dynamic> seccionesDinamicas;
  final String? codigoCie10;
  final String? diagnosticoDescripcion;
  final String? notasEvolucion;
  final String estado;
  final String? motivoCancelacion;
  final DateTime createdAt;

  const FichaEntity({
    required this.idFicha,
    required this.idClinica,
    required this.correlativo,
    required this.idPaciente,
    this.pacienteNombre,
    this.pacienteCi,
    required this.idMedico,
    this.medicoNombre,
    this.idServicio,
    this.servicioNombre,
    this.idEspecialidad,
    this.especialidadNombre,
    this.idCita,
    required this.fechaEmision,
    required this.fechaAtencion,
    required this.horaInicio,
    required this.horaFin,
    required this.motivoConsulta,
    this.signosVitales = const {},
    this.seccionesDinamicas = const {},
    this.codigoCie10,
    this.diagnosticoDescripcion,
    this.notasEvolucion,
    required this.estado,
    this.motivoCancelacion,
    required this.createdAt,
  });
}
