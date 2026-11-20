import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { Subject, of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { EventoSubida } from '../../models/laboratory-sync.models';
import { LaboratoryResultAccessService } from '../../services/laboratory-result-access.service';
import { LaboratorySyncService } from '../../services/laboratory-sync.service';
import { accesoFalso } from '../../testing/lab-result.testing';
import { archivoDemo, itemManifiestoDemo, itemSyncDemo, manifiestoDemo, syncDemo } from '../../testing/lab-sync.testing';
import { guardarManifiesto } from '../../utils/laboratory-sync-cache';
import { LaboratorySyncDetail } from './laboratory-sync-detail';

function errorHttp(status: number, cuerpo: unknown): HttpErrorResponse {
  return new HttpErrorResponse({ status, error: cuerpo, statusText: 'x' });
}

const ID_ERROR = 'LAB-2026-000125';

describe('LaboratorySyncDetail', () => {
  let fixture: ComponentFixture<LaboratorySyncDetail>;
  let componente: LaboratorySyncDetail;
  let obtenerSincronizacion: ReturnType<typeof vi.fn>;
  let reintentar: ReturnType<typeof vi.fn>;

  const raiz = () => fixture.nativeElement as HTMLElement;
  const q = (testid: string) => raiz().querySelector(`[data-testid="${testid}"]`) as HTMLElement | null;
  const celdas = (testid: string) => Array.from(raiz().querySelectorAll(`[data-testid="${testid}"]`)).map((e) => e.textContent?.trim() ?? '');

  function crear(opciones: { sincronizar?: boolean; revisar?: boolean; id?: string } = {}): void {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: convertToParamMap({ id: opciones.id ?? '31' }) } } },
        { provide: LaboratorySyncService, useValue: { obtenerSincronizacion, reintentar } },
        { provide: LaboratoryResultAccessService, useValue: accesoFalso({ leer: true, sincronizar: opciones.sincronizar ?? true, revisar: opciones.revisar ?? true }) },
      ],
    });
    fixture = TestBed.createComponent(LaboratorySyncDetail);
    componente = fixture.componentInstance;
    fixture.detectChanges();
  }

  beforeEach(() => {
    sessionStorage.clear();
    obtenerSincronizacion = vi.fn(() => of(syncDemo()));
    reintentar = vi.fn(() =>
      of({
        tipo: 'respuesta',
        sincronizacion: syncDemo({
          estado: 'COMPLETADA', incorporados: 2, con_error: 0, reintentos: 1,
          items: syncDemo().items.map((i) => (i.id_externo === ID_ERROR ? itemSyncDemo(ID_ERROR, { intento: 2, id_resultado: 40 }) : i)),
        }),
      } satisfies EventoSubida),
    );
  });

  describe('informe', () => {
    it('muestra el estado, los totales y una fila por ítem con código, mensaje e intento', () => {
      crear();
      expect(obtenerSincronizacion).toHaveBeenCalledWith(31);
      expect(q('fuente')?.textContent).toContain('LAB-CENTRAL');
      expect(raiz().querySelector('[data-testid="estado-sync"]')?.textContent).toContain('Completada con errores');
      expect([q('total-items'), q('total-incorporados'), q('total-pendientes'), q('total-duplicados'), q('total-errores'), q('total-reintentos')].map((e) => e?.textContent?.trim())).toEqual(
        ['4', '1', '1', '1', '1', '0'],
      );
      expect(celdas('item-id')).toEqual(['LAB-2026-000123', 'LAB-2026-000124', 'LAB-2026-000100', ID_ERROR]);
      // El texto de cada insignia incluye el nombre del icono (visible solo como glifo): se compara el final.
      const estados = Array.from(raiz().querySelectorAll('[data-testid="fila-item"] [data-testid="estado-sync"]')).map((e) => e.textContent?.replace(/\s+/g, ' ').trim() ?? '');
      expect(estados.map((e) => e.replace(/^\S+ /, ''))).toEqual(['Incorporado', 'Pendiente de revisión', 'Duplicado', 'Error']);
      const detalles = celdas('item-detalle');
      expect(detalles[1]).toContain('PACIENTE_NO_ENCONTRADO');
      expect(detalles[1]).toContain('No se encontró un paciente');
      expect(detalles[3]).toContain('ARCHIVO_TIPO_NO_PERMITIDO');
      expect(detalles[3]).toContain('El archivo debe ser PDF, JPG o PNG.');
      expect(celdas('item-intento')).toEqual(['1', '1', '1', '1']);
    });

    it.each([
      ['COMPLETADA', 'Completada'],
      ['COMPLETADA_CON_ERRORES', 'Completada con errores'],
      ['FALLIDA', 'Fallida'],
      ['EN_PROCESO', 'En proceso'],
    ] as const)('muestra el estado del lote %s', (estado, texto) => {
      obtenerSincronizacion.mockReturnValue(of(syncDemo({ estado })));
      crear();
      expect(raiz().querySelector('header [data-testid="estado-sync"]')?.textContent).toContain(texto);
      expect(q('aviso-en-proceso') !== null).toBe(estado === 'EN_PROCESO');
    });

    it('muestra el estado de carga y el error con reintento', () => {
      const pendiente = new Subject<ReturnType<typeof syncDemo>>();
      obtenerSincronizacion.mockReturnValue(pendiente);
      crear();
      expect(q('cargando')?.textContent).toContain('Cargando informe');
      pendiente.error(errorHttp(500, null));
      fixture.detectChanges();
      expect(q('error-informe')?.textContent).toContain('El servidor no pudo completar');
      expect(q('error-informe')?.querySelector('button')).not.toBeNull();
    });

    it('SINCRONIZACION_NO_ENCONTRADA (404): mensaje claro, sin reintento ni panel', () => {
      obtenerSincronizacion.mockReturnValue(throwError(() => errorHttp(404, { detail: { codigo: 'SINCRONIZACION_NO_ENCONTRADA', mensaje: 'x' } })));
      crear();
      expect(q('error-informe')?.textContent).toContain('La sincronización no existe o no pertenece a su clínica');
      expect(q('error-informe')?.querySelector('button')).toBeNull();
      expect(q('panel-reintento')).toBeNull();
    });

    it('un identificador de ruta no numérico no consulta al servidor', () => {
      crear({ id: 'abc' });
      expect(obtenerSincronizacion).not.toHaveBeenCalled();
      expect(q('error-informe')?.textContent).toContain('no es válido');
    });

    it('sin ítems registrados muestra el estado vacío', () => {
      obtenerSincronizacion.mockReturnValue(of(syncDemo({ items: [], estado: 'EN_PROCESO', con_error: 0 })));
      crear();
      expect(q('sin-items')).not.toBeNull();
    });

    it('enlaza la cola de revisión (filtrada por fuente) solo con pendientes y permiso de revisión', () => {
      crear();
      const enlace = q('enlace-revision') as HTMLAnchorElement;
      expect(enlace.textContent).toContain('1 pendiente(s)');
      expect(enlace.getAttribute('href')).toBe('/admin/resultados-laboratorio/revision?id_fuente=2');
    });

    it('no enlaza la revisión sin permiso o sin pendientes', () => {
      crear({ revisar: false });
      expect(q('enlace-revision')).toBeNull();
      TestBed.resetTestingModule();
      obtenerSincronizacion.mockReturnValue(of(syncDemo({ pendientes: 0 })));
      crear();
      expect(q('enlace-revision')).toBeNull();
    });
  });

  describe('reintento', () => {
    it('lista solo los ítems en ERROR y no ofrece nada si no hay errores o no hay permiso de sincronización', () => {
      crear();
      expect(raiz().querySelectorAll('[data-testid="item-reintentable"]')).toHaveLength(1);
      expect(q('item-reintentable')?.textContent).toContain(ID_ERROR);
      TestBed.resetTestingModule();
      obtenerSincronizacion.mockReturnValue(of(syncDemo({ items: syncDemo().items.filter((i) => i.resultado !== 'ERROR'), con_error: 0, estado: 'COMPLETADA' })));
      crear();
      expect(q('panel-reintento')).toBeNull();
      TestBed.resetTestingModule();
      obtenerSincronizacion.mockReturnValue(of(syncDemo()));
      crear({ sincronizar: false });
      expect(q('panel-reintento')).toBeNull();
    });

    it('pide el manifiesto original si no se conserva y lo usa para armar el reintento', () => {
      crear();
      expect(q('origen-faltante')).not.toBeNull();
      expect((q('btn-reintentar') as HTMLButtonElement).disabled).toBe(true);
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('corregido.pdf') });
      fixture.detectChanges();
      expect(q('errores-reintento')?.textContent).toContain('Cargue el manifiesto original');

      componente.aplicarManifiestoOrigen(JSON.stringify(manifiestoDemo(['LAB-2026-000123', ID_ERROR])));
      fixture.detectChanges();
      expect(q('origen-cargado')?.textContent).toContain('2 ítems');
      expect(q('errores-reintento')).toBeNull();
      expect((q('btn-reintentar') as HTMLButtonElement).disabled).toBe(false);
    });

    it('usa el manifiesto guardado al importar en esta pestaña', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      crear();
      expect(q('origen-cargado')?.textContent).toContain('guardado al importar');
      expect(q('origen-faltante')).toBeNull();
    });

    it('arma un manifiesto con solo el ítem en ERROR, adjunta el archivo corregido y llama a /reintentos', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      crear();
      const corregido = archivoDemo('hemograma-corregido.pdf');
      componente.correcciones.set({ [ID_ERROR]: corregido });
      fixture.detectChanges();
      expect((q('btn-reintentar') as HTMLButtonElement).textContent).toContain('Reintentar 1 ítem(s)');
      componente.reintentar();
      fixture.detectChanges();

      expect(reintentar).toHaveBeenCalledTimes(1);
      const [id, manifiesto, archivos] = reintentar.mock.calls[0] as [number, { fuente: string; items: Array<Record<string, unknown>> }, File[]];
      expect(id).toBe(31);
      expect(manifiesto.fuente).toBe('LAB-CENTRAL');
      expect(manifiesto.items).toHaveLength(1);
      expect(manifiesto.items[0]).toMatchObject({ id_externo: ID_ERROR, ci: '1234567', nombre_archivo: 'hemograma-corregido.pdf' });
      expect(JSON.stringify(manifiesto)).not.toMatch(/id_clinica|tenant_id/);
      expect(archivos).toEqual([corregido]);
    });

    it('actualiza el informe con la respuesta: contadores, estado e intento del ítem', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('c.pdf') });
      componente.reintentar();
      fixture.detectChanges();
      expect(q('exito-reintento')?.textContent).toContain('Reintento enviado: 1 ítem(s)');
      expect(q('total-errores')?.textContent?.trim()).toBe('0');
      expect(q('total-reintentos')?.textContent?.trim()).toBe('1');
      expect(raiz().querySelector('header [data-testid="estado-sync"]')?.textContent).toContain('Completada');
      expect(celdas('item-intento')[3]).toBe('2');
      expect(q('panel-reintento')).toBeNull();                 // ya no quedan ítems en ERROR
      expect(Object.keys(componente.correcciones())).toEqual([]);
    });

    it('muestra el progreso, deshabilita el botón y evita el doble envío', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      const subida = new Subject<EventoSubida>();
      reintentar.mockReturnValue(subida);
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('c.pdf') });
      componente.reintentar();
      componente.reintentar();
      subida.next({ tipo: 'progreso', porcentaje: 60, cargados: 6, total: 10 });
      fixture.detectChanges();
      expect(reintentar).toHaveBeenCalledTimes(1);
      expect(raiz().querySelector('[role="progressbar"]')?.getAttribute('aria-valuenow')).toBe('60');
      expect((q('btn-reintentar') as HTMLButtonElement).disabled).toBe(true);
    });

    it('rechaza en el cliente un archivo corregido inválido o repetido y avisa de ítems ausentes del manifiesto', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123']));            // no incluye el ítem en ERROR
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('virus.exe') });
      fixture.detectChanges();
      const texto = q('errores-reintento')?.textContent ?? '';
      expect(texto).toContain(`«${ID_ERROR}» no figura en el manifiesto`);
      expect(componente.preparacion().manifiesto).toBeNull();
      componente.reintentar();
      expect(reintentar).not.toHaveBeenCalled();
    });

    it('rechaza archivos corregidos que no son PDF/JPG/PNG', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('virus.exe') });
      fixture.detectChanges();
      expect(q('errores-reintento')?.textContent).toContain('PDF, JPG o PNG');
    });

    it('ITEM_NO_REINTENTABLE: muestra el mensaje, limpia la selección y vuelve a leer el informe', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      reintentar.mockReturnValue(
        throwError(() => errorHttp(422, { detail: { codigo: 'ITEM_NO_REINTENTABLE', mensaje: `Solo se pueden reintentar ítems en ERROR: ${ID_ERROR}` } })),
      );
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('c.pdf') });
      componente.reintentar();
      fixture.detectChanges();
      expect(q('error-reintento')?.textContent).toContain('Solo se pueden reintentar ítems en ERROR de esta sincronización');
      expect(q('error-reintento')?.textContent).toContain(ID_ERROR);
      expect(obtenerSincronizacion).toHaveBeenCalledTimes(2);
      expect(Object.keys(componente.correcciones())).toEqual([]);
      expect(componente.reintentando()).toBe(false);
    });

    it('SINCRONIZACION_NO_ENCONTRADA al reintentar: mensaje claro y se oculta el panel', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      reintentar.mockReturnValue(throwError(() => errorHttp(404, { detail: { codigo: 'SINCRONIZACION_NO_ENCONTRADA', mensaje: 'x' } })));
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('c.pdf') });
      componente.reintentar();
      fixture.detectChanges();
      expect(q('error-reintento')?.textContent).toContain('La sincronización no existe o no pertenece a su clínica');
      expect(q('panel-reintento')).toBeNull();
    });

    it('FUENTE_INACTIVA y LOTE_INVALIDO se muestran en español', () => {
      guardarManifiesto(31, manifiestoDemo(['LAB-2026-000123', ID_ERROR]));
      reintentar.mockReturnValueOnce(throwError(() => errorHttp(409, { detail: { codigo: 'FUENTE_INACTIVA', mensaje: 'x' } })));
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('c.pdf') });
      componente.reintentar();
      expect(componente.errorReintento()).toContain('fuente de laboratorio está inactiva');
      reintentar.mockReturnValueOnce(throwError(() => errorHttp(422, { detail: { codigo: 'LOTE_INVALIDO', mensaje: 'La fuente del manifiesto no coincide con la de la sincronización.' } })));
      componente.reintentar();
      expect(componente.errorReintento()).toContain('no coincide con la de la sincronización');
    });

    it('permite quitar el archivo corregido de un ítem', () => {
      crear();
      componente.correcciones.set({ [ID_ERROR]: archivoDemo('c.pdf') });
      fixture.detectChanges();
      expect(q('archivo-corregido')?.textContent).toContain('c.pdf');
      componente.quitarCorreccion(ID_ERROR);
      fixture.detectChanges();
      expect(q('archivo-corregido')).toBeNull();
      expect(q('entrada-correccion')).not.toBeNull();
    });

    it('aplicarManifiestoOrigen rechaza un JSON inválido y limpia con texto vacío', () => {
      crear();
      componente.aplicarManifiestoOrigen('{no');
      fixture.detectChanges();
      expect(q('error-manifiesto-origen')?.textContent).toContain('no es un JSON válido');
      componente.aplicarManifiestoOrigen(JSON.stringify({ items: [itemManifiestoDemo('A')] }));
      expect(componente.manifiestoOrigen()?.fuente).toBe('LAB-CENTRAL');
      componente.aplicarManifiestoOrigen('');
      expect(componente.manifiestoOrigen()).toBeNull();
    });
  });
});
