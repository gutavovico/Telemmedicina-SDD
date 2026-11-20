/// <reference types="cypress" />

/**
 * CU11 · Sincronización de resultados de laboratorio (web, bloque B). Tareas 7.1 a 7.5.
 *
 * Todas las llamadas al backend se simulan con `cy.intercept` (no requiere API ni base de datos): la sesión se
 * siembra en `localStorage` y el contexto del tenant (con los permisos del rol) se devuelve desde un stub.
 * Los nombres de campos, rutas y códigos de error son los de `openspec/contracts/resultados-laboratorio.md`.
 */

type Rol = 'ADMIN' | 'MEDICO';

const API = 'http://localhost:8000';
const FUENTES = `${API}/api/v1/fuentes-laboratorio`;
const SYNC = `${API}/api/v1/sincronizaciones-laboratorio`;
const RESULTADOS = `${API}/api/v1/resultados-laboratorio`;

const PERMISOS: Record<Rol, string[]> = {
  ADMIN: ['lab_results:create', 'lab_results:read', 'lab_results:review', 'lab_results:sync', 'documents:read:lab_results', 'lab_orders:read'],
  MEDICO: ['lab_results:create', 'lab_results:read', 'lab_results:review', 'documents:read:lab_results', 'lab_orders:read'],
};

const FUENTE = { id_fuente: 2, codigo: 'LAB-CENTRAL', nombre: 'Laboratorio Central S.R.L.', activa: 'SI', created_at: '2026-11-18T14:00:00Z', updated_at: '2026-11-18T14:00:00Z' };

const IDS_MIXTO = ['LAB-2026-000123', 'LAB-2026-000124', 'LAB-2026-000100', 'LAB-2026-000125'];
const ID_ERROR = 'LAB-2026-000125';

function listaFuentes(items: Array<Record<string, unknown>>): Record<string, unknown> {
  return { items, total: items.length, page: 1, page_size: 10, total_pages: 1 };
}

function item(id: string, extras: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id_externo: id, ci: '1234567', complemento: '', codigo_examen: 'HEMOGRAMA', laboratorio_origen: 'Laboratorio Central S.R.L.',
    fecha_realizacion: '2026-11-10', nombre_archivo: `${id}.pdf`, id_orden: null, observaciones: null, ...extras,
  };
}

function itemSync(id: string, resultado: string, extras: Record<string, unknown> = {}): Record<string, unknown> {
  return { id_externo: id, resultado, id_resultado: resultado === 'ERROR' ? null : 15, codigo_error: null, detalle: null, intento: 1, ...extras };
}

/** Informe del ejemplo del contrato 2.8: un ítem de cada resultado. */
function informeMixto(cambios: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id_sincronizacion: 31, id_fuente: 2, fuente_codigo: 'LAB-CENTRAL', tipo: 'LOTE', estado: 'COMPLETADA_CON_ERRORES',
    total_items: 4, incorporados: 1, pendientes: 1, duplicados: 1, con_error: 1, reintentos: 0, id_usuario: 2, proceso: null,
    iniciado_en: '2026-11-18T14:10:00Z', finalizado_en: '2026-11-18T14:10:03Z',
    items: [
      itemSync('LAB-2026-000123', 'INCORPORADO'),
      itemSync('LAB-2026-000124', 'PENDIENTE_REVISION', { id_resultado: 16, detalle: 'PACIENTE_NO_ENCONTRADO' }),
      itemSync('LAB-2026-000100', 'DUPLICADO', { id_resultado: 9 }),
      itemSync(ID_ERROR, 'ERROR', { codigo_error: 'ARCHIVO_TIPO_NO_PERMITIDO', detalle: 'Extensión .exe no permitida' }),
    ],
    ...cambios,
  };
}

/** Informe después de reintentar con éxito el ítem en ERROR. */
function informeReintentado(): Record<string, unknown> {
  const base = informeMixto();
  const items = (base['items'] as Array<Record<string, unknown>>).map((i) =>
    i['id_externo'] === ID_ERROR ? itemSync(ID_ERROR, 'INCORPORADO', { id_resultado: 40, intento: 2 }) : i,
  );
  return { ...base, estado: 'COMPLETADA', incorporados: 2, con_error: 0, reintentos: 1, items };
}

function base64Url(texto: string): string {
  return btoa(texto).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * Siembra la sesión (token, perfil y contexto del tenant) y abre la ruta indicada. `stubs` registra los
 * `cy.intercept` de las peticiones que la pantalla hace al cargar: deben declararse DESPUÉS del comodín 404
 * (los últimos tienen prioridad) y ANTES de `cy.visit` (si no, la petición ya salió).
 */
function iniciarSesion(rol: Rol, ruta: string, stubs: () => void = () => undefined): void {
  const correo = `${rol.toLowerCase()}@cu11b.test`;
  const usuario = { id_usuario: 4, id_clinica: 1, rol, nombres: 'Prueba', apellidos: rol, correo, estado: 'ACTIVO' };
  const contexto = {
    clinica_id: 1, clinica_nombre: 'Clínica de prueba', clinica_estado: 'ACTIVO', usuario_id: 4, usuario_nombres: 'Prueba',
    usuario_apellidos: rol, usuario_correo: correo, rol, permisos: PERMISOS[rol], es_super_admin: false,
  };
  const token = [
    base64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' })),
    base64Url(JSON.stringify({ sub: '4', tenant_id: 1, exp: 4102444800 })),
    'firma',
  ].join('.');

  cy.intercept({ url: `${API}/**` }, { statusCode: 404, body: { detail: 'sin simular' } });
  cy.intercept('GET', `${API}/auth/me`, { body: usuario });
  cy.intercept('GET', `${API}/api/v1/tenant/context`, { body: contexto });
  cy.intercept('GET', `${API}/auth/session`, { statusCode: 200, body: {} });
  stubs();
  cy.visit(ruta, {
    onBeforeLoad(win) {
      win.localStorage.setItem('access_token', token);
      win.localStorage.setItem('refresh_token', token);
      win.localStorage.setItem('remember_me', 'true');
      win.localStorage.setItem('user_profile', JSON.stringify(usuario));
      win.localStorage.setItem('current_tenant_context', JSON.stringify(contexto));
    },
  });
}

function pdf(nombre: string) {
  return { contents: Cypress.Buffer.from(`%PDF-1.4\n%${nombre}\n`), fileName: nombre, mimeType: 'application/pdf' };
}

const stubFuentes = () => cy.intercept('GET', `${FUENTES}?*`, { body: listaFuentes([FUENTE]) }).as('fuentes');
const stubResultadosVacios = () =>
  cy.intercept('GET', `${RESULTADOS}?*`, { body: { items: [], total: 0, page: 1, page_size: 10, total_pages: 1 } }).as('resultados');

/** Escribe el manifiesto en el área de texto (más rápido que `type` para JSON largo). */
function pegarManifiesto(texto: string): void {
  cy.get('#manifiesto-texto').invoke('val', texto).trigger('input');
}

function manifiestoDe(ids: string[], cambios: Record<string, Record<string, unknown>> = {}): string {
  return JSON.stringify({ items: ids.map((id) => item(id, cambios[id] ?? {})) });
}

describe('CU11 · Fuentes de laboratorio', () => {
  it('lista, crea una fuente (sin campos de clínica) y desactiva otra con PATCH', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/fuentes', () => {
      cy.intercept('GET', `${FUENTES}?*`, { body: listaFuentes([FUENTE, { ...FUENTE, id_fuente: 3, codigo: 'LAB-NORTE', nombre: 'Laboratorio Norte', activa: 'NO' }]) }).as('listar');
      cy.intercept('POST', FUENTES, { statusCode: 201, body: { ...FUENTE, id_fuente: 9, codigo: 'LAB-NUEVA' } }).as('crear');
      cy.intercept('PATCH', `${FUENTES}/2`, { body: { ...FUENTE, activa: 'NO' } }).as('actualizar');
    });

    cy.contains('h1', 'Fuentes de laboratorio').should('be.visible');
    cy.wait('@listar');
    cy.get('[data-testid="fila-fuente"]').should('have.length', 2);
    cy.get('[data-testid="fuente-estado"]').first().should('contain', 'Activa');
    cy.get('[data-testid="fuente-estado"]').last().should('contain', 'Inactiva');

    cy.get('#fuente-codigo').type('lab-nueva');
    cy.get('#fuente-nombre').type('Laboratorio Nuevo');
    cy.get('[data-testid="btn-crear-fuente"]').click();
    cy.wait('@crear').then(({ request }) => {
      expect(request.body).to.deep.equal({ codigo: 'lab-nueva', nombre: 'Laboratorio Nuevo' });
      expect(JSON.stringify(request.body)).not.to.match(/id_clinica|tenant_id/);
    });
    cy.get('[data-testid="exito-fuente"]').should('contain', 'LAB-NUEVA');

    cy.get('[data-testid="btn-alternar"]').first().click();
    cy.wait('@actualizar').its('request.body').should('deep.equal', { activa: 'NO' });
    cy.get('[data-testid="fuente-estado"]').first().should('contain', 'Inactiva');
  });

  it('muestra FUENTE_DUPLICADA (409) con un mensaje claro y deja corregir', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/fuentes', () => {
      stubFuentes();
      cy.intercept('POST', FUENTES, { statusCode: 409, body: { detail: { codigo: 'FUENTE_DUPLICADA', mensaje: 'Ya existe una fuente con ese código en la clínica.' } } }).as('crear');
    });
    cy.wait('@fuentes');
    cy.get('#fuente-codigo').type('LAB-CENTRAL');
    cy.get('#fuente-nombre').type('Otra vez el central');
    cy.get('[data-testid="btn-crear-fuente"]').click();
    cy.wait('@crear');
    cy.get('[data-testid="error-creacion"]').should('contain', 'Ya existe una fuente con ese código');
    cy.get('#error-codigo').should('contain', 'Ya existe una fuente');
    cy.get('#fuente-codigo').should('have.attr', 'aria-invalid', 'true');
    cy.get('[data-testid="btn-crear-fuente"]').should('not.be.disabled');
  });

  it('valida el alta en el cliente sin llamar al servidor', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/fuentes', () => {
      cy.intercept('GET', `${FUENTES}?*`, { body: listaFuentes([]) }).as('fuentes');
      cy.intercept('POST', FUENTES, cy.spy().as('noDeberiaLlamarse'));
    });
    cy.wait('@fuentes');
    cy.get('[data-testid="vacio"]').should('contain', 'Aún no hay fuentes');
    cy.get('#fuente-codigo').type('LAB CENTRAL');
    cy.get('#fuente-nombre').type('ab');
    cy.get('[data-testid="btn-crear-fuente"]').click();
    cy.get('#error-codigo').should('contain', 'sin espacios');
    cy.get('#error-nombre').should('contain', 'al menos 3');
    cy.get('@noDeberiaLlamarse').should('not.have.been.called');
  });
});

describe('CU11 · Importación por lote, informe y reintento', () => {
  it('marca en el cliente un archivo que no es PDF, JPG o PNG y no deja enviar el lote', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
      cy.intercept('POST', SYNC, cy.spy().as('noDeberiaLlamarse'));
    });
    cy.contains('h1', 'Importar lote de resultados').should('be.visible');
    cy.wait('@fuentes').its('request.url').should('contain', 'activa=SI'); // solo fuentes activas
    cy.get('#fuente').should('have.value', '2'); // la única fuente activa queda preseleccionada
    pegarManifiesto(manifiestoDe(IDS_MIXTO, { [ID_ERROR]: { nombre_archivo: 'virus.exe' } }));
    cy.get('#archivos').selectFile(
      [pdf(`${IDS_MIXTO[0]}.pdf`), pdf(`${IDS_MIXTO[1]}.pdf`), pdf(`${IDS_MIXTO[2]}.pdf`),
        { contents: Cypress.Buffer.from('MZ-binario'), fileName: 'virus.exe', mimeType: 'application/octet-stream' }],
      { force: true },
    );
    cy.get('[data-testid="errores-validacion"]').should('contain', 'PDF, JPG o PNG');
    cy.get('[data-testid="btn-importar"]').click();
    cy.get('@noDeberiaLlamarse').should('not.have.been.called');
  });

  it('un lote mixto se envía como multipart sin campos de clínica y el informe muestra los cuatro resultados', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
      cy.intercept('POST', SYNC, { statusCode: 201, body: informeMixto() }).as('importar');
      cy.intercept('GET', `${SYNC}/31`, { body: informeMixto() }).as('informe');
    });
    cy.get('#fuente').should('have.value', '2');
    pegarManifiesto(manifiestoDe(IDS_MIXTO, { [IDS_MIXTO[1]]: { ci: '0000000' } }));
    cy.get('#archivos').selectFile(IDS_MIXTO.map((id) => pdf(`${id}.pdf`)), { force: true });
    cy.get('[data-testid="validacion-ok"]').should('be.visible');
    cy.get('[data-testid="btn-importar"]').click();

    cy.wait('@importar').then(({ request }) => {
      expect(request.headers['content-type']).to.match(/^multipart\/form-data; boundary=/);
      expect(String(request.headers['authorization'])).to.match(/^Bearer /);
      const cuerpo = String(request.body);
      expect(cuerpo).to.contain('name="manifiesto"');
      expect(cuerpo.match(/name="archivos"; filename=/g)).to.have.length(4);
      expect(cuerpo).to.contain('"fuente":"LAB-CENTRAL"');
      for (const prohibido of ['id_clinica', 'tenant_id']) expect(cuerpo).not.to.contain(prohibido);
    });

    // Informe del lote (7.3): totales, estado y una fila por ítem con su resultado.
    cy.wait('@informe');
    cy.location('pathname').should('eq', '/admin/resultados-laboratorio/sincronizaciones/31');
    cy.get('header [data-testid="estado-sync"]').should('contain', 'Completada con errores');
    cy.get('[data-testid="total-items"]').should('have.text', '4');
    cy.get('[data-testid="total-incorporados"]').should('have.text', '1');
    cy.get('[data-testid="total-pendientes"]').should('have.text', '1');
    cy.get('[data-testid="total-duplicados"]').should('have.text', '1');
    cy.get('[data-testid="total-errores"]').should('have.text', '1');
    cy.get('[data-testid="fila-item"]').should('have.length', 4);
    cy.get('[data-testid="fila-item"]').eq(0).should('contain', 'Incorporado');
    cy.get('[data-testid="fila-item"]').eq(1).should('contain', 'Pendiente de revisión').and('contain', 'No se encontró un paciente');
    cy.get('[data-testid="fila-item"]').eq(2).should('contain', 'Duplicado');
    cy.get('[data-testid="fila-item"]').eq(3).should('contain', 'ARCHIVO_TIPO_NO_PERMITIDO').and('contain', 'El archivo debe ser PDF, JPG o PNG.');
    cy.get('[data-testid="item-intento"]').each(($el) => expect($el.text().trim()).to.eq('1'));
  });

  it('muestra el avance de la subida y bloquea el doble envío mientras se procesa', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
      // El servidor tarda: el botón debe quedar deshabilitado y mostrar el progreso.
      cy.intercept('POST', SYNC, { statusCode: 201, body: informeMixto(), delay: 1500 }).as('importar');
      cy.intercept('GET', `${SYNC}/31`, { body: informeMixto() });
    });
    cy.get('#fuente').should('have.value', '2');
    pegarManifiesto(manifiestoDe(['A-1']));
    cy.get('#archivos').selectFile(pdf('A-1.pdf'), { force: true });
    cy.get('[data-testid="btn-importar"]').click();
    cy.get('[data-testid="btn-importar"]').should('be.disabled').and('contain', 'Importando');
    cy.get('[data-testid="progreso"] [role="progressbar"]').should('exist');
    cy.wait('@importar');
    cy.location('pathname').should('eq', '/admin/resultados-laboratorio/sincronizaciones/31');
    cy.get('@importar.all').should('have.length', 1);
  });

  it('reenviar el mismo lote deja los ítems como DUPLICADO', () => {
    const duplicado = informeMixto({
      id_sincronizacion: 32, estado: 'COMPLETADA', incorporados: 0, pendientes: 0, duplicados: 2, con_error: 0, total_items: 2,
      items: [itemSync('A-1', 'DUPLICADO', { id_resultado: 7 }), itemSync('A-2', 'DUPLICADO', { id_resultado: 8 })],
    });
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
      cy.intercept('POST', SYNC, { statusCode: 201, body: duplicado }).as('importar');
      cy.intercept('GET', `${SYNC}/32`, { body: duplicado });
    });
    cy.get('#fuente').should('have.value', '2');
    pegarManifiesto(manifiestoDe(['A-1', 'A-2']));
    cy.get('#archivos').selectFile([pdf('A-1.pdf'), pdf('A-2.pdf')], { force: true });
    cy.get('[data-testid="btn-importar"]').click();
    cy.wait('@importar');
    cy.location('pathname').should('eq', '/admin/resultados-laboratorio/sincronizaciones/32');
    cy.get('header [data-testid="estado-sync"]').should('contain', 'Completada');
    cy.get('[data-testid="total-duplicados"]').should('have.text', '2');
    cy.get('[data-testid="total-incorporados"]').should('have.text', '0');
    cy.get('[data-testid="fila-item"]').each(($fila) => expect($fila.text()).to.contain('Duplicado'));
  });

  it('valida en el cliente: JSON inválido, id_externo repetido, archivo sin ítem y archivo faltante; no llama al servidor', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
      cy.intercept('POST', SYNC, cy.spy().as('noDeberiaLlamarse'));
    });
    cy.get('#fuente').should('have.value', '2');

    pegarManifiesto('{no es json');
    cy.get('[data-testid="errores-validacion"]').should('contain', 'no es un JSON válido');

    pegarManifiesto(JSON.stringify({ items: [item('A-1'), item('A-1', { nombre_archivo: 'otro.pdf' })] }));
    cy.get('#archivos').selectFile([pdf('A-1.pdf'), pdf('sobrante.pdf')], { force: true });
    cy.get('[data-testid="errores-validacion"]')
      .should('contain', '«A-1» está repetido')
      .and('contain', 'referencia «otro.pdf», pero ese archivo no está seleccionado')
      .and('contain', '«sobrante.pdf» no está referenciado');

    cy.get('[data-testid="btn-importar"]').click();
    cy.get('@noDeberiaLlamarse').should('not.have.been.called');
    cy.get('[data-testid="validacion"]').should('have.attr', 'aria-live', 'polite');
  });

  it('muestra los errores del servidor mapeados al español (LOTE_INVALIDO, 400 de texto plano y FUENTE_INACTIVA)', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
    });
    cy.get('#fuente').should('have.value', '2');
    pegarManifiesto(manifiestoDe(['A-1']));
    cy.get('#archivos').selectFile(pdf('A-1.pdf'), { force: true });

    cy.intercept('POST', SYNC, { statusCode: 422, body: { detail: { codigo: 'LOTE_INVALIDO', mensaje: 'El lote admite como máximo 50 ítems.' } } }).as('lote');
    cy.get('[data-testid="btn-importar"]').click();
    cy.wait('@lote');
    cy.get('[data-testid="error-envio"]').should('contain', 'El lote no es válido').and('contain', 'máximo 50 ítems');
    cy.get('[data-testid="btn-importar"]').should('not.be.disabled');

    cy.intercept('POST', SYNC, { statusCode: 400, body: { detail: 'Part exceeded maximum size of 1024KB.' } }).as('grande');
    cy.get('[data-testid="btn-importar"]').click();
    cy.wait('@grande');
    cy.get('[data-testid="error-envio"]').should('contain', 'manifiesto supera 1 MB');

    cy.intercept('POST', SYNC, { statusCode: 409, body: { detail: { codigo: 'FUENTE_INACTIVA', mensaje: 'inactiva' } } }).as('inactiva');
    cy.get('[data-testid="btn-importar"]').click();
    cy.wait('@inactiva');
    cy.get('[data-testid="error-envio"]').should('contain', 'fuente de laboratorio está inactiva');
  });

  it('sin fuentes activas guía al usuario a crear una', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      cy.intercept('GET', `${FUENTES}?*`, { body: listaFuentes([]) });
    });
    cy.get('[data-testid="sin-fuentes"]').should('contain', 'No hay fuentes activas');
    cy.get('[data-testid="sin-fuentes"] a').should('have.attr', 'href', '/admin/resultados-laboratorio/fuentes');
  });

  it('reintenta un ítem en ERROR con su archivo corregido y solo ese ítem viaja en el manifiesto', () => {
    let actual: Record<string, unknown> = informeMixto();
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/importar', () => {
      stubFuentes();
      cy.intercept('POST', SYNC, { statusCode: 201, body: informeMixto() }).as('importar');
      cy.intercept('GET', `${SYNC}/31`, (req) => req.reply({ body: actual })).as('informe');
      cy.intercept('POST', `${SYNC}/31/reintentos`, (req) => {
        actual = informeReintentado();
        req.reply({ statusCode: 200, body: actual });
      }).as('reintentar');
    });

    // 1) Importación que deja un ítem en ERROR (el manifiesto queda guardado en la pestaña).
    cy.get('#fuente').should('have.value', '2');
    pegarManifiesto(manifiestoDe(IDS_MIXTO));
    cy.get('#archivos').selectFile(IDS_MIXTO.map((id) => pdf(`${id}.pdf`)), { force: true });
    cy.get('[data-testid="btn-importar"]').click();
    cy.wait('@importar');
    cy.wait('@informe');

    // 2) Reintento (7.4): solo el ítem en ERROR, con el archivo corregido.
    cy.get('[data-testid="panel-reintento"]').should('be.visible');
    cy.get('[data-testid="item-reintentable"]').should('have.length', 1).and('contain', ID_ERROR);
    cy.get('[data-testid="origen-cargado"]').should('contain', 'guardado al importar');
    cy.get('[data-testid="btn-reintentar"]').should('be.disabled');
    cy.get('[data-testid="entrada-correccion"]').selectFile(pdf('LAB-2026-000125-corregido.pdf'), { force: true });
    cy.get('[data-testid="archivo-corregido"]').should('contain', 'LAB-2026-000125-corregido.pdf');
    cy.get('[data-testid="btn-reintentar"]').should('not.be.disabled').and('contain', 'Reintentar 1 ítem(s)').click();

    cy.wait('@reintentar').then(({ request }) => {
      expect(request.headers['content-type']).to.match(/^multipart\/form-data; boundary=/);
      const cuerpo = String(request.body);
      expect(cuerpo.match(/name="archivos"; filename=/g)).to.have.length(1);
      expect(cuerpo).to.contain('filename="LAB-2026-000125-corregido.pdf"');
      expect(cuerpo).to.contain(`"id_externo":"${ID_ERROR}"`);
      expect(cuerpo).not.to.contain('LAB-2026-000123'); // los demás ítems no viajan
      for (const prohibido of ['id_clinica', 'tenant_id']) expect(cuerpo).not.to.contain(prohibido);
    });
    cy.get('[data-testid="exito-reintento"]').should('contain', 'Reintento enviado: 1 ítem(s)');
    cy.get('[data-testid="total-errores"]').should('have.text', '0');
    cy.get('[data-testid="total-reintentos"]').should('have.text', '1');
    cy.get('[data-testid="total-incorporados"]').should('have.text', '2');
    cy.get('header [data-testid="estado-sync"]').should('contain', 'Completada');
    cy.get('[data-testid="fila-item"]').eq(3).should('contain', 'Incorporado').find('[data-testid="item-intento"]').should('have.text', '2');
    cy.get('[data-testid="panel-reintento"]').should('not.exist');
  });

  it('el reintento pide el manifiesto original cuando no se conserva y maneja ITEM_NO_REINTENTABLE', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/31', () => {
      cy.intercept('GET', `${SYNC}/31`, { body: informeMixto() }).as('informe');
      cy.intercept('POST', `${SYNC}/31/reintentos`, {
        statusCode: 422,
        body: { detail: { codigo: 'ITEM_NO_REINTENTABLE', mensaje: `Solo se pueden reintentar ítems en ERROR de esta sincronización: ${ID_ERROR}` } },
      }).as('reintentar');
    });
    cy.wait('@informe');
    cy.get('[data-testid="origen-faltante"]').should('contain', 'Cargue el manifiesto original');
    cy.get('[data-testid="entrada-correccion"]').selectFile(pdf('corregido.pdf'), { force: true });
    cy.get('[data-testid="errores-reintento"]').should('contain', 'Cargue el manifiesto original');
    cy.get('[data-testid="btn-reintentar"]').should('be.disabled');

    cy.get('#manifiesto-origen').selectFile(
      { contents: Cypress.Buffer.from(manifiestoDe([ID_ERROR])), fileName: 'manifiesto.json', mimeType: 'application/json' },
      { force: true },
    );
    cy.get('[data-testid="origen-cargado"]').should('contain', '1 ítems');
    cy.get('[data-testid="btn-reintentar"]').should('not.be.disabled').click();
    cy.wait('@reintentar');
    cy.get('[data-testid="error-reintento"]').should('contain', 'Solo se pueden reintentar ítems en ERROR').and('contain', ID_ERROR);
    // El informe se vuelve a leer: ya no se insiste con datos viejos.
    cy.wait('@informe');
  });

  it('SINCRONIZACION_NO_ENCONTRADA: mensaje claro y sin acciones', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/999', () => {
      cy.intercept('GET', `${SYNC}/999`, { statusCode: 404, body: { detail: { codigo: 'SINCRONIZACION_NO_ENCONTRADA', mensaje: 'Sincronización no encontrada.' } } }).as('informe');
    });
    cy.wait('@informe');
    cy.get('[data-testid="error-informe"]').should('contain', 'La sincronización no existe o no pertenece a su clínica');
    cy.get('[data-testid="panel-reintento"]').should('not.exist');
  });

  it('enlaza el informe con la cola de revisión filtrada por fuente cuando hay pendientes (7.5)', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones/31', () => {
      cy.intercept('GET', `${SYNC}/31`, { body: informeMixto() });
      stubResultadosVacios();
    });
    cy.get('[data-testid="enlace-revision"]').should('contain', '1 pendiente(s)').click();
    cy.location('pathname').should('eq', '/admin/resultados-laboratorio/revision');
    cy.location('search').should('eq', '?id_fuente=2');
    cy.wait('@resultados').its('request.url').should('contain', 'estado=PENDIENTE_REVISION').and('contain', 'id_fuente=2');
  });

  it('el historial lista las sincronizaciones, filtra y abre un informe', () => {
    const cabecera = (cambios: Record<string, unknown>) => {
      const { items: _omitidos, ...resto } = informeMixto(cambios);
      return resto;
    };
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio/sincronizaciones', () => {
      stubFuentes();
      cy.intercept('GET', `${SYNC}?*`, (req) => {
        const fallidas = String(req.query['estado'] ?? '') === 'FALLIDA';
        const items = fallidas ? [cabecera({ id_sincronizacion: 30, estado: 'FALLIDA' })] : [cabecera({}), cabecera({ id_sincronizacion: 30, estado: 'FALLIDA' })];
        req.reply({ body: { items, total: items.length, page: 1, page_size: 10, total_pages: 1 } });
      }).as('historial');
      cy.intercept('GET', `${SYNC}/31`, { body: informeMixto() });
    });

    cy.wait('@historial');
    cy.get('[data-testid="fila-sincronizacion"]').should('have.length', 2);
    cy.get('#filtro-estado').select('FALLIDA');
    cy.get('[data-testid="btn-filtrar"]').click();
    cy.wait('@historial').its('request.url').should('contain', 'estado=FALLIDA');
    cy.get('[data-testid="fila-sincronizacion"]').should('have.length', 1).and('contain', 'Fallida');
    cy.get('#filtro-estado').select('');
    cy.get('[data-testid="btn-filtrar"]').click();
    cy.get('[data-testid="fila-sincronizacion"]').should('have.length', 2);
    cy.get('[data-testid="enlace-informe"]').first().click();
    cy.location('pathname').should('eq', '/admin/resultados-laboratorio/sincronizaciones/31');
  });
});

describe('CU11 · Vista sin permiso de sincronización', () => {
  for (const ruta of ['fuentes', 'sincronizaciones', 'sincronizaciones/importar', 'sincronizaciones/31']) {
    it(`un MEDICO (sin lab_results:sync) es redirigido a sin-permisos en /${ruta}`, () => {
      iniciarSesion('MEDICO', `/admin/resultados-laboratorio/${ruta}`);
      cy.location('pathname').should('eq', '/sin-permisos');
    });
  }

  it('el listado de resultados no ofrece el acceso a sincronizaciones al MEDICO', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio', stubResultadosVacios);
    cy.contains('h1', 'Resultados de laboratorio').should('be.visible');
    cy.get('[data-testid="enlace-sincronizaciones"]').should('not.exist');
    cy.get('[data-testid="enlace-revision"]').should('exist');
  });

  it('el ADMIN ve el acceso a sincronizaciones en el listado', () => {
    iniciarSesion('ADMIN', '/admin/resultados-laboratorio', stubResultadosVacios);
    cy.get('[data-testid="enlace-sincronizaciones"]').should('have.attr', 'href', '/admin/resultados-laboratorio/sincronizaciones');
  });
});
