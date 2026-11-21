import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/datasources/payment_remote_datasource.dart';
import '../../data/models/payment_model.dart';

/// Estado de CU19 en la app móvil.
class PaymentProvider with ChangeNotifier {
  final PaymentRemoteDataSource _dataSource = PaymentRemoteDataSource();

  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;
  CheckoutModel? _checkout;
  List<PendingPaymentModel> _pending = const [];
  List<PaymentModel> _payments = const [];

  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  CheckoutModel? get checkout => _checkout;
  List<PendingPaymentModel> get pending => _pending;
  List<PaymentModel> get payments => _payments;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<CheckoutModel?> startCheckout(int idCita) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _checkout = await _dataSource.createCheckout(idCita);
      return _checkout;
    } catch (e) {
      _errorMessage = _mensaje(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingAndHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _dataSource.getPendingPayments(),
        _dataSource.getMyPayments(),
      ]);
      _pending = results[0] as List<PendingPaymentModel>;
      _payments = results[1] as List<PaymentModel>;
    } catch (e) {
      _errorMessage = _mensaje(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentModel?> syncPayment(int idPago) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final pago = await _dataSource.syncPayment(idPago);
      _reemplazarPago(pago);
      return pago;
    } catch (e) {
      _errorMessage = _mensaje(e);
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<PaymentModel?> simulatePayment(int idPago) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final pago = await _dataSource.simulatePayment(idPago);
      _reemplazarPago(pago);
      return pago;
    } catch (e) {
      _errorMessage = _mensaje(e);
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> downloadReceipt(int idPago) async {
    try {
      return await _dataSource.downloadReceipt(idPago);
    } catch (e) {
      _errorMessage = _mensaje(e);
      notifyListeners();
      return null;
    }
  }

  void _reemplazarPago(PaymentModel pago) {
    _payments = [
      pago,
      ..._payments.where((p) => p.idPago != pago.idPago),
    ];
    _pending = _pending.where((p) => p.idCita != pago.idCita).toList();
  }

  String _mensaje(Object error) {
    if (error is ApiException) return error.message;
    return 'No fue posible completar la operación de pago. Intenta nuevamente.';
  }
}
