// Entidades de dominio desacopladas para CU17 «Gestionar y Monitorear Tratamiento Médico».

class Diagnostico {
  final String? codigoCie;
  final String? descripcion;

  const Diagnostico({
    this.codigoCie,
    this.descripcion,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Diagnostico &&
          runtimeType == other.runtimeType &&
          codigoCie == other.codigoCie &&
          descripcion == other.descripcion;

  @override
  int get hashCode => codigoCie.hashCode ^ descripcion.hashCode;
}

class MedicamentoPlan {
  final int idMedicamentoPlan;
  final int idRecetaDetalle;
  final String medicamentoNombre;
  final String dosis;
  final String viaAdministracion;
  final String? frecuenciaTextoReceta;
  final String? duracionTextoReceta;
  final String? indicaciones;
  final String fechaInicio;
  final String fechaFin;
  final List<String> horasLocales;
  final int? intervaloHoras;
  final String estado;

  const MedicamentoPlan({
    required this.idMedicamentoPlan,
    required this.idRecetaDetalle,
    required this.medicamentoNombre,
    required this.dosis,
    required this.viaAdministracion,
    this.frecuenciaTextoReceta,
    this.duracionTextoReceta,
    this.indicaciones,
    required this.fechaInicio,
    required this.fechaFin,
    required this.horasLocales,
    this.intervaloHoras,
    required this.estado,
  });

  bool get estaActivo => estado.toUpperCase() == 'ACTIVO';
  bool get estaSuspendido => estado.toUpperCase() == 'SUSPENDIDO';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicamentoPlan &&
          runtimeType == other.runtimeType &&
          idMedicamentoPlan == other.idMedicamentoPlan;

  @override
  int get hashCode => idMedicamentoPlan.hashCode;
}

class Dosis {
  final int idDosis;
  final int idMedicamentoPlan;
  final String programadaEn;
  final String programadaHoraLocal;
  final String zonaHoraria;
  final String estado;
  final bool vencida;
  final String? efectivaEn;
  final String? registradaEn;
  final bool? puntual;
  final String? nota;

  const Dosis({
    required this.idDosis,
    required this.idMedicamentoPlan,
    required this.programadaEn,
    required this.programadaHoraLocal,
    required this.zonaHoraria,
    required this.estado,
    required this.vencida,
    this.efectivaEn,
    this.registradaEn,
    this.puntual,
    this.nota,
  });

  bool get esPendiente => estado.toUpperCase() == 'PENDIENTE';
  bool get esIngerida => estado.toUpperCase() == 'INGERIDA';
  bool get esOmitida => estado.toUpperCase() == 'OMITIDA';
  bool get esPospuesta => estado.toUpperCase() == 'POSPUESTA';
  bool get esPuntual => puntual ?? false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dosis &&
          runtimeType == other.runtimeType &&
          idDosis == other.idDosis;

  @override
  int get hashCode => idDosis.hashCode;
}

class Adherencia {
  final int numeradorPuntual;
  final int denominadorProgramado;
  final double? porcentaje;
  final String nivel;
  final String? calculadoEn;

  const Adherencia({
    required this.numeradorPuntual,
    required this.denominadorProgramado,
    this.porcentaje,
    required this.nivel,
    this.calculadoEn,
  });

  bool get esOptima => nivel.toUpperCase() == 'OPTIMA';
  bool get esRegular => nivel.toUpperCase() == 'REGULAR';
  bool get esCritica => nivel.toUpperCase() == 'CRITICA';
  bool get sinDatos => nivel.toUpperCase() == 'SIN_DATOS';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Adherencia &&
          runtimeType == other.runtimeType &&
          numeradorPuntual == other.numeradorPuntual &&
          denominadorProgramado == other.denominadorProgramado &&
          porcentaje == other.porcentaje &&
          nivel == other.nivel &&
          calculadoEn == other.calculadoEn;

  @override
  int get hashCode =>
      numeradorPuntual.hashCode ^
      denominadorProgramado.hashCode ^
      porcentaje.hashCode ^
      nivel.hashCode ^
      calculadoEn.hashCode;
}

class TreatmentPlan {
  final int idTratamiento;
  final int idClinica;
  final int idConsulta;
  final int? idReceta;
  final int? idDiagnostico;
  final Diagnostico? diagnostico;
  final int idPaciente;
  final int idMedico;
  final String fechaInicio;
  final String fechaFin;
  final String zonaHoraria;
  final String estado;
  final String? notas;
  final String? motivoCierre;
  final List<MedicamentoPlan> medicamentos;
  final String? createdAt;
  final String? updatedAt;
  final Adherencia? adherencia;

  const TreatmentPlan({
    required this.idTratamiento,
    required this.idClinica,
    required this.idConsulta,
    this.idReceta,
    this.idDiagnostico,
    this.diagnostico,
    required this.idPaciente,
    required this.idMedico,
    required this.fechaInicio,
    required this.fechaFin,
    required this.zonaHoraria,
    required this.estado,
    this.notas,
    this.motivoCierre,
    required this.medicamentos,
    this.createdAt,
    this.updatedAt,
    this.adherencia,
  });

  bool get estaActivo => estado.toUpperCase() == 'ACTIVO';
  bool get estaFinalizado => estado.toUpperCase() == 'FINALIZADO';
  bool get estaSuspendidoPorReceta =>
      estado.toUpperCase() == 'SUSPENDIDO_POR_RECETA';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreatmentPlan &&
          runtimeType == other.runtimeType &&
          idTratamiento == other.idTratamiento;

  @override
  int get hashCode => idTratamiento.hashCode;
}

class CronogramaDia {
  final int idTratamiento;
  final String fecha;
  final String zonaHoraria;
  final List<Dosis> dosis;
  final Adherencia? adherencia;

  const CronogramaDia({
    required this.idTratamiento,
    required this.fecha,
    required this.zonaHoraria,
    required this.dosis,
    this.adherencia,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CronogramaDia &&
          runtimeType == other.runtimeType &&
          idTratamiento == other.idTratamiento &&
          fecha == other.fecha;

  @override
  int get hashCode => idTratamiento.hashCode ^ fecha.hashCode;
}

class Aviso {
  final int idAviso;
  final int idTratamiento;
  final int? idDosis;
  final String tipo;
  final String canal;
  final String? titulo;
  final String? mensaje;
  final String estado;
  final String? programadaEn;
  final String? enviadaEn;
  final String? leidaEn;

  const Aviso({
    required this.idAviso,
    required this.idTratamiento,
    this.idDosis,
    required this.tipo,
    required this.canal,
    this.titulo,
    this.mensaje,
    required this.estado,
    this.programadaEn,
    this.enviadaEn,
    this.leidaEn,
  });

  bool get estaLeido => leidaEn != null && leidaEn!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aviso &&
          runtimeType == other.runtimeType &&
          idAviso == other.idAviso;

  @override
  int get hashCode => idAviso.hashCode;
}

class OperacionIdempotencia {
  final int idDosis;
  final String idempotencyKey;
  final String estado;
  final bool confirmado;
  final bool enCurso;
  final bool rechazado;
  final Dosis? dosis;
  final String? mensaje;
  final int? generacion;

  const OperacionIdempotencia({
    required this.idDosis,
    required this.idempotencyKey,
    required this.estado,
    required this.confirmado,
    required this.enCurso,
    required this.rechazado,
    this.dosis,
    this.mensaje,
    this.generacion,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperacionIdempotencia &&
          runtimeType == other.runtimeType &&
          idDosis == other.idDosis &&
          idempotencyKey == other.idempotencyKey;

  @override
  int get hashCode => idDosis.hashCode ^ idempotencyKey.hashCode;
}

class TreatmentPage {
  final List<TreatmentPlan> items;
  final int total;
  final int skip;
  final int limit;

  const TreatmentPage({
    required this.items,
    required this.total,
    this.skip = 0,
    this.limit = 20,
  });

  bool get hasMore => (skip + items.length) < total;
}

class AvisoPage {
  final List<Aviso> items;
  final int total;
  final int skip;
  final int limit;

  const AvisoPage({
    required this.items,
    required this.total,
    this.skip = 0,
    this.limit = 20,
  });

  bool get hasMore => (skip + items.length) < total;
}
