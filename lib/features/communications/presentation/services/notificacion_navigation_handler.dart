import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/notificacion_entity.dart';

/// Coordinador de navegación segura para notificaciones móviles (CU20).
///
/// Valida previamente la sesión en [AuthController]:
/// - Si la sesión está cerrada o expirada, guarda el destino pendiente, redirige a `/login`
///   y permite retomar la ruta automáticamente una vez autenticado.
/// - Si la sesión está activa, resuelve la ruta exacta según rol y tipo de recurso.
class NotificacionNavigationHandler {
  static String? _rutaPendiente;
  static Object? _argumentosPendientes;

  static String? get rutaPendiente => _rutaPendiente;

  static void limpiarPendiente() {
    _rutaPendiente = null;
    _argumentosPendientes = null;
  }

  static String resolverRuta({
    required String tipo,
    String? recursoTipo,
    String? rolUsuario,
    String? enlaceAccion,
  }) {
    final t = tipo.toUpperCase();
    final r = (recursoTipo ?? '').toUpperCase();
    final rol = (rolUsuario ?? 'paciente').toLowerCase();
    final enlace = (enlaceAccion ?? '').toLowerCase();

    if (t == 'SALA_VIRTUAL_ABIERTA' ||
        t == 'PACIENTE_EN_ESPERA' ||
        r == 'SALA_VIRTUAL' ||
        r == 'TELECONSULTA') {
      return '/teleconsulta/sala-espera';
    }
    if (enlace.contains('/fichas')) {
      return '/fichas';
    }
    if (t == 'MEDICACION_TRATAMIENTO' || r == 'TRATAMIENTO' || r == 'RECETA') {
      return '/recetas';
    }
    if (t == 'DOCUMENTO_DISPONIBLE' ||
        t == 'RESULTADO_LAB_LISTO' ||
        r == 'DOCUMENTO' ||
        r == 'LABORATORIO') {
      return '/mis-documentos';
    }
    if (rol == 'medico' || rol == 'doctor') {
      return '/appointments';
    }
    return '/mis-citas';
  }

  /// Abre la pantalla relacionada a una [NotificacionEntity] previa validación de sesión.
  static Future<bool> navegarDesdeNotificacion(
    BuildContext context,
    NotificacionEntity notif,
  ) async {
    final auth = context.read<AuthController>();
    final destino = resolverRuta(
      tipo: notif.tipo,
      recursoTipo: notif.recursoTipo,
      rolUsuario: auth.userRole,
      enlaceAccion: notif.enlaceAccion,
    );
    final args = notif.recursoId != null
        ? {'recurso_id': notif.recursoId, 'tipo': notif.tipo}
        : null;

    if (!auth.isAuthenticated) {
      _rutaPendiente = destino;
      _argumentosPendientes = args;
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
      return false;
    }

    if (context.mounted) {
      Navigator.of(context).pushNamed(destino, arguments: args);
    }
    return true;
  }

  /// Retoma la navegación pendiente inmediatamente después de un login exitoso.
  static void consumirNavegacionPendiente(BuildContext context) {
    final ruta = _rutaPendiente;
    final args = _argumentosPendientes;
    if (ruta == null) return;
    limpiarPendiente();
    if (context.mounted) {
      Navigator.of(context).pushNamed(ruta, arguments: args);
    }
  }
}
