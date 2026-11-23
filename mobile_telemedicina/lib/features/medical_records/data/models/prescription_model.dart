/// Modelos CU16 alineados a `openspec/contracts/prescriptions.md` §4.
///
/// Representan todos los campos y su anulabilidad sin omitir ninguno.
/// El mapeo a entidades de dominio se realiza en el repositorio.
class PrescriptionMedicoModel {
  final int idMedico;
  final String nombreCompleto;
  final String matriculaProfesional;
  final String? especialidad;

  const PrescriptionMedicoModel({
    required this.idMedico,
    required this.nombreCompleto,
    required this.matriculaProfesional,
    this.especialidad,
  });

  factory PrescriptionMedicoModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedicoModel(
      idMedico: (json['id_medico'] as num).toInt(),
      nombreCompleto: json['nombre_completo'] as String? ?? '',
      matriculaProfesional: json['matricula_profesional'] as String? ?? '',
      especialidad: json['especialidad'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_medico': idMedico,
      'nombre_completo': nombreCompleto,
      'matricula_profesional': matriculaProfesional,
      'especialidad': especialidad,
    };
  }
}

class PrescriptionPacienteModel {
  final int idPaciente;
  final String nombreCompleto;

  const PrescriptionPacienteModel({
    required this.idPaciente,
    required this.nombreCompleto,
  });

  factory PrescriptionPacienteModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionPacienteModel(
      idPaciente: (json['id_paciente'] as num).toInt(),
      nombreCompleto: json['nombre_completo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id_paciente': idPaciente, 'nombre_completo': nombreCompleto};
  }
}

class PrescriptionDetalleModel {
  final int idRecetaDetalle;
  final int? idMedicamento;
  final String? nombreMedicamentoManual;
  final String medicamentoNombre;
  final String? principioActivo;
  final String? concentracion;
  final String? formaFarmaceutica;
  final String dosis;
  final String frecuencia;
  final String duracion;
  final String viaAdministracion;
  final int cantidad;
  final String? indicaciones;
  final int posicion;

  const PrescriptionDetalleModel({
    required this.idRecetaDetalle,
    this.idMedicamento,
    this.nombreMedicamentoManual,
    required this.medicamentoNombre,
    this.principioActivo,
    this.concentracion,
    this.formaFarmaceutica,
    required this.dosis,
    required this.frecuencia,
    required this.duracion,
    required this.viaAdministracion,
    required this.cantidad,
    this.indicaciones,
    required this.posicion,
  });

  factory PrescriptionDetalleModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionDetalleModel(
      idRecetaDetalle: (json['id_receta_detalle'] as num).toInt(),
      idMedicamento: (json['id_medicamento'] as num?)?.toInt(),
      nombreMedicamentoManual: json['nombre_medicamento_manual'] as String?,
      medicamentoNombre: json['medicamento_nombre'] as String? ?? '',
      principioActivo: json['principio_activo'] as String?,
      concentracion: json['concentracion'] as String?,
      formaFarmaceutica: json['forma_farmaceutica'] as String?,
      dosis: json['dosis'] as String? ?? '',
      frecuencia: json['frecuencia'] as String? ?? '',
      duracion: json['duracion'] as String? ?? '',
      viaAdministracion: json['via_administracion'] as String? ?? '',
      cantidad: (json['cantidad'] as num? ?? 0).toInt(),
      indicaciones: json['indicaciones'] as String?,
      posicion: (json['posicion'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_receta_detalle': idRecetaDetalle,
      'id_medicamento': idMedicamento,
      'nombre_medicamento_manual': nombreMedicamentoManual,
      'medicamento_nombre': medicamentoNombre,
      'principio_activo': principioActivo,
      'concentracion': concentracion,
      'forma_farmaceutica': formaFarmaceutica,
      'dosis': dosis,
      'frecuencia': frecuencia,
      'duracion': duracion,
      'via_administracion': viaAdministracion,
      'cantidad': cantidad,
      'indicaciones': indicaciones,
      'posicion': posicion,
    };
  }
}

class PrescriptionModel {
  final int idReceta;
  final int idClinica;
  final int idConsulta;
  final int idPaciente;
  final int idMedico;
  final int? idDocumento;
  final int? idRecetaSustituta;
  final String folio;
  final String pdfUrl;
  final String? indicacionesGenerales;
  final String algoritmoFirma;
  final String keyId;
  final int versionPayload;
  final String hashPdf;
  final String fechaEmision;
  final String fechaVencimiento;
  final bool estaVencida;
  final String estado;
  final String? motivoAnulacion;
  final String? observacionesAnulacion;
  final String? fechaAnulacion;
  final PrescriptionMedicoModel medico;
  final PrescriptionPacienteModel paciente;
  final List<PrescriptionDetalleModel> detalles;

  const PrescriptionModel({
    required this.idReceta,
    required this.idClinica,
    required this.idConsulta,
    required this.idPaciente,
    required this.idMedico,
    this.idDocumento,
    this.idRecetaSustituta,
    required this.folio,
    required this.pdfUrl,
    this.indicacionesGenerales,
    required this.algoritmoFirma,
    required this.keyId,
    required this.versionPayload,
    required this.hashPdf,
    required this.fechaEmision,
    required this.fechaVencimiento,
    required this.estaVencida,
    required this.estado,
    this.motivoAnulacion,
    this.observacionesAnulacion,
    this.fechaAnulacion,
    required this.medico,
    required this.paciente,
    required this.detalles,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      idReceta: (json['id_receta'] as num).toInt(),
      idClinica: (json['id_clinica'] as num).toInt(),
      idConsulta: (json['id_consulta'] as num).toInt(),
      idPaciente: (json['id_paciente'] as num).toInt(),
      idMedico: (json['id_medico'] as num).toInt(),
      idDocumento: (json['id_documento'] as num?)?.toInt(),
      idRecetaSustituta: (json['id_receta_sustituta'] as num?)?.toInt(),
      folio: json['folio'] as String? ?? '',
      pdfUrl: json['pdf_url'] as String? ?? '',
      indicacionesGenerales: json['indicaciones_generales'] as String?,
      algoritmoFirma: json['algoritmo_firma'] as String? ?? '',
      keyId: json['key_id'] as String? ?? '',
      versionPayload: (json['version_payload'] as num? ?? 0).toInt(),
      hashPdf: json['hash_pdf'] as String? ?? '',
      fechaEmision: json['fecha_emision'] as String? ?? '',
      fechaVencimiento: json['fecha_vencimiento'] as String? ?? '',
      estaVencida: json['esta_vencida'] as bool? ?? false,
      // No convertir estados inválidos/ausentes en EMITIDA: se conserva el
      // crudo ('' si falta) para que el dominio lo mapee a desconocido.
      estado: json['estado'] as String? ?? '',
      motivoAnulacion: json['motivo_anulacion'] as String?,
      observacionesAnulacion: json['observaciones_anulacion'] as String?,
      fechaAnulacion: json['fecha_anulacion'] as String?,
      medico: PrescriptionMedicoModel.fromJson(
        json['medico'] as Map<String, dynamic>? ?? const {},
      ),
      paciente: PrescriptionPacienteModel.fromJson(
        json['paciente'] as Map<String, dynamic>? ?? const {},
      ),
      detalles: (json['detalles'] as List<dynamic>? ?? [])
          .map(
            (e) => PrescriptionDetalleModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_receta': idReceta,
      'id_clinica': idClinica,
      'id_consulta': idConsulta,
      'id_paciente': idPaciente,
      'id_medico': idMedico,
      'id_documento': idDocumento,
      'id_receta_sustituta': idRecetaSustituta,
      'folio': folio,
      'pdf_url': pdfUrl,
      'indicaciones_generales': indicacionesGenerales,
      'algoritmo_firma': algoritmoFirma,
      'key_id': keyId,
      'version_payload': versionPayload,
      'hash_pdf': hashPdf,
      'fecha_emision': fechaEmision,
      'fecha_vencimiento': fechaVencimiento,
      'esta_vencida': estaVencida,
      'estado': estado,
      'motivo_anulacion': motivoAnulacion,
      'observaciones_anulacion': observacionesAnulacion,
      'fecha_anulacion': fechaAnulacion,
      'medico': medico.toJson(),
      'paciente': paciente.toJson(),
      'detalles': detalles.map((e) => e.toJson()).toList(),
    };
  }
}

/// Respuesta paginada `RecetaListResponse`: solo `items` y `total`.
class PrescriptionListModel {
  final List<PrescriptionModel> items;
  final int total;

  const PrescriptionListModel({required this.items, required this.total});

  factory PrescriptionListModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionListModel(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => PrescriptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'items': items.map((e) => e.toJson()).toList(), 'total': total};
  }
}
