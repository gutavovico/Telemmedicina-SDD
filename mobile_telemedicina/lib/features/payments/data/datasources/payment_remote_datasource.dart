import 'dart:typed_data';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/payment_model.dart';

/// Acceso remoto a los endpoints de CU19.
class PaymentRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<CheckoutModel> createCheckout(
    int idCita, {
    String canal = 'MOVIL',
    String metodoPago = 'TARJETA',
  }) async {
    final response = await _apiClient.post(
      ApiConfig.paymentsCheckoutUrl,
      body: {
        'id_cita': idCita,
        'canal': canal,
        'metodo_pago': metodoPago,
      },
    );
    return CheckoutModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<PendingPaymentModel>> getPendingPayments() async {
    final response = await _apiClient.get(ApiConfig.paymentsPendingUrl);
    final data = response as Map<String, dynamic>;
    final items = (data['items'] as List? ?? const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(PendingPaymentModel.fromJson)
        .toList();
  }

  Future<List<PaymentModel>> getMyPayments() async {
    final response = await _apiClient.get(ApiConfig.paymentsMineUrl);
    final data = response as Map<String, dynamic>;
    final items = (data['items'] as List? ?? const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentModel.fromJson)
        .toList();
  }

  Future<PaymentModel> syncPayment(int idPago) async {
    final response = await _apiClient.post(ApiConfig.paymentSyncUrl(idPago));
    return PaymentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<PaymentModel> simulatePayment(int idPago) async {
    final response = await _apiClient.post(
      ApiConfig.paymentSimulateUrl(idPago),
    );
    return PaymentModel.fromJson(response as Map<String, dynamic>);
  }

  Future<Uint8List> downloadReceipt(int idPago) {
    return _apiClient.downloadBytes(ApiConfig.paymentReceiptUrl(idPago));
  }
}
