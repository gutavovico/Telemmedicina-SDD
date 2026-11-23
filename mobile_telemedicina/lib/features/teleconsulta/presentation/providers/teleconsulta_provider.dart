import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/teleconsulta_model.dart';
import '../../data/repositories/teleconsulta_repository_impl.dart';
import '../../domain/repositories/teleconsulta_repository.dart';

class TeleconsultaProvider with ChangeNotifier {
  final TeleconsultaRepository _repository;

  TeleconsultaProvider({TeleconsultaRepository? repository})
      : _repository = repository ?? TeleconsultaRepositoryImpl();

  TeleconsultaViewModel? _teleconsulta;
  List<ChatMessageModel> _mensajes = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  int? _activeCitaId;
  Timer? _pollingTimer;

  TeleconsultaViewModel? get teleconsulta => _teleconsulta;
  List<ChatMessageModel> get mensajes => _mensajes;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int? get activeCitaId => _activeCitaId;

  // Carga inicial o explícita de la teleconsulta
  Future<void> cargarTeleconsulta(int idCita, {bool silencioso = false}) async {
    _activeCitaId = idCita;
    if (!silencioso) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final vm = await _repository.getTeleconsulta(idCita);
      _teleconsulta = vm;
      
      // Sincronizar mensajes preservando mensajes optimistas pendientes
      _mensajes = _reconciliarMensajes(_mensajes, vm.mensajes);
      _errorMessage = null;
    } catch (e) {
      if (!silencioso) {
        _errorMessage = 'No se pudo cargar la información de la teleconsulta: ${e.toString()}';
      }
    } finally {
      if (!silencioso) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // Cargar teleconsulta activa más reciente del usuario
  Future<void> cargarMiTeleconsultaActiva() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final vm = await _repository.getMiTeleconsultaActiva();
      _teleconsulta = vm;
      _activeCitaId = vm.cita?.idCita;
      _mensajes = List.from(vm.mensajes);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'No se pudo cargar la consulta médica activa: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Iniciar sincronización periódica en segundo plano (Polling silencioso)
  void iniciarPolling(int idCita) {
    _activeCitaId = idCita;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (_activeCitaId != null && !_isSending) {
        cargarTeleconsulta(_activeCitaId!, silencioso: true);
      }
    });
  }

  // Detener polling al salir de la vista
  void detenerPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // Envío de mensaje con Optimistic UI
  Future<bool> enviarMensaje({
    required int idCita,
    required String contenido,
    String? adjuntoNombre,
    String? adjuntoTamano,
    String? adjuntoUrl,
  }) async {
    final textoLimpio = contenido.trim();
    if (textoLimpio.isEmpty && adjuntoNombre == null) {
      return false;
    }

    _isSending = true;
    _errorMessage = null;

    // Crear mensaje optimista
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final horaStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} h';

    final mensajeOptimista = ChatMessageModel(
      idMensaje: tempId,
      idRemitente: _teleconsulta?.usuarioActivo?['idUsuario'] as int? ?? 0,
      nombreRemitente: _teleconsulta?.usuarioActivo?['nombre'] as String? ?? 'Yo',
      rolRemitente: 'PACIENTE',
      contenido: textoLimpio,
      horaDisplay: horaStr,
      esPropio: true,
      leido: false,
      adjuntoNombre: adjuntoNombre,
      adjuntoTamano: adjuntoTamano,
      adjuntoUrl: adjuntoUrl,
    );

    // Inserción inmediata en memoria (Optimistic UI)
    _mensajes = [..._mensajes, mensajeOptimista];
    notifyListeners();

    try {
      final mensajePersistido = await _repository.enviarMensaje(
        idCita: idCita,
        contenido: textoLimpio,
        adjuntoNombre: adjuntoNombre,
        adjuntoTamano: adjuntoTamano,
        adjuntoUrl: adjuntoUrl,
      );

      // Reemplazar mensaje temporal con el registrado en el backend
      final index = _mensajes.indexWhere((m) => m.idMensaje == tempId);
      if (index != -1) {
        _mensajes[index] = mensajePersistido.copyWith(esPropio: true);
      } else {
        _mensajes.add(mensajePersistido.copyWith(esPropio: true));
      }
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Revertir mensaje optimista si falló la persistencia
      _mensajes.removeWhere((m) => m.idMensaje == tempId);
      _errorMessage = 'Error al enviar el mensaje. Intente de nuevo.';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // Reconciliación para no sobreescribir mensajes optimistas que aún no hayan sido confirmados por el servidor
  List<ChatMessageModel> _reconciliarMensajes(
    List<ChatMessageModel> actuales,
    List<ChatMessageModel> remotos,
  ) {
    // Si no hay mensajes optimistas pendientes (id negativo), devolver directamente los remotos
    final optimistas = actuales.where((m) => m.idMensaje < 0).toList();
    if (optimistas.isEmpty) {
      return List.from(remotos);
    }

    final listaResultado = List<ChatMessageModel>.from(remotos);
    for (final opt in optimistas) {
      // Si el contenido ya está en remotos (por texto idéntico y hora similar), no lo volvemos a meter
      final yaExiste = remotos.any((r) => r.contenido == opt.contenido && r.esPropio);
      if (!yaExiste) {
        listaResultado.add(opt);
      }
    }
    return listaResultado;
  }

  @override
  void dispose() {
    detenerPolling();
    super.dispose();
  }
}
