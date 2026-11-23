import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cola_provider.dart';

/// CU08 — Cola operativa del día (médico: su fila; recepción: indica idMedico).
class ColaOperativaScreen extends StatefulWidget {
  final int? idMedico;

  const ColaOperativaScreen({super.key, this.idMedico});

  @override
  State<ColaOperativaScreen> createState() => _ColaOperativaScreenState();
}

class _ColaOperativaScreenState extends State<ColaOperativaScreen> {
  final _motivoController = TextEditingController();
  String _horaInicio = '';
  String _horaFin = '';
  bool _mostrarPausa = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ColaProvider>();
      provider.cargarCola(idMedico: widget.idMedico);
      provider.iniciarPollingCola(idMedico: widget.idMedico);
    });
  }

  @override
  void dispose() {
    context.read<ColaProvider>().detenerPolling();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _elegirHora(bool esInicio) async {
    final elegida = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (elegida == null) return;
    final texto =
        '${elegida.hour.toString().padLeft(2, '0')}:${elegida.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (esInicio) {
        _horaInicio = texto;
      } else {
        _horaFin = texto;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ColaProvider>();
    final cola = provider.cola;

    return Scaffold(
      appBar: AppBar(title: const Text('Fila virtual del día')),
      body: RefreshIndicator(
        onRefresh: () => provider.cargarCola(idMedico: widget.idMedico),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (provider.isLoading && cola == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage != null && cola == null)
              Card(
                color: const Color(0xFFFEF2F2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(provider.errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B))),
                      TextButton(
                        onPressed: () => provider.cargarCola(idMedico: widget.idMedico),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else if (cola != null) ...[
              if (cola.mensajeCola != null)
                Card(
                  color: cola.estadoCola == 'PAUSADA'
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF0F9FF),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text('${cola.estadoCola}: ${cola.mensajeCola!}'),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(cola.medicoNombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${cola.fecha} · ${cola.totalPendientes} pendientes · prom. ${cola.duracionPromedioMin} min'),
                  trailing: TextButton(
                    onPressed: () => setState(() => _mostrarPausa = !_mostrarPausa),
                    child: const Text('Pausa'),
                  ),
                ),
              ),
              if (_mostrarPausa)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Registrar pausa',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _elegirHora(true),
                                child: Text(_horaInicio.isEmpty ? 'Desde' : _horaInicio),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _elegirHora(false),
                                child: Text(_horaFin.isEmpty ? 'Hasta' : _horaFin),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _motivoController,
                          decoration: const InputDecoration(
                            labelText: 'Motivo',
                            hintText: 'Ej. Desinfección de consultorio',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            final idMedico = cola.idMedico;
                            if (_horaInicio.isEmpty ||
                                _horaFin.isEmpty ||
                                _motivoController.text.trim().length < 3) {
                              return;
                            }
                            provider.registrarPausa(
                              idMedico: idMedico,
                              fecha: cola.fecha,
                              horaInicio: _horaInicio,
                              horaFin: _horaFin,
                              motivo: _motivoController.text.trim(),
                            ).then((ok) {
                              if (ok && mounted) {
                                setState(() {
                                  _mostrarPausa = false;
                                  _horaInicio = '';
                                  _horaFin = '';
                                  _motivoController.clear();
                                });
                              }
                            });
                          },
                          child: const Text('Guardar pausa'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (cola.entradas.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No hay turnos pendientes para hoy.')),
                  ),
                )
              else
                ...cola.entradas.map((e) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${e.posicion}')),
                        title: Text('${e.hora} · ${e.pacienteNombre}'),
                        subtitle: Text('${e.estado} · ETA ${e.etaMinutos} min'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              tooltip: 'Marcar atendida y avanzar',
                              onPressed: () => provider.avanzar(e.idCita),
                            ),
                            IconButton(
                              icon: const Icon(Icons.event_busy_outlined),
                              tooltip: 'Marcar turno perdido',
                              onPressed: () => provider.marcarPerdida(e.idCita),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}
