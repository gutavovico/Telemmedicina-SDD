const RECOVERY_STORAGE_KEY = 'telemedicina:chunk-reload-at';
const RECOVERY_COOLDOWN_MS = 15_000;
const CHUNK_URL_PATTERN =
  /(?:^|\/)(?:chunk-[A-Z0-9]+|main|polyfills|runtime|styles)\.(?:js|mjs)(?:\?|$)/i;

export function isChunkUrl(value: string): boolean {
  return CHUNK_URL_PATTERN.test(value);
}

function canRecover(storage: Storage | undefined, now: number, lastRecoveryAt: number): boolean {
  if (lastRecoveryAt !== 0 && now - lastRecoveryAt < RECOVERY_COOLDOWN_MS) {
    return false;
  }

  if (storage) {
    try {
      const previous = Number(storage.getItem(RECOVERY_STORAGE_KEY) ?? 0);
      if (previous && now - previous < RECOVERY_COOLDOWN_MS) {
        return false;
      }
      storage.setItem(RECOVERY_STORAGE_KEY, String(now));
    } catch {
      // Algunos navegadores bloquean sessionStorage en modo privado.
      // La protección en memoria sigue evitando bucles de recarga.
    }
  }

  return true;
}

/**
 * Recupera una pestaña que conserva un chunk de una compilación anterior.
 *
 * Un reinicio de Vite puede invalidar los chunks lazy mientras el navegador
 * conserva el grafo de módulos ya cargado. En ese caso la navegación falla
 * con un 404 del chunk viejo. Una recarga normal obtiene el `index.html` y el
 * grafo de módulos actuales; no hace falta una recarga forzada del navegador.
 */
export interface ChunkReloadRecovery {
  recover: (reason: string) => void;
}

export function createChunkReloadRecovery(
  reload: () => void,
  storage?: Storage | undefined,
  now: () => number = () => Date.now(),
): ChunkReloadRecovery {
  let lastRecoveryAt = 0;
  const recover = (reason: string) => {
    const currentTime = now();
    if (!canRecover(storage, currentTime, lastRecoveryAt)) {
      console.error(`No se pudo recuperar el chunk obsoleto: ${reason}`);
      return;
    }
    lastRecoveryAt = currentTime;
    console.warn(`Recargando la aplicación por un chunk obsoleto: ${reason}`);
    reload();
  };
  return { recover };
}

export function installChunkReloadRecovery(
  target?: Window,
  reload?: () => void,
  storage?: Storage | undefined,
  now: () => number = () => Date.now(),
): ChunkReloadRecovery | undefined {
  if (typeof window === 'undefined') {
    return undefined;
  }

  const browserWindow = target ?? window;
  const reloadPage = reload ?? (() => browserWindow.location.reload());
  let browserStorage = storage;
  if (browserStorage === undefined) {
    try {
      browserStorage = browserWindow.sessionStorage;
    } catch {
      browserStorage = undefined;
    }
  }

  const recovery = createChunkReloadRecovery(reloadPage, browserStorage, now);

  browserWindow.addEventListener(
    'error',
    (event: Event) => {
      const element = event.target as Element | null;
      const source = element?.getAttribute('src') ?? '';
      if (element?.tagName === 'SCRIPT' && isChunkUrl(source)) {
        recovery.recover(source);
      }
    },
    true,
  );

  browserWindow.addEventListener('unhandledrejection', (event: PromiseRejectionEvent) => {
    const reason = String(event.reason?.message ?? event.reason ?? '');
    if (
      /Failed to fetch dynamically imported module|Importing a module script failed/i.test(
        reason,
      ) &&
      isChunkUrl(reason)
    ) {
      recovery.recover(reason);
    }
  });

  return recovery;
}
