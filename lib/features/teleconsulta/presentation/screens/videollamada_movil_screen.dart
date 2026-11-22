import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/services/webrtc_movil_service.dart';
import 'chat_teleconsulta_screen.dart';

class VideollamadaMovilScreen extends StatefulWidget {
  final int idCita;
  final String codigoFicha;
  final String medicoNombre;
  final String especialidad;
  final String clinicaNombre;
  final String? pacienteNombre;
  final String medicoIniciales;
  final String? pacienteInicial;

  const VideollamadaMovilScreen({
    super.key,
    this.idCita = 14,
    this.codigoFicha = 'FICHA CAR-014',
    this.medicoNombre = 'Dra. Lucía Rojas',
    this.especialidad = 'Cardiología',
    this.clinicaNombre = 'Clínica Norte',
    this.pacienteNombre,
    this.medicoIniciales = 'LR',
    this.pacienteInicial,
  });

  @override
  State<VideollamadaMovilScreen> createState() => _VideollamadaMovilScreenState();
}

class _VideollamadaMovilScreenState extends State<VideollamadaMovilScreen> {
  late final WebrtcMovilService _webrtc;
  bool _cerrandoPorDoctor = false;
  int _segundosTranscurridos = 0;
  Timer? _temporizadorLlamada;
  late String _nombrePacienteResuelto;
  late String _inicialPacienteResuelta;

  @override
  void initState() {
    super.initState();
    _webrtc = WebrtcMovilService();
    _webrtc.addListener(_onWebrtcStateChanged);

    _nombrePacienteResuelto = _resolverNombrePacienteInicial();
    _inicialPacienteResuelta = _resolverInicialPaciente(_nombrePacienteResuelto);

    _iniciarTemporizador();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nombrePacienteResuelto = _resolverNombrePacienteConContexto();
      _inicialPacienteResuelta = _resolverInicialPaciente(_nombrePacienteResuelto);
      _webrtc.iniciarSesion(
        idCita: widget.idCita,
        pacienteNombre: _nombrePacienteResuelto,
      );
    });
  }

  String _resolverNombrePacienteInicial() {
    final param = widget.pacienteNombre?.trim();
    if (param != null && param.isNotEmpty) return param;
    return 'Paciente';
  }

  String _resolverNombrePacienteConContexto() {
    final param = widget.pacienteNombre?.trim();
    if (param != null && param.isNotEmpty) return param;
    try {
      final user = Provider.of<AuthController>(context, listen: false).currentUser;
      if (user != null) {
        final full = '${user.nombres} ${user.apellidos}'.trim();
        if (full.isNotEmpty) return full;
      }
    } catch (_) {}
    return 'Paciente';
  }

  String _resolverInicialPaciente(String nombre) {
    final paramIni = widget.pacienteInicial?.trim();
    if (paramIni != null && paramIni.isNotEmpty) {
      return paramIni.substring(0, 1).toUpperCase();
    }
    if (nombre.isNotEmpty) return nombre.substring(0, 1).toUpperCase();
    return 'P';
  }

  void _onWebrtcStateChanged() {
    if (!mounted) return;
    if (_webrtc.consultaFinalizadaPorDoctor && !_cerrandoPorDoctor) {
      _cerrarPorFinalizacionDelDoctor();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _detenerTemporizador();
    _webrtc.removeListener(_onWebrtcStateChanged);
    _webrtc.dispose();
    super.dispose();
  }

  void _iniciarTemporizador() {
    _temporizadorLlamada = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (_webrtc.doctorConectado ||
              _webrtc.p2pConectado ||
              _webrtc.hayVideoRemoto)) {
        setState(() {
          _segundosTranscurridos++;
        });
      }
    });
  }

  void _detenerTemporizador() {
    _temporizadorLlamada?.cancel();
    _temporizadorLlamada = null;
  }

  Future<void> _cerrarPorFinalizacionDelDoctor() async {
    if (_cerrandoPorDoctor || !mounted) return;
    _cerrandoPorDoctor = true;
    _detenerTemporizador();
    await _webrtc.cerrarSesion();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El médico ha finalizado la teleconsulta. Redirigiendo a tus recetas...',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
    if (mounted) {
      Navigator.of(context).pushNamed('/recetas');
    }
  }

  String _formatearTiempo(int totalSegundos) {
    final minutos = totalSegundos ~/ 60;
    final segundos = totalSegundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  Future<void> _alternarMicrofono() async {
    await _webrtc.alternarMicrofono();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _webrtc.microfonoActivo ? 'Micrófono activado' : 'Micrófono silenciado',
        ),
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _alternarCamara() async {
    await _webrtc.alternarCamara();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _webrtc.camaraActiva ? 'Cámara activada' : 'Cámara desactivada',
        ),
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cambiarCamara() async {
    final frontal = await _webrtc.cambiarCamara();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          frontal ? 'Cámara frontal seleccionada' : 'Cámara trasera seleccionada',
        ),
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _alternarAltavoz() async {
    await _webrtc.alternarAltavoz();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _webrtc.altavozActivo ? 'Altavoz activado' : 'Auricular activado',
        ),
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirChatModal() {
    _webrtc.reiniciarContadorMensajes();
    ChatTeleconsultaScreen.showAsModal(
      context,
      idCita: widget.idCita,
      medicoNombre: widget.medicoNombre,
      especialidadNombre: widget.especialidad,
      clinicaNombre: widget.clinicaNombre,
    );
  }

  Future<void> _colgarYLlamar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Finalizar videollamada?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Deseas salir de la sesión médica actual? Podrás consultar tus recetas y documentos clínicos.',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Continuar en llamada',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Salir de la sala',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      _detenerTemporizador();
      await _webrtc.cerrarSesion();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (mounted) {
        Navigator.of(context).pushNamed('/recetas');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneStreamRemoto = _webrtc.remoteRenderer.srcObject != null &&
        (_webrtc.doctorCamaraActiva || _webrtc.doctorCompartiendoPantalla);
    final bool mostrarFallbackEncima = !_webrtc.videoNativoDecodificando &&
        _webrtc.doctorFrameFallbackBytes != null &&
        (_webrtc.doctorCamaraActiva || _webrtc.doctorCompartiendoPantalla);
    final bool mostrarVideoRemoto = tieneStreamRemoto || mostrarFallbackEncima;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1528),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. VISTA PRINCIPAL DEL DOCTOR (WEBRTC NATIVO EN VIVO + FALLBACK + AVATAR)
            if (mostrarVideoRemoto)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (tieneStreamRemoto)
                        RTCVideoView(
                          _webrtc.remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        ),
                      if (mostrarFallbackEncima)
                        Image.memory(
                          _webrtc.doctorFrameFallbackBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _webrtc.doctorConectado
                                ? const Color(0xFF10B981).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.15),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_webrtc.doctorConectado
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF1E3A5F))
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.medicoIniciales,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.medicoNombre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.especialidad,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (_webrtc.doctorConectado
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF3B82F6))
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_webrtc.doctorConectado
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF60A5FA))
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _webrtc.doctorCompartiendoPantalla
                                  ? Icons.screen_share_rounded
                                  : (_webrtc.doctorConectado
                                      ? (_webrtc.doctorMicrofonoActivo
                                          ? Icons.graphic_eq_rounded
                                          : Icons.mic_off_rounded)
                                      : Icons.wifi_tethering_rounded),
                              color: _webrtc.doctorConectado
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF93C5FD),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _webrtc.doctorConectado
                                    ? (_webrtc.doctorCompartiendoPantalla
                                        ? 'Médico compartiendo pantalla'
                                        : (_webrtc.doctorCamaraActiva
                                            ? _webrtc.estadoConexionTexto
                                            : 'En línea · Solo Audio'))
                                    : _webrtc.estadoConexionTexto,
                                style: TextStyle(
                                  color: _webrtc.doctorConectado
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFFBFDBFE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 2. INDICADORES SUPERIORES (DURACIÓN, ESTADO P2P, CIFRADO)
            Positioned(
              top: 16,
              left: 16,
              right: 118,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _webrtc.p2pConectado
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatearTiempo(_segundosTranscurridos),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          color: _webrtc.p2pConectado
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _webrtc.p2pConectado ? 'P2P HD' : 'Conectando',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Color(0xFF60A5FA), size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Cifrado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2.5 BANNER DE AVISO DE PERMISOS SI FALTA CÁMARA O MICRÓFONO
            if (_webrtc.errorPermisos != null)
              Positioned(
                top: 62,
                left: 16,
                right: 120,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C2D12).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFB923C).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFDBA74),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _webrtc.errorPermisos!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _webrtc.reintentarPermisosYMedios();
                          if (_webrtc.errorPermisos != null) {
                            await openAppSettings();
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Permitir',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. PICTURE IN PICTURE: CÁMARA LOCAL REAL DEL PACIENTE (TÚ)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 96,
                height: 134,
                decoration: BoxDecoration(
                  color: const Color(0xFF24334A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _webrtc.tieneVideoLocal &&
                        _webrtc.localRenderer.srcObject != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          RTCVideoView(
                            _webrtc.localRenderer,
                            mirror: _webrtc.camaraFrontal,
                            objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Tú',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_webrtc.camaraActiva)
                            const Icon(
                              Icons.videocam_off_rounded,
                              color: Colors.white54,
                              size: 24,
                            )
                          else
                            Text(
                              _inicialPacienteResuelta,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            _webrtc.camaraActiva ? 'Tú' : 'Cámara off',
                            style: TextStyle(
                              color: _webrtc.camaraActiva
                                  ? const Color(0xFFCBD5E1)
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // 4. BARRA DE CONTROLES INFERIOR FLOTANTE
            Positioned(
              bottom: 24,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _construirBotonControl(
                    icono: _webrtc.microfonoActivo
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    colorFondo: _webrtc.microfonoActivo
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFEF4444),
                    onTap: _alternarMicrofono,
                  ),
                  _construirBotonControl(
                    icono: _webrtc.camaraActiva
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    colorFondo: _webrtc.camaraActiva
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFEF4444),
                    onTap: _alternarCamara,
                  ),
                  _construirBotonControl(
                    icono: Icons.cameraswitch_outlined,
                    colorFondo: const Color(0xFF1E293B),
                    onTap: _cambiarCamara,
                  ),
                  _construirBotonControl(
                    icono: _webrtc.altavozActivo
                        ? Icons.volume_up_rounded
                        : Icons.hearing_rounded,
                    colorFondo: _webrtc.altavozActivo
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF334155),
                    onTap: _alternarAltavoz,
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _construirBotonControl(
                        icono: Icons.chat_bubble_outline_rounded,
                        colorFondo: const Color(0xFF1E293B),
                        onTap: _abrirChatModal,
                      ),
                      if (_webrtc.contadorMensajesNuevos > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_webrtc.contadorMensajesNuevos}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _construirBotonControl(
                    icono: Icons.call_end_rounded,
                    colorFondo: const Color(0xFFDC2626),
                    onTap: _colgarYLlamar,
                    esBotonPeligro: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirBotonControl({
    required IconData icono,
    required Color colorFondo,
    required VoidCallback onTap,
    bool esBotonPeligro = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorFondo,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: esBotonPeligro ? 0.3 : 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            icono,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
