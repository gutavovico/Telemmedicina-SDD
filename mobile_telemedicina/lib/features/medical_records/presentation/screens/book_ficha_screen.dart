import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../appointments/domain/entities/doctor_entity.dart';
import '../../../appointments/domain/entities/specialty_entity.dart';
import '../../../appointments/presentation/controllers/doctor_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../providers/ficha_provider.dart';

class BookFichaScreen extends StatefulWidget {
  const BookFichaScreen({super.key});

  @override
  State<BookFichaScreen> createState() => _BookFichaScreenState();
}

class _BookFichaScreenState extends State<BookFichaScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedSpecialtyId;
  int? _selectedDoctorId;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;

  final TextEditingController _motivoCtrl = TextEditingController();
  final TextEditingController _tempCtrl = TextEditingController();
  final TextEditingController _paCtrl = TextEditingController();
  final TextEditingController _pesoCtrl = TextEditingController();

  final List<Map<String, String>> _availableSlots = [
    {'inicio': '08:00', 'fin': '08:30'},
    {'inicio': '08:30', 'fin': '09:00'},
    {'inicio': '09:00', 'fin': '09:30'},
    {'inicio': '09:30', 'fin': '10:00'},
    {'inicio': '10:00', 'fin': '10:30'},
    {'inicio': '10:30', 'fin': '11:00'},
    {'inicio': '14:00', 'fin': '14:30'},
    {'inicio': '14:30', 'fin': '15:00'},
    {'inicio': '15:00', 'fin': '15:30'},
    {'inicio': '15:30', 'fin': '16:00'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorController>().loadCatalog();
    });
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _tempCtrl.dispose();
    _paCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un médico especialista.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un horario para tu atención.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final authCtrl = context.read<AuthController>();
    final fichaProvider = context.read<FichaProvider>();

    final slotParts = _selectedSlot!.split(' - ');
    final horaInicio = slotParts[0];
    final horaFin = slotParts[1];

    final dateStr = '${_selectedDate.year.toString().padLeft(4, '0')}-'
        '${_selectedDate.month.toString().padLeft(2, '0')}-'
        '${_selectedDate.day.toString().padLeft(2, '0')}';

    final signosVitales = <String, dynamic>{};
    if (_tempCtrl.text.isNotEmpty) {
      signosVitales['temperatura'] = double.tryParse(_tempCtrl.text) ?? _tempCtrl.text;
    }
    if (_paCtrl.text.isNotEmpty) {
      signosVitales['presion_arterial'] = _paCtrl.text.trim();
    }
    if (_pesoCtrl.text.isNotEmpty) {
      signosVitales['peso'] = double.tryParse(_pesoCtrl.text) ?? _pesoCtrl.text;
    }

    final payload = <String, dynamic>{
      'id_paciente': authCtrl.currentUser?.idUsuario ?? 1,
      'id_medico': _selectedDoctorId,
      if (_selectedSpecialtyId != null) 'id_especialidad': _selectedSpecialtyId,
      'fecha_atencion': dateStr,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'motivo_consulta': _motivoCtrl.text.trim(),
      'signos_vitales': signosVitales,
      'secciones_dinamicas': {},
    };

    final result = await fichaProvider.createFicha(payload);

    if (result != null && mounted) {
      // Show success modal with Correlativo
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Ficha Médica Emitida!',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu turno ha sido confirmado atómicamente.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Identificador Correlativo',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.correlativo,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Ver Mis Fichas', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorCtrl = context.watch<DoctorController>();
    final fichaProvider = context.watch<FichaProvider>();

    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emisión de Ficha Médica',
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Reserva atómica de turno clínico',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryContainer,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conflict 409 Warning Banner
              if (fichaProvider.isConflict) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.onWarning, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¡Turno No Disponible (409 Conflict)!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onWarning,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fichaProvider.errorMessage ??
                                  'El médico ya tiene un turno reservado en este horario. Por favor selecciona otro intervalo horario disponible.',
                              style: const TextStyle(color: AppColors.onWarning, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section: Specialty Selection
              Text(
                '1. Especialidad Médica',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedSpecialtyId,
                    hint: const Text('Selecciona una especialidad', style: TextStyle(fontSize: 13)),
                    items: doctorCtrl.specialties.map((SpecialtyEntity sp) {
                      return DropdownMenuItem<int>(
                        value: sp.idEspecialidad,
                        child: Text(sp.nombre, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSpecialtyId = val;
                        _selectedDoctorId = null;
                      });
                      doctorCtrl.selectSpecialty(val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section: Doctor Selection
              Text(
                '2. Médico Asignado',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedDoctorId,
                    hint: const Text('Selecciona un médico', style: TextStyle(fontSize: 13)),
                    items: doctorCtrl.doctors.map((DoctorEntity doc) {
                      return DropdownMenuItem<int>(
                        value: doc.idMedico,
                        child: Text(
                          '${doc.nombres} ${doc.apellidos} (${doc.especialidadPrincipal?.nombre ?? "General"})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDoctorId = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section: Date Picker
              Text(
                '3. Fecha de Atención',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(dateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section: Time Slot
              Text(
                '4. Horario Disponible (Turno)',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSlots.map((slot) {
                  final slotLabel = '${slot["inicio"]} - ${slot["fin"]}';
                  final isSelected = _selectedSlot == slotLabel;
                  return ChoiceChip(
                    label: Text(
                      slotLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.outline,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedSlot = slotLabel;
                      });
                      if (fichaProvider.isConflict) {
                        fichaProvider.clearMessages();
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Section: Motivo de Consulta
              Text(
                '5. Motivo de la Consulta',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _motivoCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe el síntoma principal o razón de la solicitud...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'El motivo debe contener al menos 5 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Section: Optional Preliminary Vitals
              Text(
                '6. Signos Vitales Preliminares (Opcional)',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tempCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Temp (°C)',
                        hintText: '36.5',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _paCtrl,
                      decoration: InputDecoration(
                        labelText: 'P.A. (mmHg)',
                        hintText: '120/80',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Peso (kg)',
                        hintText: '70.0',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: fichaProvider.isLoading ? null : _handleSubmit,
                  child: fichaProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Emitir Ficha Atómica',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
