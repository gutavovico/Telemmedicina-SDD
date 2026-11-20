import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/waitlist_models.dart';
import '../providers/waitlist_provider.dart';

/// CU07 — Vista del paciente: inscripción, posición y respuesta a turnos ofrecidos.
class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  final TextEditingController _motivoController = TextEditingController();
  DateTime? _fechaDeseada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.isNotEmpty) {
        context.read<WaitlistProvider>().prepararInscripcion(
              idMedico: args['idMedico'] as int?,
              idEspecialidad: args['idEspecialidad'] as int?,
              nombreMedico: args['nombreMedico'] as String?,
            );
      }
      context.read<WaitlistProvider>().cargar();
    });
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaDeseada ?? ahora,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365)),
    );
    if (fecha != null) {
      setState(() => _fechaDeseada = fecha);
    }
  }

  String get _fechaFormato {
    if (_fechaDeseada == null) return '';
    return '${_fechaDeseada!.year.toString().padLeft(4, '0')}-'
        '${_fechaDeseada!.month.toString().padLeft(2, '0')}-'
        '${_fechaDeseada!.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WaitlistProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi lista de espera')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(context, provider),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Inscribirme'),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.cargar(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Card(
              color: const Color(0xFFE8F6F7),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.schedule, color: Color(0xFF049CAB), size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Te avisaremos cuando se libere un turno con el especialista que elegiste.',
                        style: TextStyle(color: Color(0xFF25627C)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (provider.status == WaitlistStatus.loading && provider.inscripciones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage != null && provider.inscripciones.isEmpty)
              _ErrorCard(
                mensaje: provider.errorMessage!,
                onReintentar: () {
                  provider.limpiarError();
                  provider.cargar();
                },
              )
            else
              ...provider.inscripciones.map(
                    (entrada) => _InscripcionCard(
                      entrada: entrada,
                      accionEnCurso: provider.accionEnCurso,
                      onConfirmar: () => provider.confirmar(entrada.idListaEspera),
                      onRechazar: () => provider.rechazar(entrada.idListaEspera),
                      onSalir: () => provider.salir(entrada.idListaEspera),
                    ),
                  ),
            if (provider.status == WaitlistStatus.success && provider.inscripciones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Aún no tienes inscripciones activas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            if (provider.errorMessage != null && provider.inscripciones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarFormulario(BuildContext context, WaitlistProvider provider) {
    if (provider.idMedico == null && provider.idEspecialidad == null) {
      _elegirEspecialista(context, provider);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inscripción en lista de espera',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (provider.nombreMedico != null)
              Text('Especialista: ${provider.nombreMedico}'),
            if (provider.idMedico != null)
              Text('ID médico: ${provider.idMedico}'),
            if (provider.idEspecialidad != null)
              Text('ID especialidad: ${provider.idEspecialidad}'),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_fechaFormato.isEmpty ? 'Fecha deseada (opcional)' : _fechaFormato),
              onTap: _elegirFecha,
            ),
            TextField(
              controller: _motivoController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: provider.accionEnCurso
                  ? null
                  : () async {
                      final ok = await provider.inscribirse(
                        fechaDeseada: _fechaFormato.isEmpty ? null : _fechaFormato,
                        motivo: _motivoController.text,
                      );
                      if (ok && sheetContext.mounted) {
                        _motivoController.clear();
                        _fechaDeseada = null;
                        Navigator.of(sheetContext).pop();
                      }
                    },
              child: const Text('Confirmar inscripción'),
            ),
          ],
        ),
      ),
    );
  }

  void _elegirEspecialista(BuildContext context, WaitlistProvider provider) {
    final idController = TextEditingController();
    final especialidadController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Datos de la especialidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID de médico'),
            ),
            TextField(
              controller: especialidadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID de especialidad'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final medico = int.tryParse(idController.text.trim());
              final especialidad = int.tryParse(especialidadController.text.trim());
              if (medico == null && especialidad == null) return;
              provider.prepararInscripcion(
                idMedico: medico,
                idEspecialidad: especialidad,
              );
              Navigator.of(dialogContext).pop();
              _mostrarFormulario(context, provider);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class _InscripcionCard extends StatelessWidget {
  final InscripcionEsperaModel entrada;
  final bool accionEnCurso;
  final VoidCallback onConfirmar;
  final VoidCallback onRechazar;
  final VoidCallback onSalir;

  const _InscripcionCard({
    required this.entrada,
    required this.accionEnCurso,
    required this.onConfirmar,
    required this.onRechazar,
    required this.onSalir,
  });

  @override
  Widget build(BuildContext context) {
    final color = entrada.fueOfrecido ? Colors.green : Colors.blueGrey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_information, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entrada.medicoNombre ?? 'Cualquier especialista',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Chip(
                  label: Text(entrada.etiquetaEstado),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(entrada.especialidadNombre ?? 'Sin especialidad',
                style: const TextStyle(color: Colors.grey)),
            if (entrada.fechaDeseada != null)
              Text('Desde el ${entrada.fechaDeseada}'),
            if (entrada.estaEnEspera)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Tu posición en la lista: #${entrada.posicion}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF049CAB)),
                ),
              ),
            if (entrada.fueOfrecido)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: accionEnCurso ? null : onConfirmar,
                        child: const Text('Confirmar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: accionEnCurso ? null : onRechazar,
                        child: const Text('Rechazar'),
                      ),
                    ),
                  ],
                ),
              ),
            if (entrada.estaActiva)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: accionEnCurso ? null : onSalir,
                  child: const Text('Salir de la lista'),
                ),
              ),
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
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(mensaje, textAlign: TextAlign.center),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
