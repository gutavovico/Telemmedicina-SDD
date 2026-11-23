import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/payment_model.dart';
import '../providers/payment_provider.dart';
import 'payment_checkout_screen.dart';

/// CU19: historial de pagos y comprobantes del paciente.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadPendingAndHistory();
    });
  }

  Future<void> _recargar() async {
    await context.read<PaymentProvider>().loadPendingAndHistory();
  }

  Future<void> _descargar(PaymentModel pago) async {
    final provider = context.read<PaymentProvider>();
    final bytes = await provider.downloadReceipt(pago.idPago);
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'No se pudo descargar el comprobante.'),
          backgroundColor: AppColors.error,
        ),
      );
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
      text: 'Comprobante de pago',
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
          'Mis pagos',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: provider.isLoading && provider.payments.isEmpty && provider.pending.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (provider.errorMessage != null) ...[
                    _buildError(provider.errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  _buildSeccion(
                    titulo: 'Citas pendientes de pago',
                    icono: Icons.pending_actions_outlined,
                    vacio: 'No tienes citas pendientes de pago.',
                    children: provider.pending
                        .map((cita) => _buildCitaPendiente(cita))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildSeccion(
                    titulo: 'Historial de pagos',
                    icono: Icons.receipt_long_outlined,
                    vacio: 'Aún no registras pagos.',
                    children: provider.payments
                        .map((pago) => _buildPago(pago))
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildError(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: AppTypography.bodySmall.copyWith(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion({
    required String titulo,
    required IconData icono,
    required String vacio,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icono, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${children.length}', style: AppTypography.bodySmall),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                vacio,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _buildCitaPendiente(PendingPaymentModel cita) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cita.medicoNombre ?? 'Especialista',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cita.especialidadNombre ?? 'Medicina General'} · '
                  '${cita.fechaCita ?? '—'} ${cita.horaInicio ?? ''}',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bs. ${cita.monto.toStringAsFixed(2)} ${cita.moneda}',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaymentCheckoutScreen(idCita: cita.idCita),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPago(PaymentModel pago) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pago.estaPagado
                  ? AppColors.successContainer
                  : AppColors.warningContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              pago.estaPagado ? Icons.check_circle : Icons.schedule,
              color: pago.estaPagado ? AppColors.success : AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pago.medicoNombre ?? 'Consulta médica',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Pago #${pago.idPago} · ${pago.estado}'
                  '${pago.comprobante != null ? ' · ${pago.comprobante!.numeroComprobante}' : ''}',
                  style: AppTypography.bodySmall,
                ),
                Text(
                  '${pago.pasarela ?? 'STRIPE'} · ${pago.metodoPago ?? 'TARJETA'}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs. ${pago.monto.toStringAsFixed(2)}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              if (pago.estaPagado)
                TextButton(
                  onPressed: () => _descargar(pago),
                  child: const Text('PDF'),
                )
              else if (pago.idCita != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentCheckoutScreen(idCita: pago.idCita),
                      ),
                    );
                  },
                  child: const Text('Pagar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
