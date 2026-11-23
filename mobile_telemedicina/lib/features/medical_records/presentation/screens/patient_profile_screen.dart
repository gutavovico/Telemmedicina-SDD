import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/patient_provider.dart';
import 'edit_patient_profile_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().fetchPatientProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mi Perfil Clínico',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'Editar Datos de Contacto',
            onPressed: () {
              final current = context.read<PatientProvider>().currentPatient;
              if (current != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditPatientProfileScreen(patient: current),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<PatientProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentPatient == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (provider.errorMessage != null && provider.currentPatient == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchPatientProfile(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final patient = provider.currentPatient;
          if (patient == null) {
            return const Center(child: Text('No hay información disponible.'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchPatientProfile(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  _buildHeaderCard(patient),
                  const SizedBox(height: 16),

                  // Grupo Sanguíneo & Datos Rápidos
                  _buildBloodGroupBadge(patient),
                  const SizedBox(height: 16),

                  // Información de Contacto
                  _buildSectionCard(
                    title: 'Contacto y Ubicación',
                    icon: Icons.person_pin_outlined,
                    children: [
                      _buildInfoRow(Icons.phone_outlined, 'Teléfono', patient.telefono),
                      _buildInfoRow(Icons.email_outlined, 'Correo', patient.correo ?? 'No registrado'),
                      _buildInfoRow(Icons.location_on_outlined, 'Dirección', patient.direccion ?? 'No registrada'),
                      _buildInfoRow(Icons.location_city_outlined, 'Ciudad', patient.ciudad ?? 'Santa Cruz de la Sierra'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Información Clínica Base
                  _buildSectionCard(
                    title: 'Historial Clínico Base',
                    icon: Icons.medical_services_outlined,
                    children: [
                      _buildInfoRow(
                        Icons.warning_amber_rounded,
                        'Alergias Conocidas',
                        patient.alergias ?? 'Ninguna alergia registrada',
                        highlightColor: patient.alergias != null && patient.alergias!.isNotEmpty
                            ? AppColors.error
                            : null,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        Icons.history_edu_outlined,
                        'Antecedentes Patológicos',
                        patient.antecedentesPatologicos ?? 'Sin antecedentes relevantes',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contacto de Emergencia
                  _buildSectionCard(
                    title: 'Contacto de Emergencia',
                    icon: Icons.emergency_outlined,
                    children: [
                      _buildInfoRow(
                        Icons.account_box_outlined,
                        'Nombre de Contacto',
                        patient.contactoEmergenciaNombre ?? 'No registrado',
                      ),
                      _buildInfoRow(
                        Icons.phone_in_talk_outlined,
                        'Teléfono de Emergencia',
                        patient.contactoEmergenciaTelefono ?? 'No registrado',
                      ),
                      _buildInfoRow(
                        Icons.family_restroom_outlined,
                        'Parentesco',
                        patient.contactoEmergenciaParentesco ?? 'No especificado',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Seguro de Salud
                  _buildSectionCard(
                    title: 'Seguro Médico / Cobertura',
                    icon: Icons.health_and_safety_outlined,
                    children: [
                      _buildInfoRow(
                        Icons.local_hospital_outlined,
                        'Aseguradora / Convenio',
                        patient.seguroMedico ?? 'Particular / Sin seguro',
                      ),
                      _buildInfoRow(
                        Icons.credit_card_outlined,
                        'Nº Póliza / Matrícula',
                        patient.numeroSeguro ?? 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(dynamic patient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primary,
            child: Text(
              '${patient.nombres.isNotEmpty ? patient.nombres[0] : ""}${patient.apellidos.isNotEmpty ? patient.apellidos[0] : ""}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'C.I.: ${patient.ci}${patient.complemento != null && patient.complemento!.isNotEmpty ? " (${patient.complemento})" : ""}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${patient.age} años',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: patient.estado == 'ACTIVO'
                            ? AppColors.successContainer
                            : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        patient.estado,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: patient.estado == 'ACTIVO'
                              ? AppColors.onSuccessContainer
                              : AppColors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupBadge(dynamic patient) {
    if (patient.tipoSangre == null || patient.tipoSangre.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Text('🩸', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Grupo Sanguíneo y Factor Rh',
                style: TextStyle(fontSize: 11, color: Color(0xFF9F1239), fontWeight: FontWeight.w600),
              ),
              Text(
                patient.tipoSangre!,
                style: const TextStyle(fontSize: 16, color: Color(0xFF881337), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: highlightColor ?? AppColors.textPrimary,
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
