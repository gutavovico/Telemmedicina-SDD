import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import {
  OveragesLiquidation,
  OveragesPaymentAttempt,
  OveragesReceipt,
  UsageCycle,
  UsageNotice,
  UsageService,
} from './models/usage-billing.model';
import { UsageBillingService } from './services/usage-billing.service';

@Component({
  selector: 'app-usage-billing',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './usage-billing.component.html',
  styleUrl: './usage-billing.component.css',
})
export class UsageBillingComponent implements OnInit {
  private readonly service = inject(UsageBillingService);

  readonly cycle = signal<UsageCycle | null>(null);
  readonly notices = signal<UsageNotice[]>([]);
  readonly liquidations = signal<OveragesLiquidation[]>([]);
  readonly selectedLiquidation = signal<OveragesLiquidation | null>(null);
  readonly payments = signal<OveragesPaymentAttempt[]>([]);
  readonly receipt = signal<OveragesReceipt | null>(null);
  readonly loading = signal(true);
  readonly paying = signal(false);
  readonly error = signal<string | null>(null);
  readonly message = signal<string | null>(null);
  readonly unreadCount = computed(() => this.notices().filter((notice) => !notice.leido_en).length);

  ngOnInit(): void {
    this.load();
    this.processCheckoutReturn();
  }

  load(): void {
    this.loading.set(true);
    this.error.set(null);
    forkJoin({
      usage: this.service.currentUsage().pipe(catchError((error: unknown) => {
        this.error.set(this.errorText(error, 'No se pudo cargar el consumo del ciclo.'));
        return of(null);
      })),
      notices: this.service.notices().pipe(catchError(() => of({ items: [], total: 0 }))),
      liquidations: this.service.liquidations().pipe(catchError(() => of({ items: [], total: 0 }))),
    }).subscribe({
      next: ({ usage, notices, liquidations }) => {
        this.cycle.set(usage);
        this.notices.set(notices.items);
        this.liquidations.set(liquidations.items);
        const current = this.selectedLiquidation();
        if (current) {
          const fresh = liquidations.items.find((item) => item.id_liquidacion === current.id_liquidacion);
          if (fresh) this.selectLiquidation(fresh);
        }
      },
      error: () => this.error.set('Ocurrió un error al consultar el consumo.'),
      complete: () => this.loading.set(false),
    });
  }

  selectLiquidation(item: OveragesLiquidation): void {
    this.selectedLiquidation.set(item);
    this.receipt.set(null);
    this.service.payments(item.id_liquidacion).subscribe({
      next: (page) => this.payments.set(page.items),
      error: () => this.payments.set([]),
    });
    if (item.comprobante_disponible) {
      this.service.receipt(item.id_liquidacion).subscribe({
        next: (receipt) => this.receipt.set(receipt),
        error: () => this.receipt.set(null),
      });
    }
  }

  markRead(notice: UsageNotice): void {
    if (notice.leido_en) return;
    this.service.markNoticeRead(notice.id_aviso).subscribe({
      next: (updated) => this.notices.update((items) =>
        items.map((item) => item.id_aviso === updated.id_aviso ? updated : item)),
      error: () => this.error.set('No se pudo marcar el aviso como leído.'),
    });
  }

  pay(liquidation: OveragesLiquidation): void {
    if (liquidation.estado !== 'PENDIENTE_PAGO' || this.paying()) return;
    this.paying.set(true);
    this.error.set(null);
    this.service.createCheckout(liquidation.id_liquidacion, this.newIdempotencyKey()).subscribe({
      next: (checkout) => {
        if (typeof window !== 'undefined') window.location.assign(checkout.checkout_url);
        else this.paying.set(false);
      },
      error: (error: unknown) => {
        this.paying.set(false);
        this.error.set(this.errorText(error, 'No se pudo iniciar el pago de prueba.'));
      },
    });
  }

  formatMoney(value: string | null | undefined): string {
    if (value == null) return '—';
    const amount = Number(value);
    if (!Number.isFinite(amount)) return '—';
    return new Intl.NumberFormat('es-BO', {
      style: 'currency', currency: 'BOB', minimumFractionDigits: 2, maximumFractionDigits: 2,
    }).format(amount);
  }

  formatDate(value: string | null | undefined): string {
    if (!value) return '—';
    return new Intl.DateTimeFormat('es-BO', { dateStyle: 'medium', timeStyle: 'short' })
      .format(new Date(value));
  }

  usageWidth(service: UsageService): string {
    const percent = Number(service.porcentaje_uso ?? 0);
    if (!Number.isFinite(percent)) return '0%';
    return `${Math.max(0, Math.min(percent, 100))}%`;
  }

  isOverLimit(service: UsageService): boolean {
    return Number(service.porcentaje_uso ?? 0) >= 100;
  }

  statusLabel(status: string): string {
    const labels: Record<string, string> = {
      PENDIENTE_PAGO: 'Pendiente de pago', PAGADA: 'Pagada',
      REVISION_REQUERIDA: 'En revisión', ANULADA: 'Anulada',
      PENDIENTE: 'Pendiente', PAGADO: 'Pagado', FALLIDO: 'Fallido', EXPIRADO: 'Expirado',
      ABIERTO: 'Ciclo actual', CERRADO: 'Cerrado',
    };
    return labels[status] ?? status.replaceAll('_', ' ').toLowerCase();
  }

  private processCheckoutReturn(): void {
    if (typeof window === 'undefined') return;
    const params = new URLSearchParams(window.location.search);
    const checkout = params.get('checkout');
    if (checkout === 'cancelled') {
      this.message.set('El checkout de prueba se canceló. La liquidación sigue pendiente y puedes reintentarlo.');
      return;
    }
    const liquidationId = params.get('id_liquidacion');
    const paymentId = params.get('id_pago_excedente');
    if (!liquidationId || !paymentId || checkout !== 'success') return;

    this.service.synchronizePayment(liquidationId, paymentId).subscribe({
      next: (status) => {
        this.message.set(status.estado_pago === 'PAGADO'
          ? 'Pago de prueba confirmado por Stripe.'
          : 'Stripe todavía no confirma el pago. Puedes actualizar el estado en unos segundos.');
        this.load();
      },
      error: (error: unknown) => this.error.set(this.errorText(error, 'No se pudo consultar el estado del pago.')),
    });
  }

  private newIdempotencyKey(): string {
    if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
    return `cu36-${Date.now()}-${Math.random().toString(36).slice(2, 18)}`;
  }

  private errorText(error: unknown, fallback: string): string {
    if (!(error instanceof HttpErrorResponse)) return fallback;
    if (error.status === 404) return 'No se encontró una suscripción o ciclo vigente para esta clínica.';
    if (error.status === 503) return 'El checkout de prueba no está disponible. Revisa la configuración Stripe de prueba.';
    if (typeof error.error?.detail === 'string') return error.error.detail;
    return fallback;
  }
}
