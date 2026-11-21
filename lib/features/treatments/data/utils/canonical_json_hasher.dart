import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Serializador JSON canónico y hasher SHA-256 equivalente a Python:
/// `json.dumps(..., sort_keys=True, separators=(',', ':'), ensure_ascii=False)`
///
/// Compatible con la serialización de modelos de Pydantic v2
/// (`RegistroDosis.model_dump(mode="json")`).
///
/// Utilizado para garantizar la idempotencia estricta en el registro de dosis (CU17).
class CanonicalJsonHasher {
  CanonicalJsonHasher._();

  static final RegExp _isoRegex = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(?::(\d{2}))?(?:\.(\d+))?(Z|[+-]\d{2}(?::?\d{2})?)?$',
  );

  /// Formatea un [DateTime] en formato canónico ISO 8601 idéntico a Python Pydantic v2:
  /// - Si es UTC con microsegundo == 0: `YYYY-MM-DDTHH:mm:ssZ` (¡sin `.000`!).
  /// - Si es UTC con microsegundo > 0: `YYYY-MM-DDTHH:mm:ss.ffffffZ` (6 dígitos fraccionales).
  /// - Si tiene offset horario (ej. `-04:00`): se preserva el offset `YYYY-MM-DDTHH:mm:ss-04:00`
  ///   (o con microsegundos si tiene).
  static String formatCanonicalDateTime(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');

    final totalMicros = dt.millisecond * 1000 + dt.microsecond;
    final fracStr =
        totalMicros > 0 ? '.${totalMicros.toString().padLeft(6, '0')}' : '';

    if (dt.isUtc) {
      return '$year-$month-${day}T$hour:$minute:$second${fracStr}Z';
    }

    final offset = dt.timeZoneOffset;
    if (offset == Duration.zero) {
      return '$year-$month-${day}T$hour:$minute:$second${fracStr}Z';
    }

    final sign = offset.isNegative ? '-' : '+';
    final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
    final offsetMins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetStr = '$sign$offsetHours:$offsetMins';

    return '$year-$month-${day}T$hour:$minute:$second$fracStr$offsetStr';
  }

  /// Normaliza una cadena de fecha ISO 8601 al estándar canónico compatible con Pydantic v2:
  /// - Elimina fracciones de segundo cuando son todas cero (`.000Z` -> `Z`).
  /// - Rellena fracciones con valor (>0) a exactamente 6 dígitos fraccionales (`.500Z` -> `.500000Z`).
  /// - Convierte offsets UTC equivalentes (`+00:00`, `-00:00`) a `Z`.
  /// - Preserva offsets específicos (ej. `-04:00`).
  static String? normalizeIsoDateTime(String? iso) {
    if (iso == null) return null;
    final trimmed = iso.trim();
    if (trimmed.isEmpty) return null;

    final match = _isoRegex.firstMatch(trimmed);
    if (match != null) {
      final datePart = match.group(1)!;
      final hourMin = match.group(2)!;
      final sec = match.group(3) ?? '00';
      final fracPart = match.group(4);
      final tzPart = match.group(5);

      String fracStr = '';
      if (fracPart != null && fracPart.isNotEmpty) {
        if (RegExp(r'[1-9]').hasMatch(fracPart)) {
          final padded = fracPart.padRight(6, '0');
          fracStr = '.${padded.substring(0, 6)}';
        }
      }

      String tzStr = '';
      if (tzPart != null && tzPart.isNotEmpty) {
        final upperTz = tzPart.toUpperCase();
        if (upperTz == 'Z' ||
            upperTz == '+00:00' ||
            upperTz == '-00:00' ||
            upperTz == '+0000' ||
            upperTz == '-0000' ||
            upperTz == '+00' ||
            upperTz == '-00') {
          tzStr = 'Z';
        } else {
          var tz = upperTz;
          if (!tz.contains(':')) {
            if (tz.length == 3) {
              tz = '$tz:00';
            } else if (tz.length == 5) {
              tz = '${tz.substring(0, 3)}:${tz.substring(3, 5)}';
            }
          }
          tzStr = tz;
        }
      }

      return '$datePart' 'T$hourMin:$sec$fracStr$tzStr';
    }

    // Fallback con DateTime.tryParse
    final dt = DateTime.tryParse(trimmed);
    if (dt != null) {
      return formatCanonicalDateTime(dt);
    }

    return trimmed;
  }

  /// Serializa recursivamente un mapa u objeto JSON canónicamente:
  /// - Claves de mapas ordenadas alfabéticamente (orden Unicode / sort_keys=True).
  /// - Separadores compactos sin espacios (',', ':').
  /// - Caracteres Unicode sin escapar (ensure_ascii=False).
  /// - Números, booleanos y nulos en representación JSON estándar.
  static String serialize(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is DateTime) return jsonEncode(formatCanonicalDateTime(value));
    if (value is String) return jsonEncode(value);
    if (value is List) {
      final elements = value.map(serialize).join(',');
      return '[$elements]';
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final pairs = <String>[];
      for (final k in keys) {
        final v = value[k];
        pairs.add('${jsonEncode(k)}:${serialize(v)}');
      }
      return '{${pairs.join(',')}}';
    }
    return jsonEncode(value);
  }

  /// Alias de conveniencia para serializar en formato canónico.
  static String canonicalize(dynamic value) => serialize(value);

  /// Alias de conveniencia para hashear un mapa canónico.
  static String hash(Map<String, dynamic> data) => hashJson(data);

  /// Calcula el hash SHA-256 hexadecimal en minúsculas de una cadena UTF-8.
  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Construye la representación canónica del cuerpo de registro de dosis.
  /// Campos ordenados alfabéticamente de manera estricta:
  /// `efectiva_en`, `estado`, `nota`.
  ///
  /// - Si [efectivaEn] o [efectivaEnDateTime] es null -> `null`.
  /// - Si [efectivaEn] es pasado como cadena o [efectivaEnDateTime] como DateTime,
  ///   se normaliza según Pydantic v2 (sin microsegundos si es .000, con 6 dígitos si >0).
  /// - Si [nota] es null -> `null`.
  static String buildDoseRegistrationJson({
    required String estado,
    String? efectivaEn,
    DateTime? efectivaEnDateTime,
    String? nota,
  }) {
    String? normalizedEfectivaEn;
    if (efectivaEnDateTime != null) {
      normalizedEfectivaEn = formatCanonicalDateTime(efectivaEnDateTime);
    } else if (efectivaEn != null) {
      normalizedEfectivaEn = normalizeIsoDateTime(efectivaEn);
    }

    final map = <String, dynamic>{
      'efectiva_en': normalizedEfectivaEn,
      'estado': estado,
      'nota': nota,
    };
    return serialize(map);
  }

  /// Hashea el cuerpo del registro de dosis usando serialización canónica + SHA-256.
  static String hashDoseRegistration({
    required String estado,
    String? efectivaEn,
    DateTime? efectivaEnDateTime,
    String? nota,
  }) {
    final jsonStr = buildDoseRegistrationJson(
      estado: estado,
      efectivaEn: efectivaEn,
      efectivaEnDateTime: efectivaEnDateTime,
      nota: nota,
    );
    return sha256Hex(jsonStr);
  }

  /// Hashea un mapa arbitrario tras ordenarlo canónicamente.
  static String hashJson(Map<String, dynamic> data) {
    final jsonStr = serialize(data);
    return sha256Hex(jsonStr);
  }
}
