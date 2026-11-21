import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/treatment_entities.dart';
import '../providers/treatment_provider.dart';
import '../widgets/dose_action_dialog.dart';
import '../widgets/treatment_status_badge.dart';

/// Pantalla del Cronograma diario de tomas (CU17).
class CronogramaScreen extends StatefulWidget {
  final int? idTratamiento;

  const CronogramaScreen({super.key, this.idTratamiento});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  int? _resolvedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _resolvedId = args;
      } else if (widget.idTratamiento != null) {
        _resolvedId = widget.idTratamiento;
      }

      if (_resolvedId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final provider = context.read<TreatmentProvider>();
          provider.loadCronograma(_resolvedId!);
          if (provider.selectedTreatment == null ||
              provider.selectedTreatment!.idTratamiento != _resolvedId) {
            provider.loadTreatmentDetail(_resolvedId!);
          }
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_resolvedId != null) {
      final provider = context.read<TreatmentProvider>();
      await provider.loadCronograma(_resolvedId!, provider.selectedDate);
    }
  }

  void _changeDate(DateTime newDate) {
    context.read<TreatmentProvider>().changeCronogramaDate(newDate);
  }

  Future<void> _pickDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(currentDate.year - 2),
      lastDate: DateTime(currentDate.year + 2),
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

    if (picked != null && mounted) {
      _changeDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreatmentProvider>();
    final selectedDate = provider.selectedDate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cronograma de Tomas'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar tomas',
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de navegación de fecha
          _buildDateSelector(selectedDate),

          // Indicador de zona horaria del plan
          if (provider.cronograma != null)
            _buildTimezoneBar(provider.cronograma!.zonaHoraria),

          // Cuerpo de la lista de dosis
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _onRefresh,
              child: _buildBody(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(DateTime selectedDate) {
    final isToday = _isSameDay(selectedDate, DateTime.now());

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Día anterior
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primary,
            tooltip: 'Día anterior',
            onPressed: () => _changeDate(
              selectedDate.subtract(const Duration(days: 1)),
            ),
          ),

          // Botón Hoy
          TextButton(
            onPressed: isToday ? null : () => _changeDate(DateTime.now()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: AppColors.primary,
            ),
            child: Text(
              'Hoy',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? AppColors.textMuted : AppColors.primary,
              ),
            ),
          ),

          // Fecha actual formateada
          Expanded(
            child: Center(
              child: Text(
                _formatDateWithDay(selectedDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Día siguiente
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primary,
            tooltip: 'Día siguiente',
            onPressed: () => _changeDate(
              selectedDate.add(const Duration(days: 1)),
            ),
          ),

          // Selector de calendario
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            color: AppColors.primary,
            tooltip: 'Seleccionar fecha',
            onPressed: () => _pickDate(selectedDate),
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneBar(String zonaHoraria) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Horarios sincronizados con la zona horaria del plan: $zonaHoraria',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(TreatmentProvider provider) {
    switch (provider.cronogramaStatus) {
      case CronogramaStatus.initial:
      case CronogramaStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case CronogramaStatus.error:
        return _buildErrorState(provider);
      case CronogramaStatus.loaded:
        final dia = provider.cronograma;
        if (dia == null || dia.dosis.isEmpty) {
          return _buildEmptyState();
        }
        return _buildDosisList(provider, dia);
    }
  }

  Widget _buildErrorState(TreatmentProvider provider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar el cronograma',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                provider.cronogramaError ?? 'Error al obtener tomas',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No hay tomas programadas',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'No existen medicamentos programados para esta fecha en este tratamiento.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDosisList(TreatmentProvider provider, CronogramaDia dia) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: dia.dosis.length,
      itemBuilder: (context, index) {
        final dosis = dia.dosis[index];
        final isLocked = provider.isDoseLocked(dosis.idDosis);
        final med = _findMedicamento(provider, dosis.idMedicamentoPlan);

        return _buildDosisCard(
          provider: provider,
          dosis: dosis,
          medicamento: med,
          isLocked: isLocked,
        );
      },
    );
  }

  Widget _buildDosisCard({
    required TreatmentProvider provider,
    required Dosis dosis,
    MedicamentoPlan? medicamento,
    required bool isLocked,
  }) {
    final medName = medicamento?.medicamentoNombre ?? 'Medicamento del Plan';
    final hasPendingOp = provider.hasPendingOperationForDose(dosis.idDosis);
    final isDoseEffectivelyLocked = isLocked || hasPendingOp;
    final pendingMarker = provider.getPendingMarkerForDose(dosis.idDosis);
    final hasBody = provider.hasPendingBodyForDose(dosis.idDosis);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDoseEffectivelyLocked ? AppColors.warning : AppColors.divider,
          width: isDoseEffectivelyLocked ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador visual de estado incierto / operación en curso
            if (isDoseEffectivelyLocked) ...[
              Container(
                key: ValueKey('lock_banner_${dosis.idDosis}'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.onWarning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.onWarning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasBody
                            ? 'Operación en curso / resultado incierto. Puedes reintentar la confirmación con los datos de esta sesión.'
                            : 'Operación en curso / resultado incierto. La sesión se cerró antes de confirmar; debes resolver la operación abandonada.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onWarning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Encabezado: Nombre del medicamento y Hora Local
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (medicamento != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${medicamento.dosis} · Vía: ${medicamento.viaAdministracion}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dosis.programadaHoraLocal,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Badges de estado y puntualidad
            Row(
              children: [
                DoseStatusBadge(
                  status: dosis.estado,
                  isVencida: dosis.vencida,
                ),
                if (dosis.esIngerida && dosis.puntual != null) ...[
                  const SizedBox(width: 8),
                  DosePuntualidadBadge(puntual: dosis.puntual!),
                ],
              ],
            ),

            // Información de ingesta efectiva
            if (dosis.efectivaEn != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_filled_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hora efectiva: ${_formatHour(dosis.efectivaEn!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            // Información de registro en servidor
            if (dosis.registradaEn != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Registrada: ${_formatHour(dosis.registradaEn!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            // Nota clínica si existe
            if (dosis.nota != null && dosis.nota!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nota: ${dosis.nota}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Botones de acción: Recuperación si bloqueada, o Registrar/Corregir
            if (isDoseEffectivelyLocked) ...[
              if (hasBody && pendingMarker != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: ValueKey('retry_btn_${dosis.idDosis}'),
                    onPressed: () => _retryRegistration(
                      dosis.idDosis,
                      pendingMarker.idempotencyKey,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar registro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: ValueKey('resolve_abandoned_btn_${dosis.idDosis}'),
                    onPressed: pendingMarker != null
                        ? () => _resolveAbandoned(
                              dosis.idDosis,
                              pendingMarker.idempotencyKey,
                            )
                        : null,
                    icon: const Icon(Icons.healing_rounded, size: 18),
                    label: const Text('Resolver operación abandonada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: dosis.esPendiente
                    ? ElevatedButton.icon(
                        key: ValueKey('btn_registrar_${dosis.idDosis}'),
                        onPressed: () => _openActionDialog(
                          dosis: dosis,
                          medicamentoNombre: medName,
                          isCorrection: false,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Registrar Toma'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : OutlinedButton.icon(
                        key: ValueKey('btn_corregir_${dosis.idDosis}'),
                        onPressed: () => _openActionDialog(
                          dosis: dosis,
                          medicamentoNombre: medName,
                          isCorrection: true,
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Corregir Toma'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _retryRegistration(int idDosis, String idempotencyKey) async {
    try {
      final res = await context
          .read<TreatmentProvider>()
          .retryDoseWithPendingBody(
            idDosis: idDosis,
            idempotencyKey: idempotencyKey,
          );
      if (mounted && res != null && res.isConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación confirmada exitosamente.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al reintentar: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resolveAbandoned(int idDosis, String idempotencyKey) async {
    try {
      final res = await context
          .read<TreatmentProvider>()
          .resolveAbandonedDose(
            idDosis: idDosis,
            idempotencyKey: idempotencyKey,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operación resuelta: ${res.estado}.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al resolver: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openActionDialog({
    required Dosis dosis,
    required String medicamentoNombre,
    required bool isCorrection,
  }) {
    DoseActionDialog.show(
      context,
      dosis: dosis,
      medicamentoNombre: medicamentoNombre,
      isCorrection: isCorrection,
      onConfirm: ({
        required estado,
        efectivaEn,
        nota,
        required isCorrection,
      }) async {
        final confirmedDosis = await context.read<TreatmentProvider>().recordDose(
              idDosis: dosis.idDosis,
              estado: estado,
              efectivaEn: efectivaEn,
              nota: nota,
              isCorrection: isCorrection,
            );
        if (confirmedDosis.esPendiente) {
          throw StateError('La toma no pudo ser confirmada por el servidor.');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCorrection
                    ? 'Toma corregida exitosamente.'
                    : 'Toma registrada exitosamente.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  MedicamentoPlan? _findMedicamento(TreatmentProvider provider, int idMedPlan) {
    final plan = provider.selectedTreatment;
    if (plan == null) return null;
    try {
      return plan.medicamentos.firstWhere(
        (m) => m.idMedicamentoPlan == idMedPlan,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDateWithDay(DateTime dt) {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final dayName = days[dt.weekday - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$dayName, $day/$month/${dt.year}';
  }

  static String _formatHour(String iso) {
    try {
      final parsed = DateTime.parse(iso).toLocal();
      final h = parsed.hour.toString().padLeft(2, '0');
      final m = parsed.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso;
    }
  }
}
