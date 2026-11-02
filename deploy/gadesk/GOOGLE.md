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
