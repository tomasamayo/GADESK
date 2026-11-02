# GADESK: registro público con Google

Estado: integración en preparación; el registro público todavía no está activo.

## Backend reproducible

Base BetterDesk: `eb84feff61c25595e326294fccd13e27ccd14a29`.
Parche: `patches/betterdesk-google.patch`.
SHA-256: `14538850a2da3bbb9b57b21538388f4635ba274813f67ae1952e2a4e065b67f2`.
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
Los otros proveedores del backend conservan su comportamiento previo.

## Configuración del propietario

Se necesitará un cliente OAuth de tipo aplicación web de Google Cloud, audiencia
externa y callback exacto:

`https://gadesk.grupoamayo.com/api/oidc/callback`

Permisos solicitados: `openid profile email`. El propietario crea el cliente y
completa las aceptaciones o verificaciones de Google. El secreto permanece en
el VPS, fuera de la web, el repositorio y los instaladores; no se envía por chat.
Primero se prueba en configuración de pruebas independiente. No se activará
facturación para esta integración. La identidad/contacto del responsable para
la página de privacidad se confirmará antes de publicar ese texto.

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

La imagen parcheada compiló en el VPS como `gadesk-google-stage:14538850`.
Un backend separado con base/clave nuevas y un nginx separado completaron 26
comprobaciones HTTP reales: opciones, métodos, sesión bearer, rutas
administrativas privadas y dos libretas independientes. El límite de inicio
de sesión respondió 429 al agotar su presupuesto. La configuración completa
de nginx validó en el contenedor oficial 1.30; el binario de aaPanel también
aceptó la sintaxis, pero su comprobación completa como usuario impetu no pudo
acceder a sus rutas privadas de PID/temporales. El despliegue de producción
debe ejecutar su validación habitual como root antes de recargar.

Los fixtures se conservan únicamente bajo `/home/impetu/gadesk-google-stage`,
los puertos de prueba sólo escuchan en localhost y no contienen datos reales
ni credenciales Google. El servicio y nginx de producción todavía no se han
reemplazado. Los tests Python de configuración (3) y Docker Compose config
pasaron localmente. El acceso real con Google sigue pendiente de su cliente OAuth.
