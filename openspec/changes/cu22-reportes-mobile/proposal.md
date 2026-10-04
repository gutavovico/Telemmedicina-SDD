# CU22/CU27 reportes en Flutter

## Propósito

El backend y la web ya exponen y consumen el contrato de reportes. La app Flutter mantiene un placeholder en Analytics. Esta etapa incorpora el constructor de reportes y la exportación para ADMIN desde Android, iOS y Flutter web.

## Alcance

- Consumir exclusivamente las cuatro rutas de `openspec/contracts/analytics.md`.
- Construir definiciones con catálogo y opciones; mostrar resultados paginados, métricas, advertencias y estados.
- Exportar PDF, XLSX, CSV y HTML desde la definición normalizada, con descarga autenticada y nombre/MIME verificados.
- Proteger navegación directa, limpiar resultados por sesión y rechazar respuestas atrasadas.

## Fuera de alcance

No se modifican backend, CU05, Neon, IA, voz, ausentismo inferido, eMail ni los permisos de documentos CU27. No se declara CU22/CU27 globalmente completo.
