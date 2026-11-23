import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/usecases/download_prescription_pdf_usecase.dart';
import '../../domain/usecases/get_my_prescriptions_usecase.dart';
import '../../domain/usecases/get_prescription_detail_usecase.dart';

/// Estado explícito del listado (sin booleanos ambiguos).
enum PrescriptionListStatus { initial, loading, loaded, empty, error }

/// Estado explícito de la carga incremental.
enum PrescriptionLoadMoreStatus { idle, loading, error }

/// Estado explícito del detalle.
enum PrescriptionDetailStatus { initial, loading, loaded, error }

/// Estado explícito de la descarga del PDF.
enum PrescriptionDownloadStatus { idle, downloading, success, error }

/// Callback desacoplado para invalidación de sesión.
///
/// La UI lo inyecta para limpiar sesión (vía `AuthController`), navegar a
/// `/login` y mostrar el mensaje. El provider nunca navega directamente y
/// nunca duplica la lógica de limpieza: solo emite el evento una vez.
typedef SessionExpiredCallback = Future<void> Function();

/// Provider CU16 con estados independientes para listado, carga adicional,
/// detalle y descarga. Una descarga fallida nunca borra ni oculta el detalle.
class PrescriptionProvider extends ChangeNotifier {
  final GetMyPrescriptionsUseCase _getMyPrescriptionsUseCase;
  final GetPrescriptionDetailUseCase _getDetailUseCase;
  final DownloadPrescriptionPdfUseCase _downloadUseCase;

  PrescriptionProvider({
    GetMyPrescriptionsUseCase? getMyPrescriptionsUseCase,
    GetPrescriptionDetailUseCase? getDetailUseCase,
    DownloadPrescriptionPdfUseCase? downloadUseCase,
    this.onSessionExpired,
  }) : _getMyPrescriptionsUseCase =
           getMyPrescriptionsUseCase ?? GetMyPrescriptionsUseCase(),
       _getDetailUseCase = getDetailUseCase ?? GetPrescriptionDetailUseCase(),
       _downloadUseCase = downloadUseCase ?? DownloadPrescriptionPdfUseCase();

  // --- Listado ---
  PrescriptionListStatus _listStatus = PrescriptionListStatus.initial;
  PrescriptionLoadMoreStatus _loadMoreStatus = PrescriptionLoadMoreStatus.idle;
  List<Prescription> _items = const [];
  int _total = 0;
  // Offset del último fetch exitoso. El siguiente offset se calcula como
  // `_skip + _lastFetchedCount` (conteo crudo del último fetch), nunca como
  // `_skip + _items.length` (acumulado) para evitar la secuencia 0 → 20 → 60.
  int _skip = 0;
  int _lastFetchedCount = 0;
  int _limit = 20;
  bool _hasMore = false;
  String? _listError;
  String? _loadMoreError;

  String? _estadoFilter;
  String? _desdeFilter;
  String? _hastaFilter;

  // --- Detalle ---
  PrescriptionDetailStatus _detailStatus = PrescriptionDetailStatus.initial;
  Prescription? _selected;
  int? _activeDetailId;
  String? _detailError;

  // --- Descarga ---
  PrescriptionDownloadStatus _downloadStatus = PrescriptionDownloadStatus.idle;
  String? _downloadError;
  Uint8List? _lastDownloadedBytes;
  String? _lastDownloadedFilename;
  int? _downloadTargetId;

  // --- Sesión expirada (evento desacoplado, una sola invalidación por ciclo) ---
  bool _sessionExpired = false;
  bool _sessionExpiredNotified = false;
  // Último estado autenticado conocido. Solo una transición false -> true
  // (evidencia explícita de nueva sesión autenticada, sin JWT) re-arma el
  // evento 401 para el nuevo ciclo. Un éxito concurrente nunca lo limpia.
  bool _wasAuthenticated = false;

  // --- Control de concurrencia (generaciones) ---
  int _listGeneration = 0;
  int _detailGeneration = 0;
  int _downloadGeneration = 0;
  bool _disposed = false;

  // Getters de listado.
  PrescriptionListStatus get listStatus => _listStatus;
  PrescriptionLoadMoreStatus get loadMoreStatus => _loadMoreStatus;
  // Copia defensiva no modificable: `provider.items.add(...)` lanza
  // UnsupportedError y nunca muta el estado interno.
  List<Prescription> get items => List<Prescription>.unmodifiable(_items);
  int get total => _total;
  int get skip => _skip;
  int get limit => _limit;
  bool get hasMore => _hasMore;
  String? get listError => _listError;
  String? get loadMoreError => _loadMoreError;
  String? get estadoFilter => _estadoFilter;
  String? get desdeFilter => _desdeFilter;
  String? get hastaFilter => _hastaFilter;

  // Getters de detalle.
  PrescriptionDetailStatus get detailStatus => _detailStatus;
  Prescription? get selected => _selected;
  String? get detailError => _detailError;

  // Getters de descarga.
  PrescriptionDownloadStatus get downloadStatus => _downloadStatus;
  String? get downloadError => _downloadError;
  Uint8List? get lastDownloadedBytes => _lastDownloadedBytes;
  String? get lastDownloadedFilename => _lastDownloadedFilename;
  bool get isDownloading =>
      _downloadStatus == PrescriptionDownloadStatus.downloading;

  // Getters de sesión.
  bool get sessionExpired => _sessionExpired;
  String get sessionExpiredMessage =>
      'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.';

  /// Callback desacoplado inyectado por la UI (coordinador de sesión).
  SessionExpiredCallback? onSessionExpired;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Sincronización explícita con el ciclo de autenticación.
  ///
  /// Debe invocarse desde `ChangeNotifierProxyProvider<AuthController, ...>`
  /// con `auth.isAuthenticated` (sin JWT, sin navegación, sin timers ni
  /// variables globales). Solo la transición false -> true re-arma el evento
  /// 401 para el nuevo ciclo de sesión.
  void syncAuthSession({required bool isAuthenticated}) {
    if (_disposed) return;
    final was = _wasAuthenticated;
    _wasAuthenticated = isAuthenticated;
    if (isAuthenticated && !was) {
      if (_sessionExpired || _sessionExpiredNotified) {
        _sessionExpired = false;
        _sessionExpiredNotified = false;
        _safeNotify();
      }
    }
  }

  /// Limpia el flag de sesión expirada (p. ej. tras un nuevo login exitoso).
  /// Re-arme explícito manual; la vía preferida es [syncAuthSession].
  void clearSessionExpired() {
    if (_disposed) return;
    if (!_sessionExpired && !_sessionExpiredNotified) return;
    _sessionExpired = false;
    _sessionExpiredNotified = false;
    _safeNotify();
  }

  /// Emite el evento de sesión expirada una sola vez por ciclo aunque varios
  /// 401 concurrentes lleguen al mismo tiempo. No navega directamente: delega
  /// en el callback inyectado por la UI (coordinador con AuthController.logout).
  Future<void> _handleSessionExpired() async {
    if (_disposed) return;
    if (_sessionExpired) return;
    _sessionExpired = true;
    _safeNotify();
    if (_sessionExpiredNotified) return;
    _sessionExpiredNotified = true;
    final callback = onSessionExpired;
    if (callback != null) {
      try {
        await callback();
      } catch (_) {
        // Best-effort: el flag ya quedó marcado y el mensaje es visible.
      }
    }
  }

  /// Aplica filtros permitidos (estado, rango de fechas) y recarga.
  Future<void> setFilters({
    String? estado,
    String? desde,
    String? hasta,
  }) async {
    _estadoFilter = (estado == null || estado.isEmpty) ? null : estado;
    _desdeFilter = (desde == null || desde.isEmpty) ? null : desde;
    _hastaFilter = (hasta == null || hasta.isEmpty) ? null : hasta;
    await loadPrescriptions(refresh: true);
  }

  Future<void> clearFilters() async {
    _estadoFilter = null;
    _desdeFilter = null;
    _hastaFilter = null;
    await loadPrescriptions(refresh: true);
  }

  /// Carga inicial o pull-to-refresh del listado propio.
  Future<void> loadPrescriptions({bool refresh = true, int? limit}) async {
    if (limit != null && limit > 0) _limit = limit;
    final generation = ++_listGeneration;
    // Un refresh invalida cualquier loadMore pendiente: su generación quedará
    // obsoleta y su resultado se descartará.
    _listStatus = PrescriptionListStatus.loading;
    _listError = null;
    _loadMoreStatus = PrescriptionLoadMoreStatus.idle;
    _loadMoreError = null;
    if (refresh) {
      _skip = 0;
      _lastFetchedCount = 0;
      _items = const [];
      _total = 0;
      _hasMore = false;
    }
    _safeNotify();

    try {
      final page = await _getMyPrescriptionsUseCase(
        estado: _estadoFilter,
        desde: _desdeFilter,
        hasta: _hastaFilter,
        skip: _skip,
        limit: _limit,
      );
      if (generation != _listGeneration || _disposed) return;
      _skip = page.skip;
      _lastFetchedCount = page.items.length;
      _items = _dedupe(_items, page.items, refresh: true);
      _total = page.total;
      _hasMore = _calcHasMore(
        fetchSkip: _skip,
        fetchedLength: page.items.length,
        total: page.total,
      );
      // Intencional: un éxito nunca limpia el estado de sesión expirada.
      // Solo syncAuthSession(false -> true) re-arma el siguiente ciclo.
      if (_items.isEmpty) {
        _listStatus = PrescriptionListStatus.empty;
      } else {
        _listStatus = PrescriptionListStatus.loaded;
      }
    } on UnauthorizedException {
      if (generation != _listGeneration || _disposed) return;
      _listStatus = PrescriptionListStatus.error;
      _listError = sessionExpiredMessage;
      _safeNotify();
      await _handleSessionExpired();
      return;
    } on ApiException catch (e) {
      if (generation != _listGeneration || _disposed) return;
      _listStatus = PrescriptionListStatus.error;
      _listError = _friendlyListMessage(e);
    } catch (_) {
      if (generation != _listGeneration || _disposed) return;
      _listStatus = PrescriptionListStatus.error;
      _listError = 'No se pudieron cargar tus recetas. Intenta nuevamente.';
    }
    _safeNotify();
  }

  /// Paginación incremental con `skip/limit`.
  ///
  /// `nextSkip = _skip + _lastFetchedCount` (offset explícito del último
  /// fetch crudo). Nunca `_skip + _items.length`, que con `_items` acumulado
  /// produce 0 → 20 → 60 y omite registros desde la tercera página.
  /// Deduplica por `idReceta`, mantiene `hasMore` coherente con `total` y
  /// detiene la paginación ante una página vacía inesperada.
  Future<void> loadMore() async {
    if (_listStatus != PrescriptionListStatus.loaded) return;
    if (!_hasMore) return;
    if (_loadMoreStatus == PrescriptionLoadMoreStatus.loading) return;

    final listGenerationAtStart = _listGeneration;
    _loadMoreStatus = PrescriptionLoadMoreStatus.loading;
    _loadMoreError = null;
    _safeNotify();

    final nextSkip = _skip + _lastFetchedCount;
    try {
      final page = await _getMyPrescriptionsUseCase(
        estado: _estadoFilter,
        desde: _desdeFilter,
        hasta: _hastaFilter,
        skip: nextSkip,
        limit: _limit,
      );
      // Si hubo un refresh/filtro mientras el loadMore estaba pendiente, se
      // descarta el resultado para no añadir elementos obsoletos.
      if (listGenerationAtStart != _listGeneration || _disposed) return;
      _skip = nextSkip;
      _lastFetchedCount = page.items.length;
      _items = _dedupe(_items, page.items, refresh: false);
      _total = page.total;
      _hasMore = _calcHasMore(
        fetchSkip: nextSkip,
        fetchedLength: page.items.length,
        total: page.total,
      );
      // Intencional: un éxito nunca limpia el estado de sesión expirada.
      _loadMoreStatus = PrescriptionLoadMoreStatus.idle;
    } on UnauthorizedException {
      if (listGenerationAtStart != _listGeneration || _disposed) return;
      _loadMoreStatus = PrescriptionLoadMoreStatus.error;
      _loadMoreError = sessionExpiredMessage;
      _safeNotify();
      await _handleSessionExpired();
      return;
    } on ApiException catch (e) {
      if (listGenerationAtStart != _listGeneration || _disposed) return;
      _loadMoreStatus = PrescriptionLoadMoreStatus.error;
      _loadMoreError = _friendlyListMessage(e);
    } catch (_) {
      if (listGenerationAtStart != _listGeneration || _disposed) return;
      _loadMoreStatus = PrescriptionLoadMoreStatus.error;
      _loadMoreError = 'No se pudo cargar más recetas. Intenta nuevamente.';
    }
    _safeNotify();
  }

  /// Calcula `hasMore` coherente con `total`.
  /// Una página vacía antes de alcanzar `total` detiene la paginación para
  /// evitar solicitudes infinitas.
  bool _calcHasMore({
    required int fetchSkip,
    required int fetchedLength,
    required int total,
  }) {
    if (fetchedLength == 0) return false;
    return fetchSkip + fetchedLength < total;
  }

  /// Fusiona páginas sin duplicar por `idReceta`.
  List<Prescription> _dedupe(
    List<Prescription> current,
    List<Prescription> incoming, {
    required bool refresh,
  }) {
    if (refresh) {
      final seen = <int>{};
      final unique = <Prescription>[];
      for (final item in incoming) {
        if (seen.add(item.idReceta)) unique.add(item);
      }
      return List<Prescription>.unmodifiable(unique);
    }
    final seen = current.map((e) => e.idReceta).toSet();
    final merged = List<Prescription>.from(current);
    for (final item in incoming) {
      if (seen.add(item.idReceta)) merged.add(item);
    }
    return List<Prescription>.unmodifiable(merged);
  }

  /// Consulta el detalle estructurado de una receta propia.
  ///
  /// Limpia error y estado de descarga previos para no mostrar éxito/error
  /// ni bytes de la receta anterior. Respuestas fuera de orden se descartan
  /// por generación: una receta anterior nunca reemplaza a la vigente.
  Future<void> loadDetail(int idReceta) async {
    final generation = ++_detailGeneration;
    // Invalida descargas en vuelo de la receta anterior.
    ++_downloadGeneration;
    _detailStatus = PrescriptionDetailStatus.loading;
    _detailError = null;
    _selected = null;
    _activeDetailId = idReceta;
    // Limpieza entre detalles: sin error/éxito ni bytes previos.
    _downloadStatus = PrescriptionDownloadStatus.idle;
    _downloadError = null;
    _lastDownloadedBytes = null;
    _lastDownloadedFilename = null;
    _downloadTargetId = null;
    _safeNotify();

    try {
      final detail = await _getDetailUseCase(idReceta);
      if (generation != _detailGeneration || _disposed) return;
      // Solo aplica si sigue siendo el detalle vigente.
      if (_activeDetailId != idReceta) return;
      _selected = detail;
      _detailStatus = PrescriptionDetailStatus.loaded;
      // Intencional: un éxito nunca limpia el estado de sesión expirada.
    } on NotFoundException {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError = 'La receta solicitada no fue encontrada.';
    } on UnauthorizedException {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError = sessionExpiredMessage;
      _safeNotify();
      await _handleSessionExpired();
      return;
    } on ForbiddenException {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError = 'Acceso restringido a esta receta.';
    } on TimeoutException {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError =
          'Tiempo de espera agotado. Verifica tu conexión e intenta nuevamente.';
    } on NetworkException {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError =
          'No se pudo conectar con el servidor. Verifica tu conexión.';
    } on ApiException catch (e) {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError = e.message.isNotEmpty
          ? e.message
          : 'No se pudo cargar la receta. Intenta nuevamente.';
    } catch (_) {
      if (generation != _detailGeneration || _disposed) return;
      if (_activeDetailId != idReceta) return;
      _detailStatus = PrescriptionDetailStatus.error;
      _detailError = 'No se pudo cargar la receta. Intenta nuevamente.';
    }
    _safeNotify();
  }

  /// Descarga el PDF autenticado. Deshabilita descargas simultáneas y
  /// conserva el detalle visible ante cualquier fallo.
  ///
  /// Una descarga de la receta A nunca actualiza la UI de la receta B:
  /// el resultado solo se aplica si la descarga sigue vigente y el detalle
  /// activo coincide con el objetivo.
  Future<Uint8List?> downloadPdf(int idReceta) async {
    if (_downloadStatus == PrescriptionDownloadStatus.downloading) {
      return null;
    }
    final generation = ++_downloadGeneration;
    final targetId = idReceta;
    _downloadTargetId = targetId;
    _downloadStatus = PrescriptionDownloadStatus.downloading;
    _downloadError = null;
    _safeNotify();

    try {
      final bytes = await _downloadUseCase(idReceta);
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      if (bytes.isEmpty) {
        _downloadStatus = PrescriptionDownloadStatus.error;
        _downloadError =
            'El servidor devolvió un documento vacío. Intenta nuevamente.';
        _safeNotify();
        return null;
      }
      final folio = _selected?.idReceta == idReceta
          ? _selected!.folio
          : 'receta-$idReceta';
      _lastDownloadedBytes = bytes;
      _lastDownloadedFilename = prescriptionPdfFilename(folio);
      _downloadStatus = PrescriptionDownloadStatus.success;
      // Intencional: un éxito nunca limpia el estado de sesión expirada.
      _safeNotify();
      return bytes;
    } on NotFoundException {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError = 'La receta solicitada no fue encontrada.';
      _safeNotify();
      return null;
    } on UnauthorizedException {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError = sessionExpiredMessage;
      _safeNotify();
      await _handleSessionExpired();
      return null;
    } on ForbiddenException {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError = 'Acceso restringido a esta receta.';
      _safeNotify();
      return null;
    } on TimeoutException {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError =
          'Tiempo de espera agotado. Verifica tu conexión e intenta nuevamente.';
      _safeNotify();
      return null;
    } on NetworkException {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError =
          'No se pudo conectar con el servidor. Verifica tu conexión.';
      _safeNotify();
      return null;
    } on StateError {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError =
          'El servidor devolvió un documento vacío. Intenta nuevamente.';
      _safeNotify();
      return null;
    } on ApiException catch (e) {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError = e.message.isNotEmpty
          ? e.message
          : 'No se pudo descargar el PDF. Intenta nuevamente.';
      _safeNotify();
      return null;
    } catch (_) {
      if (generation != _downloadGeneration || _disposed) return null;
      if (_downloadTargetId != targetId) return null;
      if (_activeDetailId != null && _activeDetailId != targetId) return null;
      _downloadStatus = PrescriptionDownloadStatus.error;
      _downloadError = 'No se pudo descargar el PDF. Intenta nuevamente.';
      _safeNotify();
      return null;
    }
  }

  /// Limpia el estado de descarga sin tocar listado ni detalle.
  void resetDownload() {
    _downloadStatus = PrescriptionDownloadStatus.idle;
    _downloadError = null;
    _safeNotify();
  }

  void clearDetail() {
    ++_detailGeneration;
    ++_downloadGeneration;
    _detailStatus = PrescriptionDetailStatus.initial;
    _selected = null;
    _activeDetailId = null;
    _detailError = null;
    _downloadStatus = PrescriptionDownloadStatus.idle;
    _downloadError = null;
    _lastDownloadedBytes = null;
    _lastDownloadedFilename = null;
    _downloadTargetId = null;
    _safeNotify();
  }

  String _friendlyListMessage(ApiException e) {
    if (e is UnauthorizedException) {
      return sessionExpiredMessage;
    }
    if (e is ForbiddenException) {
      return 'Acceso restringido. No cuentas con autorización en este centro de salud.';
    }
    if (e is TimeoutException) {
      return 'Tiempo de espera agotado. Verifica tu conexión e intenta nuevamente.';
    }
    if (e is NetworkException) {
      return 'No se pudo conectar con el servidor. Verifica tu conexión.';
    }
    if (e.message.isNotEmpty) return e.message;
    return 'No se pudieron cargar tus recetas. Intenta nuevamente.';
  }
}
