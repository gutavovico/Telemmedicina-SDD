import { describe, expect, it, vi } from 'vitest';
import { installChunkReloadRecovery, isChunkUrl } from './chunk-reload-recovery';

describe('chunk reload recovery', () => {
  it('recognizes only hashed/lazy JavaScript chunks', () => {
    expect(isChunkUrl('/chunk-KAF4CB7N.js')).toBe(true);
    expect(isChunkUrl('/chunk-KAF4CB7N.js?v=123')).toBe(true);
    expect(isChunkUrl('/main.js')).toBe(true);
    expect(isChunkUrl('/api/v1/medicos')).toBe(false);
    expect(isChunkUrl('/assets/logo.png')).toBe(false);
  });

  it('reloads once when a script chunk fails and prevents a reload loop', () => {
    const listeners = new Map<string, EventListener>();
    const fakeWindow = {
      addEventListener: vi.fn((type: string, listener: EventListener) => {
        listeners.set(type, listener);
      }),
      sessionStorage: {
        getItem: vi.fn(() => null),
        setItem: vi.fn(),
      },
    } as unknown as Window;
    const reload = vi.fn();
    const storage = fakeWindow.sessionStorage as unknown as Storage;

    installChunkReloadRecovery(fakeWindow, reload, storage, () => 1_000);

    const script = document.createElement('script');
    script.src = '/chunk-KAF4CB7N.js';
    const event = new Event('error');
    Object.defineProperty(event, 'target', { value: script });

    listeners.get('error')?.(event);
    expect(reload).toHaveBeenCalledTimes(1);

    listeners.get('error')?.(event);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('does not reload for unrelated resource errors', () => {
    const listeners = new Map<string, EventListener>();
    const fakeWindow = {
      addEventListener: vi.fn((type: string, listener: EventListener) => {
        listeners.set(type, listener);
      }),
      sessionStorage: {
        getItem: vi.fn(() => null),
        setItem: vi.fn(),
      },
    } as unknown as Window;
    const reload = vi.fn();

    installChunkReloadRecovery(
      fakeWindow,
      reload,
      fakeWindow.sessionStorage as unknown as Storage,
      () => 1_000,
    );

    const image = document.createElement('img');
    image.src = '/assets/logo.png';
    const event = new Event('error');
    Object.defineProperty(event, 'target', { value: image });

    listeners.get('error')?.(event);
    expect(reload).not.toHaveBeenCalled();
  });
});
