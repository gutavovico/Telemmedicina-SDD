import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../datasources/teleconsulta_remote_datasource.dart';

/// Utilidades puras de señalización WebRTC para facilitar pruebas unitarias.
class WebrtcSignalingHelper {
  static const Duration graceWindowInicio = Duration(milliseconds: 2500);
  static const Duration maxEdadFinalizacion = Duration(milliseconds: 3500);

  /// Determina si una señal o estado de finalización debe ignorarse por ser residual
  /// de una sesión anterior recién cerrada.
  static bool debeIgnorarFinalizacion({
    required DateTime inicioSesion,
    required DateTime ahora,
    String? signalTimestampIso,
  }) {
    if (ahora.difference(inicioSesion) < graceWindowInicio) {
      return true;
    }
    if (signalTimestampIso != null && signalTimestampIso.isNotEmpty) {
      final parsed = DateTime.tryParse(signalTimestampIso);
      if (parsed != null) {
        final edad = ahora.difference(parsed);
        if (edad > maxEdadFinalizacion) {
          return true;
        }
      }
    }
    return false;
  }

  /// Verifica si una señal entrante con [targetPeerId] corresponde al peer local [miPeerId].
  static bool correspondeAMiPeer({
    required String miPeerId,
    String? targetPeerId,
  }) {
    if (targetPeerId == null || targetPeerId.isEmpty) {
      return true;
    }
    return targetPeerId == miPeerId;
  }

  /// Decodifica una cadena base64 o data URL (`data:image/jpeg;base64,...`) a bytes.
  static Uint8List? decodificarFrameBase64(String? rawFrame) {
    if (rawFrame == null || rawFrame.isEmpty) return null;
    final commaIdx = rawFrame.indexOf(',');
    final b64 = commaIdx >= 0 ? rawFrame.substring(commaIdx + 1) : rawFrame;
    if (b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }
}

/// Motor WebRTC móvil nativo compatible 100% con el flujo P2P del médico Web y el backend FastAPI.
class WebrtcMovilService extends ChangeNotifier {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  List<Map<String, dynamic>> _iceServers =
      TeleconsultaRemoteDataSource.defaultIceServers;

  int _idCita = 0;
  String _pacienteNombre = 'Paciente';
  String _miPeerId = '';
  String? _doctorPeerId;
  String _ultimoOfferPeerIdProcesado = '';
  bool _hasRemoteDescription = false;

  DateTime _inicioSesion = DateTime.now();
  DateTime? _ultimoFrameFallbackTs;

  bool _inicializado = false;
  bool _cerrado = false;
  bool _sincronizando = false;
  bool _negociandoOffer = false;

  bool _permisoCamaraOk = false;
  bool _permisoMicrofonoOk = false;
  String? _errorPermisos;
  String _estadoConexionTexto = 'Iniciando videollamada...';

  bool _microfonoActivo = true;
  bool _camaraActiva = true;
  bool _camaraFrontal = true;
  bool _altavozActivo = true;

  bool _p2pConectado = false;
  bool _videoNativoDecodificando = false;
  bool _hayVideoRemoto = false;
  bool _doctorConectado = false;
  bool _doctorCamaraActiva = true;
  bool _doctorMicrofonoActivo = true;
  bool _doctorCompartiendoPantalla = false;
  bool _consultaFinalizadaPorDoctor = false;

  Uint8List? _doctorFrameFallbackBytes;
  int _contadorMensajesNuevos = 0;
  int _ultimoTotalMensajesDoctor = 0;

  final Set<String> _senalesProcesadas = {};
  final List<RTCIceCandidate> _candidatosPendientes = [];

  Timer? _pollingTimer;
  Timer? _reintentoJoinTimer;
  int _cicloPolling = 0;

  // Getters públicos
  bool get inicializado => _inicializado;
  bool get permisoCamaraOk => _permisoCamaraOk;
  bool get permisoMicrofonoOk => _permisoMicrofonoOk;
  String? get errorPermisos => _errorPermisos;
  String get estadoConexionTexto => _estadoConexionTexto;

  bool get microfonoActivo => _microfonoActivo;
  bool get camaraActiva => _camaraActiva;
  bool get camaraFrontal => _camaraFrontal;
  bool get altavozActivo => _altavozActivo;

  bool get tieneVideoLocal =>
      _camaraActiva && (_localStream?.getVideoTracks().isNotEmpty ?? false);
  bool get p2pConectado => _p2pConectado;
  bool get videoNativoDecodificando => _videoNativoDecodificando;
  bool get hayVideoRemoto => _hayVideoRemoto;
  bool get doctorConectado => _doctorConectado;
  bool get doctorCamaraActiva => _doctorCamaraActiva;
  bool get doctorMicrofonoActivo => _doctorMicrofonoActivo;
  bool get doctorCompartiendoPantalla => _doctorCompartiendoPantalla;
  bool get consultaFinalizadaPorDoctor => _consultaFinalizadaPorDoctor;
  Uint8List? get doctorFrameFallbackBytes => _doctorFrameFallbackBytes;
  int get contadorMensajesNuevos => _contadorMensajesNuevos;

  bool get mostrarVideoNativoRemoto =>
      remoteRenderer.srcObject != null &&
      (_videoNativoDecodificando || _hayVideoRemoto) &&
      (_doctorCamaraActiva || _doctorCompartiendoPantalla);

  bool get mostrarFallbackFrameRemoto =>
      !mostrarVideoNativoRemoto &&
      _doctorFrameFallbackBytes != null &&
      (_doctorCamaraActiva || _doctorCompartiendoPantalla);

  void reiniciarContadorMensajes() {
    if (_contadorMensajesNuevos != 0) {
      _contadorMensajesNuevos = 0;
      _notificarSeguro();
    }
  }

  /// Inicializa renderers, permisos, cámara/micrófono, PeerConnection y señalización.
  Future<void> iniciarSesion({
    required int idCita,
    required String pacienteNombre,
  }) async {
    if (_cerrado) return;

    _idCita = idCita;
    _pacienteNombre = pacienteNombre.trim().isNotEmpty
        ? pacienteNombre.trim()
        : 'Paciente';
    _inicioSesion = DateTime.now();
    _miPeerId =
        'PACIENTE-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';
    _doctorPeerId = null;
    _ultimoOfferPeerIdProcesado = '';
    _hasRemoteDescription = false;
    _senalesProcesadas.clear();
    _candidatosPendientes.clear();
    _consultaFinalizadaPorDoctor = false;
    _estadoConexionTexto = 'Solicitando permisos...';
    _notificarSeguro();

    await localRenderer.initialize();
    await remoteRenderer.initialize();
    remoteRenderer.onFirstFrameRendered = () {
      if (!_cerrado) {
        _videoNativoDecodificando = true;
        _hayVideoRemoto = true;
        _p2pConectado = true;
        _doctorConectado = true;
        _doctorFrameFallbackBytes = null;
        _estadoConexionTexto = 'Conectado · Audio y Video P2P';
        _notificarSeguro();
      }
    };

    // 1. Permisos nativos de cámara y micrófono
    await _solicitarPermisos();
    if (_cerrado) return;

    // 2. Cargar configuración ICE (STUN/TURN) del backend
    _estadoConexionTexto = 'Configurando conexión segura...';
    _notificarSeguro();
    _iceServers = await TeleconsultaRemoteDataSource.obtenerIceServers();
    if (_cerrado) return;

    // 3. Abrir cámara y micrófono locales
    await _abrirMediosLocales();
    if (_cerrado) return;

    // 4. Activar altavoz en móvil
    await _aplicarAltavoz(true);

    // 5. Construir PeerConnection
    await _construirPeerConnection();
    if (_cerrado) return;

    _inicializado = true;
    _estadoConexionTexto = 'Esperando conexión con el médico...';
    _notificarSeguro();

    // 6. Reportar presencia y enviar JOIN inicial (limpia señales previas en el backend)
    await TeleconsultaRemoteDataSource.reportarPresencia(
      idCita: _idCita,
      rol: 'PACIENTE',
      conectado: true,
      nombre: _pacienteNombre,
    );
    await _enviarJoin();

    // 7. Iniciar polling seguro (sin solapamiento) y reintentos de JOIN
    _iniciarTemporizadores();
  }

  Future<void> _solicitarPermisos() async {
    if (kIsWeb) {
      _permisoCamaraOk = true;
      _permisoMicrofonoOk = true;
      _errorPermisos = null;
      return;
    }

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      _permisoCamaraOk = statuses[Permission.camera]?.isGranted ?? false;
      _permisoMicrofonoOk = statuses[Permission.microphone]?.isGranted ?? false;

      if (!_permisoCamaraOk && !_permisoMicrofonoOk) {
        _errorPermisos =
            'Se requieren permisos de cámara y micrófono para la videollamada.';
      } else if (!_permisoCamaraOk) {
        _errorPermisos =
            'Permiso de cámara denegado. Continuando en modo solo audio.';
      } else if (!_permisoMicrofonoOk) {
        _errorPermisos =
            'Permiso de micrófono denegado. El médico no podrá escucharte.';
      } else {
        _errorPermisos = null;
      }
    } catch (e) {
      _log('Error al solicitar permisos: $e');
    }
    _notificarSeguro();
  }

  Future<void> reintentarPermisosYMedios() async {
    if (_cerrado) return;
    await _solicitarPermisos();
    if (_permisoCamaraOk || _permisoMicrofonoOk) {
      await _detenerMediosLocales();
      await _abrirMediosLocales();
      await _construirPeerConnection();
      await _enviarJoin();
    }
  }

  Future<void> _abrirMediosLocales() async {
    final audioConstraints = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': false,
    };
    final videoConstraints = <String, dynamic>{
      'facingMode': _camaraFrontal ? 'user' : 'environment',
      'width': {'ideal': 640},
      'height': {'ideal': 480},
      'frameRate': {'ideal': 24},
    };

    // Intento 1: Video + Audio con constraints ideales
    if (_permisoCamaraOk && _permisoMicrofonoOk) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': audioConstraints,
          'video': videoConstraints,
        });
      } catch (e) {
        _log('getUserMedia ideal falló, probando genérico: $e');
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': {'facingMode': 'user'},
          });
        } catch (e2) {
          _log('getUserMedia genérico falló: $e2');
        }
      }
    }

    // Intento 2: Solo audio si la cámara falló o fue denegada
    if (_localStream == null && _permisoMicrofonoOk) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': audioConstraints,
          'video': false,
        });
        _camaraActiva = false;
      } catch (e) {
        _log('getUserMedia solo audio falló: $e');
      }
    }

    // Intento 3: Solo video si el micrófono fue denegado
    if (_localStream == null && _permisoCamaraOk) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': videoConstraints,
        });
        _microfonoActivo = false;
      } catch (e) {
        _log('getUserMedia solo video falló: $e');
      }
    }

    if (_localStream != null) {
      localRenderer.srcObject = _localStream;
      _camaraActiva = _localStream!.getVideoTracks().isNotEmpty;
      _microfonoActivo = _localStream!.getAudioTracks().isNotEmpty;
    } else {
      _camaraActiva = false;
      _microfonoActivo = false;
    }
    _notificarSeguro();
  }

  Future<void> _construirPeerConnection() async {
    await _cerrarPeerConnection();
    if (_cerrado) return;

    _hasRemoteDescription = false;
    _candidatosPendientes.clear();
    _videoNativoDecodificando = false;

    final config = <String, dynamic>{
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config);
    _peerConnection = pc;

    final local = _localStream;
    bool tieneAudioLocal = false;
    bool tieneVideoLocal = false;

    if (local != null) {
      for (final track in local.getTracks()) {
        if (track.kind == 'audio') tieneAudioLocal = true;
        if (track.kind == 'video') tieneVideoLocal = true;
        await pc.addTrack(track, local);
      }
    }

    // Garantizar recepción de audio y video del médico incluso si el paciente no tiene cámara/micrófono
    if (!tieneAudioLocal) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    }
    if (!tieneVideoLocal) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    }

    pc.onTrack = (RTCTrackEvent event) async {
      if (_cerrado) return;
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
      } else {
        _remoteStream ??= await createLocalMediaStream('remote-$_idCita');
        await _remoteStream!.addTrack(event.track);
        remoteRenderer.srcObject = _remoteStream;
      }

      if (event.track.kind == 'audio') {
        event.track.enabled = _doctorMicrofonoActivo;
        await _aplicarAltavoz(_altavozActivo);
      }
      if (event.track.kind == 'video') {
        _hayVideoRemoto = true;
      }
      _doctorConectado = true;
      _p2pConectado = true;
      _estadoConexionTexto = 'Conectado · Audio y Video P2P';
      _notificarSeguro();
    };

    pc.onAddStream = (MediaStream stream) {
      if (_cerrado) return;
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
      if (stream.getVideoTracks().isNotEmpty) {
        _hayVideoRemoto = true;
      }
      _doctorConectado = true;
      _p2pConectado = true;
      _estadoConexionTexto = 'Conectado · Audio y Video P2P';
      _notificarSeguro();
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (_cerrado) return;
      final candStr = candidate.candidate;
      if (candStr == null || candStr.isEmpty) return;

      TeleconsultaRemoteDataSource.enviarSenalWebrtc(
        idCita: _idCita,
        de: 'PACIENTE',
        para: 'DOCTOR',
        tipo: 'CANDIDATE',
        peerId: _miPeerId,
        targetPeerId: _doctorPeerId,
        data: {
          'candidate': candStr,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      if (_cerrado) return;
      _log('PeerConnection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _p2pConectado = true;
        _doctorConectado = true;
        _estadoConexionTexto = 'Conectado · Audio y Video P2P';
        _notificarSeguro();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _p2pConectado = false;
        _videoNativoDecodificando = false;
        _estadoConexionTexto = 'Reconectando con el médico...';
        _notificarSeguro();
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState iceState) {
      if (_cerrado) return;
      _log('ICE state: $iceState');
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _p2pConectado = true;
        _doctorConectado = true;
        _estadoConexionTexto = 'Conectado · Audio y Video P2P';
        _notificarSeguro();
      } else if (iceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _p2pConectado = false;
        _videoNativoDecodificando = false;
        _estadoConexionTexto = 'Reintentando enlace WebRTC...';
        _notificarSeguro();
      }
    };
  }

  Future<void> _enviarJoin() async {
    if (_cerrado) return;
    final res = await TeleconsultaRemoteDataSource.enviarSenalWebrtc(
      idCita: _idCita,
      de: 'PACIENTE',
      para: 'DOCTOR',
      tipo: 'JOIN',
      peerId: _miPeerId,
      data: {
        'rol': 'PACIENTE',
        'peerId': _miPeerId,
      },
    );
    if (res != null && res['id'] != null) {
      _senalesProcesadas.add(res['id'].toString());
    }
  }

  void _iniciarTemporizadores() {
    _pollingTimer?.cancel();
    _reintentoJoinTimer?.cancel();
    _cicloPolling = 0;

    _sincronizarCiclo();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _sincronizarCiclo();
    });

    _reintentoJoinTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_cerrado || _consultaFinalizadaPorDoctor) return;

      // Limpiar frame fallback congelado si dejaron de llegar capturas
      if (!_p2pConectado &&
          _doctorFrameFallbackBytes != null &&
          _ultimoFrameFallbackTs != null &&
          DateTime.now().difference(_ultimoFrameFallbackTs!).inMilliseconds >
              4500) {
        _doctorFrameFallbackBytes = null;
        _notificarSeguro();
      }

      if (!_p2pConectado) {
        await _enviarJoin();
      }
    });
  }

  Future<void> _sincronizarCiclo() async {
    if (_cerrado || _sincronizando || _consultaFinalizadaPorDoctor) return;
    _sincronizando = true;
    _cicloPolling++;

    try {
      // 1. Reportar presencia cada ~2.4s (y en el primer ciclo)
      if (_cicloPolling == 1 || _cicloPolling % 3 == 0) {
        final presencia = await TeleconsultaRemoteDataSource.reportarPresencia(
          idCita: _idCita,
          rol: 'PACIENTE',
          conectado: true,
          nombre: _pacienteNombre,
        );

        if (_cerrado) return;
        if (presencia != null) {
          if (presencia['estado'] == 'FINALIZADA' &&
              !WebrtcSignalingHelper.debeIgnorarFinalizacion(
                inicioSesion: _inicioSesion,
                ahora: DateTime.now(),
              )) {
            _marcarFinalizadaPorDoctor();
            return;
          }

          final docOnline = presencia['doctor_conectado'] == true;
          if (docOnline != _doctorConectado) {
            _doctorConectado = docOnline;
            if (!_p2pConectado) {
              _estadoConexionTexto = docOnline
                  ? 'Médico en sala · Estableciendo video...'
                  : 'Esperando al médico...';
            }
            _notificarSeguro();
          }
        }
      }

      // 2. Procesar señales WebRTC pendientes para PACIENTE
      final senales = await TeleconsultaRemoteDataSource.obtenerSenalesWebrtc(
        idCita: _idCita,
        para: 'PACIENTE',
      );
      if (_cerrado) return;

      for (final s in senales) {
        await _manejarSenalEntrante(s);
        if (_cerrado || _consultaFinalizadaPorDoctor) return;
      }

      // 3. Consultar contador de mensajes nuevos del doctor cada ~3.2s
      if (_cicloPolling == 1 || _cicloPolling % 4 == 0) {
        final mensajes =
            await TeleconsultaRemoteDataSource.obtenerMensajesRealtime(_idCita);
        if (_cerrado) return;
        if (mensajes.isNotEmpty) {
          final totalDoc = mensajes.where((m) => m['esDoctor'] == true).length;
          if (_ultimoTotalMensajesDoctor > 0 &&
              totalDoc > _ultimoTotalMensajesDoctor) {
            _contadorMensajesNuevos += (totalDoc - _ultimoTotalMensajesDoctor);
            _notificarSeguro();
          }
          _ultimoTotalMensajesDoctor = totalDoc;
        }
      }
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _manejarSenalEntrante(Map<String, dynamic> s) async {
    final sid = (s['id'] ?? '').toString();
    if (sid.isEmpty || _senalesProcesadas.contains(sid)) return;
    _senalesProcesadas.add(sid);

    final tipo = (s['tipo'] ?? '').toString().toUpperCase();
    final data = s['data'];
    final sPeerId = s['peerId']?.toString();
    final sTargetPeerId = s['targetPeerId']?.toString();
    final timestamp = s['timestamp']?.toString();

    if (tipo == 'FINALIZAR_CONSULTA') {
      if (WebrtcSignalingHelper.debeIgnorarFinalizacion(
        inicioSesion: _inicioSesion,
        ahora: DateTime.now(),
        signalTimestampIso: timestamp,
      )) {
        return;
      }
      _marcarFinalizadaPorDoctor();
      return;
    }

    if (tipo == 'VIDEO_FRAME' && data is Map && data['frame'] is String) {
      // Solo usar relay JPEG si aún no decodificamos video nativo WebRTC
      if (!_videoNativoDecodificando) {
        final bytes =
            WebrtcSignalingHelper.decodificarFrameBase64(data['frame'] as String);
        if (bytes != null) {
          _doctorFrameFallbackBytes = bytes;
          _ultimoFrameFallbackTs = DateTime.now();
          _doctorConectado = true;
          _doctorCamaraActiva = true;
          if (!_p2pConectado) {
            _estadoConexionTexto = 'Conectado (respaldo de video)';
          }
          _notificarSeguro();
        }
      }
      return;
    }

    if (tipo == 'OFFER' && data is Map) {
      if (!WebrtcSignalingHelper.correspondeAMiPeer(
        miPeerId: _miPeerId,
        targetPeerId: sTargetPeerId,
      )) {
        return;
      }

      final offerPeerId = sPeerId ?? sid;
      if (offerPeerId == _ultimoOfferPeerIdProcesado &&
          _p2pConectado &&
          _peerConnection?.signalingState ==
              RTCSignalingState.RTCSignalingStateStable) {
        return;
      }

      await _procesarOffer(
        sdp: data['sdp']?.toString(),
        type: data['type']?.toString() ?? 'offer',
        doctorPeerId: sPeerId,
        offerKey: offerPeerId,
      );
      return;
    }

    if (tipo == 'CANDIDATE' && data is Map) {
      if (!WebrtcSignalingHelper.correspondeAMiPeer(
        miPeerId: _miPeerId,
        targetPeerId: sTargetPeerId,
      )) {
        return;
      }
      if (_doctorPeerId != null &&
          sPeerId != null &&
          sPeerId.isNotEmpty &&
          sPeerId != _doctorPeerId) {
        return;
      }

      final candStr = data['candidate']?.toString();
      if (candStr == null || candStr.isEmpty) return;

      final sdpMid = data['sdpMid']?.toString();
      final rawIdx = data['sdpMLineIndex'];
      final sdpMLineIndex = rawIdx is int
          ? rawIdx
          : (rawIdx is num ? rawIdx.toInt() : int.tryParse('$rawIdx'));

      final candidate = RTCIceCandidate(candStr, sdpMid, sdpMLineIndex);
      if (_peerConnection != null && _hasRemoteDescription) {
        try {
          await _peerConnection!.addCandidate(candidate);
        } catch (e) {
          _log('Error al agregar ICE candidate: $e');
        }
      } else {
        _candidatosPendientes.add(candidate);
      }
      return;
    }

    if (tipo == 'CAMARA_ESTADO' && data is Map) {
      _doctorCamaraActiva = data['activa'] == true;
      if (!_doctorCamaraActiva) {
        _doctorFrameFallbackBytes = null;
      }
      _notificarSeguro();
    } else if (tipo == 'MICROFONO_ESTADO' && data is Map) {
      _doctorMicrofonoActivo = data['activo'] == true;
      _remoteStream?.getAudioTracks().forEach((track) {
        track.enabled = _doctorMicrofonoActivo;
      });
      _notificarSeguro();
    } else if (tipo == 'PANTALLA_COMPARTIDA') {
      _doctorCompartiendoPantalla = true;
      _doctorConectado = true;
      _notificarSeguro();
    } else if (tipo == 'DETENER_PANTALLA') {
      _doctorCompartiendoPantalla = false;
      _notificarSeguro();
    }
  }

  Future<void> _procesarOffer({
    required String? sdp,
    required String type,
    required String? doctorPeerId,
    required String offerKey,
  }) async {
    if (sdp == null || sdp.isEmpty || _negociandoOffer || _cerrado) return;
    _negociandoOffer = true;

    try {
      _ultimoOfferPeerIdProcesado = offerKey;
      _doctorPeerId = doctorPeerId;
      _doctorConectado = true;
      _estadoConexionTexto = 'Negociando audio y video...';
      _notificarSeguro();

      if (_peerConnection == null ||
          _hasRemoteDescription ||
          _peerConnection!.signalingState !=
              RTCSignalingState.RTCSignalingStateStable) {
        await _construirPeerConnection();
      }
      if (_cerrado || _peerConnection == null) return;

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _hasRemoteDescription = true;

      await _vaciarCandidatosPendientes();

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      final res = await TeleconsultaRemoteDataSource.enviarSenalWebrtc(
        idCita: _idCita,
        de: 'PACIENTE',
        para: 'DOCTOR',
        tipo: 'ANSWER',
        peerId: _miPeerId,
        targetPeerId: _doctorPeerId,
        data: {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      );
      if (res != null && res['id'] != null) {
        _senalesProcesadas.add(res['id'].toString());
      }
    } catch (e) {
      _log('Error al procesar OFFER del médico: $e');
      _ultimoOfferPeerIdProcesado = '';
    } finally {
      _negociandoOffer = false;
    }
  }

  Future<void> _vaciarCandidatosPendientes() async {
    if (_peerConnection == null || !_hasRemoteDescription) return;
    final pendientes = List<RTCIceCandidate>.from(_candidatosPendientes);
    _candidatosPendientes.clear();
    for (final cand in pendientes) {
      try {
        await _peerConnection!.addCandidate(cand);
      } catch (e) {
        _log('Error al vaciar candidato ICE pendiente: $e');
      }
    }
  }

  void _marcarFinalizadaPorDoctor() {
    if (_consultaFinalizadaPorDoctor) return;
    _consultaFinalizadaPorDoctor = true;
    _pollingTimer?.cancel();
    _reintentoJoinTimer?.cancel();
    _notificarSeguro();
  }

  /// Silencia o reactiva el micrófono real y notifica al médico.
  Future<void> alternarMicrofono() async {
    if (_cerrado) return;
    _microfonoActivo = !_microfonoActivo;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _microfonoActivo;
    });
    _notificarSeguro();

    await TeleconsultaRemoteDataSource.enviarSenalWebrtc(
      idCita: _idCita,
      de: 'PACIENTE',
      para: 'DOCTOR',
      tipo: 'MICROFONO_ESTADO',
      peerId: _miPeerId,
      targetPeerId: _doctorPeerId,
      data: {'activo': _microfonoActivo},
    );
  }

  /// Activa o desactiva el video de la cámara real y notifica al médico.
  Future<void> alternarCamara() async {
    if (_cerrado) return;
    _camaraActiva = !_camaraActiva;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _camaraActiva;
    });
    _notificarSeguro();

    await TeleconsultaRemoteDataSource.enviarSenalWebrtc(
      idCita: _idCita,
      de: 'PACIENTE',
      para: 'DOCTOR',
      tipo: 'CAMARA_ESTADO',
      peerId: _miPeerId,
      targetPeerId: _doctorPeerId,
      data: {'activa': _camaraActiva},
    );
  }

  /// Alterna entre cámara frontal y trasera en tiempo real.
  Future<bool> cambiarCamara() async {
    if (_cerrado) return _camaraFrontal;
    final videoTracks = _localStream?.getVideoTracks() ?? const [];
    if (videoTracks.isEmpty) return _camaraFrontal;
    try {
      final isFront = await Helper.switchCamera(videoTracks.first);
      _camaraFrontal = isFront;
      _notificarSeguro();
    } catch (e) {
      _log('No se pudo cambiar de cámara: $e');
      _camaraFrontal = !_camaraFrontal;
      _notificarSeguro();
    }
    return _camaraFrontal;
  }

  /// Alterna entre altavoz y auricular del teléfono.
  Future<void> alternarAltavoz() async {
    if (_cerrado) return;
    await _aplicarAltavoz(!_altavozActivo);
    _notificarSeguro();
  }

  Future<void> _aplicarAltavoz(bool activar) async {
    _altavozActivo = activar;
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(activar);
      } catch (e) {
        _log('No se pudo cambiar el altavoz: $e');
      }
    }
  }

  Future<void> _cerrarPeerConnection() async {
    final pc = _peerConnection;
    _peerConnection = null;
    if (pc != null) {
      try {
        pc.onTrack = null;
        pc.onAddStream = null;
        pc.onIceCandidate = null;
        pc.onConnectionState = null;
        pc.onIceConnectionState = null;
        await pc.close();
      } catch (_) {}
    }
  }

  Future<void> _detenerMediosLocales() async {
    final local = _localStream;
    _localStream = null;
    if (local != null) {
      for (final track in local.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await local.dispose();
      } catch (_) {}
    }
    try {
      localRenderer.srcObject = null;
    } catch (_) {}
  }

  /// Cierra limpiamente la sesión WebRTC, libera cámara/micrófono y reporta desconexión.
  Future<void> cerrarSesion() async {
    if (_cerrado) return;
    _cerrado = true;

    _pollingTimer?.cancel();
    _pollingTimer = null;
    _reintentoJoinTimer?.cancel();
    _reintentoJoinTimer = null;

    await _cerrarPeerConnection();
    await _detenerMediosLocales();

    try {
      remoteRenderer.srcObject = null;
      await _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;

    try {
      await localRenderer.dispose();
    } catch (_) {}
    try {
      await remoteRenderer.dispose();
    } catch (_) {}

    if (_idCita > 0) {
      await TeleconsultaRemoteDataSource.reportarPresencia(
        idCita: _idCita,
        rol: 'PACIENTE',
        conectado: false,
        nombre: _pacienteNombre,
      );
    }
  }

  void _notificarSeguro() {
    if (!_cerrado) {
      notifyListeners();
    }
  }

  void _log(String msg) {
    if (kDebugMode) {
      debugPrint('[WebrtcMovilService] $msg');
    }
  }

  @override
  void dispose() {
    if (!_cerrado) {
      unawaited(cerrarSesion());
    }
    super.dispose();
  }
}
