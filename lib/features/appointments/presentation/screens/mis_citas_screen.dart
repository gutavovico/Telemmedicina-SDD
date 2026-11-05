import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../teleconsulta/presentation/screens/chat_teleconsulta_screen.dart';
import '../../../payments/presentation/screens/payment_checkout_screen.dart';
import '../../../teleconsulta/presentation/screens/sala_espera_screen.dart';
import '../../data/models/appointment_model.dart';
import '../providers/appointment_provider.dart';
import 'book_appointment_sheet.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppointmentProvider>(context, listen: false).fetchAppointments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Limpieza de títulos médicos redundantes (ej. evitar "Dr(a). Dr. Roberto")
  String _limpiarTituloMedico(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return 'Dr. Especialista';
    var limpio = nombre.trim();
    limpio = limpio.replaceAll(RegExp(r'^(Dr\(a\)\.?\s*)+', caseSensitive: false), '');
    limpio = limpio.replaceAll(RegExp(r'^(Dr\.?\s*)+', caseSensitive: false), '');
    limpio = limpio.replaceAll(RegExp(r'^(Dra\.?\s*)+', caseSensitive: false), '');
    return 'Dr. $limpio';
  }

  String _extraerDia(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '03';
    try {
      final dt = DateTime.parse(fechaStr);
      return dt.day.toString().padLeft(2, '0');
    } catch (_) {
      final partes = fechaStr.split('-');
      if (partes.length == 3) return partes[2].padLeft(2, '0');
      return '03';
    }
  }

  String _extraerMes(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return 'OCT';
    try {
      final dt = DateTime.parse(fechaStr);
      const meses = [
        'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
        'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
      ];
      return meses[dt.month - 1];
    } catch (_) {
      return 'OCT';
    }
  }

  void _abrirSalaDeEspera(AppointmentModel cita) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalaEsperaScreen(
          idCita: cita.idCita,
          codigoFicha: 'FICHA CIT-${cita.idCita}',
          medicoNombre: _limpiarTituloMedico(cita.medicoNombre),
          especialidad: '${cita.especialidadNombre} · Teleconsulta',
          clinicaNombre: 'Hospital San Juan de Dios',
          clinicaIniciales: 'SJ',
          horaTeleconsulta: cita.horaInicio.isNotEmpty ? cita.horaInicio : '10:30',
          posicionEnFila: 2,
          pacientesAntes: 1,
          tiempoEstimadoMinutos: 8,
        ),
      ),
    );
  }

  void _abrirChat(AppointmentModel cita) {
    ChatTeleconsultaScreen.showAsModal(
      context,
      idCita: cita.idCita,
      medicoNombre: cita.medicoNombre,
      especialidadNombre: cita.especialidadNombre,
      fechaCita: cita.fechaCita,
      horaCita: cita.horaInicio,
      clinicaNombre: 'Hospital San Juan de Dios',
    );
  }

  void _abrirAgendarCita([AppointmentModel? citaToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookAppointmentSheet(appointmentToEdit: citaToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
    final todas = appointmentProvider.appointments;

    // Clasificación dinámica de citas reales (cero mocks)
    final hoyStr = DateTime.now().toIso8601String().split('T')[0];

    final canceladas = todas.where((c) {
      final st = c.estado.toUpperCase();
      return st == 'CANCELADA' || st == 'ANULADA';
    }).toList();

    final listaEspera = todas.where((c) {
      final st = c.estado.toUpperCase();
      return st == 'EN_ESPERA' || st == 'LISTA_ESPERA' || st == 'ESPERA';
    }).toList();

    final pasadas = todas.where((c) {
      final st = c.estado.toUpperCase();
      if (st == 'CANCELADA' || st == 'ANULADA' || st == 'EN_ESPERA') return false;
      if (st == 'COMPLETADA' || st == 'FINALIZADA') return true;
      if (c.fechaCita.isNotEmpty && c.fechaCita.compareTo(hoyStr) < 0) return true;
      return false;
    }).toList();

    final proximas = todas.where((c) {
      final st = c.estado.toUpperCase();
      if (st == 'CANCELADA' || st == 'ANULADA' || st == 'EN_ESPERA') return false;
      if (st == 'COMPLETADA' || st == 'FINALIZADA') return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis citas',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'En todas tus instituciones',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _abrirAgendarCita(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva cita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTypography.button.copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: 'Próximas (${proximas.length})'),
                Tab(text: 'Lista de espera (${listaEspera.length})'),
                Tab(text: 'Pasadas (${pasadas.length})'),
                Tab(text: 'Canceladas (${canceladas.length})'),
              ],
            ),
          ),
        ),
      ),
      body: appointmentProvider.isLoading && todas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => appointmentProvider.fetchAppointments(),
              color: AppColors.primary,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppointmentList(proximas, 'próximas'),
                  _buildAppointmentList(listaEspera, 'en lista de espera'),
                  _buildAppointmentList(pasadas, 'pasadas'),
                  _buildAppointmentList(canceladas, 'canceladas'),
                ],
              ),
            ),
    );
  }

  Widget _buildAppointmentList(List<AppointmentModel> lista, String categoria) {
    if (lista.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No tienes citas $categoria',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cuando programes o se actualicen tus citas, las verás reflejadas en esta sección en tiempo real.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _abrirAgendarCita(),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Agendar cita ahora'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: lista.length,
      itemBuilder: (ctx, index) {
        final cita = lista[index];
        return _buildAppointmentCard(cita);
      },
    );
  }

  Widget _buildAppointmentCard(AppointmentModel cita) {
    final dia = _extraerDia(cita.fechaCita);
    final mes = _extraerMes(cita.fechaCita);
    final medicoLimpio = _limpiarTituloMedico(cita.medicoNombre);
    final especialidad = cita.especialidadNombre.isNotEmpty
        ? cita.especialidadNombre
        : 'Medicina General';
    final motivo = cita.motivo != null && cita.motivo!.isNotEmpty
        ? cita.motivo!
        : 'Consulta médica de seguimiento';

    final esConfirmada = cita.estado.toUpperCase() == 'CONFIRMADA';
    final esPendiente = cita.estado.toUpperCase() == 'PENDIENTE';
    final esCancelada = cita.estado.toUpperCase() == 'CANCELADA';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Superior: Badge Fecha + Especialista + Estado Chip
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Cuadrado con Día y Mes
                Container(
                  width: 58,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dia,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          height: 1.1,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        mes,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Especialidad, Nombre Médico y Motivo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              especialidad,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusChip(cita.estado),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicoLimpio,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        motivo,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Metadatos: Institución, Horario, Modalidad y Código
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag de Institución
                Row(
                  children: [
                    const Icon(
                      Icons.local_hospital_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hospital San Juan de Dios',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // Código de ficha
                    Text(
                      '#CIT-${cita.idCita}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Horario y Modalidad
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      cita.horaFin != null && cita.horaFin!.isNotEmpty
                          ? '${cita.horaInicio} - ${cita.horaFin}'
                          : '${cita.horaInicio} h',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      cita.tipoConsulta == 'TELEMEDICINA'
                          ? Icons.videocam_outlined
                          : Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cita.tipoConsulta == 'TELEMEDICINA'
                          ? 'Videoconsulta'
                          : 'Presencial',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Botones de Acción
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Botón según modalidad: Si es telemedicina muestra Chatear y Entrar a la sala
                if (cita.tipoConsulta == 'TELEMEDICINA') ...[
                  OutlinedButton.icon(
                    onPressed: () => _abrirChat(cita),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                    label: const Text('Chatear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirSalaDeEspera(cita),
                      icon: const Icon(Icons.videocam_rounded, size: 18, color: Colors.white),
                      label: const Text('Entrar a la sala'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2948),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: AppTypography.button.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Botón Chatear estándar para presencial
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirChat(cita),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Chatear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: AppTypography.button.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),

                // Botón Secundario Contextual (Reprogramar o Pagar ahora)
                if (esConfirmada)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirAgendarCita(cita),
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('Reprogramar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.outline),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: AppTypography.button.copyWith(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                else if (esPendiente)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // CU19: abre la pantalla de pago (Stripe Checkout + QR).
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PaymentCheckoutScreen(idCita: cita.idCita),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment_outlined, size: 18),
                      label: const Text('Pagar ahora'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningContainer,
                        foregroundColor: AppColors.onWarning,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: AppTypography.button.copyWith(fontSize: 14),
                      ),
                    ),
                  )
                else if (esCancelada)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirAgendarCita(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Nueva cita'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildStatusChip(String estado) {
    Color bg;
    Color fg;
    String label;

    switch (estado.toUpperCase()) {
      case 'CONFIRMADA':
        bg = AppColors.successContainer;
        fg = AppColors.onSuccessContainer;
        label = 'Confirmada';
        break;
      case 'PENDIENTE':
        bg = AppColors.warningContainer;
        fg = AppColors.onWarning;
        label = 'Pago pendiente';
        break;
      case 'COMPLETADA':
      case 'FINALIZADA':
        bg = const Color(0xFFE2E8F0);
        fg = AppColors.textPrimary;
        label = 'Completada';
        break;
      case 'CANCELADA':
      case 'ANULADA':
        bg = AppColors.errorContainer;
        fg = AppColors.onErrorContainer;
        label = 'Cancelada';
        break;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        label = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
