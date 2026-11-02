# GADESK: registro público con Google e interfaz

## Solicitud y decisiones del usuario

El usuario pide poder crear una cuenta e iniciar sesión en GADESK, y una
interfaz muy parecida a su primer mockup. Eligió registro público para cualquier
persona y después la opción 2: iniciar sesión con Google. Conservamos la marca,
el logo vectorial, el dominio y los clientes Android, macOS y Windows existentes.

## Enfoques considerados

1. Correo y contraseña propios: exige verificación, recuperación y entrega de
   correo. Se ofreció, pero el usuario eligió Google.
2. Google mediante OpenID Connect: seleccionado por el usuario. Aprovecha el
   flujo de navegador y consulta de resultado que ya tiene el cliente Flutter.
   El backend actual dispone de OIDC y aprovisionamiento automático, pero necesita
   validación y ajustes específicos antes de publicar cuentas para terceros.

El diseñador propone conservar Flutter y el backend Go ya desplegado. No se
construye otro protocolo de acceso remoto ni se sustituye el servidor de relay.

## Comportamiento para la persona que usa GADESK

- El diálogo de cuenta muestra «Continuar con Google» y explica que la primera
  vez crea su cuenta. Se abre el navegador del sistema, Google solicita la
  autorización y GADESK recupera la sesión. Cancelar permite volver a intentarlo.
- El mismo Google inicia la misma cuenta desde Android, macOS y Windows.
- Tras entrar se muestran nombre y avatar si están disponibles y se permite
  cerrar sesión. La libreta personal puede sincronizarse entre sus dispositivos.
- Una persona nueva comienza con su libreta vacía; no recibe listas de equipos
  ajenos, credenciales, permisos de administración ni acceso automático a equipos.
- La conexión por ID sigue funcionando sin cuenta. El control remoto conserva
  la contraseña o aprobación y los permisos del dispositivo remoto.
- Durante un fallo de red o configuración se muestra un mensaje comprensible,
  sin presentar un HTTP 404 ni un formulario de contraseña inutilizable.

## Identidad y separación de cuentas

Se solicita sólo `openid profile email`. La identidad se asocia al emisor de
Google y su `sub`, nunca al prefijo del correo. El correo y nombre son atributos
de presentación y no sirven para fusionar silenciosamente cuentas existentes.
El registro público asigna el rol limitado `pro` del backend y no admite mapas
que eleven a administrador. Se verifica con dos cuentas separadas que el rol y
las rutas de libreta/dispositivos no permitan consultar datos de otras cuentas.
Las funciones de grupos que no correspondan a una cuenta personal se muestran
vacías o deshabilitadas con explicación; no se simulan capacidades compartidas.

El backend fijado actualmente extrae el payload del ID token sin comprobar su
firma y permite que UserInfo falle sin abortar. No se habilitará ese flujo tal
cual para registro público: antes se exige validación estándar de firma/JWKS,
emisor, audiencia, caducidad, nonce, state de un solo uso y vínculo de `sub`
entre ID token y UserInfo cuando se consulte. Se mantienen PKCE, caducidad y
vinculación del resultado con el dispositivo. Cualquier fallo impide crear la
cuenta o emitir la sesión. No se registran códigos, tokens ni secretos en logs.
Los ajustes necesarios se conservan como parche reproducible y probado del
backend fijado, con fuente y licencia; no se cambia `libs/hbb_common`.

## Servidor y Google

El callback propuesto y único de producción es:
`https://gadesk.grupoamayo.com/api/oidc/callback`.
Nginx publica únicamente la lista de rutas de sesión, callback y libreta que
necesitan los clientes. La API administrativa y los servicios internos siguen
privados; no se publica indiscriminadamente `/api/`.
Los endpoints de autenticación llevan límites de solicitudes apropiados y no
cachean respuestas con sesiones. El endpoint de opciones deja de devolver 404.

El propietario debe disponer de un proyecto Google Cloud, un cliente OAuth de
tipo aplicación web y la configuración de audiencia externa. Se utiliza una
configuración de prueba separada de producción para verificar el flujo antes
de permitir a cualquier cuenta entrar. Las credenciales permanecen en el VPS
en almacenamiento privado; el secreto nunca se incorpora al APK, instaladores,
repositorio, descargas o chat. La creación de credenciales y las aceptaciones de
Google las completa el propietario. Se prepara el código y la configuración
sin esperar esa acción, pero el acceso real no se declara operativo sin una
prueba con Google. No se activan servicios facturados ni suscripciones.

La web de descargas conserva su función. Se prepara una página de privacidad
para revisión del propietario que describa los datos realmente almacenados y
la identidad del responsable; no se inventan datos de contacto ni compromisos
legales. Los requisitos de publicación o verificación que imponga Google son
una dependencia externa, no un resultado que el código pueda garantizar.

## Aspecto y distribución

La referencia visual es la primera imagen adjunta por el usuario el 1 de
noviembre de 2026. Se reproducen su jerarquía, espaciado y componentes dentro de
Flutter, sin incrustar la imagen como fondo ni usar sus ID/contraseñas de ejemplo.

- Tema claro predeterminado para GADESK, fondo blanco azulado, bordes suaves,
  tarjetas redondeadas y sombras discretas. El modo oscuro continúa disponible.
- Barra lateral con el logo vectorial existente, GADESK/GRUPO AMAYO y el aviso
  de tecnología de RustDesk. Tarjetas «Tu escritorio» y «Permisos» con contenido
  real, botones de copiar/regenerar y acceso a los permisos del sistema.
- Tarjeta principal con el icono de monitor, «Controlar escritorio remoto», campo
  de ID, botón azul «Conectar» y selección del tipo de conexión existente.
- Pestañas de recientes, favoritos, descubrimiento, libreta y dispositivos:
  selección turquesa/azul, conservación de sus acciones actuales y estados vacíos
  ilustrados con vectores sencillos. Se preservan búsqueda, filtros y menús.
- Estado real del servicio en el pie. No se presenta «Listo» si no está conectado.
- En macOS y Windows se mantiene la estructura del mockup y se adapta al tamaño
  de ventana. La barra de título conserva los controles nativos de cada sistema.
- Android usa la misma identidad, colores, tarjetas y flujo de cuenta con una
  distribución de móvil; no comprime las columnas de escritorio en el teléfono.

Se conservan textos traducibles, foco/teclado, contraste, escalado y los permisos
reales de cada sistema. No se amplía el alcance a rediseñar la sesión remota,
transferencias, ajustes avanzados ni el protocolo. Los nuevos elementos gráficos
son SVG/código vectorial del repositorio; el logo actual permanece intacto.

## Implementación y entrega propuestas

Primero se prepara y prueba la autenticación aislada del relay; después se aplica
el diseño en componentes de inicio y cuenta. Se reutilizan los manejadores de
conexión, portapapeles, contraseña, pestañas y permisos. Se conserva la firma de
Android y se incrementan los números de compilación para actualizar sin borrar
datos. macOS y Windows conservan las limitaciones de firma ya comunicadas.

Antes de publicar se hacen copias privadas consistentes de configuración y base
de datos. La migración y despliegue tienen reversión, sin cambiar las claves del
servidor ni sustituir las apps de descarga hasta verificar las nuevas.
Se entregan APK ARM64, DMG/PKG Apple Silicon y EXE/MSI Windows x64, checksums,
fuente correspondiente y documentación operativa actualizada.

## Criterios de validación

- Registro inicial y segundo acceso Google, cancelación, expiración y logout;
  rechazar state/nonce inválidos, tokens de otro cliente/emisor y repetición.
- Dos identidades distintas con libretas independientes; denegar permisos de
  administración y lectura de dispositivos de otros usuarios.
- Dos cuentas Google con el mismo prefijo de correo permanecen distintas;
  una cuenta local existente no se vincula por coincidencia de nombre.
- Inicio y reconexión por ID con y sin cuenta, registro WSS y relay existente.
- Comparación visual de la pantalla macOS con el mockup; ventana estrecha,
  estados vacíos y con equipos, tema oscuro y escalado de texto.
- Android: arranques en frío y flujo navegador/regreso en el Samsung Android 16;
  macOS: abrir el paquete y probar las acciones principales; Windows: build y
  metadatos, y prueba de ejecución si hay equipo disponible. Se declaran las
  pruebas de plataforma que no se puedan ejecutar.
- Publicación verificable: firma y versión del APK, sumas de cada archivo,
  fuente correspondiente y ausencia de secretos en archivos públicos.

## Estado y decisiones pendientes

Éste es un diseño propuesto para aprobación; todavía no habilita registro ni
modifica la aplicación. Tras aprobarlo se escribe el plan de implementación.
La creación/configuración del cliente Google y los datos de responsable y
contacto para privacidad requieren al propietario en la etapa correspondiente.
El implementador elige los componentes Flutter y detalles de espaciado que
mejor reproduzcan el mockup y define la lista exacta de endpoints tras seguir
las llamadas reales del cliente. Cualquier ampliación que cambie privilegios,
datos recopilados o el flujo acordado debe volver a revisión.
