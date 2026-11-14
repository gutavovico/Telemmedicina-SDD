import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../../../../environments/environment';
import {
  CreateOveragesCheckoutResponse,
  OveragesLiquidation,
  OveragesPaymentAttempt,
  OveragesPaymentStatus,
  OveragesReceipt,
  Page,
  UsageCycle,
  UsageNotice,
} from '../models/usage-billing.model';

@Injectable({ providedIn: 'root' })
export class UsageBillingService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/api/v1/facturacion`;

  currentUsage(): Observable<UsageCycle> {
    return this.http.get<UsageCycle>(`${this.baseUrl}/consumo/actual`);
  }

  notices(noRead?: boolean, skip = 0, limit = 20): Observable<Page<UsageNotice>> {
    let params = new HttpParams().set('skip', String(skip)).set('limit', String(limit));
    if (noRead !== undefined) params = params.set('no_leidos', String(noRead));
    return this.http.get<Page<UsageNotice>>(`${this.baseUrl}/avisos`, { params });
  }

  markNoticeRead(id: string): Observable<UsageNotice> {
    return this.http.patch<UsageNotice>(`${this.baseUrl}/avisos/${encodeURIComponent(id)}/leer`, null);
  }

  liquidations(skip = 0, limit = 20): Observable<Page<OveragesLiquidation>> {
    const params = new HttpParams().set('skip', String(skip)).set('limit', String(limit));
    return this.http.get<Page<OveragesLiquidation>>(`${this.baseUrl}/liquidaciones`, { params });
  }

  liquidation(id: string): Observable<OveragesLiquidation> {
    return this.http.get<OveragesLiquidation>(`${this.baseUrl}/liquidaciones/${encodeURIComponent(id)}`);
  }

  payments(idLiquidation: string, skip = 0, limit = 20): Observable<Page<OveragesPaymentAttempt>> {
    const params = new HttpParams().set('skip', String(skip)).set('limit', String(limit));
    return this.http.get<Page<OveragesPaymentAttempt>>(
      `${this.baseUrl}/liquidaciones/${encodeURIComponent(idLiquidation)}/pagos`,
      { params },
    );
  }

  createCheckout(idLiquidation: string, idempotencyKey: string): Observable<CreateOveragesCheckoutResponse> {
    return this.http.post<CreateOveragesCheckoutResponse>(
      `${this.baseUrl}/liquidaciones/${encodeURIComponent(idLiquidation)}/checkout`,
      null,
      { headers: { 'Idempotency-Key': idempotencyKey } },
    );
  }

  synchronizePayment(idLiquidation: string, idPayment: string): Observable<OveragesPaymentStatus> {
    return this.http.post<OveragesPaymentStatus>(
      `${this.baseUrl}/liquidaciones/${encodeURIComponent(idLiquidation)}/pagos/${encodeURIComponent(idPayment)}/sincronizar`,
      null,
    );
  }

  receipt(idLiquidation: string): Observable<OveragesReceipt> {
    return this.http.get<OveragesReceipt>(
      `${this.baseUrl}/liquidaciones/${encodeURIComponent(idLiquidation)}/comprobante`,
    );
  }
}
