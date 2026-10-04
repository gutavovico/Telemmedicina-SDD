## Context

Los tres repositorios están en main. El backend usa sesiones síncronas existentes; esta corrección no convierte toda la arquitectura. Neon confirma citas.hora_inicio/hora_fin varchar y ausencia de medicos.id_clinica. Esta última requiere reconciliación futura del esquema, no eliminación del filtro de tenant.

## Decisions

- Declarar postgresql+psycopg2, consistente con requirements.txt.
- Reflejar tipos reales de citas mediante inspección SQLAlchemy y normalizar horas en Python. Horas nulas, inválidas, con zona o intervalos invertidos producen advertencias y no anuncian disponibilidad libre.
- Usar exclusivamente session.rol para permisos visuales; backend sigue autorizando cada operación. El catálogo de roles administrativo no es requisito para Recepción.
- Demo explícita, con usuarios sintéticos, SQLite en memoria, get_db sustituido únicamente en el lanzador de pruebas, autenticación JWT real, bind loopback y claves efímeras. Nunca usarla como servidor de producción.
- CU16 sigue fallando si falta configuración; no se cambia lifespan.

## Validation

Compilación, unittest CU5/CU4/auth, regresiones Angular y navegador local. Neon se inspecciona con transaction_read_only=on. La demo no certifica exclusión GiST, concurrencia PostgreSQL ni compatibilidad del esquema remoto.
