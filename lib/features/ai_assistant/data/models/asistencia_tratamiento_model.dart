import '../../domain/entities/asistencia_tratamiento.dart';

/// Modelo de medicamento analizado (DTO).
class MedicamentoAnalizadoModel extends MedicamentoAnalizado {
  const MedicamentoAnalizadoModel({
    super.idMedicamento,
    required super.nombre,
    required super.principioActivo,
    required super.dosis,
    required super.frecuencia,
    super.viaAdministracion,
  });

  factory MedicamentoAnalizadoModel.fromJson(Map<String, dynamic> json) {
    return MedicamentoAnalizadoModel(
      idMedicamento: (json['id_medicamento'] as num?)?.toInt(),
      nombre: json['nombre'] as String? ?? '',
      principioActivo: json['principio_activo'] as String? ?? '',
      dosis: json['dosis'] as String? ?? '',
      frecuencia: json['frecuencia'] as String? ?? '',
      viaAdministracion: json['via_administracion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_medicamento': idMedicamento,
      'nombre': nombre,
      'principio_activo': principioActivo,
      'dosis': dosis,
      'frecuencia': frecuencia,
      'via_administracion': viaAdministracion,
    };
  }
}

/// Modelo de alerta de interacción farmacológica detectada.
class AlertaInteraccionModel extends AlertaInteraccion {
  const AlertaInteraccionModel({
    super.idAlerta,
    required super.principioActivo1,
    required super.principioActivo2,
    required super.medicamento1Nombre,
    required super.medicamento2Nombre,
    required super.severidad,
    required super.colorAlerta,
    required super.mensajeAlerta,
    required super.pautaPrecaucion,
  });

  factory AlertaInteraccionModel.fromJson(Map<String, dynamic> json) {
    return AlertaInteraccionModel(
      idAlerta: (json['id_alerta'] as num?)?.toInt(),
      principioActivo1: json['principio_activo_1'] as String? ?? '',
      principioActivo2: json['principio_activo_2'] as String? ?? '',
      medicamento1Nombre: json['medicamento_1_nombre'] as String? ?? '',
      medicamento2Nombre: json['medicamento_2_nombre'] as String? ?? '',
      severidad: json['severidad'] as String? ?? 'LEVE',
      colorAlerta: json['color_alerta'] as String? ?? 'AMBAR',
      mensajeAlerta: json['mensaje_alerta'] as String? ?? '',
      pautaPrecaucion: json['pauta_precaucion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_alerta': idAlerta,
      'principio_activo_1': principioActivo1,
      'principio_activo_2': principioActivo2,
      'medicamento_1_nombre': medicamento1Nombre,
      'medicamento_2_nombre': medicamento2Nombre,
      'severidad': severidad,
      'color_alerta': colorAlerta,
      'mensaje_alerta': mensajeAlerta,
      'pauta_precaucion': pautaPrecaucion,
    };
  }
}

/// Modelo de sugerencia o recomendación contextual.
class RecomendacionTratamientoModel extends RecomendacionTratamiento {
  const RecomendacionTratamientoModel({
    super.idRecomendacion,
    required super.categoria,
    required super.titulo,
    required super.detalle,
    required super.origen,
  });

  factory RecomendacionTratamientoModel.fromJson(Map<String, dynamic> json) {
    return RecomendacionTratamientoModel(
      idRecomendacion: (json['id_recomendacion'] as num?)?.toInt(),
      categoria: json['categoria'] as String? ?? 'PRECAUCION_GENERAL',
      titulo: json['titulo'] as String? ?? '',
      detalle: json['detalle'] as String? ?? '',
      origen: json['origen'] as String? ?? 'REGLA_PREDEFINIDA',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_recomendacion': idRecomendacion,
      'categoria': categoria,
      'titulo': titulo,
      'detalle': detalle,
      'origen': origen,
    };
  }
}

/// Modelo de evaluación completa de tratamiento.
class EvaluacionTratamientoModel extends EvaluacionTratamiento {
  const EvaluacionTratamientoModel({
    super.idEvaluacion,
    required super.idPaciente,
    required super.fechaEvaluacion,
    required super.estadoEvaluacion,
    required super.nivelRiesgoGlobal,
    required super.totalMedicamentosAnalizados,
    required super.totalAlertasDetectadas,
    super.resumenEjecutivo,
    required super.avisoLegal,
    required super.medicamentosAnalizados,
    required super.alertas,
    required super.recomendaciones,
  });

  factory EvaluacionTratamientoModel.fromJson(Map<String, dynamic> json) {
    final rawMeds = json['medicamentos_analizados'] as List<dynamic>? ?? [];
    final rawAlertas = json['alertas'] as List<dynamic>? ?? [];
    final rawRecs = json['recomendaciones'] as List<dynamic>? ?? [];

    return EvaluacionTratamientoModel(
      idEvaluacion: (json['id_evaluacion'] as num?)?.toInt(),
      idPaciente: (json['id_paciente'] as num?)?.toInt() ?? 0,
      fechaEvaluacion: json['fecha_evaluacion'] != null
          ? DateTime.parse(json['fecha_evaluacion'] as String)
          : DateTime.now(),
      estadoEvaluacion: json['estado_evaluacion'] as String? ?? 'COMPLETADA',
      nivelRiesgoGlobal: json['nivel_riesgo_global'] as String? ?? 'SIN_RIESGO',
      totalMedicamentosAnalizados: (json['total_medicamentos_analizados'] as num?)?.toInt() ?? 0,
      totalAlertasDetectadas: (json['total_alertas_detectadas'] as num?)?.toInt() ?? 0,
      resumenEjecutivo: json['resumen_ejecutivo'] as String?,
      avisoLegal: json['aviso_legal'] as String? ??
          'Esta asistencia inteligente apoya con alertas y sugerencias de autocuidado. No sustituye la valoración médica profesional ni modifica diagnósticos, dosis o prescripciones vigentes.',
      medicamentosAnalizados: rawMeds
          .map((m) => MedicamentoAnalizadoModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      alertas: rawAlertas
          .map((a) => AlertaInteraccionModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      recomendaciones: rawRecs
          .map((r) => RecomendacionTratamientoModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_evaluacion': idEvaluacion,
      'id_paciente': idPaciente,
      'fecha_evaluacion': fechaEvaluacion.toIso8601String(),
      'estado_evaluacion': estadoEvaluacion,
      'nivel_riesgo_global': nivelRiesgoGlobal,
      'total_medicamentos_analizados': totalMedicamentosAnalizados,
      'total_alertas_detectadas': totalAlertasDetectadas,
      'resumen_ejecutivo': resumenEjecutivo,
      'aviso_legal': avisoLegal,
      'medicamentos_analizados': medicamentosAnalizados
          .map((m) => (m is MedicamentoAnalizadoModel ? m : MedicamentoAnalizadoModel(
                idMedicamento: m.idMedicamento,
                nombre: m.nombre,
                principioActivo: m.principioActivo,
                dosis: m.dosis,
                frecuencia: m.frecuencia,
                viaAdministracion: m.viaAdministracion,
              )).toJson())
          .toList(),
      'alertas': alertas
          .map((a) => (a is AlertaInteraccionModel ? a : AlertaInteraccionModel(
                idAlerta: a.idAlerta,
                principioActivo1: a.principioActivo1,
                principioActivo2: a.principioActivo2,
                medicamento1Nombre: a.medicamento1Nombre,
                medicamento2Nombre: a.medicamento2Nombre,
                severidad: a.severidad,
                colorAlerta: a.colorAlerta,
                mensajeAlerta: a.mensajeAlerta,
                pautaPrecaucion: a.pautaPrecaucion,
              )).toJson())
          .toList(),
      'recomendaciones': recomendaciones
          .map((r) => (r is RecomendacionTratamientoModel ? r : RecomendacionTratamientoModel(
                idRecomendacion: r.idRecomendacion,
                categoria: r.categoria,
                titulo: r.titulo,
                detalle: r.detalle,
                origen: r.origen,
              )).toJson())
          .toList(),
    };
  }
}

/// Modelo de resumen para listado de historial.
class EvaluacionResumenModel extends EvaluacionResumen {
  const EvaluacionResumenModel({
    required super.idEvaluacion,
    required super.idPaciente,
    required super.fechaEvaluacion,
    required super.estadoEvaluacion,
    required super.nivelRiesgoGlobal,
    required super.totalMedicamentosAnalizados,
    required super.totalAlertasDetectadas,
    super.resumenEjecutivo,
  });

  factory EvaluacionResumenModel.fromJson(Map<String, dynamic> json) {
    return EvaluacionResumenModel(
      idEvaluacion: (json['id_evaluacion'] as num).toInt(),
      idPaciente: (json['id_paciente'] as num).toInt(),
      fechaEvaluacion: DateTime.parse(json['fecha_evaluacion'] as String),
      estadoEvaluacion: json['estado_evaluacion'] as String? ?? 'COMPLETADA',
      nivelRiesgoGlobal: json['nivel_riesgo_global'] as String? ?? 'SIN_RIESGO',
      totalMedicamentosAnalizados: (json['total_medicamentos_analizados'] as num).toInt(),
      totalAlertasDetectadas: (json['total_alertas_detectadas'] as num).toInt(),
      resumenEjecutivo: json['resumen_ejecutivo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_evaluacion': idEvaluacion,
      'id_paciente': idPaciente,
      'fecha_evaluacion': fechaEvaluacion.toIso8601String(),
      'estado_evaluacion': estadoEvaluacion,
      'nivel_riesgo_global': nivelRiesgoGlobal,
      'total_medicamentos_analizados': totalMedicamentosAnalizados,
      'total_alertas_detectadas': totalAlertasDetectadas,
      'resumen_ejecutivo': resumenEjecutivo,
    };
  }
}

/// Modelo para respuesta paginada del historial de evaluaciones.
class HistorialEvaluacionModel extends HistorialEvaluacion {
  const HistorialEvaluacionModel({
    required super.items,
    required super.total,
    required super.page,
    required super.limit,
    required super.totalPaginas,
  });

  factory HistorialEvaluacionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return HistorialEvaluacionModel(
      items: rawItems
          .map((i) => EvaluacionResumenModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      totalPaginas: (json['total_paginas'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items
          .map((i) => (i is EvaluacionResumenModel ? i : EvaluacionResumenModel(
                idEvaluacion: i.idEvaluacion,
                idPaciente: i.idPaciente,
                fechaEvaluacion: i.fechaEvaluacion,
                estadoEvaluacion: i.estadoEvaluacion,
                nivelRiesgoGlobal: i.nivelRiesgoGlobal,
                totalMedicamentosAnalizados: i.totalMedicamentosAnalizados,
                totalAlertasDetectadas: i.totalAlertasDetectadas,
                resumenEjecutivo: i.resumenEjecutivo,
              )).toJson())
          .toList(),
      'total': total,
      'page': page,
      'limit': limit,
      'total_paginas': totalPaginas,
    };
  }
}

