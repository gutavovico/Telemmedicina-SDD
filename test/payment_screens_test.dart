import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/features/payments/data/models/payment_model.dart';
import 'package:mobile_telemedicina/features/payments/presentation/providers/payment_provider.dart';
import 'package:mobile_telemedicina/features/payments/presentation/screens/payment_checkout_screen.dart';
import 'package:mobile_telemedicina/features/payments/presentation/screens/payment_history_screen.dart';

/// Proveedor de CU19 con respuestas controladas para probar las pantallas.
class _PaymentProviderFake extends PaymentProvider {
  _PaymentProviderFake({
    this.pendingItems = const [],
    this.paymentItems = const [],
    this.checkoutResult,
    this.simulatedResult,
    this.error,
  });

  final List<PendingPaymentModel> pendingItems;
  final List<PaymentModel> paymentItems;
  final CheckoutModel? checkoutResult;
  final PaymentModel? simulatedResult;
  final String? error;
  final List<int> receiptRequests = [];

  @override
  bool get isLoading => false;

  @override
  bool get isProcessing => false;

  @override
  String? get errorMessage => error;

  @override
  List<PendingPaymentModel> get pending => pendingItems;

  @override
  List<PaymentModel> get payments => paymentItems;

  @override
  CheckoutModel? get checkout => checkoutResult;

  @override
  Future<void> loadPendingAndHistory() async {}

  @override
  Future<CheckoutModel?> startCheckout(int idCita) async => checkoutResult;

  @override
  Future<PaymentModel?> simulatePayment(int idPago) async => simulatedResult;

  @override
  Future<Uint8List?> downloadReceipt(int idPago) async {
    receiptRequests.add(idPago);
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

ComprobanteModel _comprobante() => const ComprobanteModel(
  idComprobante: 5,
  idPago: 1,
  numeroComprobante: 'REC-20261104-000001',
  tipoComprobante: 'RECIBO',
  estado: 'EMITIDO',
);

PaymentModel _pago({String estado = 'PAGADO', bool conComprobante = true}) {
  return PaymentModel(
    idPago: 1,
    idUsuario: 15,
    idCita: 38,
    monto: 120.50,
    moneda: 'BOB',
    metodoPago: 'TARJETA',
    pasarela: 'STRIPE',
    estado: estado,
    citaFecha: '2026-11-10',
    citaHora: '09:00',
    medicoNombre: 'Dr. Roberto Gómez',
    especialidadNombre: 'Cardiología',
    tipoConsulta: 'TELEMEDICINA',
    comprobante: conComprobante ? _comprobante() : null,
  );
}

CheckoutModel _checkout({bool simulado = false}) {
  return CheckoutModel(
    idPago: 1,
    idUsuario: 15,
    idCita: 38,
    monto: 120.50,
    moneda: 'BOB',
    estado: 'PENDIENTE',
    urlCheckout: 'https://checkout.stripe.com/c/pay/cs_test_demo',
    citaFecha: '2026-11-10',
    citaHora: '09:00',
    medicoNombre: 'Dr. Roberto Gómez',
    especialidadNombre: 'Cardiología',
    tipoConsulta: 'TELEMEDICINA',
    qrPayload: 'https://backend-telemedicina.onrender.com/pagos/qr/token-abc',
    simulado: simulado,
  );
}

PendingPaymentModel _pendiente() => const PendingPaymentModel(
  idCita: 38,
  fechaCita: '2026-11-10',
  horaInicio: '09:00',
  medicoNombre: 'Dr. Roberto Gómez',
  especialidadNombre: 'Cardiología',
  tipoConsulta: 'TELEMEDICINA',
  monto: 120.50,
  moneda: 'BOB',
);

Future<void> _montar(WidgetTester tester, Widget pantalla, _PaymentProviderFake provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PaymentProvider>.value(
      value: provider,
      child: MaterialApp(home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CU19 pantalla Mis pagos (móvil)', () {
    testWidgets('muestra citas pendientes, historial y comprobante', (tester) async {
      await _montar(
        tester,
        const PaymentHistoryScreen(),
        _PaymentProviderFake(pendingItems: [_pendiente()], paymentItems: [_pago()]),
      );

      expect(find.text('Mis pagos'), findsOneWidget);
      expect(find.text('Citas pendientes de pago'), findsOneWidget);
      expect(find.text('Historial de pagos'), findsOneWidget);
      expect(find.text('Dr. Roberto Gómez'), findsAtLeastNWidgets(1));
      expect(find.text('Bs. 120.50 BOB'), findsOneWidget);
      expect(find.text('Pagar'), findsOneWidget);
      expect(find.textContaining('REC-20261104-000001'), findsOneWidget);
    });

    testWidgets('sin datos muestra los estados vacíos', (tester) async {
      await _montar(tester, const PaymentHistoryScreen(), _PaymentProviderFake());

      expect(find.text('No tienes citas pendientes de pago.'), findsOneWidget);
      expect(find.text('Aún no registras pagos.'), findsOneWidget);
    });

    testWidgets('Pagar abre el checkout de la cita', (tester) async {
      final provider = _PaymentProviderFake(
        pendingItems: [_pendiente()],
        checkoutResult: _checkout(),
      );
      await _montar(tester, const PaymentHistoryScreen(), provider);

      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      expect(find.text('Pago en línea'), findsOneWidget);
      expect(find.text('Resumen de la cita'), findsOneWidget);
    });
  });

  group('CU19 pantalla Pago en línea (móvil)', () {
    testWidgets('muestra el resumen y el botón de Stripe', (tester) async {
      await _montar(
        tester,
        const PaymentCheckoutScreen(idCita: 38),
        _PaymentProviderFake(checkoutResult: _checkout()),
      );

      expect(find.text('Pago en línea'), findsOneWidget);
      expect(find.text('Resumen de la cita'), findsOneWidget);
      expect(find.text('STRIPE'), findsOneWidget);
      expect(find.text('Bs. 120.50 BOB'), findsOneWidget);
      expect(find.text('Pagar con tarjeta en Stripe'), findsOneWidget);
      expect(find.text('Ya pagué, verificar estado'), findsOneWidget);
      expect(find.text('Pago con QR'), findsNothing);
    });

    testWidgets('en modo demostración confirma el pago y muestra el comprobante', (tester) async {
      final provider = _PaymentProviderFake(
        checkoutResult: _checkout(simulado: true),
        simulatedResult: _pago(),
      );
      await _montar(tester, const PaymentCheckoutScreen(idCita: 38), provider);

      expect(find.text('DEMO'), findsOneWidget);
      await tester.tap(find.text('Confirmar pago (demostración)'));
      await tester.pumpAndSettle();

      expect(find.text('¡Pago registrado correctamente!'), findsOneWidget);
      expect(find.textContaining('REC-20261104-000001'), findsOneWidget);
      expect(find.text('Descargar comprobante PDF'), findsOneWidget);
    });

    testWidgets('muestra el error del backend con opción de reintentar', (tester) async {
      await _montar(
        tester,
        const PaymentCheckoutScreen(idCita: 38),
        _PaymentProviderFake(error: 'La cita ya fue pagada'),
      );

      expect(find.text('La cita ya fue pagada'), findsWidgets);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
