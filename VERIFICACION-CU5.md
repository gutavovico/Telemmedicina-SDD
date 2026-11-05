# Verificación CU5 tras merge — registro histórico de 2026-09-26

## Actualización de estado — 2026-10-03

Este documento conserva la evidencia aislada ejecutada el 26 de septiembre; las
filas y comandos de esa revisión no describen por sí solos el estado actual.
Posteriormente se ejecutó la verificación API de CU05 contra el esquema real de
Neon con el marcador `CU05NEONVERIFYV1`, documentada en
`backend_Telemedicina/scripts/cu05_neon/README.md`. El usuario informó que
completó satisfactoriamente el recorrido manual web de CU05 contra Neon y los
recorridos web CU22/CU27 contra Neon, incluidos filtros, exportaciones,
interpretación y dictado. Esos recorridos manuales fueron informados por el
usuario; no se repitieron en esta preparación de ramas.

La aplicación móvil CU22/CU27 aún tiene pendientes la resolución de
dependencias, compilación, pruebas Flutter y revisión visual. La integración
entre disponibilidad CU05 y reserva de citas CU25 sigue pendiente del
responsable de CU25; la verificación propia de CU05 no la acredita.

Directorio exclusivo: `C:\Users\hp\Desktop\si2G3-4\Telemmedicina-SDD`.

| Repositorio | Rama | Commit inicial y final |
|---|---|---|
| raíz | main | 963d8defa5516785e2cc8dcd0e4289933914ee37 |
| backend_Telemedicina | main | f451c0d7876e7d7f90c573dc5e7c223749c62dc7 |
| frontend_Telemedicina | main | d05386662ad812db4721e3aa0ae62000a5a3988b |

No había cambios preexistentes. No se hicieron commits, merges, publicaciones, migraciones ni escrituras en Neon. `.env` no se modificó. Las mutaciones de prueba se realizaron sólo en SQLite en memoria.

## Resultados separados

| Área | Resultado |
|---|---|
| Compilación Angular | Producción y development correctos. Producción prerenderiza 13 rutas. |
| Compilación Python | `compileall` correcto. La importación inicial fallaba por driver; corregido. |
| Pruebas backend | 52 aprobadas: CU5 (TIME y varchar), CU04 multitenant y /auth/me rol. |
| Pruebas Angular | 103 aprobadas, 18 archivos, runner Angular/Vitest con jsdom. Incluye Recepción, rol desconocido, médico, admin y enlace Agenda. |
| Arranque Angular | ng serve en http://localhost:4200; GET /appointments/agenda devuelve shell Angular HTTP 200. |
| Arranque FastAPI normal | Bloqueado por claves CU16 ausentes en .env. Se conserva el fallo explícito exigido por lifespan. |
| Arranque FastAPI aislado | Correcto en 127.0.0.1:8000 con SQLite y claves Ed25519 efímeras, ejecutando lifespan real. |
| Interacción real en navegador en esta revisión del 26 de septiembre | No realizada entonces: CUA devolvía apps=[] y browsers=[]. El usuario informó posteriormente los recorridos manuales web contra Neon indicados arriba. |
| OpenSpec | doctor correcto; validate --specs: 5 aprobadas, 0 fallos; cambio verify-cu05-local-main válido. |

La primera compilación dentro del sandbox dio errores de acceso de esbuild; fuera de esa restricción la compilación terminó correctamente. No fue necesario modificar Angular para resolverlos. Python muestra una advertencia de deprecación de TestClient/httpx; no falla ninguna de las 52 pruebas.

## Correcciones

- `config.py`: `postgresql+psycopg2://` selecciona el driver instalado. Con SQLAlchemy 2.1.1, el URL genérico seleccionaba psycopg y fallaba la importación.
- `environment.ts`: API development en `http://localhost:8000`. `environment.prod.ts` conserva Render. `npm run build` es producción; para probar local usar `npm start`.
- CU5 usa `rol` de `/auth/me`, sin consultar catálogo administrativo ni inferir rol de IDs. Recepción puede cargar médicos/servicios y tiene enlace Agenda en los tres menús.
- `_citas`: inspecciona los tipos reales y normaliza horas TIME/varchar antes de comparar. Horas inválidas, nulas, con zona o intervalos invertidos generan advertencias y no anuncian slots libres. No modifica citas ni su esquema.
- Demo de pruebas `backend_Telemedicina/scripts/run_cu05_local.py`: SQLite en memoria, autenticación JWT real, claves efímeras y bind loopback. Sólo sustituye get_db. No utiliza la conexión Neon; apunta cualquier conexión PostgreSQL accidental a loopback puerto 1.

## Rutas y contratos

Los diez métodos CU5 del servicio Angular coinciden con el router FastAPI bajo `/appointments/agenda`: servicios, horarios GET/POST, cambio de estado de horario, bloqueos GET/POST, aprobar/rechazar/liberar y disponibilidad. Los nombres de payloads y respuestas utilizados coinciden con schemas.py; las horas viajan como strings ISO. También se verificó /auth/me y /medicos como dependencias de la pantalla.

No se puede certificar conformidad histórica completa: main de la raíz no contiene el contrato/especificación original CU5; los directorios specs de los hijos están vacíos. El gitlink backend apunta a d70af589f9c0b8c3ebda2b8ed20a4241dba35e0f, que el remoto respondió `not our ref`. Los contratos raíz de auth/doctors todavía describen /api/v1 y UUID, mientras la implementación actual usa rutas sin ese prefijo e id_clinica entero. Esta discrepancia se documentó; no se reescribió silenciosamente la línea base.

El complemento `openspec/contracts/agenda-local-verification.md` delimita las correcciones verificadas y no reemplaza el contrato histórico faltante.

## Neon y CORS

Inspección con conexión `default_transaction_read_only=on`, sesión readonly y rollback:

- `citas.hora_inicio` y `hora_fin`: character varying.
- Horas de servicios y bloqueos: time without time zone.
- En la inspección de esa fecha, `medicos.id_clinica` estaba ausente y `SELECT medicos.id_clinica FROM medicos LIMIT 0` reproducía SQLSTATE 42703. Este hallazgo histórico no se presenta como bloqueo vigente tras la verificación API posterior de CU05 en Neon.
- CORS configurado en .env: `http://localhost:4200`. Preflight local: 200 y allow-origin exacto. `http://127.0.0.1:4200`: 400; usar localhost en el navegador.

No se inspeccionaron registros de pacientes ni se ejecutaron migraciones. SQLite no certifica GiST ni concurrencia de PostgreSQL.

## Prueba HTTP con servidor real aislado

Login de Recepción, Médico, Administración y Paciente: 200. /auth/me devuelve el rol correcto. Recepción consulta médicos y servicios: 200. Crea horario: 201. Disponibilidad inicial: 10 slots libres. Médico solicita bloqueo 10:00–11:00 para mañana: 201. Recepción no puede aprobar: 403. Administración aprueba: 200; quedan 8 slots libres. Recepción libera: 200. Médico de otra clínica: 404. Paciente consultando servicios: 403.

## Comandos PowerShell

Las dependencias ya están instaladas en `.venv` y frontend/node_modules. Para preparar otra instalación de esta misma copia:

```powershell
Set-Location 'C:\Users\hp\Desktop\si2G3-4\Telemmedicina-SDD'
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r .\backend_Telemedicina\requirements.txt
Set-Location .\frontend_Telemedicina
npm.cmd ci --no-audit --no-fund
```

Terminal 1 — demo funcional sin tocar Neon:

```powershell
Set-Location 'C:\Users\hp\Desktop\si2G3-4\Telemmedicina-SDD\backend_Telemedicina'
..\.venv\Scripts\python.exe .\scripts\run_cu05_local.py
```

Terminal 2 — Angular development:

```powershell
Set-Location 'C:\Users\hp\Desktop\si2G3-4\Telemmedicina-SDD\frontend_Telemedicina'
npm.cmd start -- --host localhost --port 4200
```

Abrir http://localhost:4200/login y luego http://localhost:4200/appointments/agenda. Detener con Ctrl+C en ambas terminales; la demo pierde sus datos al detener. Los servidores usados durante esta revisión se detuvieron.

Usuarios sintéticos: `u1@example.com` Administración, `u2@example.com` Médico, `u3@example.com` Recepción, `u4@example.com` Paciente. Contraseña común **sólo de esta demo**: `Cu5-local-2026!`.

Comando READ ONLY conservado como registro de aquella revisión; no representa
el arranque usado en la verificación posterior de escritura CU05 en Neon:

```powershell
Set-Location 'C:\Users\hp\Desktop\si2G3-4\Telemmedicina-SDD\backend_Telemedicina'
$env:PGOPTIONS = '-c default_transaction_read_only=on'
..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Mantener el modo sólo lectura mientras Neon no esté autorizado para cambios. La demo genera sus claves sin guardarlas; no usar sus claves ni usuarios para producción.

Repetir verificaciones:

```powershell
Set-Location 'C:\Users\hp\Desktop\si2G3-4\Telemmedicina-SDD\backend_Telemedicina'
..\.venv\Scripts\python.exe -m unittest tests.test_cu05_medical_agenda tests.test_cu04_medicos_tenant tests.test_cu16_auth_me_rol -q
..\.venv\Scripts\python.exe -m compileall -q app
Set-Location ..\frontend_Telemedicina
npm.cmd test -- --watch=false
npm.cmd run build
Set-Location ..
$env:OPENSPEC_TELEMETRY = '0'
npm.cmd exec --yes --package=@fission-ai/openspec -- openspec doctor
npm.cmd exec --yes --package=@fission-ai/openspec -- openspec validate --specs
npm.cmd exec --yes --package=@fission-ai/openspec -- openspec validate verify-cu05-local-main
```

## Guion manual de la demo aislada de 2026-09-26

El usuario informó posteriormente que completó el recorrido web CU05 contra
Neon. La lista siguiente queda como guion histórico de la demo SQLite.

1. Recepción: verificar enlace Agenda, selector de médicos de su clínica y tres servicios. Network debe mostrar localhost:8000, nunca Render ni consultas al catálogo de roles para CU5.
2. Activar Consulta general para el día de semana de mañana: 08:00–13:00 en slots de 30 minutos. Repetir el alta: conflicto 409. Inactivar/reactivar y revisar disponibilidad.
3. Médico: solicitar bloqueo mañana 10:00–11:00; intentar hoy, un intervalo no múltiplo de 30 minutos y un solapamiento. Ver validaciones y conflicto.
4. Administración: aprobar/rechazar pendientes. Recepción/Médico no deben tener aprobación. Liberar un aprobado y confirmar recuperación de slots.
5. Paciente: abrir /appointments/agenda y comprobar que no aparecen acciones. Con sesión de otra clínica no deben verse recursos ajenos.
6. Probar filtros, actualización, teclado, modal y pantalla estrecha. Esta parte visual permanece sin verificar automáticamente.
