String gadeskText(String language, String text) {
  if (!language.toLowerCase().startsWith('es')) return text;
  return {
        'Your first Google sign-in creates your GADESK account.':
            'La primera vez que continúes con Google se creará tu cuenta de GADESK.',
        'Your address book is personal. Remote access still requires permission from the other device.':
            'Tu libreta es personal. Para acceder a otro equipo seguirás necesitando su autorización.',
        'Google sign-in is not available yet. You can connect using a remote ID and password.':
            'El acceso con Google todavía no está disponible. Puedes conectarte por ID y contraseña.',
        'We could not reach the account service. Check your connection and try again.':
            'No pudimos conectar con el servidor de cuentas. Comprueba tu conexión y vuelve a intentarlo.',
        'Retry': 'Reintentar',
        'Recents': 'Recientes',
        'Favorites': 'Favoritos',
        'Discovery': 'Descubrimiento',
        'Address book': 'Libreta de direcciones',
        'Devices': 'Dispositivos',
        'No recent connections': 'No hay conexiones recientes',
        'No favorites yet': 'Todavía no hay favoritos',
        'No devices discovered': 'No hay equipos descubiertos',
        'Your address book is empty': 'Tu libreta está vacía',
        'When you connect to other devices, they will appear here.':
            'Cuando te conectes a otros equipos, aparecerán aquí.',
        'Add a device to your favorites to find it here.':
            'Añade un equipo a tus favoritos para encontrarlo aquí.',
        'Devices discovered on your local network will appear here.':
            'Los equipos descubiertos en tu red local aparecerán aquí.',
        'Save devices in your personal address book to find them on your GADESK devices.':
            'Guarda equipos en tu libreta personal para encontrarlos en tus dispositivos con GADESK.',
        'This is a personal account. Save your devices in the address book.':
            'Esta cuenta es personal. Guarda tus equipos en la libreta de direcciones.',
      }[text] ??
      text;
}
