import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/features/treatments/data/utils/canonical_json_hasher.dart';

void main() {
  group('CanonicalJsonHasher (CU17) - Vectores Pydantic v2', () {
    test('Vector 1: Dosis OMITIDA sin efectiva_en y sin nota', () {
      const expectedJson =
          '{"efectiva_en":null,"estado":"OMITIDA","nota":null}';
      const expectedHash =
          'e1c957e50de95d78022e7ea6c9a47da8c7e9e79e0e5bbdd9992bc79c25a9c1bf';

      final json = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'OMITIDA',
        efectivaEn: null,
        nota: null,
      );
      final hash = CanonicalJsonHasher.hashDoseRegistration(
        estado: 'OMITIDA',
        efectivaEn: null,
        nota: null,
      );

      expect(json, equals(expectedJson));
      expect(hash, equals(expectedHash));
    });

    test('Vector 2: Dosis POSPUESTA sin efectiva_en y con nota con tilde', () {
      const expectedJson =
          '{"efectiva_en":null,"estado":"POSPUESTA","nota":"Aplazado por reunión"}';
      const expectedHash =
          '2a9952bf6560d9440005915c3ec2596c5d5e5297638f21dd4feb5b52e42f301a';

      final json = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'POSPUESTA',
        efectivaEn: null,
        nota: 'Aplazado por reunión',
      );
      final hash = CanonicalJsonHasher.hashDoseRegistration(
        estado: 'POSPUESTA',
        efectivaEn: null,
        nota: 'Aplazado por reunión',
      );

      expect(json, equals(expectedJson));
      expect(hash, equals(expectedHash));
    });

    test('Vector 3: Dosis INGERIDA con fecha con offset y nota con tildes', () {
      const expectedJson =
          '{"efectiva_en":"2026-11-01T10:08:00-04:00","estado":"INGERIDA","nota":"Náusea leve"}';
      const expectedHash =
          '97473bc2d514a9780f07a3156dbe337a5453901a5795020fbd8c4de5b524eb43';

      final json = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T10:08:00-04:00',
        nota: 'Náusea leve',
      );
      final hash = CanonicalJsonHasher.hashDoseRegistration(
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T10:08:00-04:00',
        nota: 'Náusea leve',
      );

      expect(json, equals(expectedJson));
      expect(hash, equals(expectedHash));
    });

    test('Vector 4: Dosis INGERIDA UTC Z (desde 2026-11-01T14:08:00Z o .000Z)', () {
      const expectedJson =
          '{"efectiva_en":"2026-11-01T14:08:00Z","estado":"INGERIDA","nota":null}';
      const expectedHash =
          '9a3978548168a501ead22e7318cec77a913fb34114318b54da334d4696614515';

      // Con String ISO exacto
      final jsonZ = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T14:08:00Z',
        nota: null,
      );
      expect(jsonZ, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEn: '2026-11-01T14:08:00Z',
          nota: null,
        ),
        equals(expectedHash),
      );

      // Con String ISO con .000Z (debe normalizarse a sin microsegundos)
      final jsonMillis0 = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T14:08:00.000Z',
        nota: null,
      );
      expect(jsonMillis0, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEn: '2026-11-01T14:08:00.000Z',
          nota: null,
        ),
        equals(expectedHash),
      );

      // Con DateTime UTC directo (sin microsegundos)
      final dt = DateTime.utc(2026, 11, 1, 14, 8, 0);
      final jsonDt = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEnDateTime: dt,
        nota: null,
      );
      expect(jsonDt, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEnDateTime: dt,
          nota: null,
        ),
        equals(expectedHash),
      );
    });

    test('Vector 5: Dosis INGERIDA con milisegundos .500Z (6 dígitos .500000Z)', () {
      const expectedJson =
          '{"efectiva_en":"2026-11-01T14:08:00.500000Z","estado":"INGERIDA","nota":"Test"}';
      const expectedHash =
          '292f66a48f7ded90fa2242ac26fcc48362e82dc0fca60b0c9bf99e16072bee7d';

      // Con String ISO .500Z
      final jsonIso = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T14:08:00.500Z',
        nota: 'Test',
      );
      expect(jsonIso, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEn: '2026-11-01T14:08:00.500Z',
          nota: 'Test',
        ),
        equals(expectedHash),
      );

      // Con DateTime UTC directo con 500 ms
      final dt = DateTime.utc(2026, 11, 1, 14, 8, 0, 500);
      final jsonDt = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEnDateTime: dt,
        nota: 'Test',
      );
      expect(jsonDt, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEnDateTime: dt,
          nota: 'Test',
        ),
        equals(expectedHash),
      );
    });

    test('Vector 6: Dosis INGERIDA con microsegundos .123456Z', () {
      const expectedJson =
          '{"efectiva_en":"2026-11-01T14:08:00.123456Z","estado":"INGERIDA","nota":"Micros"}';
      const expectedHash =
          'd03dde740e16850ea0cfc7f00d8af3119fb73dc6240a4d6e614ef6bbaa16c88c';

      // Con String ISO
      final jsonIso = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEn: '2026-11-01T14:08:00.123456Z',
        nota: 'Micros',
      );
      expect(jsonIso, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEn: '2026-11-01T14:08:00.123456Z',
          nota: 'Micros',
        ),
        equals(expectedHash),
      );

      // Con DateTime UTC directo con microsegundos
      final dt = DateTime.utc(2026, 11, 1, 14, 8, 0, 123, 456);
      final jsonDt = CanonicalJsonHasher.buildDoseRegistrationJson(
        estado: 'INGERIDA',
        efectivaEnDateTime: dt,
        nota: 'Micros',
      );
      expect(jsonDt, equals(expectedJson));
      expect(
        CanonicalJsonHasher.hashDoseRegistration(
          estado: 'INGERIDA',
          efectivaEnDateTime: dt,
          nota: 'Micros',
        ),
        equals(expectedHash),
      );
    });

    test('normalizeIsoDateTime maneja correctamente offsets UTC (+00:00) y formatos variados', () {
      expect(CanonicalJsonHasher.normalizeIsoDateTime(null), isNull);
      expect(CanonicalJsonHasher.normalizeIsoDateTime(''), isNull);
      expect(
        CanonicalJsonHasher.normalizeIsoDateTime('2026-11-01T14:08:00+00:00'),
        equals('2026-11-01T14:08:00Z'),
      );
      expect(
        CanonicalJsonHasher.normalizeIsoDateTime('2026-11-01T14:08:00.000+00:00'),
        equals('2026-11-01T14:08:00Z'),
      );
      expect(
        CanonicalJsonHasher.normalizeIsoDateTime('2026-11-01T10:08:00-0400'),
        equals('2026-11-01T10:08:00-04:00'),
      );
      expect(
        CanonicalJsonHasher.normalizeIsoDateTime('2026-11-01 10:08:00-04:00'),
        equals('2026-11-01T10:08:00-04:00'),
      );
    });

    test('Serialización canónica ordena claves anidadas arbitrarias', () {
      final input = {
        'z': 1,
        'a': {
          'd': 'cuatro',
          'b': [2, 1],
        },
      };
      final canonical = CanonicalJsonHasher.serialize(input);
      expect(canonical, equals('{"a":{"b":[2,1],"d":"cuatro"},"z":1}'));
    });
  });
}
