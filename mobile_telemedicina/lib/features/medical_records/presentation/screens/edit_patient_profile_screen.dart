import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';

class EditPatientProfileScreen extends StatefulWidget {
  final PatientEntity patient;

  const EditPatientProfileScreen({super.key, required this.patient});

  @override
  State<EditPatientProfileScreen> createState() => _EditPatientProfileScreenState();
}

class _EditPatientProfileScreenState extends State<EditPatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _telefonoController;
  late TextEditingController _correoController;
  late TextEditingController _direccionController;
  late TextEditingController _ciudadController;
  late TextEditingController _emergenciaNombreController;
  late TextEditingController _emergenciaTelefonoController;
  late TextEditingController _emergenciaParentescoController;

  @override
  void initState() {
    super.initState();
    _telefonoController = TextEditingController(text: widget.patient.telefono);
    _correoController = TextEditingController(text: widget.patient.correo ?? '');
    _direccionController = TextEditingController(text: widget.patient.direccion ?? '');
    _ciudadController = TextEditingController(text: widget.patient.ciudad ?? 'Santa Cruz de la Sierra');
    _emergenciaNombreController = TextEditingController(text: widget.patient.contactoEmergenciaNombre ?? '');
    _emergenciaTelefonoController = TextEditingController(text: widget.patient.contactoEmergenciaTelefono ?? '');
    _emergenciaParentescoController = TextEditingController(text: widget.patient.contactoEmergenciaParentesco ?? '');
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _correoController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _emergenciaNombreController.dispose();
    _emergenciaTelefonoController.dispose();
    _emergenciaParentescoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<PatientProvider>();
    final success = await provider.updatePatientProfile(
      telefono: _telefonoController.text,
      correo: _correoController.text,
      direccion: _direccionController.text,
      ciudad: _ciudadController.text,
      contactoEmergenciaNombre: _emergenciaNombreController.text,
      contactoEmergenciaTelefono: _emergenciaTelefonoController.text,
      contactoEmergenciaParentesco: _emergenciaParentescoController.text,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos actualizados correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      } else if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<PatientProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Actualizar Contacto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contact Section
              _buildCard(
                title: 'Información de Contacto',
                icon: Icons.phone_android_outlined,
                children: [
                  TextFormField(
                    controller: _telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono / Celular *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El teléfono es obligatorio';
                      }
                      if (val.trim().length < 6) {
                        return 'Ingrese un número válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _correoController,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccionController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección de Domicilio',
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ciudadController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Emergency Contact Section
              _buildCard(
                title: 'Contacto de Emergencia / Tutor',
                icon: Icons.emergency_outlined,
                children: [
                  TextFormField(
                    controller: _emergenciaNombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Contacto',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergenciaTelefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de Emergencia',
                      prefixIcon: Icon(Icons.phone_in_talk_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergenciaParentescoController,
                    decoration: const InputDecoration(
                      labelText: 'Parentesco (Ej: Madre, Padre)',
                      prefixIcon: Icon(Icons.family_restroom_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Guardar Cambios',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
