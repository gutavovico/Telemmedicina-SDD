import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/appointment_model.dart';
import '../providers/appointment_provider.dart';

class BookAppointmentSheet extends StatefulWidget {
  final AppointmentModel? appointmentToEdit;

  const BookAppointmentSheet({super.key, this.appointmentToEdit});

  @override
  State<BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<BookAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _motivoController;
  late TextEditingController _nombresController;
  late TextEditingController _apellidosController;
  late TextEditingController _ciController;
  late TextEditingController _telefonoController;

  late String _selectedDate;
  late String _selectedTime;
  String _selectedPatient = '1';
  String _selectedDoctor = '1';
  String _selectedStatus = 'CONFIRMADA';
  String _birthDate = '';
  String _gender = 'M';
  bool _isNewPatient = false;

  final List<String> _availableSlots = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.appointmentToEdit;
    _motivoController = TextEditingController(
      text: edit?.motivo ?? 'Consulta Médica',
    );
    _nombresController = TextEditingController();
    _apellidosController = TextEditingController();
    _ciController = TextEditingController();
    _telefonoController = TextEditingController();
    _selectedDate =
        edit?.fechaCita ?? DateTime.now().toIso8601String().split('T')[0];
    _selectedTime = edit?.horaInicio ?? '09:30';
    _selectedPatient = edit?.idPaciente.toString() ?? '1';
    _selectedDoctor = edit?.idMedico.toString() ?? '1';
    _selectedStatus = edit?.estado ?? 'CONFIRMADA';
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _ciController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked.toIso8601String().split('T')[0]);
    }
  }

  InputDecoration _patientDecoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _patientField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _patientDecoration(label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Requerido' : null,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppointmentProvider>();
    final isEditing = widget.appointmentToEdit != null;

    var patientId = int.tryParse(_selectedPatient) ?? 1;

    if (_isNewPatient) {
      if (_birthDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona la fecha de nacimiento.')),
        );
        return;
      }
      try {
        final patient = await provider.createPatient({
          'nombres': _nombresController.text.trim(),
          'apellidos': _apellidosController.text.trim(),
          'ci': _ciController.text.trim(),
          'fecha_nacimiento': _birthDate,
          'genero': _gender,
          'telefono': _telefonoController.text.trim(),
        });
        patientId = int.parse(patient['id_paciente'].toString());
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return;
      }
    }

    final data = {
      'id_paciente': patientId,
      'id_medico': int.tryParse(_selectedDoctor) ?? 1,
      'fecha_cita': _selectedDate,
      'hora_inicio': _selectedTime,
      'motivo': _motivoController.text.trim(),
      'estado': _selectedStatus,
      'tipo_consulta': 'TELEMEDICINA',
    };

    bool success = false;
    try {
      if (isEditing) {
        success = await provider.updateAppointment(
          widget.appointmentToEdit!.idCita,
          data,
        );
      } else {
        success = await provider.createAppointment(data);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted && success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isEditing
                    ? '¡Cita actualizada exitosamente!'
                    : '¡Cita agendada exitosamente!',
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.appointmentToEdit != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF001738),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Editar Consulta' : 'Agendar Consulta',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isEditing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Editando #${widget.appointmentToEdit!.idCita}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEditing
                          ? 'Modifique los datos seleccionados en tiempo real.'
                          : 'Complete los datos para agendar su cita médica.',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Paciente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _isNewPatient = !_isNewPatient),
                    icon: Icon(
                      _isNewPatient ? Icons.group : Icons.person_add,
                      size: 18,
                    ),
                    label: Text(
                      _isNewPatient ? 'Elegir registrado' : 'Nuevo paciente',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_isNewPatient)
                DropdownButtonFormField<String>(
                  initialValue: _selectedPatient,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '1',
                      child: Text('Maria Rodriguez (ID: 982-11-2)'),
                    ),
                    DropdownMenuItem(
                      value: '2',
                      child: Text('Juan Gómez (ID: 451-88-9)'),
                    ),
                    DropdownMenuItem(
                      value: '3',
                      child: Text('Carlos Méndez (ID: 672-33-4)'),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedPatient = val ?? '1'),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0DBFF)),
                  ),
                  child: Column(
                    children: [
                      _patientField(_nombresController, 'Nombres'),
                      const SizedBox(height: 10),
                      _patientField(_apellidosController, 'Apellidos'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _patientField(_ciController, 'C.I.')),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: _patientDecoration('Género'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'M',
                                  child: Text('Masculino'),
                                ),
                                DropdownMenuItem(
                                  value: 'F',
                                  child: Text('Femenino'),
                                ),
                                DropdownMenuItem(
                                  value: 'OTRO',
                                  child: Text('Otro'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _gender = value ?? 'M'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _patientField(
                        _telefonoController,
                        'Teléfono',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _pickBirthDate,
                        child: InputDecorator(
                          decoration: _patientDecoration('Fecha de nacimiento'),
                          child: Text(
                            _birthDate.isEmpty
                                ? 'Seleccionar fecha'
                                : _birthDate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Especialista
              const Text(
                'Especialista / Doctor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedDoctor,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                items: const [
                  DropdownMenuItem(
                    value: '1',
                    child: Text('Dr. Carlos Mendoza - Cardiología'),
                  ),
                  DropdownMenuItem(
                    value: '2',
                    child: Text('Dra. Ana Silva - Medicina General'),
                  ),
                  DropdownMenuItem(
                    value: '3',
                    child: Text('Dr. Roberto Paz - Pediatría'),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _selectedDoctor = val ?? '1'),
              ),
              const SizedBox(height: 14),

              // Fecha
              const Text(
                'Fecha de Consulta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Horarios Disponibles (Chips)
              const Text(
                'Horarios Disponibles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSlots.map((slot) {
                  final isSelected = _selectedTime == slot;
                  return InkWell(
                    onTap: () => setState(() => _selectedTime = slot),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF001738)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF001738)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        slot,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Motivo
              const Text(
                'Motivo de Consulta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _motivoController,
                decoration: InputDecoration(
                  hintText: 'Ej: Control anual, Dolor de cabeza...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingrese un motivo' : null,
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001738),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Guardar Cambios' : 'Confirmar Cita',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
