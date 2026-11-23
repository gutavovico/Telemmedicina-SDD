/// Formato visible de fechas CU16: `dd/MM/yyyy` en UI, ISO 8601 en red.
String formatVisibleDate(String raw) {
  if (raw.trim().isEmpty) return '—';
  try {
    final parsed = DateTime.parse(raw);
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  } catch (_) {
    // Si solo llega `YYYY-MM-DD`, se formatea manualmente.
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (match != null) {
      return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
    }
    return raw;
  }
}

/// Valida un rango ISO `YYYY-MM-DD` para filtros (`hasta` no anterior a `desde`).
bool isValidDateRange(String? desde, String? hasta) {
  if (desde == null || desde.isEmpty) return true;
  if (hasta == null || hasta.isEmpty) return true;
  try {
    final d = DateTime.parse(desde);
    final h = DateTime.parse(hasta);
    return !h.isBefore(d);
  } catch (_) {
    return false;
  }
}
