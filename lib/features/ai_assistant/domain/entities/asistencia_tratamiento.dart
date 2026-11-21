// Entidades inmutables de CU18: Recibir Asistencia Inteligente de Tratamiento.
// Alineadas a openspec/contracts/asistencia-tratamiento.md y RF-25.

/// Nivel de severidad clínica de una alerta farmacológica.
enum SeveridadAlerta { grave, moderada, leve, desconocida }

SeveridadAlerta severidadAlertaFromString(String? raw) {
  final normalized = (raw ?? '').trim().toUpperCase();
  switch (normalized) {
    case 'GRAVE':
      return SeveridadAlerta.grave;
    case 'MODERADA':
      return SeveridadAlerta.moderada;
    case 'LEVE':
      return SeveridadAlerta.leve;
    default:
      return SeveridadAlerta.desconocida;
  }
}

String severidadAlertaToString(SeveridadAlerta severidad) {
  switch (severidad) {
    case SeveridadAlerta.grave:
      return 'GRAVE';
    case SeveridadAlerta.moderada:
      return 'MODERADA';
    case SeveridadAlerta.leve:
      return 'LEVE';
    case SeveridadAlerta.desconocida:
      return 'DESCONOCIDA';
  }
}

/// Estado de la evaluación bajo demanda.
enum EstadoEvaluacion {
  completada,
  degradadoReglasBase,
  sinTratamientoVigente,
  desconocido,
}

EstadoEvaluacion estadoEvaluacionFromString(String? raw) {
  final normalized = (raw ?? '').trim().toUpperCase();
  switch (normalized) {
    case 'COMPLETADA':
      return EstadoEvaluacion.completada;
    case 'DEGRADADO_REGLAS_BASE':
      return EstadoEvaluacion.degradadoReglasBase;
    case 'SIN_TRATAMIENTO_VIGENTE':
      return EstadoEvaluacion.sinTratamientoVigente;
    default:
      return EstadoEvaluacion.desconocido;
  }
}

/// Medicamento vigente analizado durante la evaluación.
class MedicamentoAnalizado {
  final int? idMedicamento;
  final String nombre;
  final String principioActivo;
  final String dosis;
  final String frecuencia;
  final String? viaAdministracion;

  const MedicamentoAnalizado({
    this.idMedicamento,
    required this.nombre,
    required this.principioActivo,
    required this.dosis,
    required this.frecuencia,
    this.viaAdministracion,
  });
}

/// Alerta de interacción farmacológica detectada.
class AlertaInteraccion {
  final int? idAlerta;
  final String principioActivo1;
  final String principioActivo2;
  final String medicamento1Nombre;
  final String medicamento2Nombre;
  final String severidad;
  final String colorAlerta;
  final String mensajeAlerta;
  final String pautaPrecaucion;

  const AlertaInteraccion({
    this.idAlerta,
    required this.principioActivo1,
    required this.principioActivo2,
    required this.medicamento1Nombre,
    required this.medicamento2Nombre,
    required this.severidad,
    required this.colorAlerta,
    required this.mensajeAlerta,
    required this.pautaPrecaucion,
  });

  SeveridadAlerta get severidadEnum => severidadAlertaFromString(severidad);
  bool get isGrave => severidadEnum == SeveridadAlerta.grave;
  bool get isModerada => severidadEnum == SeveridadAlerta.moderada;
  bool get isLeve => severidadEnum == SeveridadAlerta.leve;
}

/// Sugerencia o recomendación personalizada de cuidado.
class RecomendacionTratamiento {
  final int? idRecomendacion;
  final String categoria;
  final String titulo;
  final String detalle;
  final String origen;

  const RecomendacionTratamiento({
    this.idRecomendacion,
    required this.categoria,
    required this.titulo,
    required this.detalle,
    required this.origen,
  });

  bool get isGeneradaPorIa => origen.toUpperCase() == 'IA_GENERATIVA';
  bool get isReglaPredefinida => origen.toUpperCase() == 'REGLA_PREDEFINIDA';
}

/// Resultado completo de la evaluación bajo demanda (RF-25).
class EvaluacionTratamiento {
  final int? idEvaluacion;
  final int idPaciente;
  final DateTime fechaEvaluacion;
  final String estadoEvaluacion;
  final String nivelRiesgoGlobal;
  final int totalMedicamentosAnalizados;
  final int totalAlertasDetectadas;
  final String? resumenEjecutivo;
  final String avisoLegal;
  final List<MedicamentoAnalizado> medicamentosAnalizados;
  final List<AlertaInteraccion> alertas;
  final List<RecomendacionTratamiento> recomendaciones;

  const EvaluacionTratamiento({
    this.idEvaluacion,
    required this.idPaciente,
    required this.fechaEvaluacion,
    required this.estadoEvaluacion,
    required this.nivelRiesgoGlobal,
    required this.totalMedicamentosAnalizados,
    required this.totalAlertasDetectadas,
    this.resumenEjecutivo,
    required this.avisoLegal,
    required this.medicamentosAnalizados,
    required this.alertas,
    required this.recomendaciones,
  });

  EstadoEvaluacion get estadoEnum => estadoEvaluacionFromString(estadoEvaluacion);
  bool get isDegraded => estadoEnum == EstadoEvaluacion.degradadoReglasBase;
  bool get hasNoActiveTreatment => estadoEnum == EstadoEvaluacion.sinTratamientoVigente;
  bool get hasNoRisk => nivelRiesgoGlobal.toUpperCase() == 'SIN_RIESGO';
  bool get hasHighRisk => nivelRiesgoGlobal.toUpperCase() == 'ALTO';
}

/// Registro resumido de una evaluación en el historial.
class EvaluacionResumen {
  final int idEvaluacion;
  final int idPaciente;
  final DateTime fechaEvaluacion;
  final String estadoEvaluacion;
  final String nivelRiesgoGlobal;
  final int totalMedicamentosAnalizados;
  final int totalAlertasDetectadas;
  final String? resumenEjecutivo;

  const EvaluacionResumen({
    required this.idEvaluacion,
    required this.idPaciente,
    required this.fechaEvaluacion,
    required this.estadoEvaluacion,
    required this.nivelRiesgoGlobal,
    required this.totalMedicamentosAnalizados,
    required this.totalAlertasDetectadas,
    this.resumenEjecutivo,
  });

  EstadoEvaluacion get estadoEnum => estadoEvaluacionFromString(estadoEvaluacion);
  bool get isHighRisk => nivelRiesgoGlobal.toUpperCase() == 'ALTO';
}

/// Historial paginado de evaluaciones.
class HistorialEvaluacion {
  final List<EvaluacionResumen> items;
  final int total;
  final int page;
  final int limit;
  final int totalPaginas;

  const HistorialEvaluacion({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPaginas,
  });

  bool get hasNextPage => page < totalPaginas;
}

