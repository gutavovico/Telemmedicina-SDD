import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { WaitlistService } from '../waitlist.service';
import { MedicoService } from '../../../../core/services/medico.service';
import type { MedicoResponse } from '../../../../core/models/medico.models';
import type { InscripcionEsperaDTO } from '../../../../core/models/waitlist.models';
import { etiquetaEstadoEspera } from '../../../../core/models/waitlist.models';

@Component({
  selector: 'app-gestion-lista-espera',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './gestion-lista-espera.html',
})
export class GestionListaEspera implements OnInit {
  readonly waitlist = inject(WaitlistService);
  private readonly medicoService = inject(MedicoService);

  readonly etiquetaEstado = etiquetaEstadoEspera;
  readonly medicos = signal<MedicoResponse[]>([]);

  estado = '';
  idMedico: number | null = null;
  idEspecialidad: number | null = null;
  fechaDeseada = '';

  idPaciente: number | null = null;
  idMedicoNuevo: number | null = null;
  idEspecialidadNueva: number | null = null;
  prioridad = 0;
  motivoNuevo = '';
  readonly mostrarNueva = signal(false);

  readonly ofreciendo = signal<number | null>(null);
  fechaOferta = '';
  horaInicio = '';
  horaFin = '';

  ngOnInit(): void {
    this.cargar();
    this.medicoService.listarMedicos({ estado: 'activo', limit: 100 }).subscribe({
      next: (res) => this.medicos.set(res.items ?? []),
      error: () => this.medicos.set([]),
    });
  }

  cargar(): void {
    this.waitlist.listar({
      estado: this.estado || undefined,
      idMedico: this.idMedico ?? undefined,
      idEspecialidad: this.idEspecialidad ?? undefined,
      fechaDeseada: this.fechaDeseada || undefined,
    });
  }

  limpiar(): void {
    this.estado = '';
    this.idMedico = null;
    this.idEspecialidad = null;
    this.fechaDeseada = '';
    this.cargar();
  }

  nombreMedico(m: MedicoResponse): string {
    const nombre = `${m.usuario?.nombres ?? ''} ${m.usuario?.apellidos ?? ''}`.trim();
    return nombre || `Médico #${m.id_medico}`;
  }

  crear(): void {
    if (!this.idPaciente || (!this.idMedicoNuevo && !this.idEspecialidadNueva)) {
      return;
    }
    this.waitlist.inscribirse(
      {
        idPaciente: this.idPaciente,
        idMedico: this.idMedicoNuevo ?? undefined,
        idEspecialidad: this.idEspecialidadNueva ?? undefined,
        prioridad: this.prioridad,
        motivo: this.motivoNuevo.trim() || undefined,
      },
      () => {
        this.idPaciente = null;
        this.idMedicoNuevo = null;
        this.idEspecialidadNueva = null;
        this.prioridad = 0;
        this.motivoNuevo = '';
        this.mostrarNueva.set(false);
        this.cargar();
      },
    );
  }

  abrirOferta(entrada: InscripcionEsperaDTO): void {
    this.ofreciendo.set(entrada.idListaEspera);
    this.idMedico = entrada.idMedico;
    this.fechaOferta = entrada.fechaDeseada ?? new Date().toISOString().slice(0, 10);
    this.horaInicio = '';
    this.horaFin = '';
  }

  ofrecer(entrada: InscripcionEsperaDTO): void {
    if (!this.idMedico || !this.fechaOferta || !this.horaInicio) {
      return;
    }
    this.waitlist.ofrecer(
      entrada.idListaEspera,
      {
        fecha: this.fechaOferta,
        horaInicio: this.horaInicio,
        horaFin: this.horaFin || undefined,
        idMedico: this.idMedico,
      },
      () => {
        this.ofreciendo.set(null);
        this.cargar();
      },
    );
  }

  confirmar(entrada: InscripcionEsperaDTO): void {
    this.waitlist.confirmar(entrada.idListaEspera, () => this.cargar());
  }

  rechazar(entrada: InscripcionEsperaDTO): void {
    this.waitlist.rechazar(entrada.idListaEspera, () => this.cargar());
  }

  salir(entrada: InscripcionEsperaDTO): void {
    this.waitlist.salir(entrada.idListaEspera, () => this.cargar());
  }

  reintentar(): void {
    this.waitlist.limpiarError();
    this.cargar();
  }
}
