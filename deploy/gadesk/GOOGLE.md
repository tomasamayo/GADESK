# GADESK: registro público con Google

Estado: registro público activado en producción el 1 de noviembre de 2026, tras aprobación del propietario y pruebas con dos cuentas Google.

## Backend reproducible

Base BetterDesk: `eb84feff61c25595e326294fccd13e27ccd14a29`.
Parche: `patches/betterdesk-google.patch`.
SHA-256: `355668c6a8205e8f56ffaacf5b7e0ca1f56a98733cc029afe9920073128594f6`.
Licencia original: `third-party/BetterDesk-LICENSE` (AGPL-3.0).
El parche añade la biblioteca de verificación `github.com/coreos/go-oidc/v3`
fijada a v3.21.0, con sus dependencias y sumas. No se implementa criptografía
propia para validar tokens.

Aplicar únicamente sobre la base fijada:

```sh
git apply --check /ruta/patches/betterdesk-google.patch
git apply /ruta/patches/betterdesk-google.patch
cd betterdesk-server
go test ./...
go vet ./auth ./api
```

Para Google se comprueban firma RS256/JWKS, emisor, audiencia, caducidad, nonce,
state de un uso y coincidencia de sub con UserInfo. Se requiere correo verificado.
La identidad es `google:<sub>`, independiente del correo o nombre. Las altas
usarán el rol limitado `pro`; no se vinculan automáticamente cuentas locales.
El nombre, correo y foto verificados se conservan bajo claves de perfil Google
en la base privada y se devuelven sólo al titular autenticado. Las fotos se
limitan a URLs HTTPS de googleusercontent.com. Al atender una solicitud de
eliminación de cuenta debe eliminarse también su clave `gadesk.google.profile.google:<sub>`.
Los otros proveedores del backend conservan su comportamiento previo.

## Configuración del propietario

Se necesitará un cliente OAuth de tipo aplicación web de Google Cloud, audiencia
externa y callback exacto:

`https://gadesk.grupoamayo.com/api/oidc/callback`

Permisos solicitados: `openid profile email`. El propietario crea el cliente y
completa las aceptaciones o verificaciones de Google. El secreto permanece en
el VPS, fuera de la web, el repositorio y los instaladores; no se envía por chat.
Primero se prueba en configuración de pruebas independiente. No se activará
facturación para esta integración. Correo público de asistencia autorizado: `tomasamayo@gmail.com`. El propietario
autorizó aceptar la política de Google y crear el cliente OAuth durante la
configuración. El propietario aprobó publicar la política con `Grupo Amayo J Sac` como responsable
y ese correo de contacto; está disponible en `/privacy.html`.

## Validación realizada

Las pruebas nuevas rechazaron respuestas inválidas antes de la corrección y
pasaron con el parche. Cubren firma, audiencia, emisor, expiración, nonce, token
ausente, UserInfo no disponible o de otra identidad, y correo no verificado.
Dos sujetos con el mismo prefijo de correo conservan identidades distintas.
Las pruebas API confirman que no se reclama una cuenta local preexistente, que
dos libretas personales permanecen separadas y que pro no recibe inventario
global ni permisos de configuración. La suite Go completa y go vet pasaron
localmente con el Go oficial 1.26.10. Esto no sustituye la prueba real con Google
ni la validación del contenedor/nginx antes de desplegar.

## Rutas y configuración privada

`nginx-account-rates.conf` se instala en el contexto HTTP de aaPanel, en
`/www/server/panel/vhost/nginx/00-gadesk-account-rates.conf`; el host debe incluir
ese directorio dentro de HTTP. El include de proxy termina en `.inc` para no
cargarse accidentalmente como un bloque de servidor. El despliegue restaura
los tres archivos si nginx no valida o no puede recargarse.

Sólo se publican las rutas exactas de opciones, autorización/consulta/callback
Google, logout, currentUser y libreta personal/legacy/tags. Los métodos están
limitados. Las demás rutas `/api/` devuelven 404, incluidas las administrativas.
La consulta de grupos/inventario no se habilita para cuentas públicas. Las
respuestas no se cachean, se conserva HSTS y no se escriben URLs de cuenta con
códigos de un uso en los access logs. Hay límites separados para inicios,
consultas de resultado y libreta, contando la IP efectiva en nginx.

El backend expone su API sólo en `127.0.0.1:21114`. La etiqueta de imagen incluye
el SHA-256 completo del parche, calculado por `deploy-wss.sh` al preparar `.env`.
No se reemplaza el servicio de producción hasta validar la imagen y nginx en
un entorno separado. El script conserva los datos y la clave del relay.

El archivo privado de OAuth contiene `client_id` y `client_secret`. Sus permisos
deben ser 0600 y debe permanecer fuera del directorio público. Las demás
opciones son los valores fijos del flujo aprobado; un valor contradictorio
se rechaza sin modificar la base de datos. Tras detener el backend, ejecutar
desde el host (requiere Docker para comprobar que está detenido):

```sh
python3 configure-google.py /opt/gadesk/private/google.json /opt/gadesk/wss/data/gadesk.sqlite3
```

La herramienta crea una copia consistente SQLite de modo 0600 antes de una
actualización transaccional de las opciones. No muestra el secreto. Reiniciar
el backend después y verificar el inicio de sesión antes de anunciarlo.

## Entorno de pruebas (1 de noviembre de 2026)

La primera versión del parche compiló en el VPS como `gadesk-google-stage:14538850`.
La ampliación de perfiles (parche anterior `9d04483a…`) pasó la suite Go completa y
compiló como `gadesk-google-stage:9d04483a`; volvió a superar las 26
comprobaciones HTTP en `/home/impetu/gadesk-google-profile-stage`.
Un backend separado con base/clave nuevas y un nginx separado completaron 26
comprobaciones HTTP reales: opciones, métodos, sesión bearer, rutas
administrativas privadas y dos libretas independientes. El límite de inicio
de sesión respondió 429 al agotar su presupuesto. La configuración completa
de nginx validó en el contenedor oficial 1.30; el binario de aaPanel también
aceptó la sintaxis, pero su comprobación completa como usuario impetu no pudo
acceder a sus rutas privadas de PID/temporales. El despliegue de producción
debe ejecutar su validación habitual como root antes de recargar.

Los fixtures sintéticos de HTTP se conservan en directorios privados de pruebas.
Los proyectos Google `gadesk-grupoamayo` y `gadesk-grupoamayo-test` tienen clientes
separados; sus secretos permanecen en archivos 0600 fuera de la web del VPS.

Con aprobación expresa del propietario se activaron temporalmente las rutas HTTPS
de cuentas contra `gadesk-google-oauth-test`, API `127.0.0.1:22134`. La base/clave de
pruebas son persistentes y privadas bajo `/home/impetu/gadesk-google-oauth-test/data`.
El relay original sigue sin cambios. La recarga del nginx de aaPanel y los checks
HTTPS pasaron; la comprobación del relay por WSS completó 52 verificaciones.
El proyecto de pruebas permite únicamente los dos correos autorizados por el propietario.

El acceso real desde macOS build71 confirmó perfiles persistentes y dos identidades
Google diferentes, con libretas separadas y sin acceso a inventario ni administración.
El cambio de selector se desplegó como `gadesk-google-stage:355668c6`, conservando la
base, su copia consistente y el contenedor anterior detenido para recuperación.
Con aprobación explícita en el paso final, el proyecto `gadesk-grupoamayo` pasó a
«En producción». Se configuró su cliente privado en el backend original actualizado,
con API en localhost21114 y clave de relay conservada. `nginx -t` ejecutado como root
pasó y aaPanel confirmó la recarga. La API HTTPS usa el cliente de producción, PKCE
y sólo los scopes aprobados; currentUser sin sesión devuelve401 y administración404.
Las 52 comprobaciones de WSS/relay cifrado pasaron de nuevo. Los accesos reales
en producción devolvieron perfiles verificados con sesiones ordinarias sin administración.
Las dos identidades mantuvieron libretas separadas; al volver a la cuenta principal
su identidad y libreta persistieron. La entrada sintética de verificación fue retirada.

Recuperación privada: `/opt/gadesk/wss/google-before-build71` conserva SQLite
consistente, claves, compose, env, configuración nginx e inspección del contenedor.
El origen previo está en `source.before-google71`; la nueva fuente aplicada ocupa
`source`. Los servicios Google de pruebas quedaron detenidos y sus datos privados
persistentes se conservaron. La imagen de producción lleva el SHA completo del parche.
Los instaladores build71 y la fuente correspondiente se promovieron juntos; las
versiones anteriores de alias, manifiesto e índice se copiaron al respaldo privado.
Los cinco binarios publicados, las fuentes y la política de privacidad se descargaron
por HTTPS y coincidieron con sus SHA-256 locales.

La fuente correspondiente de los clientes build71 permanece en
`GADESK-1.5.1-build71-source.tar.gz` (revisión `80b1857`). El cambio posterior del
servidor tiene su fuente completa y Dockerfile por separado en
`GADESK-betterdesk-355668c6-source.tar.gz`, SHA-256
`5aed48c95e181f0249d8911f572f0091cea436ef01ea2fca851b880f899b444b`.

El parche solicita `prompt=select_account` únicamente al proveedor Google para
que cerrar sesión en GADESK permita elegir otra cuenta sin cerrar la sesión del navegador.
La prueba de regresión reproduce la URL anterior sin selector y mantiene sin cambios
la autorización de los demás proveedores.

## Registro completo de decisiones de ejecución y revisión

La revisión independiente no encontró incidencias Critical/Important en el candidato.
El selector de cuentas fue una corrección posterior reportada por el propietario,
validada con regresión RED→GREEN y pruebas reales dentro de la única pasada de correcciones.
Estas son todas las decisiones registradas, incluidas las cuestiones que la revisión
delegó al implementador; se conserva su justificación y el coste si resultan incorrectas.

- Work in the existing dedicated codex/gadesk-deployment checkout — user chose execution here, it is clean and not main/master, and current toolchain caches are already configured here — cost if wrong: concurrent manual edits would need reconciliation.
- Run the verified official Go1.26.10 darwin-arm64 toolchain locally rather than through VPS UI/Docker for unit tests — exact upstream toolchain is available and fixture tests do not depend on Linux — cost if wrong: Linux runtime differences still require staged-container tests before deployment.
- verification is an OIDCProvider method rather than a free function to reuse the existing HTTP client timeout and test transport — avoids global network configuration — cost if wrong: method may need adaptation if upstream client ownership changes.
- two-account/private-inventory checks characterize existing pro-role boundaries (not artificially forced RED); new validation and local collision tests supply the feature RED→GREEN — cost if wrong: existing isolation assumptions must still be verified through staged HTTP routes.
- keep group inventory APIs private; the GADESK public-account UI will explain unsupported shared-device inventory rather than query /api/users or /api/peers — required by public pro account scope and approved spec — cost if wrong: shared organization inventory would need a separately authorized feature.
- interleave independent UI work while server validation builds in background, retaining incomplete task gates rather than marking them done — avoids waiting on external setup and preserves approved sequence dependencies — cost if wrong: final review must inspect combined task ranges.
- persist verified Google display name/email/avatar in feature-prefixed private DB config using the existing DB interface, with Google-only read/write hooks — approved spec requires a human-readable profile after session refresh; avoids broad User schema/driver changes — cost if wrong: profile records need explicit removal together with an account deletion request.
- owner explicitly authorized agent to accept the displayed Google API User Data Policy and create the OAuth web client at action time, superseding the plan handoff — follows newer direct owner instruction — cost if wrong: owner remains responsible for policy acceptance and must revoke the client if configuration is rejected. No billing enabled.
- live Google signup/cancel/retry/logout set aside by review — keep an explicit live verification gate before public signup is advertised — cost if wrong: broken browser-return or session behavior could escape automated tests.
- Android/Windows physical runtime checks set aside by review — run available emulator/packaging/CI checks and report unavailable hardware tests — cost if wrong: device-specific behavior remains unverified.
- privacy-owner identity/approval and Google publication set aside by review — require factual owner approval and Google readiness before public activation — cost if wrong: release remains blocked or Google rejects public access.
- non-Google upstream identity validation remains outside this Google-only patch — server is configured only for the verified Google flow and GADESK hides other providers — cost if wrong: enabling another provider would need a separate verification audit.
- outgoing-only Settings remains available from the existing title-bar action — no new sidebar shortcut is necessary to preserve capability — cost if wrong: users need the alternate existing entry.
- reviewer did not receive original mockup pixels — implementer compared the running macOS UI with the supplied reference and tested small/zoomed windows — cost if wrong: small visual differences remain.
- versioned source correspondence and stable alias promotion remain release gates — generate from actual build71 revision including pinned submodule/backend patch and update the source alias together with installers — cost if wrong: downloads could point at older corresponding source.
- retain the original incoming-only desktop layout because its existing child-key sizing lifecycle depends on it; apply the new sidebar to full/outgoing clients — preserves directional controls without native window lifecycle changes — cost if wrong: incoming-only visual parity is deferred.

Minor diferido: `deploy-wss.sh` rechaza de forma segura un checkout que lleva
un parche Google anterior diferente. Para una actualización futura debe recrearse
el checkout administrado en el pin antes de aplicar el nuevo parche; el origen previo
se conserva en el respaldo. No se añadió lógica para administrar historiales de parches.

Límites de validación: el propietario confirmó arranque del APK71 en el Samsung S24;
la compilación y estructura de Windows pasaron, pero no se ejecutó Windows físico.
macOS conserva firma ad hoc y Windows carece de firma de editor. No se afirma
notarización ni verificación de marca por Google. Caducidad y rechazo de estados
inválidos se verifican en las suites automatizadas; no se esperó la expiración real
de un consentimiento Google. El relay se probó a nivel de protocolo cifrado con
IDs sintéticos, sin afirmar una sesión real completa de vídeo/ratón entre equipos.
