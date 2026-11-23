import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/ficha_entity.dart';
import '../providers/ficha_provider.dart';

class FichasScreen extends StatefulWidget {
  const FichasScreen({super.key});

  @override
  State<FichasScreen> createState() => _FichasScreenState();
}

class _FichasScreenState extends State<FichasScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FichaProvider>().fetchFichas();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'EMITIDA':
        return const Color(0xFF0284C7); // Sky blue
      case 'EN_ATENCION':
        return AppColors.warning; // Amber
      case 'FINALIZADA':
        return AppColors.success; // Green
      case 'CANCELADA':
        return AppColors.error; // Red
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'EMITIDA':
        return const Color(0xFFE0F2FE);
      case 'EN_ATENCION':
        return AppColors.warningContainer;
      case 'FINALIZADA':
        return AppColors.successContainer;
      case 'CANCELADA':
        return AppColors.errorContainer;
      default:
        return AppColors.surfaceVariant;
    }
  }

  Future<void> _handleCancelFicha(FichaEntity ficha) async {
    final motifCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancelar Ficha ${ficha.correlativo}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Indica el motivo de cancelación para liberar el turno:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: motifCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ej. Imposibilidad de asistir por viaje...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'El motivo debe tener al menos 5 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Confirmar Cancelación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<FichaProvider>().cancelFicha(ficha.idFicha, motifCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Ficha ${ficha.correlativo} cancelada exitosamente.' : 'No se pudo cancelar la ficha.',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fichaProvider = context.watch<FichaProvider>();
    final fichas = fichaProvider.filteredFichas;

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
              'Expediente y Fichas',
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'CU09 • Fichas Médicas Dinámicas',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryContainer,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar',
            onPressed: () => fichaProvider.fetchFichas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text(
          'Nueva Ficha',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/fichas/nueva');
          if (result == true && mounted) {
            fichaProvider.fetchFichas();
          }
        },
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: fichaProvider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Buscar por correlativo, médico, especialidad...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              fichaProvider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('TODOS', fichaProvider),
                      const SizedBox(width: 8),
                      _buildFilterChip('EMITIDA', fichaProvider),
                      const SizedBox(width: 8),
                      _buildFilterChip('EN_ATENCION', fichaProvider),
                      const SizedBox(width: 8),
                      _buildFilterChip('FINALIZADA', fichaProvider),
                      const SizedBox(width: 8),
                      _buildFilterChip('CANCELADA', fichaProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message banner if any
          if (fichaProvider.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.errorContainer,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fichaProvider.errorMessage!,
                      style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Fichas List
          Expanded(
            child: fichaProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => fichaProvider.fetchFichas(),
                    child: fichas.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                            itemCount: fichas.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildFichaCard(fichas[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, FichaProvider provider) {
    final isSelected = provider.statusFilter == status;
    return ChoiceChip(
      label: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      onSelected: (_) => provider.setStatusFilter(status),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.assignment_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No se encontraron fichas clínicas',
            style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Toca en "Nueva Ficha" para emitir y reservar un turno de atención.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildFichaCard(FichaEntity ficha) {
    final statusColor = _getStatusColor(ficha.estado);
    final statusBg = _getStatusBg(ficha.estado);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Correlativo & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ficha.correlativo,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ficha.estado.replaceAll('_', ' '),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.divider),

            // Doctor & Specialty
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ficha.medicoNombre ?? 'Médico Asignado',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                if (ficha.especialidadNombre != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ficha.especialidadNombre!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Date & Time Slot
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${ficha.fechaAtencion} • ${ficha.horaInicio} - ${ficha.horaFin}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason
            Text(
              ficha.motivoConsulta,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Vital Signs preview if present
            if (ficha.signosVitales.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ficha.signosVitales.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${e.key.toUpperCase()}: ${e.value}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ],

            // If Finalized: Clinical Notes preview & CIE-10
            if (ficha.estado == 'FINALIZADA' && ficha.codigoCie10 != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CIE-10: [${ficha.codigoCie10}] ${ficha.diagnosticoDescripcion ?? ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSuccessContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action: Cancel button if EMITIDA
            if (ficha.estado == 'EMITIDA') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                  label: const Text('Cancelar Turno', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  onPressed: () => _handleCancelFicha(ficha),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
