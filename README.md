# safelogin

Aplicacion Flutter con login seguro, proteccion contra captura de pantalla,
deteccion de ubicacion falsa, almacenamiento seguro local y borrado remoto de
datos sensibles mediante Firebase Cloud Messaging.

## Datos sensibles

Al iniciar sesion con `admin` / `1234`, la app crea automaticamente estos campos
en `flutter_secure_storage`:

- `sensitive.session_token`
- `sensitive.refresh_token`
- `sensitive.account_number`
- `sensitive.security_pin`

Los valores se generan localmente y se muestran en pantalla solo en forma
enmascarada.

## Configuracion de Firebase FCM

Este repositorio ya incluye `firebase_core`, `firebase_messaging` y un archivo
placeholder en `lib/firebase_options.dart`. Para asociarlo con un proyecto real:

1. Crea un proyecto en Firebase Console.
2. Registra la app Android con paquete `com.gloria.safelogin`.
3. Descarga `google-services.json` y colocalo en `android/app/`.
4. Activa Cloud Messaging en el proyecto.
5. Instala FlutterFire CLI y reemplaza el placeholder:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<tu-project-id> --platforms=android,ios
```

En iOS tambien debes registrar el bundle, agregar `GoogleService-Info.plist` en
`ios/Runner/` y habilitar Push Notifications en Xcode.

## Borrado remoto especifico por usuario

La app solo borra datos cuando recibe un mensaje FCM con `action` correcto,
`scope=user` y `targetUserId` igual al usuario registrado en ese dispositivo.
El envio debe hacerse al token FCM del dispositivo del usuario, no a un topic.

Payload de datos esperado:

```json
{
  "message": {
    "token": "<TOKEN_FCM_DEL_USUARIO>",
    "data": {
      "action": "remote_delete_sensitive_data",
      "scope": "user",
      "targetUserId": "admin",
      "reason": "security_policy"
    },
    "android": {
      "priority": "HIGH"
    },
    "apns": {
      "payload": {
        "aps": {
          "content-available": 1
        }
      }
    }
  }
}
```
