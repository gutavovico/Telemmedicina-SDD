import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/treatment_entities.dart';
import '../providers/treatment_provider.dart';

/// Pantalla de bandeja de avisos y recordatorios de tratamientos (CU17).
class AvisosInboxScreen extends StatefulWidget {
  const AvisosInboxScreen({super.key});

  @override
  State<AvisosInboxScreen> createState() => _AvisosInboxScreenState();
}

class _AvisosInboxScreenState extends State<AvisosInboxScreen> {
  bool _soloNoLeidos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TreatmentProvider>().loadAvisos(noLeidos: _soloNoLeidos);
    });
  }

  Future<void> _onRefresh() async {
    await context.read<TreatmentProvider>().loadAvisos(noLeidos: _soloNoLeidos);
  }

  void _toggleFilter(bool noLeidos) {
    setState(() => _soloNoLeidos = noLeidos);
    context.read<TreatmentProvider>().loadAvisos(noLeidos: noLeidos);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreatmentProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Avisos y Recordatorios'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar avisos',
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterBar(),

          // List Body
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

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todos'),
            selected: !_soloNoLeidos,
            onSelected: (_) => _toggleFilter(false),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            labelStyle: TextStyle(
              color: !_soloNoLeidos ? Colors.white : AppColors.textPrimary,
              fontWeight: !_soloNoLeidos ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: !_soloNoLeidos ? AppColors.primary : AppColors.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Solo no leídos'),
            selected: _soloNoLeidos,
            onSelected: (_) => _toggleFilter(true),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            labelStyle: TextStyle(
              color: _soloNoLeidos ? Colors.white : AppColors.textPrimary,
              fontWeight: _soloNoLeidos ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _soloNoLeidos ? AppColors.primary : AppColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(TreatmentProvider provider) {
    switch (provider.avisosStatus) {
      case AvisosStatus.initial:
      case AvisosStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case AvisosStatus.error:
        return _buildErrorState(provider);
      case AvisosStatus.empty:
        return _buildEmptyState();
      case AvisosStatus.loaded:
        return _buildListView(provider);
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
                'No se pudieron cargar los avisos',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                provider.avisosError ?? 'Error de conexión',
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
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _soloNoLeidos
                    ? 'No tienes avisos sin leer'
                    : 'Bandeja de avisos vacía',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _soloNoLeidos
                    ? 'Todos tus avisos y alertas han sido marcados como leídos.'
                    : 'Tus recordatorios de tomas, avisos de omisión y alertas de seguimiento aparecerán aquí.',
                style: const TextStyle(
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

  Widget _buildListView(TreatmentProvider provider) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: provider.avisos.length,
      itemBuilder: (context, index) {
        final aviso = provider.avisos[index];
        return _buildAvisoCard(provider, aviso);
      },
    );
  }

  Widget _buildAvisoCard(TreatmentProvider provider, Aviso aviso) {
    final config = _avisoConfigFor(aviso.tipo);
    final isUnread = !aviso.estaLeido;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnread ? config.color.withValues(alpha: 0.5) : AppColors.divider,
          width: isUnread ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      color: isUnread ? Colors.white : const Color(0xFFFBFBFB),
      child: InkWell(
        onTap: () {
          if (isUnread) {
            provider.markAvisoAsRead(aviso.idAviso);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono por tipo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: config.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(config.icon, color: config.color, size: 22),
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            aviso.titulo ?? config.defaultTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      aviso.mensaje ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Fecha y canal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(aviso.enviadaEn ?? aviso.programadaEn),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (aviso.estaLeido)
                          Row(
                            children: const [
                              Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Leído',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Toca para marcar leído',
                            style: TextStyle(
                              fontSize: 10,
                              color: config.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final parsed = DateTime.parse(iso).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final min = parsed.minute.toString().padLeft(2, '0');
      return '$day/$month/${parsed.year} $hour:$min';
    } catch (_) {
      return iso;
    }
  }
}

class _AvisoTypeConfig {
  final IconData icon;
  final Color color;
  final Color background;
  final String defaultTitle;

  const _AvisoTypeConfig({
    required this.icon,
    required this.color,
    required this.background,
    required this.defaultTitle,
  });
}

_AvisoTypeConfig _avisoConfigFor(String tipo) {
  switch (tipo.toUpperCase()) {
    case 'RECORDATORIO':
      return const _AvisoTypeConfig(
        icon: Icons.alarm_rounded,
        color: Color(0xFF2563EB),
        background: Color(0xFFEFF6FF),
        defaultTitle: 'Recordatorio de toma',
      );
    case 'OMISION':
      return const _AvisoTypeConfig(
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFD97706),
        background: Color(0xFFFEF3C7),
        defaultTitle: 'Alerta de omisión de toma',
      );
    case 'RIESGO_ABANDONO':
      return const _AvisoTypeConfig(
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
        background: Color(0xFFFFDAD6),
        defaultTitle: 'Alerta clínica: Riesgo de abandono',
      );
    default:
      return const _AvisoTypeConfig(
        icon: Icons.notifications_rounded,
        color: AppColors.primary,
        background: AppColors.surfaceVariant,
        defaultTitle: 'Aviso del tratamiento',
      );
  }
}
