const CLAVE_DISPOSITIVO = 'telemedicina_dispositivo_id';
const UUID_V4_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function obtenerDispositivoId(): string {
  if (typeof window === 'undefined' || !window.localStorage) {
    return '00000000-0000-4000-8000-000000000000';
  }
  let id = localStorage.getItem(CLAVE_DISPOSITIVO);
  if (!id || !UUID_V4_REGEX.test(id)) {
    id =
      typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
        ? crypto.randomUUID()
        : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
            const r = (Math.random() * 16) | 0;
            return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
          });
    try {
      localStorage.setItem(CLAVE_DISPOSITIVO, id);
    } catch {
      // Ignorar si storage no disponible en modo privado estricto
    }
  }
  return id;
}
