import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/treatment_entities.dart';
import 'treatment_status_badge.dart';

/// Diálogo modal para registrar o corregir la toma de una dosis médica (CU17).
///
/// Opciones de registro:
/// - `INGERIDA`: requiere hora efectiva (por defecto ahora). Valida que no sea futura.
/// - `OMITIDA`: valida que la hora programada ya haya sido alcanzada.
/// - `POSPUESTA`: requiere o sugiere motivo/síntoma.
/// - Nota clínica: campo de texto opcional hasta 1000 caracteres.
///
/// Si la dosis ya fue registrada previamente (`INGERIDA`, `OMITIDA`, `POSPUESTA`),
/// muestra explícitamente el banner de **CORRECCIÓN DE TOMA**, indicando que se
/// procesará con una nueva clave de idempotencia conservando el historial.
class DoseActionDialog extends StatefulWidget {
  final Dosis dosis;
  final String? medicamentoNombre;
  final bool isCorrection;
  final Future<void> Function({
    required String estado,
    DateTime? efectivaEn,
    String? nota,
    required bool isCorrection,
  }) onConfirm;

  const DoseActionDialog({
    super.key,
    required this.dosis,
    this.medicamentoNombre,
    this.isCorrection = false,
    required this.onConfirm,
  });

  /// Muestra el diálogo modal centrado o bottom-sheet.
  static Future<void> show(
    BuildContext context, {
    required Dosis dosis,
    String? medicamentoNombre,
    bool isCorrection = false,
    required Future<void> Function({
      required String estado,
      DateTime? efectivaEn,
      String? nota,
      required bool isCorrection,
    }) onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: DoseActionDialog(
          dosis: dosis,
          medicamentoNombre: medicamentoNombre,
          isCorrection: isCorrection,
          onConfirm: onConfirm,
        ),
      ),
    );
  }

  @override
  State<DoseActionDialog> createState() => _DoseActionDialogState();
}

class _DoseActionDialogState extends State<DoseActionDialog> {
  late String _selectedEstado;
  late DateTime _efectivaEn;
  late TextEditingController _notaController;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isActualCorrection =>
      widget.isCorrection || !widget.dosis.esPendiente;

  @override
  void initState() {
    super.initState();
    _selectedEstado = widget.dosis.esPendiente ? 'INGERIDA' : widget.dosis.estado;
    if (_selectedEstado != 'INGERIDA' &&
        _selectedEstado != 'OMITIDA' &&
        _selectedEstado != 'POSPUESTA') {
      _selectedEstado = 'INGERIDA';
    }
    _efectivaEn = DateTime.now();
    _notaController = TextEditingController(text: widget.dosis.nota ?? '');
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  /// Valida las reglas de negocio CU17 antes del envío:
  /// - `INGERIDA`: la hora efectiva no puede ser futura.
  /// - `OMITIDA`: la hora programada ya debió haber ocurrido.
  /// - `nota`: no puede superar 1000 caracteres.
  bool _validate() {
    setState(() => _errorMessage = null);

    if (_notaController.text.length > 1000) {
      setState(() => _errorMessage = 'La nota no puede superar 1000 caracteres.');
      return false;
    }

    if (_selectedEstado == 'INGERIDA') {
      final now = DateTime.now().add(const Duration(minutes: 2));
      if (_efectivaEn.isAfter(now)) {
        setState(() => _errorMessage = 'La hora efectiva de ingesta no puede ser futura.');
        return false;
      }
    } else if (_selectedEstado == 'OMITIDA') {
      try {
        final programadaUtc = DateTime.parse(widget.dosis.programadaEn).toUtc();
        final nowUtc = DateTime.now().toUtc();
        if (nowUtc.isBefore(programadaUtc)) {
          setState(() {
            _errorMessage =
                'No se puede omitir una toma futura. La hora programada (${widget.dosis.programadaHoraLocal}) aún no ha sido alcanzada.';
          });
          return false;
        }
      } catch (_) {
        // Si no se puede parsear, no bloqueamos la validación local
      }
    }

    return true;
  }

  Future<void> _handleConfirm() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final nota = _notaController.text.trim();
      await widget.onConfirm(
        estado: _selectedEstado,
        efectivaEn: _selectedEstado == 'INGERIDA' ? _efectivaEn : null,
        nota: nota.isEmpty ? null : nota,
        isCorrection: _isActualCorrection,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _efectivaEn,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_efectivaEn),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      setState(() {
        _errorMessage = 'La fecha y hora efectiva no puede ser futura.';
      });
      return;
    }

    setState(() {
      _efectivaEn = combined;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header con título y hora programada
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isActualCorrection ? 'Corregir Toma' : 'Registrar Toma',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.medicamentoNombre != null)
                        Text(
                          widget.medicamentoNombre!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.dosis.programadaHoraLocal,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Hora programada',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Banner explicativo si es CORRECCIÓN
            if (_isActualCorrection) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.history_edu_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'CORRECCIÓN DE TOMA',
                                style: TextStyle(
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              DoseStatusBadge(
                                status: widget.dosis.estado,
                                isVencida: widget.dosis.vencida,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Esta dosis ya fue registrada previamente. La corrección se registrará con una nueva clave y preservará el historial clínico previo en orden cronológico.',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Selector de estado
            Text(
              'Seleccione el estado de la toma:',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildEstadoOption(
                  estado: 'INGERIDA',
                  label: 'Ingerida',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                _buildEstadoOption(
                  estado: 'OMITIDA',
                  label: 'Omitida',
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                _buildEstadoOption(
                  estado: 'POSPUESTA',
                  label: 'Pospuesta',
                  icon: Icons.update_rounded,
                  color: const Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selector de fecha y hora efectiva (Solo para INGERIDA)
            if (_selectedEstado == 'INGERIDA') ...[
              Text(
                'Fecha y hora efectiva de ingesta:',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _isLoading ? null : _selectDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatDateTime(_efectivaEn),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Por defecto: hora actual en tu zona horaria local.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Indicación específica para OMITIDA o POSPUESTA
            if (_selectedEstado == 'OMITIDA') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Una dosis omitida sigue computando en el denominador de adherencia acumulada.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedEstado == 'POSPUESTA') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.update_rounded, color: Color(0xFFB45309), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pospuesta: no modifica la prescripción ni crea otra toma; por favor indica el motivo o síntoma.',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Campo de nota clínica
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedEstado == 'POSPUESTA'
                        ? 'Motivo o síntoma (Recomendado):'
                        : 'Nota o síntomas observados (Opcional):',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _notaController,
                  builder: (context, value, _) {
                    final len = value.text.length;
                    return Text(
                      '$len / 1000',
                      style: TextStyle(
                        fontSize: 11,
                        color: len > 1000 ? AppColors.error : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notaController,
              maxLines: 3,
              maxLength: 1000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: _selectedEstado == 'POSPUESTA'
                    ? 'Ej: Se pospone por náuseas leves tras el almuerzo...'
                    : 'Ej: Tomado con agua abundante, sin efectos adversos...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            // Mensaje de error
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.outline),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isActualCorrection
                          ? const Color(0xFF1D4ED8)
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isActualCorrection
                                ? 'Confirmar Corrección'
                                : 'Confirmar Registro',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoOption({
    required String estado,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedEstado == estado;
    return Expanded(
      child: InkWell(
        onTap: _isLoading
            ? null
            : () {
                setState(() {
                  _selectedEstado = estado;
                  _errorMessage = null;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }
}
