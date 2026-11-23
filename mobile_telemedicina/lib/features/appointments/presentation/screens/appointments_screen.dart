import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/appointment_model.dart';
import '../providers/appointment_provider.dart';
import 'book_appointment_sheet.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchAppointments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBookSheet([AppointmentModel? editAppointment]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookAppointmentSheet(appointmentToEdit: editAppointment),
    );
  }

  void _confirmDelete(AppointmentModel cita) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('¿Eliminar cita?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la cita de ${cita.pacienteNombre} para el ${cita.fechaCita} a las ${cita.horaInicio}?',
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<AppointmentProvider>().deleteAppointment(cita.idCita);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cita eliminada exitosamente'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado.toUpperCase()) {
      case 'CONFIRMADA':
        return const Color(0xFF059669);
      case 'PENDIENTE':
        return const Color(0xFFD97706);
      case 'COMPLETADA':
        return const Color(0xFF2563EB);
      case 'CANCELADA':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getStatusBg(String estado) {
    switch (estado.toUpperCase()) {
      case 'CONFIRMADA':
        return const Color(0xFFECFDF5);
      case 'PENDIENTE':
        return const Color(0xFFFFFBEB);
      case 'COMPLETADA':
        return const Color(0xFFEFF6FF);
      case 'CANCELADA':
        return const Color(0xFFFEF2F2);
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();
    final items = provider.filteredAppointments;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001738),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Consultas',
              style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              'San Juan de Dios Telemedicina',
              style: AppTypography.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => provider.fetchAppointments(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBookSheet(),
        backgroundColor: const Color(0xFF001738),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Agendar Consulta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAppointments(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => provider.search(val),
                  decoration: InputDecoration(
                    hintText: 'Buscar paciente o médico...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.search('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Todas',
                      isSelected: provider.statusFilter == 'TODOS' && provider.dateFilter == null,
                      onTap: () => provider.clearFilters(),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Hoy',
                      isSelected: provider.dateFilter != null,
                      icon: Icons.calendar_today_rounded,
                      onTap: () => provider.toggleFilterByToday(),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Confirmadas',
                      isSelected: provider.statusFilter == 'CONFIRMADA',
                      onTap: () => provider.filterByStatus('CONFIRMADA'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Pendientes',
                      isSelected: provider.statusFilter == 'PENDIENTE',
                      onTap: () => provider.filterByStatus('PENDIENTE'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Total info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Consultas Registradas (${items.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                  ),
                  if (provider.isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // List of Appointments
              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        'No se encontraron consultas',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Intenta ajustar los filtros de búsqueda.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cita = items[index];
                    final statusColor = _getStatusColor(cita.estado);
                    final statusBg = _getStatusBg(cita.estado);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Patient & Actions
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFE0E7FF),
                                child: Text(
                                  cita.pacienteIniciales,
                                  style: const TextStyle(
                                    color: Color(0xFF4338CA),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cita.pacienteNombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      cita.pacienteCi,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cita.estado,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _openBookSheet(cita);
                                  } else if (val == 'delete') {
                                    _confirmDelete(cita);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Eliminar'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // Details grid
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('FECHA & HORA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${cita.fechaCita} - ${cita.horaInicio}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ESPECIALIDAD / MÉDICO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${cita.especialidadNombre} (${cita.medicoNombre})',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF001738) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF001738) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

