import { Component, inject } from '@angular/core';
import { NavigationError, Router, RouterOutlet } from '@angular/router';
import { Header } from './shared/components/header/header';
import { InactivityWarning } from './features/auth/inactivity-warning/inactivity-warning';
import { installChunkReloadRecovery, isChunkUrl } from './core/utils/chunk-reload-recovery';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, Header, InactivityWarning],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  private readonly router = inject(Router);
  private readonly chunkRecovery = installChunkReloadRecovery();

  constructor() {
    this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationError)) {
        return;
      }
      const reason = String(event.error?.message ?? event.error ?? '');
      if (isChunkUrl(reason)) {
        this.chunkRecovery?.recover(reason);
      }
    });
  }

  // El header global se oculta en /admin (ver Header.isAdminRoute):
  // sin esto el <main> dejaba 80px (pt-20) de aire huérfano arriba del topbar del panel.
  isAdminRoute(): boolean {
    return this.router.url.startsWith('/admin');
  }
}
