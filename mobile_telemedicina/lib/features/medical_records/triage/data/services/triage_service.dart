import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_telemedicina/core/config/api_config.dart';
import '../models/triage_model.dart';
import 'dart:io';

class TriageService {
  Future<TriageResponse> calcularPreliminar(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/triaje/preliminar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return TriageResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to calculate preliminar triage');
    }
  }

  Future<TriageResponse> analizarIA(Map<String, dynamic> data, List<File> files) async {
    var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/triaje/analizar'));
    
    request.fields['motivo'] = data['motivo'];
    request.fields['intensidad_dolor'] = data['intensidad_dolor'].toString();
    request.fields['tiempo_evolucion'] = data['tiempo_evolucion'];
    request.fields['signos_alarma'] = jsonEncode(data['signos_alarma']);
    request.fields['consulta_directa'] = data['consulta_directa'];

    for (var file in files) {
      request.files.add(await http.MultipartFile.fromPath('evidencia', file.path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return TriageResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze with IA: ${response.body}');
    }
  }

  Future<void> derivarGuardia(int id) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/triaje/$id/derivar'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to derive to ER');
    }
  }
}
