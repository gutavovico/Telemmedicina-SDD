import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Genera y persiste localmente un UUID v4 único para identificar esta instalación
/// móvil ante el backend de notificaciones (CU20). No requiere paquetes externos.
class DispositivoHelper {
  static const String _kDispositivoId = 'telemedicina_dispositivo_id';
  static String? _cache;

  static Future<String> obtenerDispositivoId() async {
    if (_cache != null && _cache!.isNotEmpty) return _cache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kDispositivoId);
      if (id == null || id.isEmpty) {
        id = _generarUuidV4();
        await prefs.setString(_kDispositivoId, id);
      }
      _cache = id;
      return id;
    } catch (_) {
      _cache = _generarUuidV4();
      return _cache!;
    }
  }

  static String _generarUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
