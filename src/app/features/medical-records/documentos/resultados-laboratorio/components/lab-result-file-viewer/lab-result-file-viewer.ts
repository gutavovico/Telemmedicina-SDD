import { Component, OnDestroy, computed, effect, inject, input, signal, untracked } from '@angular/core';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { ArchivoDescargado } from '../../models/laboratory-result.models';
import { LaboratoryResultsService } from '../../services/laboratory-results.service';
import { interpretarErrorResultado } from '../../utils/laboratory-result-errors';

/**
 * Vista previa y descarga del archivo de un resultado (criterio 7). El endpoint exige `Authorization: Bearer`,
 * por lo que el archivo se obtiene como `Blob` y se muestra con una URL de objeto. Las URLs se revocan al
 * cambiar de resultado, al volver a cargar y al destruir el componente. El tipo mostrado es el `Content-Type`
 * real que devuelve el servidor.
 */
@Component({
  selector: 'app-lab-result-file-viewer',
  standalone: true,
  templateUrl: './lab-result-file-viewer.html',
})
export class LabResultFileViewer implements OnDestroy {
  private readonly servicio = inject(LaboratoryResultsService);
  private readonly sanitizer = inject(DomSanitizer);

  readonly idResultado = input.required<number>();

  readonly cargando = signal(false);
  readonly error = signal<string | null>(null);
  readonly archivo = signal<ArchivoDescargado | null>(null);
  readonly urlObjeto = signal<string | null>(null);
  readonly urlSegura = signal<SafeResourceUrl | null>(null);
  readonly vistaPreviaVisible = signal(false);

  readonly esImagen = computed(() => (this.archivo()?.contentType ?? '').startsWith('image/'));
  readonly esPdf = computed(() => this.archivo()?.contentType === 'application/pdf');

  constructor() {
    // Al cambiar de resultado se descarta lo cargado y se revoca la URL anterior.
    effect(() => {
      this.idResultado();
      untracked(() => this.reiniciar());
    });
  }

  ngOnDestroy(): void {
    this.revocar();
  }

  /** Descarga el archivo una sola vez y lo conserva para la vista previa y el guardado. */
  private obtener(alTerminar: (archivo: ArchivoDescargado) => void): void {
    const actual = this.archivo();
    if (actual) {
      alTerminar(actual);
      return;
    }
    this.cargando.set(true);
    this.error.set(null);
    this.servicio.descargar(this.idResultado()).subscribe({
      next: (archivo) => {
        this.cargando.set(false);
        this.archivo.set(archivo);
        this.revocar();
        const url = URL.createObjectURL(archivo.blob);
        this.urlObjeto.set(url);
        this.urlSegura.set(this.sanitizer.bypassSecurityTrustResourceUrl(url));
        alTerminar(archivo);
      },
      error: (error: unknown) => {
        this.cargando.set(false);
        this.error.set(interpretarErrorResultado(error).mensaje);
      },
    });
  }

  alternarVistaPrevia(): void {
    if (this.vistaPreviaVisible()) {
      this.vistaPreviaVisible.set(false);
      return;
    }
    this.obtener(() => this.vistaPreviaVisible.set(true));
  }

  descargar(): void {
    this.obtener((archivo) => {
      const url = this.urlObjeto();
      if (!url) return;
      const enlace = document.createElement('a');
      enlace.href = url;
      enlace.download = archivo.nombre;
      enlace.rel = 'noopener';
      document.body.appendChild(enlace);
      enlace.click();
      enlace.remove();
    });
  }

  private reiniciar(): void {
    this.revocar();
    this.archivo.set(null);
    this.error.set(null);
    this.cargando.set(false);
    this.vistaPreviaVisible.set(false);
  }

  private revocar(): void {
    const url = this.urlObjeto();
    if (url) {
      URL.revokeObjectURL(url);
    }
    this.urlObjeto.set(null);
    this.urlSegura.set(null);
  }
}
