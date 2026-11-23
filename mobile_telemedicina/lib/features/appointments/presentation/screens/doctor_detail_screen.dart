import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/doctor_entity.dart';

class DoctorDetailScreen extends StatelessWidget {
  final DoctorEntity doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perfil Médico'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Doctor Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      doctor.nombres.isNotEmpty
                          ? doctor.nombres.substring(0, 1).toUpperCase()
                          : 'D',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dr. ${doctor.nombreCompleto}',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: doctor.especialidades.map((esp) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: esp.esPrincipal
                              ? AppColors.primaryContainer
                              : AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          esp.nombre + (esp.esPrincipal ? ' (Principal)' : ''),
                          style: TextStyle(
                            color: esp.esPrincipal
                                ? AppColors.primaryDark
                                : AppColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat(
                        icon: Icons.badge_outlined,
                        label: 'Matrícula',
                        value: doctor.matriculaProfesional,
                      ),
                      _buildHeaderStat(
                        icon: Icons.work_outline,
                        label: 'Experiencia',
                        value: doctor.aniosExperiencia != null
                            ? '${doctor.aniosExperiencia} años'
                            : 'N/A',
                      ),
                      _buildHeaderStat(
                        icon: Icons.check_circle_outline,
                        label: 'Estado',
                        value: doctor.estado.toUpperCase(),
                        valueColor: doctor.estado.toLowerCase() == 'activo'
                            ? AppColors.secondary
                            : AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bio / Description Card
            if (doctor.descripcionProfesional != null &&
                doctor.descripcionProfesional!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acerca del Especialista',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      doctor.descripcionProfesional!,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Contact Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de Contacto',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                    title: const Text('Correo Electrónico', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    subtitle: Text(doctor.correo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (doctor.telefono != null && doctor.telefono!.isNotEmpty) ...[
                    const Divider(color: AppColors.divider),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                      title: const Text('Teléfono', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      subtitle: Text(doctor.telefono!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Agendamiento con Dr. ${doctor.nombreCompleto} próximamente en Sprint 1'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Agendar Cita Médica'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
