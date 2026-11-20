/// <reference types="cypress" />

/**
 * CU11 · Resultados de laboratorio (web, bloque A). Tareas 4.2 a 4.6.
 *
 * Todas las llamadas al backend se simulan con `cy.intercept` (no requiere API ni base de datos): la sesión
 * se siembra en `localStorage` y el contexto del tenant (con los permisos del rol) se devuelve desde un stub.
 * Los nombres de campos, rutas y códigos de error son los de `openspec/contracts/resultados-laboratorio.md`.
 */

type Rol = 'ADMIN' | 'MEDICO' | 'RECEPCION';

const API = 'http://localhost:8000';
const BASE = `${API}/api/v1/resultados-laboratorio`;

const PERMISOS: Record<Rol, string[]> = {
  ADMIN: ['lab_results:create', 'lab_results:read', 'lab_results:review', 'lab_results:sync', 'documents:read:lab_results', 'lab_orders:read'],
  MEDICO: ['lab_results:create', 'lab_results:read', 'lab_results:review', 'documents:read:lab_results', 'lab_orders:read'],
  RECEPCION: ['lab_results:create', 'lab_results:read', 'lab_orders:read'],
};

const PACIENTE = {
  id_paciente: 10, nombres: 'Carlos', apellidos: 'Mamani', ci: '1234567', fecha_nacimiento: '1990-01-01',
  genero: 'M', telefono: '70000000', estado: 'ACTIVO', created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
};

const CATALOGO = [
  { id_examen: 1, id_clinica: 1, codigo: 'HEMOGRAMA', nombre: 'Hemograma completo', categoria: 'HEMATOLOGIA', activo: 'SI', requiere_ayuno: 0, tiempo_entrega_horas: 4, created_at: '2026-01-01T00:00:00Z' },
  { id_examen: 2, id_clinica: 1, codigo: 'GLUCOSA', nombre: 'Glucosa en sangre', categoria: 'BIOQUIMICA', activo: 'SI', requiere_ayuno: 1, tiempo_entrega_horas: 2, created_at: '2026-01-01T00:00:00Z' },
];

function resumen(cambios: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id_resultado: 15, id_clinica: 1, estado: 'INCORPORADO', origen: 'MANUAL', id_paciente: 10, paciente_nombre: 'Carlos Mamani',
    id_orden: null, id_examen: 1, codigo_examen: 'HEMOGRAMA', nombre_examen: 'Hemograma completo',
    laboratorio_origen: 'Laboratorio Central', fecha_realizacion: '2026-11-10', nombre_archivo: 'hemograma.pdf',
    content_type: 'application/pdf', tamano_bytes: 2048, hash_archivo: 'a'.repeat(64), id_documento: 88, id_fuente: null,
    fuente_codigo: null, id_externo: null, id_sincronizacion: null, motivo_pendiente: null, registrado_por: 4,
    registrado_por_nombre: 'Prueba Cypress', proceso: null, registrado_en: '2026-11-18T14:05:00Z', resuelto_por: null,
    resuelto_en: null, motivo_resolucion: null, ...cambios,
  };
}

function detalle(cambios: Record<string, unknown> = {}): Record<string, unknown> {
  return { ...resumen(), observaciones: 'Muestra en ayunas', datos_correspondencia: null, ...cambios };
}

function lista(items: Array<Record<string, unknown>>): Record<string, unknown> {
  return { items, total: items.length, page: 1, page_size: 10, total_pages: 1 };
}

function base64Url(texto: string): string {
  return btoa(texto).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Siembra la sesión (token, perfil y contexto del tenant) y abre la ruta indicada. */
function iniciarSesion(rol: Rol, ruta: string): void {
  const correo = `${rol.toLowerCase()}@cu11.test`;
  const usuario = {
    id_usuario: 4, id_clinica: 1, rol, nombres: 'Prueba', apellidos: rol, correo, estado: 'ACTIVO',
  };
  const contexto = {
    clinica_id: 1, clinica_nombre: 'Clínica de prueba', clinica_estado: 'ACTIVO', usuario_id: 4,
    usuario_nombres: 'Prueba', usuario_apellidos: rol, usuario_correo: correo, rol, permisos: PERMISOS[rol], es_super_admin: false,
  };
  const token = [
    base64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' })),
    base64Url(JSON.stringify({ sub: '4', tenant_id: 1, exp: 4102444800 })),
    'firma',
  ].join('.');

  // Cualquier otra llamada al backend responde vacío; las específicas se declaran después y tienen prioridad.
  cy.intercept({ url: `${API}/**` }, { statusCode: 404, body: { detail: 'sin simular' } });
  cy.intercept('GET', `${API}/auth/me`, { body: usuario });
  cy.intercept('GET', `${API}/api/v1/tenant/context`, { body: contexto });
  cy.intercept('GET', `${API}/auth/session`, { statusCode: 200, body: {} });
  cy.intercept('GET', `${API}/api/v1/ordenes-laboratorio/examenes`, { body: CATALOGO }).as('catalogo');
  cy.intercept('GET', `${API}/api/v1/pacientes?*`, {
    body: { items: [PACIENTE], total: 1, page: 1, page_size: 8, total_pages: 1 },
  }).as('pacientes');

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

function pdf(nombre = 'hemograma.pdf') {
  return { contents: Cypress.Buffer.from('%PDF-1.4\n%CU11\n'), fileName: nombre, mimeType: 'application/pdf' };
}

/** Completa el formulario de carga con datos válidos (todos los controles tienen etiqueta asociada). */
function completarFormulario(opciones: { archivo?: ReturnType<typeof pdf> } = {}): void {
  cy.get('#paciente').type('Car');
  cy.wait('@pacientes');
  cy.get('[role="option"]').first().click();
  cy.get('[data-testid="paciente-elegido"]').should('contain', 'Carlos Mamani');
  cy.get('#codigo_examen').select('HEMOGRAMA');
  cy.get('#fecha_realizacion').type('2026-11-10');
  cy.get('#laboratorio_origen').type('Laboratorio Central');
  cy.get('#archivo').selectFile(opciones.archivo ?? pdf(), { force: true });
}

describe('CU11 · Carga manual de resultados de laboratorio', () => {
  it('carga un resultado válido enviando multipart sin campos de clínica ni estado', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, { statusCode: 201, body: detalle() }).as('cargar');
    cy.contains('h1', 'Cargar resultado de laboratorio').should('be.visible');
    cy.wait('@catalogo');
    completarFormulario();
    cy.contains('button', 'Guardar resultado').click();
    cy.wait('@cargar').then(({ request }) => {
      expect(request.headers['content-type']).to.match(/^multipart\/form-data; boundary=/);
      expect(String(request.headers['authorization'])).to.match(/^Bearer /);
      const cuerpo = String(request.body);
      for (const campo of ['archivo', 'id_paciente', 'codigo_examen', 'fecha_realizacion', 'laboratorio_origen']) {
        expect(cuerpo).to.contain(`name="${campo}"`);
      }
      for (const prohibido of ['id_clinica', 'tenant_id', 'name="estado"', 'name="origen"']) {
        expect(cuerpo).not.to.contain(prohibido);
      }
      expect(cuerpo).to.contain('name="id_paciente"\r\n\r\n10');
    });
    cy.get('[data-testid="carga-exitosa"]').should('contain', 'Resultado incorporado al expediente');
    cy.contains('a', 'Ver resultado').should('have.attr', 'href', '/admin/resultados-laboratorio/15');
  });

  it('valida en el cliente: sin datos no envía nada y anuncia los errores', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, cy.spy().as('noDeberiaLlamarse'));
    cy.contains('button', 'Guardar resultado').click();
    cy.get('[data-testid="error-general"]').should('contain', 'Revise los campos');
    cy.get('#archivo-error').should('contain', 'Seleccione el archivo');
    cy.get('#resumen-errores').should('have.attr', 'aria-live', 'assertive');
    cy.get('@noDeberiaLlamarse').should('not.have.been.called');
  });

  it('rechaza en el cliente un archivo que no es PDF, JPG o PNG', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, cy.spy().as('noDeberiaLlamarse'));
    completarFormulario({ archivo: { contents: Cypress.Buffer.from('MZ'), fileName: 'programa.exe', mimeType: 'application/octet-stream' } as ReturnType<typeof pdf> });
    cy.contains('button', 'Guardar resultado').click();
    cy.get('#archivo-error').should('contain', 'PDF, JPG o PNG');
    cy.get('@noDeberiaLlamarse').should('not.have.been.called');
  });

  it('muestra el error de validación del servidor (ARCHIVO_FIRMA_INVALIDA) junto al archivo', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, {
      statusCode: 422,
      body: { detail: { codigo: 'ARCHIVO_FIRMA_INVALIDA', mensaje: 'El contenido del archivo no corresponde a su extensión.' } },
    }).as('cargar');
    completarFormulario();
    cy.contains('button', 'Guardar resultado').click();
    cy.wait('@cargar');
    cy.get('[data-testid="error-general"]').should('contain', 'no corresponde a su extensión');
    cy.get('#archivo-error').should('be.visible');
    cy.get('form').should('exist'); // el usuario puede corregir y reintentar
  });

  it('muestra los errores de validación en forma de lista del servidor (422) por campo', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, {
      statusCode: 422,
      body: { detail: [{ type: 'value_error', loc: ['body', 'laboratorio_origen'], msg: 'El laboratorio de origen es obligatorio (máximo 200 caracteres).' }] },
    }).as('cargar');
    completarFormulario();
    cy.contains('button', 'Guardar resultado').click();
    cy.wait('@cargar');
    cy.get('#laboratorio_origen-error').should('contain', 'obligatorio');
  });

  it('informa el duplicado (409 RESULTADO_DUPLICADO)', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, {
      statusCode: 409,
      body: { detail: { codigo: 'RESULTADO_DUPLICADO', mensaje: 'Ya existe un resultado incorporado con el mismo archivo para este paciente.' } },
    }).as('cargar');
    completarFormulario();
    cy.contains('button', 'Guardar resultado').click();
    cy.wait('@cargar');
    cy.get('[data-testid="error-general"]').should('contain', 'mismo archivo');
    cy.get('#archivo-error').should('contain', 'mismo archivo');
  });

  it('sin permiso para el catálogo de estudios ofrece escribir el código y avisa por qué', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('GET', `${API}/api/v1/ordenes-laboratorio/examenes`, {
      statusCode: 403,
      body: { detail: "Permiso denegado. Se requiere el permiso 'lab_orders:read'." },
    }).as('catalogoSinPermiso');
    cy.reload();
    cy.wait('@catalogoSinPermiso');
    cy.get('[data-testid="aviso-catalogo"]').should('contain', 'lab_orders:read');
    cy.get('input#codigo_examen').should('be.visible');
  });
});

describe('CU11 · Consulta, vista previa y descarga', () => {
  it('lista los resultados con insignias de estado y abre el detalle', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio');
    cy.intercept('GET', `${BASE}?*`, { body: lista([resumen(), resumen({ id_resultado: 16, estado: 'ANULADO' })]) }).as('listado');
    cy.intercept('GET', `${BASE}/15`, { body: detalle() }).as('detalle');
    cy.reload();
    cy.wait('@listado');
    cy.get('[data-testid="fila-resultado"]').should('have.length', 2);
    cy.get('[data-testid="estado-resultado"]').first().should('contain', 'Incorporado');
    cy.get('[data-testid="estado-resultado"]').last().should('contain', 'Anulado');
    cy.contains('a', 'Ver detalle').first().click();
    cy.wait('@detalle');
    cy.location('pathname').should('eq', '/admin/resultados-laboratorio/15');
    cy.get('[data-testid="observaciones"]').should('contain', 'Muestra en ayunas');
  });

  it('muestra el estado vacío del listado', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio');
    cy.intercept('GET', `${BASE}?*`, { body: lista([]) }).as('listado');
    cy.reload();
    cy.wait('@listado');
    cy.get('[data-testid="vacio"]').should('contain', 'No hay resultados');
  });

  it('descarga con Bearer como Blob y muestra una imagen con el tipo real devuelto', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/15');
    cy.intercept('GET', `${BASE}/15`, { body: detalle({ content_type: 'image/png', nombre_archivo: 'imagen.png' }) });
    cy.intercept('GET', `${BASE}/15/archivo`, {
      statusCode: 200,
      headers: { 'content-type': 'image/png', 'content-disposition': 'attachment; filename="imagen.png"', 'x-content-type-options': 'nosniff' },
      body: Cypress.Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex'),
    }).as('archivo');
    cy.reload();
    cy.get('[data-testid="btn-ver-archivo"]').click();
    cy.wait('@archivo').then(({ request }) => {
      expect(String(request.headers['authorization'])).to.match(/^Bearer /);
    });
    cy.get('[data-testid="vista-previa"] img').should('have.attr', 'src').and('match', /^blob:/);
    cy.get('[data-testid="btn-ver-archivo"]').should('contain', 'Ocultar vista previa');
  });

  it('muestra un PDF en un marco con título y permite descargarlo', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/15');
    cy.intercept('GET', `${BASE}/15`, { body: detalle() });
    cy.intercept('GET', `${BASE}/15/archivo`, {
      statusCode: 200,
      headers: { 'content-type': 'application/pdf', 'content-disposition': 'attachment; filename="hemograma.pdf"' },
      body: Cypress.Buffer.from('%PDF-1.4\n%CU11\n'),
    }).as('archivo');
    cy.reload();
    cy.get('[data-testid="btn-ver-archivo"]').click();
    cy.wait('@archivo');
    cy.get('[data-testid="vista-previa"] iframe').should('have.attr', 'title').and('contain', 'hemograma.pdf');
    cy.get('[data-testid="btn-descargar"]').click();
    cy.readFile('cypress/downloads/hemograma.pdf', { timeout: 15000 }).should('exist');
    cy.get('@archivo.all').should('have.length', 1); // el archivo descargado se reutiliza
  });

  it('muestra el error del servidor si el archivo no está disponible (404 ARCHIVO_NO_ENCONTRADO)', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/15');
    cy.intercept('GET', `${BASE}/15`, { body: detalle() });
    cy.intercept('GET', `${BASE}/15/archivo`, {
      statusCode: 404,
      body: { detail: { codigo: 'ARCHIVO_NO_ENCONTRADO', mensaje: 'x' } },
    }).as('archivo');
    cy.reload();
    cy.get('[data-testid="btn-ver-archivo"]').click();
    cy.wait('@archivo');
    cy.get('[data-testid="error-archivo"]').should('contain', 'no se encuentra en el almacenamiento');
  });
});

describe('CU11 · Vista por rol', () => {
  it('RECEPCION consulta metadatos pero no ve archivo, observaciones, filtro de estado ni la revisión', () => {
    iniciarSesion('RECEPCION', '/admin/resultados-laboratorio');
    cy.intercept('GET', `${BASE}?*`, { body: lista([resumen({ hash_archivo: null })]) }).as('listado');
    cy.intercept('GET', `${BASE}/15`, { body: detalle({ observaciones: null, hash_archivo: null }) }).as('detalle');
    cy.intercept('GET', `${BASE}/15/archivo`, cy.spy().as('archivo'));
    cy.reload();
    cy.wait('@listado');
    cy.get('[data-testid="enlace-nuevo"]').should('be.visible'); // tiene lab_results:create
    cy.get('[data-testid="enlace-revision"]').should('not.exist');
    cy.get('[data-testid="filtro-estado"]').should('not.exist');
    cy.contains('a', 'Ver detalle').first().click();
    cy.wait('@detalle');
    cy.get('[data-testid="sin-descarga"]').should('contain', 'no ver ni descargar el archivo');
    cy.get('[data-testid="btn-ver-archivo"]').should('not.exist');
    cy.get('[data-testid="btn-descargar"]').should('not.exist');
    cy.get('[data-testid="observaciones"]').should('not.exist');
    cy.get('[data-testid="btn-anular"]').should('not.exist');
    cy.get('@archivo').should('not.have.been.called');
  });

  it('MEDICO ve el filtro de estado, el enlace de revisión y las acciones de archivo', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio');
    cy.intercept('GET', `${BASE}?*`, { body: lista([resumen()]) }).as('listado');
    cy.reload();
    cy.wait('@listado');
    cy.get('[data-testid="filtro-estado"]').should('be.visible');
    cy.get('[data-testid="enlace-revision"]').should('be.visible');
    cy.intercept('GET', `${BASE}?*estado=PENDIENTE_REVISION*`, { body: lista([]) }).as('listadoPendientes');
    cy.get('[data-testid="filtro-estado"]').select('PENDIENTE_REVISION');
    cy.contains('button', 'Buscar').click();
    cy.wait('@listadoPendientes').its('request.url').should('contain', 'estado=PENDIENTE_REVISION');
  });

  it('RECEPCION no entra a la revisión de pendientes (sin lab_results:review)', () => {
    iniciarSesion('RECEPCION', '/admin/resultados-laboratorio/revision');
    cy.location('pathname').should('eq', '/sin-permisos');
  });

  it('el menú lateral ofrece Resultados de Laboratorio a quien tiene lab_results:read', () => {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio');
    cy.get('a[href="/admin/resultados-laboratorio"]').should('exist');
  });
});

describe('CU11 · Revisión de pendientes', () => {
  const pendiente = resumen({
    id_resultado: 31, estado: 'PENDIENTE_REVISION', id_paciente: null, paciente_nombre: null, origen: 'SINCRONIZADO',
    motivo_pendiente: 'PACIENTE_NO_ENCONTRADO', fuente_codigo: 'LAB-CENTRAL', id_externo: 'EXT-9',
  });
  const detallePendiente = detalle({
    ...pendiente, observaciones: null,
    datos_correspondencia: { ci: '9999999', complemento: '', codigo_examen: 'HEMOGRAMA', id_orden: null },
  });

  function abrirRevision(): void {
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/revision');
    cy.intercept('GET', `${BASE}?*`, { body: lista([pendiente]) }).as('pendientes');
    cy.intercept('GET', `${BASE}/31`, { body: detallePendiente }).as('detalle');
    cy.reload();
    cy.wait('@pendientes').its('request.url').should('contain', 'estado=PENDIENTE_REVISION');
    cy.get('[data-testid="fila-pendiente"]').should('have.length', 1);
    cy.get('[data-testid="btn-revisar"]').click();
    cy.wait('@detalle');
    cy.get('[data-testid="datos-crudos"]').should('contain', '9999999');
  }

  it('asigna el pendiente a un paciente y estudio válidos', () => {
    abrirRevision();
    cy.intercept('POST', `${BASE}/31/resolver`, {
      body: detalle({ estado: 'INCORPORADO', paciente_nombre: 'Carlos Mamani' }),
    }).as('resolver');
    cy.get('#paciente-revision').type('Car');
    cy.wait('@pacientes');
    cy.get('[role="option"]').first().click();
    cy.get('#codigo-revision').select('HEMOGRAMA');
    cy.get('[data-testid="btn-resolver"]').click();
    cy.wait('@resolver').its('request.body').should('deep.equal', {
      accion: 'ASIGNAR', id_paciente: 10, codigo_examen: 'HEMOGRAMA',
    });
    cy.get('[data-testid="exito-revision"]').should('contain', 'Carlos Mamani');
  });

  it('descarta el pendiente con motivo y exige el motivo', () => {
    abrirRevision();
    cy.intercept('POST', `${BASE}/31/resolver`, { body: detalle({ estado: 'ANULADO' }) }).as('resolver');
    cy.get('[data-testid="accion-descartar"]').check();
    cy.get('[data-testid="btn-resolver"]').click();
    cy.get('#motivo-descarte').should('have.attr', 'aria-invalid', 'true');
    cy.get('@resolver.all').should('have.length', 0);
    cy.get('#motivo-descarte').type('No corresponde a la clínica');
    cy.get('[data-testid="btn-resolver"]').click();
    cy.wait('@resolver').its('request.body').should('deep.equal', { accion: 'DESCARTAR', motivo: 'No corresponde a la clínica' });
    cy.get('[data-testid="exito-revision"]').should('contain', 'descartó');
  });

  it('muestra el error del servidor al asignar a un paciente de otra clínica (404)', () => {
    abrirRevision();
    cy.intercept('POST', `${BASE}/31/resolver`, {
      statusCode: 404,
      body: { detail: { codigo: 'PACIENTE_NO_ENCONTRADO', mensaje: 'x' } },
    }).as('resolver');
    cy.get('#paciente-revision').type('Car');
    cy.wait('@pacientes');
    cy.get('[role="option"]').first().click();
    cy.get('#codigo-revision').select('HEMOGRAMA');
    cy.get('[data-testid="btn-resolver"]').click();
    cy.wait('@resolver');
    cy.get('[data-testid="error-resolucion"]').should('contain', 'no existe en su clínica');
  });
});

describe('CU11 · Flujo completo: carga manual → consulta → anulación', () => {
  it('carga un resultado, lo consulta y lo anula', () => {
    let anulado = false;
    iniciarSesion('MEDICO', '/admin/resultados-laboratorio/nuevo');
    cy.intercept('POST', BASE, { statusCode: 201, body: detalle() }).as('cargar');
    cy.intercept('GET', `${BASE}?*`, (req) => req.reply({ body: lista([resumen({ estado: anulado ? 'ANULADO' : 'INCORPORADO' })]) })).as('listado');
    cy.intercept('GET', `${BASE}/15`, (req) =>
      req.reply({ body: detalle(anulado ? { estado: 'ANULADO', motivo_resolucion: 'Cargado por error', resuelto_en: '2026-11-18T15:00:00Z' } : {}) }),
    ).as('detalle');
    cy.intercept('POST', `${BASE}/15/anular`, (req) => {
      anulado = true;
      req.reply({ body: detalle({ estado: 'ANULADO', motivo_resolucion: 'Cargado por error', resuelto_en: '2026-11-18T15:00:00Z' }) });
    }).as('anular');

    completarFormulario();
    cy.contains('button', 'Guardar resultado').click();
    cy.wait('@cargar');
    cy.get('[data-testid="carga-exitosa"]').should('be.visible');

    cy.contains('a', 'Ver resultado').click();
    cy.wait('@detalle');
    cy.get('[data-testid="estado-resultado"]').should('contain', 'Incorporado');

    cy.get('[data-testid="btn-anular"]').click();
    cy.get('[data-testid="btn-confirmar-anulacion"]').click();
    cy.get('[data-testid="error-anulacion"]').should('contain', 'motivo');
    cy.get('#motivo-anulacion').type('Cargado por error');
    cy.get('[data-testid="btn-confirmar-anulacion"]').click();
    cy.wait('@anular').its('request.body').should('deep.equal', { motivo: 'Cargado por error' });
    cy.get('[data-testid="estado-resultado"]').should('contain', 'Anulado');
    cy.get('[data-testid="motivo-resolucion"]').should('contain', 'Cargado por error');
    cy.get('[data-testid="btn-ver-archivo"]').should('not.exist');
  });
});
