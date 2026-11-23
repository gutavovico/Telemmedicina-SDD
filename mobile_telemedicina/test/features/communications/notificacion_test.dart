import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_telemedicina/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mobile_telemedicina/features/communications/data/models/notificacion_model.dart';
import 'package:mobile_telemedicina/features/communications/data/services/fcm_adapter.dart';
import 'package:mobile_telemedicina/features/communications/presentation/providers/notificacion_provider.dart';
import 'package:mobile_telemedicina/features/communications/presentation/screens/notificaciones_screen.dart';
import 'package:mobile_telemedicina/features/communications/presentation/services/notificacion_navigation_handler.dart';
import 'package:mobile_telemedicina/features/communications/presentation/widgets/in_app_notification_banner.dart';
import 'package:mobile_telemedicina/features/medical_records/presentation/screens/home_screen.dart';

void main() {
  group('CU20 - Notificaciones Móvil', () {
    test('NotificacionModel serializa y deserializa correctamente con badge WhatsApp/Push', () {
      final json = {
        'id_notificacion': 10,
        'id_clinica': 1,
        'id_usuario': 5,
        'rol_destinatario': 'PACIENTE',
        'tipo': 'RECORDATORIO_CITA',
        'categoria': 'CITAS',
        'canal': 'SMS',
        'canal_badge': 'WhatsApp',
        'titulo': 'Recordatorio de cita',
        'mensaje': 'Mañana 10:30 con la Dra. Lucía Rojas',
        'recurso_tipo': 'CITA',
        'recurso_id': '99',
        'created_at': DateTime.now().toIso8601String(),
        'estado': 'ENVIADO',
      };

      final model = NotificacionModel.fromJson(json);
      expect(model.id, 10);
      expect(model.canalBadge, 'WhatsApp');
      expect(model.estaLeida, isFalse);
      expect(model.toJson()['titulo'], 'Recordatorio de cita');
    });

    testWidgets('HomeScreen muestra botón compacto de puerta salir y campana con badge',
        (tester) async {
      final notifProvider = NotificacionProvider();
      notifProvider.establecerNotificacionesLocales([
        NotificacionModel(
          id: 1,
          idUsuario: 1,
          tipo: 'SALA_VIRTUAL_ABIERTA',
          categoria: 'CITAS',
          canal: 'PUSH',
          canalBadge: 'Push',
          titulo: 'La Dra. Rojas abrió la sala',
          mensaje: 'Tu teleconsulta de las 10:30 está lista.',
          creadaEn: DateTime.now(),
          estado: 'ENVIADO',
        ),
        NotificacionModel(
          id: 2,
          idUsuario: 1,
          tipo: 'DOCUMENTO_DISPONIBLE',
          categoria: 'DOCUMENTOS',
          canal: 'EMAIL',
          canalBadge: 'Correo',
          titulo: 'Nuevo resultado disponible',
          mensaje: 'Hemograma completo',
          creadaEn: DateTime.now(),
          estado: 'ENVIADO',
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthController()),
            ChangeNotifierProvider.value(value: notifProvider),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      expect(find.byKey(const Key('home_notifications_bell_btn')), findsOneWidget);
      expect(find.byKey(const Key('home_compact_logout_btn')), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app_rounded), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('NotificacionesScreen renderiza Hoy/Ayer, tabs, punto azul y marca todas leídas',
        (tester) async {
      final now = DateTime.now();
      final ayer = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(hours: 9));

      final notifProvider = NotificacionProvider();
      notifProvider.establecerNotificacionesLocales([
        NotificacionModel(
          id: 1,
          idUsuario: 1,
          tipo: 'SALA_VIRTUAL_ABIERTA',
          categoria: 'CITAS',
          canal: 'PUSH',
          canalBadge: 'Push',
          titulo: 'La Dra. Rojas abrió la sala',
          mensaje: 'Tu teleconsulta de las 10:30 está lista.',
          recursoTipo: 'SALA_VIRTUAL',
          recursoId: '42',
          creadaEn: now.subtract(const Duration(minutes: 1)),
          estado: 'ENVIADO',
        ),
        NotificacionModel(
          id: 2,
          idUsuario: 1,
          tipo: 'DOCUMENTO_DISPONIBLE',
          categoria: 'DOCUMENTOS',
          canal: 'EMAIL',
          canalBadge: 'Correo',
          titulo: 'Nuevo resultado disponible',
          mensaje: 'Hemograma completo · Laboratorio central',
          recursoTipo: 'DOCUMENTO',
          recursoId: '77',
          creadaEn: now.subtract(const Duration(hours: 2)),
          estado: 'ENVIADO',
        ),
        NotificacionModel(
          id: 3,
          idUsuario: 1,
          tipo: 'RECORDATORIO_CITA',
          categoria: 'CITAS',
          canal: 'SMS',
          canalBadge: 'WhatsApp',
          titulo: 'Recordatorio de cita',
          mensaje: 'Mañana 10:30 con la Dra. Lucía Rojas',
          recursoTipo: 'CITA',
          recursoId: '88',
          creadaEn: ayer,
          leidaEn: ayer,
          estado: 'LEIDA',
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthController()),
            ChangeNotifierProvider.value(value: notifProvider),
          ],
          child: const MaterialApp(home: NotificacionesScreen()),
        ),
      );

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Citas'), findsOneWidget);
      expect(find.text('Documentos'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ayer'), findsOneWidget);
      expect(find.byKey(const Key('notif_unread_dot_1')), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      // Filtrar por Documentos
      await tester.tap(find.byKey(const Key('notif_tab_DOCUMENTOS')));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo resultado disponible'), findsOneWidget);
      expect(find.text('La Dra. Rojas abrió la sala'), findsNothing);

      // Volver a Todas y marcar todas como leídas
      await tester.tap(find.byKey(const Key('notif_tab_TODAS')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notif_mark_all_read_btn')));
      await tester.pumpAndSettle();
      expect(notifProvider.conteoNoLeidas, 0);
      expect(find.byKey(const Key('notif_unread_dot_1')), findsNothing);
    });

    testWidgets('NotificacionNavigationHandler exige sesión activa y redirige a /login',
        (tester) async {
      NotificacionNavigationHandler.limpiarPendiente();
      final notif = NotificacionModel(
        id: 1,
        idUsuario: 1,
        tipo: 'SALA_VIRTUAL_ABIERTA',
        categoria: 'CITAS',
        canal: 'PUSH',
        canalBadge: 'Push',
        titulo: 'Sala lista',
        mensaje: 'Ingresa a tu teleconsulta',
        recursoTipo: 'SALA_VIRTUAL',
        recursoId: '42',
        creadaEn: DateTime.now(),
        estado: 'ENVIADO',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthController(),
          child: MaterialApp(
            routes: {
              '/login': (_) => const Scaffold(body: Text('Pantalla Login')),
              '/teleconsulta/sala-espera': (_) => const Scaffold(body: Text('Sala Espera')),
            },
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    NotificacionNavigationHandler.navegarDesdeNotificacion(ctx, notif),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla Login'), findsOneWidget);
      expect(NotificacionNavigationHandler.rutaPendiente, '/teleconsulta/sala-espera');
    });

    testWidgets('InAppNotificationBanner muestra aviso en primer plano y responde al toque',
        (tester) async {
      var tapped = false;
      final msg = NotificacionMensajePush(
        id: 'm1',
        titulo: 'La Dra. Rojas abrió la sala',
        cuerpo: 'Tu teleconsulta está lista.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InAppNotificationBanner(
              mensaje: msg,
              onTap: () => tapped = true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('La Dra. Rojas abrió la sala'), findsOneWidget);
      await tester.tap(find.text('La Dra. Rojas abrió la sala'));
      expect(tapped, isTrue);
    });
  });
}
