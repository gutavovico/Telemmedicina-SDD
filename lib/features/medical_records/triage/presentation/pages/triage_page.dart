import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/triage_model.dart';
import '../../data/services/triage_service.dart';

class TriagePage extends StatefulWidget {
  const TriagePage({super.key});

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  final TriageService _triageService = TriageService();
  final _consultaController = TextEditingController();

  String? _motivo;
  int _intensidadDolor = 1;
  String? _tiempoEvolucion;
  final List<String> _signosAlarma = [];
  final List<File> _archivos = [];

  bool _loadingPreliminar = false;
  bool _loadingIA = false;
  TriageResponse? _resultado;

  final List<String> _motivos = [
    'Fiebre alta', 'Dolor agudo', 'Traumatismo / Golpe',
    'Dificultad respiratoria', 'Erupción cutánea', 'Mareo / Vértigo', 'Otro motivo'
  ];

    final List<String> _tiempos = [
    'Menos de 2 horas', 'Hoy / Pocas horas', '24 - 48 horas', 'Más de 3 días'
  ];

    final List<String> _signosList = [
    'Dificultad o mucho esfuerzo para respirar',
    'Dolor fuerte en el pecho que no se pasa',
    'Fiebre muy alta que no baja con medicamentos',
    'Sangrado abundante que no se detiene',
    'Confusión, mareos fuertes o hablar raro',
    'Debilidad, pérdida de fuerza o parálisis de repente',
    'Vómitos constantes o no poder tomar líquidos',
    'Golpe fuerte en la cabeza o pérdida de conocimiento'
  ];

  bool get _hasGraveSigns => _signosAlarma.isNotEmpty;

  void _toggleSigno(String signo) {
    setState(() {
      if (_signosAlarma.contains(signo)) {
        _signosAlarma.remove(signo);
      } else {
        _signosAlarma.add(signo);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _addFile(File(pickedFile.path));
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      _addFile(File(result.files.single.path!));
    }
  }

  void _addFile(File file) {
    if (_archivos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Máximo 5 archivos permitidos')));
      return;
    }
    if (file.lengthSync() > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El archivo excede 10MB')));
      return;
    }
    setState(() {
      _archivos.add(file);
    });
  }

  void _removeFile(int index) {
    setState(() {
      _archivos.removeAt(index);
    });
  }

  Map<String, dynamic> _getFormData() {
    return {
      'motivo': _motivo ?? '',
      'intensidad_dolor': _intensidadDolor,
      'tiempo_evolucion': _tiempoEvolucion ?? '',
      'signos_alarma': _signosAlarma,
      'consulta_directa': _consultaController.text,
    };
  }

  Future<void> _calcularPreliminar() async {
    if (_motivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seleccione un motivo')));
      return;
    }
    setState(() => _loadingPreliminar = true);
    try {
      final res = await _triageService.calcularPreliminar(_getFormData());
      if (!mounted) return;
      setState(() => _resultado = res);
      _showResultDialog(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingPreliminar = false);
    }
  }

  Future<void> _analizarIA() async {
    if (_motivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seleccione un motivo')));
      return;
    }
    if (_consultaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Describa sus síntomas')));
      return;
    }
    setState(() => _loadingIA = true);
    try {
      final res = await _triageService.analizarIA(_getFormData(), _archivos);
      if (!mounted) return;
      setState(() => _resultado = res);
      _showResultDialog(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingIA = false);
    }
  }

  Color _getColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rojo': return Colors.red;
      case 'naranja': return Colors.orange;
      case 'amarillo': return Colors.yellow;
      case 'verde': return Colors.green;
      case 'azul': return Colors.blue;
      default: return Colors.grey;
    }
  }


  void _showResultDialog(TriageResponse res) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.circle, color: _getColor(res.color)),
            SizedBox(width: 8),
            Expanded(child: Text('NIVEL ${res.nivel}: ${res.color.toUpperCase()}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(res.descripcionNivel, style: TextStyle(color: Colors.white70)),
              SizedBox(height: 12),
              Text('Tiempo de atención: ${res.tiempoAtencionMaxMin == 0 ? "Inmediato" : "Menos de ${res.tiempoAtencionMaxMin} minutos"}', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              if (res.posiblesCausas.isNotEmpty) ...[
                Text('Análisis detallado:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                ...res.posiblesCausas.map((c) => Padding(padding: EdgeInsets.only(bottom: 6), child: Text('- $c', style: TextStyle(color: Colors.white70)))),
              ],
              SizedBox(height: 16),
              Text(res.aviso, style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enviado a guardia exitosamente')));
            },
            icon: Icon(Icons.local_hospital),
            label: Text('Conectar con Guardia'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Triaje y Urgencias')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasGraveSigns)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red[700], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Protocolo Crítico Inmediato. Llame al 3332222.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            
            Text('1. Motivo principal', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _motivos.map((m) => ChoiceChip(
                label: Text(m),
                selected: _motivo == m,
                onSelected: (val) => setState(() => _motivo = val ? m : null),
              )).toList(),
            ),
            SizedBox(height: 16),

            Text('2. Intensidad del Dolor: $_intensidadDolor/10', style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _intensidadDolor.toDouble(),
              min: 1, max: 10, divisions: 9,
              onChanged: (val) => setState(() => _intensidadDolor = val.toInt()),
            ),
            SizedBox(height: 16),

            Text('3. Tiempo de evolución', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _tiempos.map((t) => ChoiceChip(
                label: Text(t),
                selected: _tiempoEvolucion == t,
                onSelected: (val) => setState(() => _tiempoEvolucion = val ? t : null),
              )).toList(),
            ),
            SizedBox(height: 16),

            Text('4. Signos de alarma', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._signosList.map((s) => CheckboxListTile(
              title: Text(s, style: TextStyle(fontSize: 14)),
              value: _signosAlarma.contains(s),
              onChanged: (val) => _toggleSigno(s),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            )),
            SizedBox(height: 16),

            Text('5. Consulta directa', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _consultaController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Describa sus síntomas...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            Text('6. Evidencia clínica (${_archivos.length}/5)', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _pickImage, icon: Icon(Icons.image), label: Text('Foto')),
                SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _pickFile, icon: Icon(Icons.picture_as_pdf), label: Text('PDF')),
              ],
            ),
            ..._archivos.asMap().entries.map((e) => ListTile(
              leading: Icon(Icons.insert_drive_file),
              title: Text(e.value.path.split('/').last, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: Icon(Icons.close), onPressed: () => _removeFile(e.key)),
            )),
            SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: ElevatedButton(
                  onPressed: _loadingPreliminar ? null : _calcularPreliminar,
                  child: _loadingPreliminar ? CircularProgressIndicator() : Text('Preliminar'),
                )),
                SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  onPressed: _loadingIA ? null : _analizarIA,
                  child: _loadingIA ? CircularProgressIndicator() : Text('Analizar IA'),
                )),
              ],
            ),
            SizedBox(height: 24),

            if (_resultado != null)
              Card(
                color: Colors.blueGrey[900],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clasificación Estimada', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.circle, color: _getColor(_resultado!.color)),
                          SizedBox(width: 8),
                          Text('NIVEL ${_resultado!.nivel}: ${_resultado!.color.toUpperCase()}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(_resultado!.descripcionNivel, style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 8),
                      Text('Tiempo estimado: < ${_resultado!.tiempoAtencionMaxMin} min', style: TextStyle(color: Colors.tealAccent)),
                      SizedBox(height: 8),
                      if (_resultado!.posiblesCausas.isNotEmpty) ...[
                        Text('Causas posibles:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ..._resultado!.posiblesCausas.map((c) => Text('- $c', style: TextStyle(color: Colors.white70))),
                      ],
                      SizedBox(height: 16),
                      Text(_resultado!.aviso, style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 12)),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enviado a guardia exitosamente')));
                          },
                          icon: Icon(Icons.local_hospital),
                          label: Text('Conectar con Guardia'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        ),
                      )
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
