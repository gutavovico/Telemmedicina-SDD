import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/notificacion_model.dart';

/// Servicio de notificaciones emergentes nativas (heads-up tipo WhatsApp) sin apps externas ni Firebase.
class LocalHeadsUpNotificationService {
  static final LocalHeadsUpNotificationService instance =
      LocalHeadsUpNotificationService._internal();
  factory LocalHeadsUpNotificationService() => instance;
  LocalHeadsUpNotificationService._internal();

  static const String _channelId = 'telemedicina_emergentes_v1';
  static const String _channelName = 'Alertas de Telemedicina';
  static const String _channelDescription =
      'Notificaciones emergentes de citas, salas de teleconsulta y resultados médicos.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;
  void Function(Map<String, dynamic> payload)? onTapNotificacion;

  /// Inicializa el plugin nativo, crea el canal de máxima prioridad y solicita permiso en Android 13+.
  Future<void> inicializar() async {
    if (_inicializado || kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _manejarToquePayload(response.payload);
        },
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(channel);
        await androidPlugin.requestNotificationsPermission();
      }

      // Refuerzo de permiso POST_NOTIFICATIONS en Android 13+
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {}

      _inicializado = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocalHeadsUpNotificationService] Error inicializando: $e');
      }
    }
  }

  /// Muestra una notificación emergente nativa en la parte superior de Android (heads-up tipo WhatsApp)
  /// que aparece con sonido/vibración y luego se repliega automáticamente en la barra de estado.
  Future<void> mostrarNotificacionEmergente(NotificacionModel notif) async {
    if (kIsWeb) return;
    if (!_inicializado) {
      await inicializar();
    }
    if (!_inicializado) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        ticker: notif.titulo,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          notif.mensaje,
          contentTitle: notif.titulo,
          summaryText: 'Telemedicina',
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
        presentBadge: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final payload = jsonEncode({
        'id': notif.id,
        'tipo': notif.tipo,
        'recurso_tipo': notif.recursoTipo,
        'recurso_id': notif.recursoId,
        'enlace_accion': notif.enlaceAccion,
      });

      final notifId = notif.id > 0
          ? notif.id
          : DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _plugin.show(
        notifId,
        notif.titulo,
        notif.mensaje,
        details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocalHeadsUpNotificationService] Error mostrando alerta: $e');
      }
    }
  }

  void _manejarToquePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        onTapNotificacion?.call(decoded);
      }
    } catch (_) {}
  }
}
