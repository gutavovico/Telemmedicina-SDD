import { HttpEventType, provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { environment } from '../../../../../../environments/environment';
import { EventoSubida } from '../models/laboratory-sync.models';
import { archivoDemo, fuenteDemo, listaFuentesDemo, listaSyncDemo, manifiestoDemo, resumenSyncDemo, syncDemo } from '../testing/lab-sync.testing';
import { LaboratorySyncService } from './laboratory-sync.service';

const FUENTES = `${environment.apiUrl}/api/v1/fuentes-laboratorio`;
const SYNC = `${environment.apiUrl}/api/v1/sincronizaciones-laboratorio`;

describe('LaboratorySyncService', () => {
  let servicio: LaboratorySyncService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    servicio = TestBed.inject(LaboratorySyncService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  describe('fuentes', () => {
    it('listarFuentes usa la ruta del contrato con paginación por defecto y omite el filtro vacío', () => {
      servicio.listarFuentes({ activa: '' }).subscribe();
      const req = http.expectOne((r) => r.url === FUENTES);
      expect(req.request.method).toBe('GET');
      expect(req.request.params.keys().sort()).toEqual(['page', 'page_size']);
      expect(req.request.params.get('page')).toBe('1');
      expect(req.request.params.get('page_size')).toBe('10');
      req.flush(listaFuentesDemo([fuenteDemo()]));
    });

    it('listarFuentes envía el filtro activa', () => {
      servicio.listarFuentes({ activa: 'SI', page: 2, page_size: 100 }).subscribe();
      const req = http.expectOne((r) => r.url === FUENTES);
      expect(req.request.params.get('activa')).toBe('SI');
      expect(req.request.params.get('page')).toBe('2');
      expect(req.request.params.get('page_size')).toBe('100');
      req.flush(listaFuentesDemo([]));
    });

    it('crearFuente envía solo codigo y nombre (sin id_clinica ni tenant_id) y recorta espacios', () => {
      servicio.crearFuente({ codigo: ' lab-central ', nombre: ' Laboratorio Central ' }).subscribe((f) => expect(f.codigo).toBe('LAB-CENTRAL'));
      const req = http.expectOne(FUENTES);
      expect(req.request.method).toBe('POST');
      expect(req.request.body).toEqual({ codigo: 'lab-central', nombre: 'Laboratorio Central' });
      expect(Object.keys(req.request.body as object)).toEqual(['codigo', 'nombre']);
      req.flush(fuenteDemo());
    });

    it('actualizarFuente usa PATCH sobre la fuente y solo lo indicado', () => {
      servicio.actualizarFuente(2, { activa: 'NO' }).subscribe();
      const req = http.expectOne(`${FUENTES}/2`);
      expect(req.request.method).toBe('PATCH');
      expect(req.request.body).toEqual({ activa: 'NO' });
      req.flush(fuenteDemo({ activa: 'NO' }));
    });
  });

  describe('sincronizaciones', () => {
    it('listarSincronizaciones envía solo los filtros presentes', () => {
      servicio.listarSincronizaciones({ estado: '', id_fuente: null }).subscribe();
      const vacio = http.expectOne((r) => r.url === SYNC);
      expect(vacio.request.params.keys().sort()).toEqual(['page', 'page_size']);
      vacio.flush(listaSyncDemo([resumenSyncDemo()]));

      servicio
        .listarSincronizaciones({ page: 3, page_size: 5, id_fuente: 2, estado: 'FALLIDA', fecha_desde: '2026-11-01', fecha_hasta: '2026-11-30' })
        .subscribe();
      const completo = http.expectOne((r) => r.url === SYNC);
      const p = completo.request.params;
      expect([p.get('page'), p.get('page_size'), p.get('id_fuente'), p.get('estado'), p.get('fecha_desde'), p.get('fecha_hasta')]).toEqual([
        '3', '5', '2', 'FALLIDA', '2026-11-01', '2026-11-30',
      ]);
      completo.flush(listaSyncDemo([]));
    });

    it('obtenerSincronizacion pide el detalle por id', () => {
      servicio.obtenerSincronizacion(31).subscribe((s) => expect(s.items).toHaveLength(4));
      const req = http.expectOne(`${SYNC}/31`);
      expect(req.request.method).toBe('GET');
      req.flush(syncDemo());
    });

    it('importar envía multipart con manifiesto (texto) y una parte archivos por archivo, sin fijar Content-Type', () => {
      const manifiesto = manifiestoDemo(['EXT-1', 'EXT-2']);
      const a = archivoDemo('EXT-1.pdf');
      const b = archivoDemo('EXT-2.pdf');
      servicio.importar(manifiesto, [a, b]).subscribe();
      const req = http.expectOne(SYNC);
      expect(req.request.method).toBe('POST');
      expect(req.request.reportProgress).toBe(true);
      expect(req.request.headers.has('Content-Type')).toBe(false);
      const cuerpo = req.request.body as FormData;
      expect(cuerpo).toBeInstanceOf(FormData);
      expect(typeof cuerpo.get('manifiesto')).toBe('string');
      expect(JSON.parse(cuerpo.get('manifiesto') as string)).toEqual(manifiesto);
      const partes = cuerpo.getAll('archivos') as File[];
      expect(partes.map((f) => f.name)).toEqual(['EXT-1.pdf', 'EXT-2.pdf']);
      expect([...cuerpo.keys()].sort()).toEqual(['archivos', 'archivos', 'manifiesto']);
      req.flush(syncDemo(), { status: 201, statusText: 'Created' });
    });

    it('importar nunca envía id_clinica ni tenant_id', () => {
      servicio.importar(manifiestoDemo(), [archivoDemo('EXT-1.pdf')]).subscribe();
      const req = http.expectOne(SYNC);
      const cuerpo = req.request.body as FormData;
      expect([...cuerpo.keys()]).not.toContain('id_clinica');
      expect([...cuerpo.keys()]).not.toContain('tenant_id');
      expect(cuerpo.get('manifiesto') as string).not.toMatch(/id_clinica|tenant_id/);
      req.flush(syncDemo(), { status: 201, statusText: 'Created' });
    });

    it('importar emite el progreso de subida y luego la sincronización', () => {
      const eventos: EventoSubida[] = [];
      servicio.importar(manifiestoDemo(), [archivoDemo('EXT-1.pdf')]).subscribe((e) => eventos.push(e));
      const req = http.expectOne(SYNC);
      req.event({ type: HttpEventType.UploadProgress, loaded: 250, total: 1000 });
      req.event({ type: HttpEventType.UploadProgress, loaded: 1000, total: 1000 });
      req.flush(syncDemo(), { status: 201, statusText: 'Created' });

      expect(eventos.map((e) => e.tipo)).toEqual(['progreso', 'progreso', 'respuesta']);
      expect(eventos[0]).toMatchObject({ tipo: 'progreso', porcentaje: 25, cargados: 250, total: 1000 });
      expect(eventos[1]).toMatchObject({ porcentaje: 100 });
      const ultimo = eventos[2];
      expect(ultimo.tipo === 'respuesta' && ultimo.sincronizacion.id_sincronizacion).toBe(31);
    });

    it('el progreso sin total conocido se informa como null', () => {
      const eventos: EventoSubida[] = [];
      servicio.importar(manifiestoDemo(), [archivoDemo('EXT-1.pdf')]).subscribe((e) => eventos.push(e));
      const req = http.expectOne(SYNC);
      req.event({ type: HttpEventType.UploadProgress, loaded: 500 });
      req.flush(syncDemo(), { status: 201, statusText: 'Created' });
      expect(eventos[0]).toMatchObject({ tipo: 'progreso', porcentaje: null, total: null });
    });

    it('reintentar usa la ruta de reintentos de la sincronización con multipart', () => {
      const manifiesto = manifiestoDemo(['EXT-9']);
      servicio.reintentar(31, manifiesto, [archivoDemo('EXT-9.pdf')]).subscribe();
      const req = http.expectOne(`${SYNC}/31/reintentos`);
      expect(req.request.method).toBe('POST');
      expect(req.request.headers.has('Content-Type')).toBe(false);
      const cuerpo = req.request.body as FormData;
      expect(JSON.parse(cuerpo.get('manifiesto') as string)).toEqual(manifiesto);
      expect((cuerpo.getAll('archivos') as File[]).map((f) => f.name)).toEqual(['EXT-9.pdf']);
      req.flush(syncDemo(), { status: 200, statusText: 'OK' });
    });

    it('propaga el error del servidor para que la pantalla lo interprete', () => {
      let status = 0;
      servicio.importar(manifiestoDemo(), [archivoDemo('EXT-1.pdf')]).subscribe({ error: (e: { status: number }) => (status = e.status) });
      http.expectOne(SYNC).flush({ detail: { codigo: 'LOTE_INVALIDO', mensaje: 'x' } }, { status: 422, statusText: 'Unprocessable' });
      expect(status).toBe(422);
    });
  });
});
