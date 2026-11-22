import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../appointments/presentation/providers/appointment_provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'chat_teleconsulta_screen.dart';
import 'sala_espera_screen.dart';

class TeleconsultasListScreen extends StatefulWidget {
  const TeleconsultasListScreen({super.key});

  @override
  State<TeleconsultasListScreen> createState() => _TeleconsultasListScreenState();
}

class _TeleconsultasListScreenState extends State<TeleconsultasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppointmentProvider>(context, listen: false).fetchAppointments();
    });
  }

  void _abrirSalaDeEspera({
    required int idCita,
    required String codigoFicha,
    required String medicoNombre,
    required String especialidad,
    required String clinicaNombre,
    required String clinicaIniciales,
    required String horaTeleconsulta,
    required int posicionEnFila,
    required int pacientesAntes,
    required int tiempoEstimadoMinutos,
  }) {
    String? nombrePaciente;
    try {
      final user = Provider.of<AuthController>(context, listen: false).currentUser;
      if (user != null) {
        final full = '${user.nombres} ${user.apellidos}'.trim();
        if (full.isNotEmpty) nombrePaciente = full;
      }
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalaEsperaScreen(
          idCita: idCita,
          codigoFicha: codigoFicha,
          medicoNombre: medicoNombre,
          especialidad: especialidad,
          clinicaNombre: clinicaNombre,
          clinicaIniciales: clinicaIniciales,
          horaTeleconsulta: horaTeleconsulta,
          posicionEnFila: posicionEnFila,
          pacientesAntes: pacientesAntes,
          tiempoEstimadoMinutos: tiempoEstimadoMinutos,
          pacienteNombre: nombrePaciente,
        ),
      ),
    );
  }

  void _abrirChat(int idCita, String medicoNombre, String especialidad, String clinica) {
    ChatTeleconsultaScreen.showAsModal(
      context,
      idCita: idCita,
      medicoNombre: medicoNombre,
      especialidadNombre: especialidad,
      clinicaNombre: clinica,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
    final todas = appointmentProvider.appointments;

    // Filtrar citas virtuales (Telemedicina)
    final citasVirtuales = todas.where((c) {
      final tipo = c.tipoConsulta.toUpperCase();
      return tipo == 'TELEMEDICINA' || tipo == 'VIRTUAL' || tipo == 'TELECONSULTA';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teleconsultas',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Atención médica virtual en tiempo real',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<AppointmentProvider>(context, listen: false).fetchAppointments();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BANNER INFORMATIVO
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2942), Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F2942).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.video_call_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sala de Espera Virtual',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Entra a la sala para verificar tu turno, equipo de audio y esperar la atención del médico.',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const Text(
                'Tus Teleconsultas Activas',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),

              // ========================================================
              // CONSULTA 1: Dra. Lucía Rojas (CAR-014 - Cardiología)
              // ========================================================
              _construirTarjetaTeleconsulta(
                codigoFicha: 'FICHA CAR-014',
                estadoEtiqueta: 'En sala de espera',
                colorEstado: const Color(0xFF10B981),
                colorEstadoFondo: const Color(0xFFE6F4EA),
                medicoNombre: 'Dra. Lucía Rojas',
                especialidad: 'Cardiología · Control',
                clinicaNombre: 'Clínica Norte',
                clinicaIniciales: 'CN',
                horario: '10:30 - 11:00',
                posicionEnFila: 2,
                pacientesAntes: 1,
                tiempoEstimadoMin: 8,
                onEntrar: () {
                  _abrirSalaDeEspera(
                    idCita: 14,
                    codigoFicha: 'FICHA CAR-014',
                    medicoNombre: 'Dra. Lucía Rojas',
                    especialidad: 'Cardiología · Teleconsulta',
                    clinicaNombre: 'Clinica Norte',
                    clinicaIniciales: 'CN',
                    horaTeleconsulta: '10:30',
                    posicionEnFila: 2,
                    pacientesAntes: 1,
                    tiempoEstimadoMinutos: 8,
                  );
                },
                onChatear: () {
                  _abrirChat(14, 'Dra. Lucía Rojas', 'Cardiología', 'Clínica Norte');
                },
              ),
              const SizedBox(height: 14),

              // ========================================================
              // CONSULTA 2: Dr. Martín Vaca (PED-008 - Pediatría)
              // ========================================================
              _construirTarjetaTeleconsulta(
                codigoFicha: 'FICHA PED-008',
                estadoEtiqueta: 'Tu turno',
                colorEstado: const Color(0xFF0D9488),
                colorEstadoFondo: const Color(0xFFCCFBF1),
                medicoNombre: 'Dr. Martín Vaca',
                especialidad: 'Pediatría · Control infantil',
                clinicaNombre: 'Hospital San Juan de Dios',
                clinicaIniciales: 'SJ',
                horario: '17:00 - 17:30',
                posicionEnFila: 1,
                pacientesAntes: 0,
                tiempoEstimadoMin: 4,
                onEntrar: () {
                  _abrirSalaDeEspera(
                    idCita: 8,
                    codigoFicha: 'FICHA PED-008',
                    medicoNombre: 'Dr. Martín Vaca',
                    especialidad: 'Pediatría · Teleconsulta',
                    clinicaNombre: 'Hospital San Juan de Dios',
                    clinicaIniciales: 'SJ',
                    horaTeleconsulta: '17:00',
                    posicionEnFila: 1,
                    pacientesAntes: 0,
                    tiempoEstimadoMinutos: 4,
                  );
                },
                onChatear: () {
                  _abrirChat(8, 'Dr. Martín Vaca', 'Pediatría', 'Hospital San Juan de Dios');
                },
              ),
              const SizedBox(height: 14),

              // ========================================================
              // CONSULTA 3: Dr. Roberto Gómez Flores (MED-003 - Medicina)
              // ========================================================
              _construirTarjetaTeleconsulta(
                codigoFicha: 'FICHA MED-003',
                estadoEtiqueta: 'En fila virtual',
                colorEstado: const Color(0xFF2563EB),
                colorEstadoFondo: const Color(0xFFEFF6FF),
                medicoNombre: 'Dr. Roberto Gómez Flores',
                especialidad: 'Medicina General · Consulta',
                clinicaNombre: 'Hospital San Juan de Dios',
                clinicaIniciales: 'SJ',
                horario: '09:00 - 09:30',
                posicionEnFila: 3,
                pacientesAntes: 2,
                tiempoEstimadoMin: 15,
                onEntrar: () {
                  _abrirSalaDeEspera(
                    idCita: 3,
                    codigoFicha: 'FICHA MED-003',
                    medicoNombre: 'Dr. Roberto Gómez Flores',
                    especialidad: 'Medicina General · Teleconsulta',
                    clinicaNombre: 'Hospital San Juan de Dios',
                    clinicaIniciales: 'SJ',
                    horaTeleconsulta: '09:00',
                    posicionEnFila: 3,
                    pacientesAntes: 2,
                    tiempoEstimadoMinutos: 15,
                  );
                },
                onChatear: () {
                  _abrirChat(3, 'Dr. Roberto Gómez Flores', 'Medicina General', 'Hospital San Juan de Dios');
                },
              ),
              const SizedBox(height: 14),

              // Si existen citas adicionales cargadas desde la BD
              for (final cita in citasVirtuales)
                if (cita.idCita != 14 && cita.idCita != 8 && cita.idCita != 3) ...[
                  _construirTarjetaTeleconsulta(
                    codigoFicha: 'FICHA CIT-${cita.idCita}',
                    estadoEtiqueta: cita.estado,
                    colorEstado: const Color(0xFF2563EB),
                    colorEstadoFondo: const Color(0xFFEFF6FF),
                    medicoNombre: cita.medicoNombre.isNotEmpty ? cita.medicoNombre : 'Dr. Especialista',
                    especialidad: '${cita.especialidadNombre} · Teleconsulta',
                    clinicaNombre: 'Hospital San Juan de Dios',
                    clinicaIniciales: 'SJ',
                    horario: cita.horaInicio.isNotEmpty ? '${cita.horaInicio} h' : 'Horario programado',
                    posicionEnFila: 1,
                    pacientesAntes: 0,
                    tiempoEstimadoMin: 5,
                    onEntrar: () {
                      _abrirSalaDeEspera(
                        idCita: cita.idCita,
                        codigoFicha: 'FICHA CIT-${cita.idCita}',
                        medicoNombre: cita.medicoNombre.isNotEmpty ? cita.medicoNombre : 'Dr. Especialista',
                        especialidad: '${cita.especialidadNombre} · Teleconsulta',
                        clinicaNombre: 'Hospital San Juan de Dios',
                        clinicaIniciales: 'SJ',
                        horaTeleconsulta: cita.horaInicio.isNotEmpty ? cita.horaInicio : '11:00',
                        posicionEnFila: 1,
                        pacientesAntes: 0,
                        tiempoEstimadoMinutos: 5,
                      );
                    },
                    onChatear: () {
                      _abrirChat(cita.idCita, cita.medicoNombre, cita.especialidadNombre, 'Hospital San Juan de Dios');
                    },
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirTarjetaTeleconsulta({
    required String codigoFicha,
    required String estadoEtiqueta,
    required Color colorEstado,
    required Color colorEstadoFondo,
    required String medicoNombre,
    required String especialidad,
    required String clinicaNombre,
    required String clinicaIniciales,
    required String horario,
    required int posicionEnFila,
    required int pacientesAntes,
    required int tiempoEstimadoMin,
    required VoidCallback onEntrar,
    required VoidCallback onChatear,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la tarjeta
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC5221F),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        clinicaIniciales,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clinicaNombre,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorEstadoFondo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    estadoEtiqueta,
                    style: TextStyle(
                      color: colorEstado,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Cuerpo con datos del médico y cita
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicoNombre,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  especialidad,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      horario,
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.videocam_outlined, size: 16, color: Color(0xFF0D9488)),
                    const SizedBox(width: 4),
                    const Text(
                      'Videoconsulta',
                      style: TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Botones de acción: Chatear y Entrar a la sala
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Botón Chatear
                OutlinedButton.icon(
                  onPressed: onChatear,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Chatear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 10),

                // Botón Entrar a la sala (Destacado)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEntrar,
                    icon: const Icon(Icons.videocam_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Entrar a la sala',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2948),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
