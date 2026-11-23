import 'dart:convert';

// JSON shapes from openspec/contracts/analytics.md.
class CatalogReport {
  final String id, titulo, metricaPrincipal, semantica;
  final List<String> dimensiones, columnas, ordenables, metricas;
  final List<String> filtros;
  CatalogReport(Map<String, dynamic> json)
      : id = json['id'] as String,
        titulo = json['titulo'] as String,
        metricaPrincipal = json['metrica_principal'] as String,
        semantica = json['semantica'] as String,
        dimensiones = List<String>.from(json['dimensiones'] as List),
        columnas = List<String>.from(json['columnas'] as List),
        ordenables = List<String>.from(json['ordenables'] as List),
        metricas = List<String>.from(json['metricas'] as List),
        filtros = (json['filtros'] as List)
            .map((item) => (item as Map<String, dynamic>)['campo'] as String).toList();
}

class ReportCatalog {
  final List<CatalogReport> reportes;
  final List<String> formatos, modalidades;
  final Map<String, int> limites;
  final Map<String, String> categoriasNulas;
  final Map<String, ReportMetric> metricasNoDisponibles;
  ReportCatalog(Map<String, dynamic> json)
      : reportes = (json['reportes'] as List)
            .map((item) => CatalogReport(item as Map<String, dynamic>)).toList(),
        formatos = List<String>.from(json['formatos'] as List),
        modalidades = List<String>.from(json['modalidades'] as List),
        limites = (json['limites'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, value as int)),
        categoriasNulas = (json['categorias_nulas'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as String)),
        metricasNoDisponibles = (json['metricas_no_disponibles'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, ReportMetric(value as Map<String, dynamic>)));
}

class ReportOptions {
  final List<Map<String, dynamic>> medicos, especialidades;
  ReportOptions(Map<String, dynamic> json)
      : medicos = (json['medicos'] as List).cast<Map<String, dynamic>>(),
        especialidades = (json['especialidades'] as List).cast<Map<String, dynamic>>();
}

class ReportFilter {
  final String campo;
  final Object valor;
  const ReportFilter(this.campo, this.valor);
  Map<String, dynamic> toJson() => {'campo': campo, 'operador': 'eq', 'valor': valor};
  factory ReportFilter.fromJson(Map<String, dynamic> json) {
    if (json['operador'] != 'eq') {
      throw const FormatException('Operador de filtro no admitido.');
    }
    return ReportFilter(json['campo'] as String, json['valor'] as Object);
  }
}

class ReportSort {
  final String campo, direccion;
  const ReportSort(this.campo, this.direccion);
  Map<String, dynamic> toJson() => {'campo': campo, 'direccion': direccion};
  factory ReportSort.fromJson(Map<String, dynamic> json) =>
      ReportSort(json['campo'] as String, json['direccion'] as String);
}

class ReportQuery {
  final String reporte, desde, hasta;
  final List<ReportFilter> filtros;
  final List<String> columnas, agrupacion;
  final List<ReportSort> orden;
  final int pagina, tamanoPagina;
  const ReportQuery({required this.reporte, required this.desde, required this.hasta,
    this.filtros = const [], this.columnas = const [], this.agrupacion = const [],
    this.orden = const [], this.pagina = 1, this.tamanoPagina = 20});

  ReportQuery copyWith({String? reporte, String? desde, String? hasta,
    List<ReportFilter>? filtros, List<String>? columnas, List<String>? agrupacion,
    List<ReportSort>? orden, int? pagina, int? tamanoPagina}) => ReportQuery(
      reporte: reporte ?? this.reporte, desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta, filtros: filtros ?? this.filtros,
      columnas: columnas ?? this.columnas, agrupacion: agrupacion ?? this.agrupacion,
      orden: orden ?? this.orden, pagina: pagina ?? this.pagina,
      tamanoPagina: tamanoPagina ?? this.tamanoPagina);

  Map<String, dynamic> toJson() => {
    'reporte': reporte, 'periodo': {'desde': desde, 'hasta': hasta},
    'filtros': filtros.map((item) => item.toJson()).toList(),
    'columnas': columnas, 'agrupacion': agrupacion,
    'orden': orden.map((item) => item.toJson()).toList(),
    'pagina': pagina, 'tamano_pagina': tamanoPagina,
  };
  bool sameDefinition(ReportQuery other) =>
      jsonEncode(copyWith(pagina: 1).toJson()) ==
      jsonEncode(other.copyWith(pagina: 1).toJson());
  factory ReportQuery.fromJson(Map<String, dynamic> json) {
    final period = json['periodo'] as Map<String, dynamic>;
    return ReportQuery(reporte: json['reporte'] as String,
      desde: period['desde'] as String, hasta: period['hasta'] as String,
      filtros: (json['filtros'] as List).map((item) =>
        ReportFilter.fromJson(item as Map<String, dynamic>)).toList(),
      columnas: List<String>.from(json['columnas'] as List),
      agrupacion: List<String>.from(json['agrupacion'] as List),
      orden: (json['orden'] as List).map((item) =>
        ReportSort.fromJson(item as Map<String, dynamic>)).toList(),
      pagina: json['pagina'] as int, tamanoPagina: json['tamano_pagina'] as int);
  }
}

class ReportMetric {
  final bool disponible;
  final int? valor;
  final String? causa;
  ReportMetric(Map<String, dynamic> json)
      : disponible = json['disponible'] as bool,
        valor = json['valor'] as int?, causa = json['causa'] as String?;
  String get display => disponible && valor != null ? '$valor' : 'No disponible';
}

class ReportResult {
  final ReportQuery definicion;
  final String semantica, generadoEn;
  final Map<String, ReportMetric> metricas;
  final int total;
  final List<Map<String, dynamic>> filas;
  final List<String> advertencias;
  ReportResult(Map<String, dynamic> json)
      : definicion = ReportQuery.fromJson(json['definicion'] as Map<String, dynamic>),
        semantica = json['semantica'] as String,
        generadoEn = json['generado_en'] as String,
        metricas = (json['metricas'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, ReportMetric(value as Map<String, dynamic>))),
        total = json['total'] as int,
        filas = (json['filas'] as List).cast<Map<String, dynamic>>(),
        advertencias = List<String>.from(json['advertencias'] as List);
}

class ReportInterpretation {
  final String estado, resumen;
  final ReportQuery? definicion;
  final List<String> camposAclaracion, advertencias;

  ReportInterpretation(Map<String, dynamic> json)
      : estado = json['estado'] as String,
        resumen = json['resumen'] as String,
        definicion = json['definicion'] == null ? null : ReportQuery.fromJson(
          json['definicion'] as Map<String, dynamic>),
        camposAclaracion = List<String>.from(json['campos_aclaracion'] as List),
        advertencias = List<String>.from(json['advertencias'] as List) {
    if (!const {'valida', 'aclaracion', 'no_admitida'}.contains(estado) ||
        (estado == 'valida') != (definicion != null)) {
      throw const FormatException('Respuesta de interpretación incompatible.');
    }
  }
}
