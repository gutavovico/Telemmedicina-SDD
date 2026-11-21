# mobile_telemedicina

## CU22/CU27 reportes: comprobación posterior en un equipo con Flutter

Reportes y exportación usan las cuatro rutas originales de `openspec/contracts/analytics.md`; texto y dictado añaden `/interpretar` y `/transcribir`. Solo ADMIN activo con clínica asignada ve Reportes. El servidor determina `id_clinica` desde la sesión; el móvil nunca la envía en el cuerpo. El móvil no llama directamente a Groq. Ausentismo calculado y eMail siguen pendientes. Esta adaptación móvil **no se ha compilado ni probado con Flutter**.

La solicitud permite Enviar (interpretar y consultar), Aplicar filtros (solo interpretar) y Limpiar texto (conserva definición y resultados). El dictado normal deja texto editable. «Enviar al terminar» empieza apagado y solo reutiliza Enviar tras pulsar Detener explícitamente; aclaraciones, errores y respuestas obsoletas no generan. La transcripción se incorpora o descarta manualmente si se editó el texto durante la captura.

Dependencias nuevas por resolver en un equipo preparado: `record: ^6.2.1` y `http_parser: ^4.1.2`. Se eligió `record` 6.2.1 para el SDK Dart `^3.11.1` declarado; la serie 7 exige un SDK mayor. Su API `AudioRecorder.hasPermission`, `isEncoderSupported`, `startStream(RecordConfig(encoder: AudioEncoder.pcm16bits))`, `stop`, `cancel` y `dispose` soporta Android, iOS y web. El móvil arma WAV PCM16 mono de 16 kHz en memoria, `dictado.wav` / `audio/wav`; no guarda grabaciones. `http_parser` provee `MediaType` para el multipart de `package:http`. Se añadió `RECORD_AUDIO` a Android y `NSMicrophoneUsageDescription` a iOS; la versión mínima efectiva de Android es 23 por `record` y el proyecto iOS declara 15.0 por los paquetes Firebase. No se ampliaron permisos de almacenamiento. Ver [record 6.2.1](https://pub.dev/packages/record/versions/6.2.1) y [http_parser](https://pub.dev/packages/http_parser).

### Preparación en otro equipo con Flutter web

Abre en VS Code la raíz que contiene `backend_Telemedicina` y `mobile_telemedicina`. Ese equipo debe tener Flutter compatible con Dart `^3.11.1`, Chrome o Edge, el entorno Python del backend con sus dependencias y acceso a Groq para interpretación y dictado (`GROQ_API_KEY` en el `.env` **del backend**, nunca en Flutter). `record: ^6.2.1`, `http_parser: ^4.1.2` y `file_saver: ^0.4.0` deben resolverse allí; en este equipo no se ejecutó `pub get` ni se editó `pubspec.lock`. La documentación de [record 6.2.1](https://pub.dev/documentation/record/6.2.1/record/AudioRecorder-class.html) confirma la API de captura en stream PCM16; [file_saver 0.4.0](https://pub.dev/packages/file_saver/versions/0.4.0) admite bytes en Flutter web. La captura real, su frecuencia de muestreo y los archivos guardados requieren comprobación en hardware/navegador.

En una terminal de VS Code situada en la **raíz del proyecto**, inicia el backend sintético. El intérprete mostrado es el entorno existente de este repositorio; si ese equipo tiene el entorno Python en otra ubicación, usa su intérprete equivalente con las dependencias del backend ya preparadas.

```powershell
Set-Location .\backend_Telemedicina
& '..\.venv\Scripts\python.exe' .\scripts\run_cu22_local.py
```

El lanzador escucha en `127.0.0.1:8000`, usa SQLite en memoria y no conecta a Neon. El JWT local cambia al reiniciar el proceso; vuelve a iniciar sesión después de cada reinicio. Solo `/interpretar` y `/transcribir` necesitan el proveedor Groq; la consulta manual y la exportación usan el backend aislado.

| Rol | Correo sintético | Contraseña sintética |
| --- | --- | --- |
| ADMIN clínica 1 | `admin1@example.com` | `Cu22-local-2026!` |
| ADMIN clínica 2 | `admin2@example.com` | `Cu22-local-2026!` |
| Médico | `medico@example.com` | `Cu22-local-2026!` |
| Recepción | `recepcion@example.com` | `Cu22-local-2026!` |
| Paciente | `paciente@example.com` | `Cu22-local-2026!` |

El backend permite exactamente los orígenes `http://127.0.0.1:4200` y `http://localhost:4200`. Si Angular ocupa el puerto, detén su servidor con **Ctrl+C en su propia terminal**. Para identificar el proceso antes de detenerlo:

```powershell
Get-NetTCPConnection -LocalPort 4200 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
```

En **otra terminal nueva desde la raíz**, ejecuta estas comprobaciones y luego **una** de las dos variantes de navegador. `API_BASE_URL` solo se sobreescribe para esa ejecución; el valor predeterminado del proyecto permanece intacto.

```powershell
Set-Location .\mobile_telemedicina
flutter devices
flutter pub get
flutter analyze
flutter test test/analytics_reports_test.dart
flutter test
flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 4200 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Para Edge, sustituye únicamente el último comando por:

```powershell
flutter run -d edge --web-hostname 127.0.0.1 --web-port 4200 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Abre `http://127.0.0.1:4200/`. Flutter web usa navegación hash en este proyecto: la ruta directa de Reportes es `http://127.0.0.1:4200/#/analytics`. En Chrome/Edge reduce la ventana o usa el modo de dispositivo de DevTools a 390 × 844 y luego 320 × 640; revisa controles, tabla horizontal, foco, consola y red. Detén Flutter y backend con **Ctrl+C** en sus terminales.

### Recorridos manuales propuestos

1. Entra con admin1. Debe aparecer Reportes. Para septiembre de 2026, Citas sin desglose suma 14, Encuentros 12, Cancelaciones 2 y Pacientes únicos globales 2; Ausentismo indica «No disponible». Agrupa Citas por fecha, selecciona columnas y orden descendente, fija 10 grupos por página: deben verse 10 y luego 4. Cambia filtros después de generar; la exportación debe bloquearse hasta regenerar. Restablece los filtros, regenera y descarga PDF, XLSX, CSV y HTML: cada archivo debe incluir los 14 grupos filtrados, no solo la primera página.
2. Escribe «Citas de septiembre de 2026» y pulsa **Aplicar filtros**: se actualiza la definición sin consulta. Pulsa **Enviar**: interpreta y consulta. «Citas de septiembre» debe pedir aclaración sin aplicar filtros parciales. **Limpiar texto** borra solo solicitud y mensajes; conserva definición, resultados, página y exportación.
3. Permite el micrófono del sitio cuando el navegador lo solicite. Con **Enviar al terminar** apagado, pulsa Micrófono, dicta y pulsa Detener: se transcribe al cuadro editable, sin interpretación ni consulta. Con la opción encendida **antes de iniciar**, una detención explícita transcribe y usa Enviar una vez. Si editas el texto durante el dictado, queda transcripción pendiente para incorporar o descartar sin autoenvío. Comprueba error de permiso, transcripción vacía, aclaración y fallo de red; conserva la entrada manual. Al llegar a 60 segundos o al salir/ocultar la pestaña no debe haber autoenvío y el micrófono debe liberarse.
4. Cierra sesión y entra con admin2: septiembre de 2026 tiene 4 citas y 4 encuentros, con solo las opciones de su clínica y sin resultados anteriores. Prueba después Médico, Recepción y Paciente: no debe aparecer Reportes y `/#/analytics` debe rechazar el acceso sin invalidar una sesión válida. Prueba también cierre de sesión y cambio de cuenta mientras espera una transcripción o interpretación; ninguna respuesta tardía debe aparecer en la cuenta siguiente.

La descarga web usa `file_saver` con bytes autenticados: Chrome/Edge controla la ubicación y puede descargar sin diálogo. Revisa nombre, extensión, MIME y contenido. El micrófono requiere permiso y un [contexto seguro](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia); loopback local funciona para desarrollo. `localhost` y `127.0.0.1` son **el equipo donde corre el navegador**. Si Flutter web y backend corren en equipos distintos, el lanzador actual no es accesible porque escucha solo en loopback: prepara aparte un backend de pruebas aislado accesible desde el navegador, autoriza el origen exacto en CORS y configura `API_BASE_URL` con su dirección HTTPS. Una página HTTPS no debe llamar a una API HTTP; mantén origen seguro para micrófono y no alteres producción por esta prueba.

Esta guía prueba **Flutter web**. Android e iOS siguen pendientes por separado: permisos y audio reales, API accesible desde emulador/dispositivo, política de HTTP local, ciclo de vida nativo y guardado de archivos. El manifiesto Android permite HTTP solo en debug y el Info.plist de iOS contiene el motivo del permiso de micrófono.

Desde la raíz del proyecto, si OpenSpec CLI está disponible en ese equipo, ejecuta `openspec doctor`, `openspec validate --specs` y `openspec validate cu22-interpretar-dictado-mobile`. Siguen pendientes la resolución de dependencias, compilación, pruebas Flutter, revisión visual, micrófono y descargas. La web Angular ya revisada no sustituye estas pruebas móviles.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
