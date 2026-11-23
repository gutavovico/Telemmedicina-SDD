import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/medical_records/data/models/patient_model.dart';

void main() {
  group('PatientModel Serialization & Methods Suite', () {
    test('Deserializes correctly from JSON matching API Contract', () {
      final json = {
        'id_paciente': 1,
        'id_usuario': 12,
        'nombres': 'Carlos Alberto',
        'apellidos': 'Mamani Terrazas',
        'ci': '7891234',
        'complemento': 'LP',
        'fecha_nacimiento': '1990-05-15',
        'genero': 'M',
        'telefono': '+591 71234567',
        'correo': 'carlos.mamani@email.com',
        'direccion': 'Av. Banzer 4to Anillo',
        'ciudad': 'Santa Cruz de la Sierra',
        'tipo_sangre': 'O+',
        'alergias': 'Penicilina, AINEs',
        'antecedentes_patologicos': 'Asma en la infancia',
        'contacto_emergencia_nombre': 'Maria Terrazas',
        'contacto_emergencia_telefono': '+591 79876543',
        'contacto_emergencia_parentesco': 'Madre',
        'seguro_medico': 'Seguro Universitario',
        'numero_seguro': 'SU-98765',
        'estado': 'ACTIVO',
        'created_at': '2026-08-24T12:00:00Z',
        'updated_at': '2026-08-24T12:00:00Z',
      };

      final patient = PatientModel.fromJson(json);

      expect(patient.idPaciente, 1);
      expect(patient.idUsuario, 12);
      expect(patient.fullName, 'Carlos Alberto Mamani Terrazas');
      expect(patient.ci, '7891234');
      expect(patient.complemento, 'LP');
      expect(patient.tipoSangre, 'O+');
      expect(patient.estado, 'ACTIVO');
      expect(patient.age, greaterThanOrEqualTo(35));
      expect(patient.contactoEmergenciaNombre, 'Maria Terrazas');
    });

    test('Serializes to JSON correctly', () {
      final patient = PatientModel(
        idPaciente: 2,
        nombres: 'Ana',
        apellidos: 'Gutiérrez',
        ci: '9876543',
        fechaNacimiento: '1995-08-20',
        genero: 'F',
        telefono: '+591 71112222',
        estado: 'ACTIVO',
      );

      final json = patient.toJson();

      expect(json['id_paciente'], 2);
      expect(json['nombres'], 'Ana');
      expect(json['apellidos'], 'Gutiérrez');
      expect(json['ci'], '9876543');
      expect(json['genero'], 'F');
      expect(json['telefono'], '+591 71112222');
      expect(json['estado'], 'ACTIVO');
    });

    test('copyWith updates specific fields properly', () {
      final patient = PatientModel(
        idPaciente: 1,
        nombres: 'Carlos',
        apellidos: 'Mamani',
        ci: '7891234',
        fechaNacimiento: '1990-05-15',
        genero: 'M',
        telefono: '+591 71234567',
        estado: 'ACTIVO',
      );

      final updated = patient.copyWith(
        telefono: '+591 70099888',
        direccion: 'Barrio Equipetrol',
        contactoEmergenciaNombre: 'Roberto Mamani',
      );

      expect(updated.telefono, '+591 70099888');
      expect(updated.direccion, 'Barrio Equipetrol');
      expect(updated.contactoEmergenciaNombre, 'Roberto Mamani');
      expect(updated.nombres, 'Carlos');
      expect(updated.ci, '7891234');
    });
  });
}
