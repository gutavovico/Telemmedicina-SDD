class TriageResponse {
  final int nivel;
  final String color;
  final String descripcionNivel;
  final int tiempoAtencionMaxMin;
  final List<String> posiblesCausas;
  final List<String> recomendaciones;
  final String motivoClasificacion;
  final String aviso;

  TriageResponse({
    required this.nivel,
    required this.color,
    required this.descripcionNivel,
    required this.tiempoAtencionMaxMin,
    required this.posiblesCausas,
    required this.recomendaciones,
    required this.motivoClasificacion,
    required this.aviso,
  });

  factory TriageResponse.fromJson(Map<String, dynamic> json) {
    return TriageResponse(
      nivel: json['nivel'] as int,
      color: json['color'] as String,
      descripcionNivel: json['descripcion_nivel'] as String,
      tiempoAtencionMaxMin: json['tiempo_atencion_max_min'] as int,
      posiblesCausas: List<String>.from(json['posibles_causas'] ?? []),
      recomendaciones: List<String>.from(json['recomendaciones'] ?? []),
      motivoClasificacion: json['motivo_clasificacion'] as String,
      aviso: json['aviso'] as String? ?? 'Orientacin preliminar, no sustituye una evaluacin mdica.',
    );
  }
}
