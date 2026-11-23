import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/asistencia_tratamiento.dart';
import '../providers/asistencia_provider.dart';
import '../widgets/alerta_card.dart';
import '../widgets/aviso_legal_widget.dart';
import '../widgets/recomendacion_card.dart';

/// Pantalla principal móvil de Asistencia Inteligente de Tratamiento (CU18, HU1-87..HU1-90, RF-25).
///
/// Ofrece al paciente:
/// 1. Solicitud bajo demanda de evaluación del tratamiento activo.
/// 2. Visualización jerárquica de alertas de interacción (GRAVE, MODERADA, LEVE).
/// 3. Sugerencias contextuales y de estilo de vida.
/// 4. Historial paginado de evaluaciones con consulta de detalle.
/// 5. Manejo explícito de todos los estados: carga, sin tratamiento, sin riesgo,
///    modo degradado de reglas, rate limiting (429) y errores de red.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AsistenciaProvider>();
      provider.cargarHistorial();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _llamarUrgencias() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Qué hacer ante una urgencia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Si presenta síntomas graves (como dificultad para respirar, dolor intenso en el pecho o abdomen, sangrado anormal o mareos severos), acuda de inmediato al centro de urgencias más cercano o llame al número de emergencias de su localidad.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Consulte con su médico tratante antes de continuar tomando los medicamentos señalados con interacción.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AsistenciaProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Asistencia de Tratamiento'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'Evaluación'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEvaluacionTab(provider),
          _buildHistorialTab(provider),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: Evaluación y Asistencia Actual
  // ==========================================================================
  Widget _buildEvaluacionTab(AsistenciaProvider provider) {
    final evaluacion = provider.evaluacionActual;

    return RefreshIndicator(
      onRefresh: () => provider.solicitarEvaluacion(forzarRecalculo: true),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Tarjeta Principal de Cabecera con pastilla "IA"
          _buildHeaderPanel(provider),

          const SizedBox(height: 16),

          // Manejo de Error / Rate Limit (429) / Red (conservando evaluación visible si existe)
          if (provider.status == AsistenciaStatus.error) ...[
            _buildErrorBanner(provider),
            const SizedBox(height: 16),
          ],

          // Estado: Cargando
          if (provider.isLoading) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Analizando interacciones farmacológicas y recomendaciones...',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ] else if (evaluacion != null) ...[
            // Contenido de la evaluación recibida
            _buildResultadoEvaluacion(evaluacion),
          ] else ...[
            // Estado inicial antes de la primera evaluación
            _buildEstadoInicial(provider),
          ],

          const SizedBox(height: 24),

          // Aviso legal permanente RF-25 al pie
          const AvisoLegalWidget(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Encabezado estético con pastilla IA y botón de acción.
  Widget _buildHeaderPanel(AsistenciaProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pastilla IA (fondo azul claro, icono cerebro, texto bold)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.psychology, color: AppColors.primary, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'IA',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Asistencia Inteligente',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Revisa posibles interacciones entre tus medicamentos prescritos y recibe recomendaciones de cuidado personalizadas.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Botón de evaluación bajo demanda
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: provider.isLoading
                  ? null
                  : () => provider.solicitarEvaluacion(forzarRecalculo: false),
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 20),
              label: Text(
                provider.isLoading ? 'Evaluando tratamiento...' : 'Solicitar evaluación asistida',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner de errores específicos (Rate limit 429, red, permisos).
  Widget _buildErrorBanner(AsistenciaProvider provider) {
    final isRateLimit = provider.isRateLimited;
    final message = provider.errorMessage ?? 'No fue posible completar la asistencia.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRateLimit ? AppColors.warningContainer : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRateLimit ? AppColors.warning : AppColors.error,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRateLimit ? Icons.access_time_filled : Icons.error_outline_rounded,
                color: isRateLimit ? AppColors.onWarning : AppColors.error,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRateLimit
                      ? 'Límite de solicitudes alcanzado (429)'
                      : 'Error de comunicación',
                  style: TextStyle(
                    color: isRateLimit ? AppColors.onWarning : AppColors.onErrorContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isRateLimit
                ? 'Has alcanzado el límite de 10 evaluaciones por hora para cuidar la estabilidad del servicio. Por favor intenta nuevamente más tarde.'
                : message,
            style: TextStyle(
              color: isRateLimit ? AppColors.onWarning : AppColors.onErrorContainer,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          if (!isRateLimit) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => provider.solicitarEvaluacion(forzarRecalculo: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Estado antes de pulsar evaluar por primera vez.
  Widget _buildEstadoInicial(AsistenciaProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_liquid_outlined, size: 48, color: AppColors.primaryContainer),
          const SizedBox(height: 14),
          Text(
            'Evaluación bajo demanda',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Presiona el botón superior para contrastar tus medicamentos vigentes contra el catálogo farmacológico y recibir sugerencias personalizadas.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Construye las tarjetas de alertas, sugerencias o estados vacíos.
  Widget _buildResultadoEvaluacion(EvaluacionTratamiento evaluacion) {
    // 1. Estado: SIN TRATAMIENTO VIGENTE
    if (evaluacion.hasNoActiveTreatment) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sin tratamiento activo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    evaluacion.resumenEjecutivo ??
                        'No cuentas con recetas ni medicamentos vigentes registrados en la clínica en este momento.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de modo degradado si la IA falló pero las reglas respondieron
        if (evaluacion.isDegraded) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_gmailerrorred_rounded, color: AppColors.onWarning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Evaluación con reglas clínicas base: las sugerencias generativas no estuvieron disponibles temporalmente, pero tus alertas farmacológicas están garantizadas.',
                    style: const TextStyle(color: AppColors.onWarning, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Chip de estado de riesgo global
        Row(
          children: [
            Text(
              'Riesgo consolidado:',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: evaluacion.hasHighRisk
                    ? AppColors.errorContainer
                    : evaluacion.hasNoRisk
                        ? AppColors.successContainer
                        : AppColors.warningContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                evaluacion.nivelRiesgoGlobal,
                style: TextStyle(
                  color: evaluacion.hasHighRisk
                      ? AppColors.error
                      : evaluacion.hasNoRisk
                          ? AppColors.onSuccessContainer
                          : AppColors.onWarning,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${evaluacion.totalMedicamentosAnalizados} medicamentos analizados',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // SECCIÓN A: ALERTAS DE INTERACCIÓN
        if (evaluacion.alertas.isNotEmpty) ...[
          Text(
            'Alertas Farmacológicas (${evaluacion.totalAlertasDetectadas})',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...evaluacion.alertas.map(
            (alerta) => AlertaCard(
              alerta: alerta,
              onUrgenciasTap: _llamarUrgencias,
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          // Criterio 5: Sin interacciones detectadas
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    evaluacion.resumenEjecutivo ??
                        'No se detectaron interacciones adversas entre sus medicamentos vigentes.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],

        // SECCIÓN B: SUGERENCIAS PERSONALIZADAS
        if (evaluacion.recomendaciones.isNotEmpty) ...[
          Text(
            'Sugerencias de Autocuidado',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...evaluacion.recomendaciones.map(
            (rec) => RecomendacionCard(recomendacion: rec),
          ),
        ],
      ],
    );
  }

  // ==========================================================================
  // TAB 2: Historial Paginado de Evaluaciones
  // ==========================================================================
  Widget _buildHistorialTab(AsistenciaProvider provider) {
    if (provider.isLoadingHistory && provider.historialItems.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (provider.historyStatus == AsistenciaHistoryStatus.error &&
        provider.historialItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                provider.historyErrorMessage ?? 'Error al cargar historial.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => provider.cargarHistorial(refresh: true),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.historialItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_toggle_off_rounded, size: 52, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Sin evaluaciones previas',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Cuando solicites asistencia para tu tratamiento, cada resultado quedará registrado aquí.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.cargarHistorial(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.historialItems.length + (provider.hasMoreHistory ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.historialItems.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: provider.isLoadingMoreHistory
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : OutlinedButton(
                        onPressed: provider.cargarMasHistorial,
                        child: const Text('Cargar más evaluaciones'),
                      ),
              ),
            );
          }

          final item = provider.historialItems[index];
          final hasAlerts = item.totalAlertasDetectadas > 0;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.divider),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: item.isHighRisk
                    ? AppColors.errorContainer
                    : hasAlerts
                        ? AppColors.warningContainer
                        : AppColors.successContainer,
                child: Icon(
                  item.isHighRisk
                      ? Icons.shield_outlined
                      : hasAlerts
                          ? Icons.warning_amber_rounded
                          : Icons.check_rounded,
                  color: item.isHighRisk
                      ? AppColors.error
                      : hasAlerts
                          ? AppColors.onWarning
                          : AppColors.success,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'Evaluación #${item.idEvaluacion}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.nivelRiesgoGlobal,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Fecha: ${item.fechaEvaluacion.toLocal().toString().split('.')[0]}',
                    style: AppTypography.bodySmall,
                  ),
                  Text(
                    '${item.totalMedicamentosAnalizados} medicamentos · ${item.totalAlertasDetectadas} alertas',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => _mostrarDetalleHistorico(context, item.idEvaluacion),
            ),
          );
        },
      ),
    );
  }

  /// Muestra el modal con el detalle completo de la evaluación seleccionada del historial.
  void _mostrarDetalleHistorico(BuildContext context, int idEvaluacion) {
    final provider = context.read<AsistenciaProvider>();
    provider.verDetalleEvaluacion(idEvaluacion);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<AsistenciaProvider>(
          builder: (context, prov, _) {
            final detail = prov.selectedEvaluacion;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollController) {
                if (prov.isLoadingDetail) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (prov.detailStatus == AsistenciaDetailStatus.error || detail == null) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(prov.detailErrorMessage ?? 'Error al cargar detalle.'),
                      ],
                    ),
                  );
                }

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
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
                    Text(
                      'Detalle de Evaluación #${detail.idEvaluacion}',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${detail.fechaEvaluacion.toLocal().toString().split('.')[0]}',
                      style: AppTypography.bodySmall,
                    ),
                    const Divider(height: 24),
                    _buildResultadoEvaluacion(detail),
                    const SizedBox(height: 20),
                    const AvisoLegalWidget(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
