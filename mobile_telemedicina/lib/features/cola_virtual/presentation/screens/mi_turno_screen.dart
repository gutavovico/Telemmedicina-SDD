import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cola_provider.dart';

/// CU08 — Vista del paciente: posición y tiempo estimado en la fila virtual.
class MiTurnoScreen extends StatefulWidget {
  const MiTurnoScreen({super.key});

  @override
  State<MiTurnoScreen> createState() => _MiTurnoScreenState();
}

class _MiTurnoScreenState extends State<MiTurnoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ColaProvider>();
      provider.cargarMiTurno();
      provider.iniciarPollingMiTurno();
    });
  }

  @override
  void dispose() {
    context.read<ColaProvider>().detenerPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ColaProvider>();
    final turno = provider.miTurno;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi turno de hoy')),
      body: RefreshIndicator(
        onRefresh: () => provider.cargarMiTurno(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (provider.isLoading && turno == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage != null && turno == null)
              _ErrorCard(
                mensaje: provider.errorMessage!,
                onReintentar: () => provider.cargarMiTurno(),
              )
            else if (turno == null || turno.estadoCola == 'SIN_TURNOS')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.event_available_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No tienes turnos pendientes hoy',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(turno?.mensajeCola ?? 'Consulta tus citas agendadas.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pushNamed('/mis-citas'),
                        child: const Text('Ver mis citas'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (turno.proximo)
                const Card(
                  color: Color(0xFFECFDF5),
                  child: ListTile(
                    leading: Icon(Icons.notifications_active_outlined, color: Color(0xFF059669)),
                    title: Text('Tu turno está próximo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Mantente atento al llamado.'),
                  ),
                ),
              if (turno.mensajeCola != null)
                Card(
                  color: turno.estadoCola == 'PAUSADA'
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF0F9FF),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(turno.mensajeCola!),
                  ),
                ),
              Card(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF003667), Color(0xFF049CAB)]),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Column(
                        children: [
                          const Text('TU POSICIÓN EN LA FILA',
                              style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2)),
                          Text('${turno.posicion}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
                          Text(
                            turno.etaMinutos == 0
                                ? 'Es tu turno ahora'
                                : 'Espera aprox. ${turno.etaMinutos} min · ${turno.delante} por delante',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Hora de tu cita'),
                      trailing: Text(turno.hora,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.medical_services_outlined),
                      title: const Text('Médico'),
                      subtitle: Text(turno.medicoNombre),
                      trailing: Chip(label: Text(turno.estado)),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('La fila se actualiza automáticamente cada 5 segundos.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorCard({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(mensaje, style: const TextStyle(color: Color(0xFF991B1B))),
            const SizedBox(height: 8),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
