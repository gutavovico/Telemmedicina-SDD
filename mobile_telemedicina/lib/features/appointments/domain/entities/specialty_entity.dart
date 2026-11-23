class SpecialtyEntity {
  final int idEspecialidad;
  final String nombre;
  final String? descripcion;
  final String estado;

  const SpecialtyEntity({
    required this.idEspecialidad,
    required this.nombre,
    this.descripcion,
    required this.estado,
  });
}
