import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { environment } from '../../../../../../environments/environment';
import { interpretarErrorResultado } from '../utils/laboratory-result-errors';
import { detalleDemo, listaDemo, resumenDemo } from '../testing/lab-result.testing';
import { LaboratoryResultsService } from './laboratory-results.service';

const BASE = `${environment.apiUrl}/api/v1/resultados-laboratorio`;

describe('LaboratoryResultsService', () => {
  let servicio: LaboratoryResultsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    servicio = TestBed.inject(LaboratoryResultsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  describe('listados', () => {
    it('listar usa la ruta del contrato con paginación por defecto y omite filtros vacíos', () => {
      servicio.listar({ codigo_examen: ' ', laboratorio_origen: '', origen: '', estado: '' }).subscribe();
      const req = http.expectOne((r) => r.url === BASE);
      expect(req.request.method).toBe('GET');
      expect(req.request.params.get('page')).toBe('1');
      expect(req.request.params.get('page_size')).toBe('10');
      expect(req.request.params.keys().sort()).toEqual(['page', 'page_size']);
      req.flush(listaDemo([resumenDemo()]));
    });

    it('listar envía los filtros del contrato', () => {
      servicio
        .listar({
          page: 2, page_size: 5, id_paciente: 10, id_fuente: 3, codigo_examen: ' HEMOGRAMA ',
          laboratorio_origen: 'Central', origen: 'MANUAL', estado: 'PENDIENTE_REVISION',
          fecha_desde: '2026-11-01', fecha_hasta: '2026-11-30',
        })
        .subscribe();
      const req = http.expectOne((r) => r.url === BASE);
      const p = req.request.params;
      expect(p.get('page')).toBe('2');
      expect(p.get('page_size')).toBe('5');
      expect(p.get('id_paciente')).toBe('10');
      expect(p.get('id_fuente')).toBe('3');
      expect(p.get('codigo_examen')).toBe('HEMOGRAMA');
      expect(p.get('laboratorio_origen')).toBe('Central');
      expect(p.get('origen')).toBe('MANUAL');
      expect(p.get('estado')).toBe('PENDIENTE_REVISION');
      expect(p.get('fecha_desde')).toBe('2026-11-01');
      expect(p.get('fecha_hasta')).toBe('2026-11-30');
      req.flush(listaDemo([]));
    });

    it('listarDePaciente usa el expediente y no repite el paciente ni el estado', () => {
      servicio.listarDePaciente(10, { id_paciente: 99, estado: 'ANULADO', codigo_examen: 'HEMOGRAMA' }).subscribe();
      const req = http.expectOne((r) => r.url === `${environment.apiUrl}/api/v1/pacientes/10/resultados-laboratorio`);
      expect(req.request.params.has('id_paciente')).toBe(false);
      expect(req.request.params.has('estado')).toBe(false);
      expect(req.request.params.get('codigo_examen')).toBe('HEMOGRAMA');
      req.flush(listaDemo([]));
    });

    it('listarPropios usa /me con los filtros permitidos por el contrato', () => {
      servicio.listarPropios({ codigo_examen: 'GLUCOSA', origen: 'MANUAL', laboratorio_origen: 'x', fecha_desde: '2026-01-01' }).subscribe();
      const req = http.expectOne((r) => r.url === `${BASE}/me`);
      expect(req.request.params.get('codigo_examen')).toBe('GLUCOSA');
      expect(req.request.params.get('fecha_desde')).toBe('2026-01-01');
      expect(req.request.params.has('origen')).toBe(false);
      expect(req.request.params.has('laboratorio_origen')).toBe(false);
      req.flush(listaDemo([]));
    });

    it('obtener pide el detalle por identificador', () => {
      servicio.obtener(15).subscribe((r) => expect(r.observaciones).toBe('Muestra en ayunas'));
      const req = http.expectOne(`${BASE}/15`);
      expect(req.request.method).toBe('GET');
      req.flush(detalleDemo());
    });
  });

  describe('cargarManual', () => {
    function archivo(): File {
      return new File(['%PDF-1.4'], 'hemograma.pdf', { type: 'application/pdf' });
    }

    it('envía multipart/form-data sin fijar Content-Type y solo con los campos del contrato', () => {
      servicio
        .cargarManual({
          id_paciente: 10,
          codigo_examen: ' HEMOGRAMA ',
          fecha_realizacion: '2026-11-10',
          laboratorio_origen: ' Laboratorio Central ',
          id_orden: 7,
          observaciones: ' Muestra en ayunas ',
          archivo: archivo(),
        })
        .subscribe();
      const req = http.expectOne(BASE);
      expect(req.request.method).toBe('POST');
      expect(req.request.body).toBeInstanceOf(FormData);
      expect(req.request.headers.has('Content-Type')).toBe(false);
      const cuerpo = req.request.body as FormData;
      expect(Array.from(cuerpo.keys()).sort()).toEqual([
        'archivo', 'codigo_examen', 'fecha_realizacion', 'id_orden', 'id_paciente', 'laboratorio_origen', 'observaciones',
      ]);
      expect(cuerpo.get('id_paciente')).toBe('10');
      expect(cuerpo.get('codigo_examen')).toBe('HEMOGRAMA');
      expect(cuerpo.get('laboratorio_origen')).toBe('Laboratorio Central');
      expect(cuerpo.get('observaciones')).toBe('Muestra en ayunas');
      expect((cuerpo.get('archivo') as File).name).toBe('hemograma.pdf');
      req.flush(detalleDemo());
    });

    it('omite orden y observaciones vacías y nunca envía id_clinica, tenant_id, estado ni origen', () => {
      servicio
        .cargarManual({
          id_paciente: 10, codigo_examen: 'HEMOGRAMA', fecha_realizacion: '2026-11-10',
          laboratorio_origen: 'Central', id_orden: null, observaciones: '   ', archivo: archivo(),
        })
        .subscribe();
      const req = http.expectOne(BASE);
      const claves = Array.from((req.request.body as FormData).keys());
      expect(claves).not.toContain('id_orden');
      expect(claves).not.toContain('observaciones');
      for (const prohibido of ['id_clinica', 'tenant_id', 'estado', 'origen']) {
        expect(claves).not.toContain(prohibido);
      }
      req.flush(detalleDemo());
    });

    it('propaga el error del servidor para que la pantalla lo muestre', () => {
      let mensaje = '';
      servicio
        .cargarManual({
          id_paciente: 10, codigo_examen: 'HEMOGRAMA', fecha_realizacion: '2026-11-10',
          laboratorio_origen: 'Central', archivo: archivo(),
        })
        .subscribe({ error: (e: unknown) => (mensaje = interpretarErrorResultado(e).mensaje) });
      http.expectOne(BASE).flush(
        { detail: { codigo: 'RESULTADO_DUPLICADO', mensaje: 'Ya existe' } },
        { status: 409, statusText: 'Conflict' },
      );
      expect(mensaje).toContain('mismo archivo');
    });
  });

  describe('descargar', () => {
    it('pide un Blob autenticado y usa el Content-Type y el nombre reales devueltos', () => {
      let recibido: { contentType: string; nombre: string; size: number } | null = null;
      servicio.descargar(15).subscribe((a) => (recibido = { contentType: a.contentType, nombre: a.nombre, size: a.blob.size }));
      const req = http.expectOne(`${BASE}/15/archivo`);
      expect(req.request.method).toBe('GET');
      expect(req.request.responseType).toBe('blob');
      req.flush(new Blob(['PNGDATA'], { type: 'image/png' }), {
        headers: {
          'Content-Type': 'image/png',
          'Content-Disposition': `attachment; filename="imagen.png"; filename*=UTF-8''imagen.png`,
        },
      });
      expect(recibido).toEqual({ contentType: 'image/png', nombre: 'imagen.png', size: 7 });
    });

    it('usa el tipo del Blob y un nombre de respaldo si faltan las cabeceras', () => {
      let recibido: { contentType: string; nombre: string } | null = null;
      servicio.descargar(9).subscribe((a) => (recibido = { contentType: a.contentType, nombre: a.nombre }));
      http.expectOne(`${BASE}/9/archivo`).flush(new Blob(['x'], { type: 'application/pdf' }));
      expect(recibido).toEqual({ contentType: 'application/pdf', nombre: 'resultado-9' });
    });

    it('convierte el Blob de un error en el JSON del servidor', async () => {
      const resultado = new Promise<string | null>((resolver) => {
        servicio.descargar(15).subscribe({
          error: (e: unknown) => resolver(interpretarErrorResultado(e).codigo),
        });
      });
      http.expectOne(`${BASE}/15/archivo`).flush(
        new Blob([JSON.stringify({ detail: { codigo: 'ARCHIVO_NO_ENCONTRADO', mensaje: 'x' } })], { type: 'application/json' }),
        { status: 404, statusText: 'Not Found' },
      );
      expect(await resultado).toBe('ARCHIVO_NO_ENCONTRADO');
    });
  });

  describe('revisión', () => {
    it('resolver ASIGNAR envía solo los campos del contrato', () => {
      servicio.resolver(15, { accion: 'ASIGNAR', id_paciente: 10, codigo_examen: 'HEMOGRAMA', id_orden: 7 }).subscribe();
      const req = http.expectOne(`${BASE}/15/resolver`);
      expect(req.request.method).toBe('POST');
      expect(req.request.body).toEqual({ accion: 'ASIGNAR', id_paciente: 10, codigo_examen: 'HEMOGRAMA', id_orden: 7 });
      req.flush(detalleDemo());
    });

    it('resolver DESCARTAR envía el motivo', () => {
      servicio.resolver(15, { accion: 'DESCARTAR', motivo: 'Corresponde a otra institución' }).subscribe();
      const req = http.expectOne(`${BASE}/15/resolver`);
      expect(req.request.body).toEqual({ accion: 'DESCARTAR', motivo: 'Corresponde a otra institución' });
      req.flush(detalleDemo({ estado: 'ANULADO' }));
    });

    it('anular envía el motivo', () => {
      servicio.anular(15, { motivo: 'Cargado en el paciente equivocado' }).subscribe();
      const req = http.expectOne(`${BASE}/15/anular`);
      expect(req.request.method).toBe('POST');
      expect(req.request.body).toEqual({ motivo: 'Cargado en el paciente equivocado' });
      req.flush(detalleDemo({ estado: 'ANULADO' }));
    });
  });
});
