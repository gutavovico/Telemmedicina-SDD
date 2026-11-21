/// <reference types="cypress" />

describe('CU07 - Lista de espera en la web', () => {
  const api = 'http://localhost:8000';
  const correoPaciente = 'paciente.carlos@telemedicina.com';
  const correoAdmin = 'admin@telemedicina.com';

  const tokenPaciente = () => Cypress.env('cu07PatientToken') as string;
  const tokenAdmin = () => Cypress.env('cu07AdminToken') as string;
  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

  const loginApi = (correo: string, password: string) =>
    cy.request({
      method: 'POST',
      url: `${api}/auth/login`,
      headers: { 'Content-Type': 'application/json' },
      body: { correo, password },
    }).then((response) => response.body.access_token as string);

  const miEspera = () =>
    cy.request({
      method: 'GET',
      url: `${api}/api/v1/lista-espera/mi-espera`,
      headers: auth(tokenPaciente()),
    });

  const limpiarActivas = () =>
    miEspera().then((response) => {
      (response.body as Array<{ id_lista_espera: number; estado: string }>)
        .filter((entrada) => entrada.estado === 'EN_ESPERA' || entrada.estado === 'OFRECIDO')
        .forEach((entrada) =>
          cy.request({
            method: 'DELETE',
            url: `${api}/api/v1/lista-espera/${entrada.id_lista_espera}`,
            headers: auth(tokenPaciente()),
            failOnStatusCode: false,
          }),
        );
    });

  const crearCita = (fecha: string, idEspecialidad: number) =>
    cy
      .request({
        method: 'POST',
        url: `${api}/citas`,
        headers: auth(tokenAdmin()),
        body: {
          id_paciente: 3,
          id_medico: 1,
          id_especialidad: idEspecialidad,
          fecha_cita: fecha,
          hora_inicio: '10:00',
          hora_fin: '11:00',
          motivo: 'E2E web CU07',
          estado: 'CONFIRMADA',
          tipo_consulta: 'PRESENCIAL',
        },
      })
      .then((response) => response.body.id_cita as number);

  const cancelarCita = (idCita: number) =>
    cy.request({
      method: 'PUT',
      url: `${api}/citas/${idCita}`,
      headers: auth(tokenAdmin()),
      body: { estado: 'CANCELADA' },
    });

  before(() => {
    loginApi(correoPaciente, 'paciente123').then((token) =>
      Cypress.env('cu07PatientToken', token),
    );
    loginApi(correoAdmin, 'admin123').then((token) => Cypress.env('cu07AdminToken', token));
  });

  beforeEach(() => {
    limpiarActivas();
    cy.login(correoPaciente, 'paciente123');
  });

  afterEach(() => {
    limpiarActivas();
  });

  it('debe inscribirse, recibir el turno reasignado y confirmarlo en la web', () => {
    cy.navigateTo('/mi-lista-espera');
    cy.contains('h1', 'Mi lista de espera').should('be.visible');

    cy.intercept('GET', '**/api/v1/lista-espera/mi-espera').as('miasTrasInscribir');
    cy.contains('button', 'Inscribirme').click();
    cy.get('input[type="number"]').eq(0).clear().type('1');
    cy.get('input[type="number"]').eq(1).clear().type('2');
    cy.contains('button', 'Confirmar inscripción').click();
    cy.wait('@miasTrasInscribir');

    cy.contains('En espera').should('be.visible');
    cy.contains('Tu posición en la lista:').should('contain', '#1');
    miEspera().its('body').then((items: any[]) => {
      expect(items.some((item) => item.estado === 'EN_ESPERA')).to.eq(true);
    });

    cy.intercept('GET', '**/api/v1/lista-espera/mi-espera').as('miasTrasCancelar');
    crearCita('2026-12-01', 2).then((idCita) => cancelarCita(idCita));
    cy.reload();
    cy.wait('@miasTrasCancelar');

    cy.contains('¡Hay un turno disponible para ti!').should('be.visible');
    cy.contains('Turno ofrecido').should('be.visible');
    miEspera().its('body').then((items: any[]) => {
      const ofrecida = items.find((item) => item.estado === 'OFRECIDO');
      expect(ofrecida, 'debe existir una inscripción OFRECIDO').to.exist;
      expect(ofrecida.id_cita_ofrecida).to.not.eq(null);
    });

    cy.intercept('GET', '**/api/v1/lista-espera/mi-espera').as('miasTrasConfirmar');
    cy.contains('button', 'Confirmar turno').click();
    cy.wait('@miasTrasConfirmar');

    cy.contains('Confirmado').should('be.visible');
    miEspera().its('body').then((items: any[]) => {
      expect(items.some((item) => item.estado === 'CONFIRMADO')).to.eq(true);
    });
  });

  it('debe rechazar un turno ofrecido desde la web', () => {
    cy.navigateTo('/mi-lista-espera');
    cy.contains('h1', 'Mi lista de espera').should('be.visible');

    cy.intercept('GET', '**/api/v1/lista-espera/mi-espera').as('miasTrasInscribir');
    cy.contains('button', 'Inscribirme').click();
    cy.get('input[type="number"]').eq(0).clear().type('1');
    cy.get('input[type="number"]').eq(1).clear().type('1');
    cy.contains('button', 'Confirmar inscripción').click();
    cy.wait('@miasTrasInscribir');

    cy.contains('En espera').should('be.visible');

    cy.intercept('GET', '**/api/v1/lista-espera/mi-espera').as('miasTrasCancelar');
    crearCita('2026-12-02', 1).then((idCita) => cancelarCita(idCita));
    cy.reload();
    cy.wait('@miasTrasCancelar');

    cy.contains('¡Hay un turno disponible para ti!').should('be.visible');

    cy.intercept('GET', '**/api/v1/lista-espera/mi-espera').as('miasTrasRechazar');
    cy.contains('button', 'Rechazar').click();
    cy.wait('@miasTrasRechazar');

    cy.contains('Rechazado').should('be.visible');
    miEspera().its('body').then((items: any[]) => {
      expect(items.some((item) => item.estado === 'RECHAZADO')).to.eq(true);
    });
  });

  it('debe permitir al staff crear una inscripción y ofrecer un cupo desde la gestión', () => {
    cy.login(correoAdmin, 'admin123');

    cy.navigateTo('/admin/lista-espera');
    cy.contains('h1', 'Gestión de lista de espera').should('be.visible');

    const textoFila = (element: HTMLElement) => element.textContent ?? '';
    const filaEnEspera = () =>
      cy.get('tbody tr').filter((_index, element) => {
        const texto = textoFila(element as HTMLElement);
        return texto.includes('Carlos Mamani Choque') && texto.includes('En espera');
      });

    cy.intercept('POST', '**/api/v1/lista-espera').as('crearInscripcion');
    cy.contains('button', 'Nueva inscripción').click();
    cy.get('input[type="number"]').eq(0).clear().type('3');
    cy.get('select').eq(0).select(1);
    cy.get('input[type="number"]').eq(1).clear().type('2');
    cy.contains('button', 'Guardar inscripción').click();
    cy.wait('@crearInscripcion');

    filaEnEspera().should('have.length', 1);
    filaEnEspera().contains('button', 'Ofrecer cupo').click();

    filaEnEspera().find('input[type="date"]').clear().type('2026-12-03');
    filaEnEspera().find('input[type="time"]').eq(0).type('10:00');
    filaEnEspera().find('input[type="time"]').eq(1).type('10:20');

    cy.intercept('POST', '**/api/v1/lista-espera/*/ofrecer').as('ofrecerCupo');
    filaEnEspera().contains('button', 'Enviar oferta').click();
    cy.wait('@ofrecerCupo');

    cy.get('tbody tr')
      .filter((_index, element) => {
        const texto = textoFila(element as HTMLElement);
        return texto.includes('Carlos Mamani Choque') && texto.includes('Turno ofrecido');
      })
      .should('have.length', 1);
    miEspera().its('body').then((items: any[]) => {
      expect(items.some((item) => item.estado === 'OFRECIDO')).to.eq(true);
    });
  });
});
