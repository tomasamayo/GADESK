# GADESK

Acceso remoto de Grupo Amayo, basado en RustDesk 1.5.1.

Descargas: <https://gadesk.grupoamayo.com/>

## Conexión

Los clientes incluyen el servidor y su clave pública. El transporte es WSS
por HTTPS, puerto 443. No hace falta redirigir los puertos 21115–21117 del
router para esta instalación. Las sesiones pasan por el relay del servidor.

| Ajuste | Valor |
|---|---|
| Servidor de ID | `gadesk.grupoamayo.com` |
| Relay | `gadesk.grupoamayo.com:21117` (convertido a WSS por el cliente) |
| API / selección de HTTPS | `https://gadesk.grupoamayo.com` |
| WebSocket | Activado |
| Clave pública | `8wk8CXUVJg69QnzZH2of2LjRk7VsY+OP+Tub87xv+XM=` |

El endpoint de señalización es `/ws/id` y el de relay es `/ws/relay`.
El servidor no publica su API administrativa. La contraseña o aprobación
del equipo remoto sigue siendo necesaria.

## Aplicaciones

- Android: APK ARM64, ID `com.grupoamayo.gadesk`. La instalación y los permisos
  de captura de pantalla/Accesibilidad se completan en el dispositivo.
- macOS: DMG y PKG para Apple Silicon, macOS 12.3 o superior. La app lleva firma ad hoc; el PKG no
  está firmado y no hay notarización de Apple. El usuario autoriza Grabación
  de pantalla y Accesibilidad para compartir y controlar su escritorio.
- Windows: EXE instalable y MSI para x64, sin firma de editor.

La identidad GADESK permite perfiles separados de RustDesk. Las actualizaciones
oficiales de RustDesk están desactivadas para mantener la marca y configuración.
Los archivos `SHA256SUMS` y `downloads.json` describen los instaladores publicados.

## Servidor

La instalación activa usa exclusivamente el backend Go de BetterDesk fijado en
`eb84feff61c25595e326294fccd13e27ccd14a29`. Consulta [WSS.md](WSS.md) para
la configuración, el límite compartido de conexiones y la reversión.

```sh
cd /opt/gadesk/wss
docker compose ps
docker compose logs --tail 100 backend
```

Los datos y claves privados están en `/opt/gadesk/wss/data`. Conserva una copia
privada de las claves y una copia consistente de SQLite. Los datos del servidor
original permanecen en `/opt/gadesk/server/data`; sus contenedores están detenidos.

El sitio y los instaladores públicos están en `/www/wwwroot/GA/DATAX/GADESK`.
Los archivos privados de compilación están en `/opt/gadesk/build`.
La clave de firma de Android y su contraseña se conservan únicamente en
`/opt/gadesk/build/secrets`; ambas son necesarias para publicar actualizaciones
del mismo APK. No deben copiarse al sitio ni al repositorio.

## Compilación

- [ANDROID.md](ANDROID.md): entorno Linux, dependencias y firma del APK.
- `package-macos.sh`: empaqueta una compilación Release de macOS ya terminada.
- `.github/workflows/gadesk-windows.yml`: compila y verifica los instaladores
  de Windows en GitHub Actions.
- `publish-downloads.py`: genera el manifiesto y las sumas de archivos
  verificados que ya estén copiados al directorio público.

Se conservan las licencias y avisos de RustDesk. El código correspondiente está
en el repositorio público y en el archivo fuente enlazado en las descargas.
