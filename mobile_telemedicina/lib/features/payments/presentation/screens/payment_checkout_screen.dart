import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/payment_model.dart';
import '../providers/payment_provider.dart';

/// CU19: pago en línea de una cita o teleconsulta (Stripe Checkout + QR).
class PaymentCheckoutScreen extends StatefulWidget {
  final int? idCita;

  const PaymentCheckoutScreen({super.key, this.idCita});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen>
    with WidgetsBindingObserver {
  int? _idCita;
  bool _inicializado = false;
  CheckoutModel? _checkout;
  PaymentModel? _pagoActual;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _idCita = widget.idCita;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializado) return;
    _inicializado = true;

    if (_idCita == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _idCita = args;
      } else if (args is Map && args['idCita'] is int) {
        _idCita = args['idCita'] as int;
      }
    }
    _iniciarCheckout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del navegador de Stripe, se consulta el estado real del pago.
    if (state == AppLifecycleState.resumed && _pagoActual == null) {
      _verificarEstado(silencioso: true);
    }
  }

  Future<void> _iniciarCheckout() async {
    final idCita = _idCita;
    if (idCita == null || idCita <= 0) {
      _mostrarError('No se indicó la cita a pagar.');
      return;
    }

    final provider = context.read<PaymentProvider>();
    final checkout = await provider.startCheckout(idCita);
    if (!mounted) return;
    if (checkout == null) {
      _mostrarError(provider.errorMessage ?? 'No se pudo iniciar el pago.');
      return;
    }
    setState(() {
      _checkout = checkout;
      _pagoActual = checkout.estaPagado ? checkout : null;
    });
  }

  Future<void> _pagar() async {
    final checkout = _checkout;
    if (checkout == null) return;

    if (checkout.simulado) {
      final provider = context.read<PaymentProvider>();
      final pago = await provider.simulatePayment(checkout.idPago);
      if (!mounted) return;
      if (pago != null) {
        setState(() => _pagoActual = pago);
      } else {
        _mostrarError(provider.errorMessage ?? 'No se pudo confirmar el pago.');
      }
      return;
    }

    final url = checkout.urlCheckout;
    if (url == null || url.isEmpty) {
      _mostrarError('La pasarela no devolvió un enlace de pago.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _mostrarError('No se pudo abrir la pasarela de pago.');
    }
  }

  Future<void> _verificarEstado({bool silencioso = false}) async {
    final idPago = _pagoActual?.idPago ?? _checkout?.idPago;
    if (idPago == null) return;

    final provider = context.read<PaymentProvider>();
    final pago = await provider.syncPayment(idPago);
    if (!mounted) return;
    if (pago == null) {
      if (!silencioso) {
        _mostrarError(provider.errorMessage ?? 'No se pudo verificar el pago.');
      }
      return;
    }
    if (pago.estaPagado) {
      setState(() => _pagoActual = pago);
    } else if (!silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El pago aún no ha sido confirmado por la pasarela.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _descargarComprobante() async {
    final pago = _pagoActual;
    if (pago == null || _descargando) return;

    setState(() => _descargando = true);
    final provider = context.read<PaymentProvider>();
    final bytes = await provider.downloadReceipt(pago.idPago);
    if (!mounted) return;
    setState(() => _descargando = false);

    if (bytes == null) {
      _mostrarError(provider.errorMessage ?? 'No se pudo descargar el comprobante.');
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'comprobante_${pago.idPago}.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      text: 'Comprobante de pago CU19',
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.black,
        title: const Text(
          'Pago en línea',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: provider.isLoading && _checkout == null
            ? const Center(child: CircularProgressIndicator())
            : _checkout == null
                ? _buildErrorState(provider)
                : _buildContenido(provider),
      ),
    );
  }

  Widget _buildErrorState(PaymentProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'No se pudo iniciar el pago.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _iniciarCheckout,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido(PaymentProvider provider) {
    final checkout = _checkout!;
    final pago = _pagoActual;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildResumen(checkout),
          const SizedBox(height: 16),
          if (pago != null && pago.estaPagado)
            _buildPagoConfirmado(pago)
          else ...[
            _buildBotonPago(checkout, provider),
            const SizedBox(height: 12),
            if (!checkout.simulado)
              OutlinedButton.icon(
                onPressed: provider.isProcessing ? null : _verificarEstado,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Ya pagué, verificar estado'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.outline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumen(CheckoutModel checkout) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Resumen de la cita',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: checkout.simulado
                      ? AppColors.warningContainer
                      : AppColors.successContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  checkout.simulado ? 'DEMO' : 'STRIPE',
                  style: AppTypography.bodySmall.copyWith(
                    color: checkout.simulado
                        ? AppColors.onWarning
                        : AppColors.onSuccessContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _fila('Médico', checkout.medicoNombre ?? 'Especialista'),
          _fila('Especialidad', checkout.especialidadNombre ?? 'Medicina General'),
          _fila('Modalidad', checkout.tipoConsulta ?? 'TELEMEDICINA'),
          _fila('Fecha', '${checkout.citaFecha ?? '—'} ${checkout.citaHora ?? ''}'),
          _fila('Cita', '#${checkout.idCita ?? '—'}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total a pagar', style: AppTypography.bodyMedium),
              Text(
                'Bs. ${checkout.monto.toStringAsFixed(2)} ${checkout.moneda}',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPago(CheckoutModel checkout, PaymentProvider provider) {
    return ElevatedButton.icon(
      onPressed: provider.isProcessing ? null : _pagar,
      icon: const Icon(Icons.lock_outline, size: 20),
      label: Text(
        checkout.simulado
            ? 'Confirmar pago (demostración)'
            : 'Pagar con tarjeta en Stripe',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: checkout.simulado ? AppColors.warning : const Color(0xFF635BFF),
        foregroundColor: checkout.simulado ? AppColors.onWarning : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppTypography.button.copyWith(fontSize: 15),
      ),
    );
  }

  Widget _buildPagoConfirmado(PaymentModel pago) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.successContainer),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 56),
          const SizedBox(height: 10),
          Text(
            '¡Pago registrado correctamente!',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pago.comprobante == null
                ? 'Tu comprobante se está generando.'
                : 'Comprobante N° ${pago.comprobante!.numeroComprobante}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _descargando ? null : _descargarComprobante,
            icon: const Icon(Icons.download_outlined, size: 20),
            label: Text(_descargando ? 'Generando...' : 'Descargar comprobante PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
