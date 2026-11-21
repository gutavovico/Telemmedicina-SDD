import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../../../environments/environment';

import type { Configuracion } from '../models/entity-configuration.model';

@Injectable({ providedIn: 'root' })
export class ConfigurationService {
  private readonly http = inject(HttpClient);
  private readonly url = environment.apiUrl + '/api/v1/tenant/configuracion';
  leer() {
    return this.http.get<Configuracion>(this.url);
  }
  guardar(method: 'PUT' | 'POST' | 'PATCH', path: string, body: object) {
    return this.http.request<{ mensaje: string }>(method, this.url + '/' + path, { body });
  }
}
