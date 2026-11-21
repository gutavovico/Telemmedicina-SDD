import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/notificacion_model.dart';
import '../providers/notificacion_provider.dart';
import '../services/notificacion_navigation_handler.dart';

/// Pantalla móvil de Notificaciones y Recordatorios Multicanal (CU20).
/// Diseño alineado al mockup: cabecera `< Notificaciones ✓`, pestañas `Todas | Citas | Documentos`,
/// agrupación cronológica `Hoy | Ayer`, tarjetas con icono circular, punto azul de no leída y canal.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  static const List<Map<String, String>> _tabs = [
    {'id': 'TODAS', 'label': 'Todas'},
    {'id': 'CITAS', 'label': 'Citas'},
    {'id': 'DOCUMENTOS', 'label': 'Documentos'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<NotificacionProvider>();
      if (provider.notificaciones.isEmpty) {
        provider.cargarBandeja();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificacionProvider>();
    final items = provider.notificacionesFiltradas;
    final grupos = _agruparPorFecha(items);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF0F172A), size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Volver',
        ),
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('notif_mark_all_read_btn'),
            icon: const Icon(Icons.check_rounded, color: Color(0xFF334155), size: 24),
            tooltip: 'Marcar todas como leídas',
            onPressed: provider.conteoNoLeidas > 0
                ? () async {
                    await provider.marcarTodasLeidas();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Todas las notificaciones marcadas como leídas'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                : null,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: Column(
        children: [
          // Pestañas: Todas | Citas | Documentos
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _tabs.map((tab) {
                final id = tab['id']!;
                final activa = provider.categoriaActiva == id;
                return Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: InkWell(
                    key: Key('notif_tab_$id'),
                    onTap: () => provider.cambiarCategoria(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: activa ? const Color(0xFF0F4C81) : Colors.transparent,
                            width: 2.2,
                          ),
                        ),
                      ),
                      child: Text(
                        tab['label']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                          color: activa ? const Color(0xFF0F4C81) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Lista agrupada por Hoy / Ayer / Anteriores
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.cargarBandeja(),
              child: provider.cargando && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 96),
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 52,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'No tienes notificaciones pendientes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: grupos.length,
                          itemBuilder: (context, idx) {
                            final grupo = grupos[idx];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: idx == 0 ? 4 : 14,
                                    bottom: 10,
                                  ),
                                  child: Text(
                                    grupo.etiqueta,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                ...grupo.items.map(
                                  (notif) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _NotificacionCard(
                                      notif: notif,
                                      esHoy: grupo.etiqueta == 'Hoy',
                                      onTap: () async {
                                        await provider.marcarLeida(notif.id);
                                        if (context.mounted) {
                                          await NotificacionNavigationHandler
                                              .navegarDesdeNotificacion(context, notif);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  List<_GrupoFecha> _agruparPorFecha(List<NotificacionModel> lista) {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final inicioAyer = inicioHoy.subtract(const Duration(days: 1));

    final hoy = <NotificacionModel>[];
    final ayer = <NotificacionModel>[];
    final anteriores = <NotificacionModel>[];

    for (final n in lista) {
      if (!n.creadaEn.isBefore(inicioHoy)) {
        hoy.add(n);
      } else if (!n.creadaEn.isBefore(inicioAyer)) {
        ayer.add(n);
      } else {
        anteriores.add(n);
      }
    }

    return [
      if (hoy.isNotEmpty) _GrupoFecha('Hoy', hoy),
      if (ayer.isNotEmpty) _GrupoFecha('Ayer', ayer),
      if (anteriores.isNotEmpty) _GrupoFecha('Anteriores', anteriores),
    ];
  }
}

class _GrupoFecha {
  final String etiqueta;
  final List<NotificacionModel> items;
  const _GrupoFecha(this.etiqueta, this.items);
}

class _NotificacionCard extends StatelessWidget {
  final NotificacionModel notif;
  final bool esHoy;
  final VoidCallback onTap;

  const _NotificacionCard({
    required this.notif,
    required this.esHoy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final noLeida = !notif.estaLeida;
    final estilo = _estiloIcono(notif.tipo, notif.recursoTipo);

    return Material(
      color: noLeida ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: noLeida ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contenedor circular del icono temático
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: noLeida ? Colors.white : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(estilo.icon, color: estilo.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Título, cuerpo y fila de metadatos (hora · canal)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.titulo,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (noLeida)
                          Container(
                            key: Key('notif_unread_dot_${notif.id}'),
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5, left: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1D4ED8),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.mensaje,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatearTiempo(notif.creadaEn, esHoy),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        Icon(
                          _iconoCanal(notif.canalBadge),
                          size: 13,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notif.canalBadge,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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

  _IconoEstilo _estiloIcono(String tipo, String? recursoTipo) {
    final t = tipo.toUpperCase();
    final r = (recursoTipo ?? '').toUpperCase();
    if (t == 'SALA_VIRTUAL_ABIERTA' || t == 'PACIENTE_EN_ESPERA' || r == 'SALA_VIRTUAL') {
      return const _IconoEstilo(Icons.videocam_outlined, Color(0xFF0F766E));
    }
    if (t == 'TURNO_LIBERADO' || t == 'NUEVA_CITA_AGENDADA' || t == 'CITA_CANCELADA') {
      return const _IconoEstilo(Icons.event_available_outlined, Color(0xFF0F766E));
    }
    if (t == 'DOCUMENTO_DISPONIBLE' || t == 'RESULTADO_LAB_LISTO' || r == 'DOCUMENTO') {
      return const _IconoEstilo(Icons.description_outlined, Color(0xFF1D4ED8));
    }
    if (t == 'MEDICACION_TRATAMIENTO' || r == 'TRATAMIENTO') {
      return const _IconoEstilo(Icons.medication_outlined, Color(0xFFC2410C));
    }
    return const _IconoEstilo(Icons.access_time_rounded, Color(0xFF1D4ED8));
  }

  IconData _iconoCanal(String badge) {
    final b = badge.toLowerCase();
    if (b == 'correo' || b == 'email') return Icons.mail_outline_rounded;
    if (b == 'whatsapp' || b == 'sms') return Icons.chat_bubble_outline_rounded;
    return Icons.smartphone_outlined;
  }

  String _formatearTiempo(DateTime dt, bool esHoy) {
    if (!esHoy) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace 1 min';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours} h';
  }
}

class _IconoEstilo {
  final IconData icon;
  final Color color;
  const _IconoEstilo(this.icon, this.color);
}
