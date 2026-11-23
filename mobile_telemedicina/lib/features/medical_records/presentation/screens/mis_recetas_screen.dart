import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prescription.dart';
import '../providers/prescription_provider.dart';
import '../utils/prescription_dates.dart';
import '../widgets/prescription_status_badge.dart';
import 'receta_detail_screen.dart';

/// Listado de recetas propias del paciente (CU16).
///
/// Ruta autenticada `/recetas` con pull-to-refresh, paginación incremental
/// (`skip/limit`) y filtros permitidos (estado y rango de fechas).
class MisRecetasScreen extends StatefulWidget {
  const MisRecetasScreen({super.key});

  @override
  State<MisRecetasScreen> createState() => _MisRecetasScreenState();
}

class _MisRecetasScreenState extends State<MisRecetasScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _estadoSeleccionado;
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrescriptionProvider>().loadPrescriptions(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<PrescriptionProvider>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      provider.loadMore();
    }
  }

  String? _toIsoDate(DateTime? date) {
    if (date == null) return null;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<void> _pickDate({required bool isDesde}) async {
    final now = DateTime.now();
    final previousDesde = _desde;
    final previousHasta = _hasta;
    // Restringe la selección mediante firstDate/lastDate según el otro
    // extremo para que el rango inválido sea imposible desde el picker.
    final firstDate = isDesde
        ? DateTime(now.year - 5)
        : (_desde ?? DateTime(now.year - 5));
    final lastDate = isDesde
        ? (_hasta ?? DateTime(now.year + 5))
        : DateTime(now.year + 5);
    DateTime initial =
        (isDesde ? _desde : _hasta) ?? (isDesde ? lastDate : firstDate);
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isDesde ? 'Fecha desde' : 'Fecha hasta',
    );
    if (picked == null) return;
    setState(() {
      if (isDesde) {
        _desde = picked;
      } else {
        _hasta = picked;
      }
    });
    if (!isValidDateRange(_toIsoDate(_desde), _toIsoDate(_hasta))) {
      // Revierte el valor inválido antes de mostrar el mensaje: el filtro
      // visible siempre coincide con el filtro aplicado al provider.
      setState(() {
        _desde = previousDesde;
        _hasta = previousHasta;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha "hasta" no puede ser anterior a "desde".'),
          ),
        );
      }
      return;
    }
    if (mounted) {
      await context.read<PrescriptionProvider>().setFilters(
        estado: _estadoSeleccionado,
        desde: _toIsoDate(_desde),
        hasta: _toIsoDate(_hasta),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mis recetas',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<PrescriptionProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildFilters(provider),
              Expanded(child: _buildBody(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(PrescriptionProvider provider) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: 'Todas',
                  selected: _estadoSeleccionado == null,
                  onSelected: () async {
                    setState(() => _estadoSeleccionado = null);
                    await provider.setFilters(
                      estado: null,
                      desde: _toIsoDate(_desde),
                      hasta: _toIsoDate(_hasta),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Emitidas',
                  selected: _estadoSeleccionado == 'EMITIDA',
                  onSelected: () async {
                    setState(() => _estadoSeleccionado = 'EMITIDA');
                    await provider.setFilters(
                      estado: 'EMITIDA',
                      desde: _toIsoDate(_desde),
                      hasta: _toIsoDate(_hasta),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Anuladas',
                  selected: _estadoSeleccionado == 'ANULADA',
                  onSelected: () async {
                    setState(() => _estadoSeleccionado = 'ANULADA');
                    await provider.setFilters(
                      estado: 'ANULADA',
                      desde: _toIsoDate(_desde),
                      hasta: _toIsoDate(_hasta),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  label: _desde == null
                      ? 'Desde'
                      : 'Desde ${formatVisibleDate(_toIsoDate(_desde)!)}',
                  tooltip: 'Filtrar por fecha desde',
                  onTap: () => _pickDate(isDesde: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateButton(
                  label: _hasta == null
                      ? 'Hasta'
                      : 'Hasta ${formatVisibleDate(_toIsoDate(_hasta)!)}',
                  tooltip: 'Filtrar por fecha hasta',
                  onTap: () => _pickDate(isDesde: false),
                ),
              ),
              if (_desde != null || _hasta != null)
                IconButton(
                  tooltip: 'Limpiar fechas',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () async {
                    setState(() {
                      _desde = null;
                      _hasta = null;
                    });
                    await provider.setFilters(
                      estado: _estadoSeleccionado,
                      desde: null,
                      hasta: null,
                    );
                  },
                  icon: const Icon(Icons.clear_rounded, color: AppColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.onPrimary : AppColors.textPrimary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.outline),
    );
  }

  Widget _dateButton({
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(PrescriptionProvider provider) {
    switch (provider.listStatus) {
      case PrescriptionListStatus.initial:
      case PrescriptionListStatus.loading:
        return Semantics(
          label: 'Cargando tus recetas',
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      case PrescriptionListStatus.error:
        return _buildError(provider);
      case PrescriptionListStatus.empty:
        return _buildEmpty(provider);
      case PrescriptionListStatus.loaded:
        return _buildList(provider);
    }
  }

  Widget _buildError(PrescriptionProvider provider) {
    return Semantics(
      label: 'Error al cargar recetas',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                provider.listError ?? 'No se pudieron cargar tus recetas.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => provider.loadPrescriptions(refresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildEmpty(PrescriptionProvider provider) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.loadPrescriptions(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.medication_outlined,
                  size: 56,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aún no tienes recetas registradas.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => provider.loadPrescriptions(refresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(PrescriptionProvider provider) {
    final items = provider.items;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.loadPrescriptions(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: items.length + (provider.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _buildLoadMore(provider);
          }
          return _PrescriptionCard(prescription: items[index]);
        },
      ),
    );
  }

  Widget _buildLoadMore(PrescriptionProvider provider) {
    if (provider.loadMoreStatus == PrescriptionLoadMoreStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => provider.loadMore(),
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(
              provider.loadMoreError ?? 'Cargar más',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Receta ${prescription.folio}, médico ${prescription.medico.nombreCompleto}',
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    RecetaDetailScreen(idReceta: prescription.idReceta),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prescription.folio,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PrescriptionStatusBadge(status: prescription.estadoVisual),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prescription.medico.nombreCompleto,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (prescription.medico.especialidad != null &&
                    prescription.medico.especialidad!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_hospital_outlined,
                          size: 16,
                          color: AppColors.tealAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            prescription.medico.especialidad!,
                            style: AppTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _dateItem(
                        label: 'Emisión',
                        value: formatVisibleDate(prescription.fechaEmision),
                      ),
                    ),
                    Expanded(
                      child: _dateItem(
                        label: 'Vencimiento',
                        value: formatVisibleDate(prescription.fechaVencimiento),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
