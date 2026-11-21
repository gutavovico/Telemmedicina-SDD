import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Header } from '../../../../shared/components/header/header';
import { WaitlistService } from '../waitlist.service';
import { etiquetaEstadoEspera } from '../../../../core/models/waitlist.models';

@Component({
  selector: 'app-mi-lista-espera',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, Header],
  templateUrl: './mi-lista-espera.html',
})
export class MiListaEspera implements OnInit {
  readonly waitlist = inject(WaitlistService);
  private readonly route = inject(ActivatedRoute);

  readonly etiquetaEstado = etiquetaEstadoEspera;
  readonly mostrarFormulario = signal(false);

  idMedico: number | null = null;
  idEspecialidad: number | null = null;
  nombreMedico = '';
  fechaDeseada = '';
  motivo = '';

  ngOnInit(): void {
    const params = this.route.snapshot.queryParamMap;
    const medico = params.get('idMedico');
    const especialidad = params.get('idEspecialidad');
    this.idMedico = medico ? Number(medico) : null;
    this.idEspecialidad = especialidad ? Number(especialidad) : null;
    this.nombreMedico = params.get('nombreMedico') ?? '';
    this.mostrarFormulario.set(this.idMedico !== null || this.idEspecialidad !== null);
    this.waitlist.cargarMias();
  }

  abrirFormulario(): void {
    this.mostrarFormulario.set(true);
  }

  inscribirse(): void {
    if (!this.idMedico && !this.idEspecialidad) {
      return;
    }
    this.waitlist.inscribirse(
      {
        idMedico: this.idMedico ?? undefined,
        idEspecialidad: this.idEspecialidad ?? undefined,
        fechaDeseada: this.fechaDeseada || undefined,
        motivo: this.motivo.trim() || undefined,
      },
      () => {
        this.fechaDeseada = '';
        this.motivo = '';
        this.mostrarFormulario.set(false);
        this.waitlist.cargarMias();
      },
    );
  }

  confirmar(id: number): void {
    this.waitlist.confirmar(id, () => this.waitlist.cargarMias());
  }

  rechazar(id: number): void {
    this.waitlist.rechazar(id, () => this.waitlist.cargarMias());
  }

  salir(id: number): void {
    this.waitlist.salir(id, () => this.waitlist.cargarMias());
  }

  reintentar(): void {
    this.waitlist.limpiarError();
    this.waitlist.cargarMias();
  }
}
