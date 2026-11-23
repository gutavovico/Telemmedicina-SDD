import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/medical_records/presentation/session/prescription_session_coordinator.dart'
    show prescriptionNavigatorKey;
import '../config/api_config.dart';
import '../network/api_client.dart';

/// CU19: notificaciones push solo para la APK Android.
///
/// Implementación real con Firebase Cloud Messaging y flutter_local_notifications.
/// Solo se compila en plataformas no-web (Android).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const String _channelId = 'cu19_pagos';
  static const String _channelName = 'Pagos';
  static const String _deviceIdKey = 'cu19_push_device_id';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Inicializa Firebase y el canal local. Silencioso si falla.
  Future<void> initialize() async {
    if (!_isAndroid || _ready) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      await _initLocalNotifications();

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      // Si FCM rota el token, se vuelve a registrar en el backend.
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        registerCurrentToken();
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFromMessage(initial);
        });
      }

      _ready = true;
    } catch (e) {
      debugPrint('PushService no disponible: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          prescriptionNavigatorKey.currentState?.pushNamed('/pagos');
        }
      },
    );
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Avisos de pagos confirmados',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Avisos de pagos confirmados',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  void _openFromMessage(RemoteMessage message) {
    final tipo = message.data['tipo'];
    if (tipo == null || tipo == 'PAGO_CONFIRMADO') {
      prescriptionNavigatorKey.currentState?.pushNamed('/pagos');
    }
  }

  /// Registra el token FCM del dispositivo en el backend.
  Future<void> registerCurrentToken() async {
    if (!_isAndroid || !_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final response = await ApiClient().post(
        ApiConfig.pushDevicesUrl,
        body: {'token': token, 'plataforma': 'ANDROID'},
      );
      final id = response is Map ? response['id_dispositivo'] : null;
      final parsed = id is int ? id : int.tryParse('${id ?? ''}');
      if (parsed != null && parsed > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_deviceIdKey, parsed);
      }
    } catch (e) {
      debugPrint('No se pudo registrar el token push: $e');
    }
  }

  /// Desactiva el dispositivo al cerrar sesión.
  Future<void> unregisterDevice() async {
    if (!_isAndroid || !_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_deviceIdKey);
      if (id != null && id > 0) {
        await ApiClient().delete(ApiConfig.pushDeviceUrl(id));
        await prefs.remove(_deviceIdKey);
      }
    } catch (e) {
      debugPrint('No se pudo revocar el token push: $e');
    }
  }
}
