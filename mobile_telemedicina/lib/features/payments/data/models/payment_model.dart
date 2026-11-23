/// Modelos de CU19 - Pagos de servicios médicos y comprobantes.
class ComprobanteModel {
  final int idComprobante;
  final int idPago;
  final String numeroComprobante;
  final String tipoComprobante;
  final String? fechaEmision;
  final String? archivoUrl;
  final String estado;

  const ComprobanteModel({
    required this.idComprobante,
    required this.idPago,
    required this.numeroComprobante,
    required this.tipoComprobante,
    this.fechaEmision,
    this.archivoUrl,
    required this.estado,
  });

  factory ComprobanteModel.fromJson(Map<String, dynamic> json) {
    return ComprobanteModel(
      idComprobante: _toInt(json['id_comprobante']),
      idPago: _toInt(json['id_pago']),
      numeroComprobante: (json['numero_comprobante'] ?? '').toString(),
      tipoComprobante: (json['tipo_comprobante'] ?? 'RECIBO').toString(),
      fechaEmision: json['fecha_emision']?.toString(),
      archivoUrl: json['archivo_url']?.toString(),
      estado: (json['estado'] ?? 'EMITIDO').toString(),
    );
  }
}

class PaymentModel {
  final int idPago;
  final int idUsuario;
  final int? idCita;
  final double monto;
  final String moneda;
  final String? metodoPago;
  final String? pasarela;
  final String? referenciaTransaccion;
  final String? fechaPago;
  final String estado;
  final String? urlCheckout;
  final String? expiraEn;
  final String? citaFecha;
  final String? citaHora;
  final String? medicoNombre;
  final String? especialidadNombre;
  final String? tipoConsulta;
  final ComprobanteModel? comprobante;

  const PaymentModel({
    required this.idPago,
    required this.idUsuario,
    this.idCita,
    required this.monto,
    required this.moneda,
    this.metodoPago,
    this.pasarela,
    this.referenciaTransaccion,
    this.fechaPago,
    required this.estado,
    this.urlCheckout,
    this.expiraEn,
    this.citaFecha,
    this.citaHora,
    this.medicoNombre,
    this.especialidadNombre,
    this.tipoConsulta,
    this.comprobante,
  });

  bool get estaPagado => estado.toUpperCase() == 'PAGADO';

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final comprobanteJson = json['comprobante'];
    return PaymentModel(
      idPago: _toInt(json['id_pago']),
      idUsuario: _toInt(json['id_usuario']),
      idCita: json['id_cita'] == null ? null : _toInt(json['id_cita']),
      monto: _toDouble(json['monto']),
      moneda: (json['moneda'] ?? 'BOB').toString(),
      metodoPago: json['metodo_pago']?.toString(),
      pasarela: json['pasarela']?.toString(),
      referenciaTransaccion: json['referencia_transaccion']?.toString(),
      fechaPago: json['fecha_pago']?.toString(),
      estado: (json['estado'] ?? 'PENDIENTE').toString(),
      urlCheckout: json['url_checkout']?.toString(),
      expiraEn: json['expira_en']?.toString(),
      citaFecha: json['cita_fecha']?.toString(),
      citaHora: json['cita_hora']?.toString(),
      medicoNombre: json['medico_nombre']?.toString(),
      especialidadNombre: json['especialidad_nombre']?.toString(),
      tipoConsulta: json['tipo_consulta']?.toString(),
      comprobante: comprobanteJson is Map<String, dynamic>
          ? ComprobanteModel.fromJson(comprobanteJson)
          : null,
    );
  }
}

class CheckoutModel extends PaymentModel {
  final String? qrUrl;
  final String? qrPayload;
  final bool simulado;

  const CheckoutModel({
    required super.idPago,
    required super.idUsuario,
    super.idCita,
    required super.monto,
    required super.moneda,
    super.metodoPago,
    super.pasarela,
    super.referenciaTransaccion,
    super.fechaPago,
    required super.estado,
    super.urlCheckout,
    super.expiraEn,
    super.citaFecha,
    super.citaHora,
    super.medicoNombre,
    super.especialidadNombre,
    super.tipoConsulta,
    super.comprobante,
    this.qrUrl,
    this.qrPayload,
    required this.simulado,
  });

  factory CheckoutModel.fromJson(Map<String, dynamic> json) {
    final base = PaymentModel.fromJson(json);
    return CheckoutModel(
      idPago: base.idPago,
      idUsuario: base.idUsuario,
      idCita: base.idCita,
      monto: base.monto,
      moneda: base.moneda,
      metodoPago: base.metodoPago,
      pasarela: base.pasarela,
      referenciaTransaccion: base.referenciaTransaccion,
      fechaPago: base.fechaPago,
      estado: base.estado,
      urlCheckout: base.urlCheckout,
      expiraEn: base.expiraEn,
      citaFecha: base.citaFecha,
      citaHora: base.citaHora,
      medicoNombre: base.medicoNombre,
      especialidadNombre: base.especialidadNombre,
      tipoConsulta: base.tipoConsulta,
      comprobante: base.comprobante,
      qrUrl: json['qr_url']?.toString(),
      qrPayload: json['qr_payload']?.toString(),
      simulado: json['simulado'] == true,
    );
  }
}

class PendingPaymentModel {
  final int idCita;
  final String? fechaCita;
  final String? horaInicio;
  final String? horaFin;
  final String? medicoNombre;
  final String? especialidadNombre;
  final String? tipoConsulta;
  final String? estadoCita;
  final double monto;
  final String moneda;
  final String? estadoPago;
  final int? idPago;

  const PendingPaymentModel({
    required this.idCita,
    this.fechaCita,
    this.horaInicio,
    this.horaFin,
    this.medicoNombre,
    this.especialidadNombre,
    this.tipoConsulta,
    this.estadoCita,
    required this.monto,
    required this.moneda,
    this.estadoPago,
    this.idPago,
  });

  factory PendingPaymentModel.fromJson(Map<String, dynamic> json) {
    return PendingPaymentModel(
      idCita: _toInt(json['id_cita']),
      fechaCita: json['fecha_cita']?.toString(),
      horaInicio: json['hora_inicio']?.toString(),
      horaFin: json['hora_fin']?.toString(),
      medicoNombre: json['medico_nombre']?.toString(),
      especialidadNombre: json['especialidad_nombre']?.toString(),
      tipoConsulta: json['tipo_consulta']?.toString(),
      estadoCita: json['estado_cita']?.toString(),
      monto: _toDouble(json['monto']),
      moneda: (json['moneda'] ?? 'BOB').toString(),
      estadoPago: json['estado_pago']?.toString(),
      idPago: json['id_pago'] == null ? null : _toInt(json['id_pago']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
