# Configuración de Permisos Android

## Permisos Configurados

### 1. Permisos de Ubicación

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

- **ACCESS_FINE_LOCATION**: Ubicación precisa (GPS)
- **ACCESS_COARSE_LOCATION**: Ubicación aproximada (red celular/WiFi)
- **ACCESS_BACKGROUND_LOCATION**: Ubicación en segundo plano

### 2. Permisos de Cámara

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

- **CAMERA**: Acceso a la cámara
- **hardware.camera**: Característica de cámara (opcional)
- **hardware.camera.autofocus**: Autofocus (opcional)

### 3. Permisos de Almacenamiento

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

- **READ_EXTERNAL_STORAGE**: Leer archivos
- **WRITE_EXTERNAL_STORAGE**: Escribir archivos
- **MANAGE_EXTERNAL_STORAGE**: Gestión completa de archivos (Android 11+)

### 4. Permisos de Internet

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

- **INTERNET**: Conexión a internet
- **ACCESS_NETWORK_STATE**: Estado de la red
- **ACCESS_WIFI_STATE**: Estado del WiFi

### 5. Permisos Adicionales

```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
```

- **WAKE_LOCK**: Mantener pantalla encendida
- **VIBRATE**: Vibración del dispositivo

## Configuración de Seguridad de Red

### Archivo: `network_security_config.xml`

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">172.25.67.77</domain>
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>
</network-security-config>
```

**Propósito**: Permitir conexiones HTTP a servidores de desarrollo y producción.

## MainActivity.kt Mejorado

### Funcionalidades Agregadas:

- **MethodChannel**: Para comunicación entre Flutter y Android
- **checkPermission**: Verificar estado de permisos
- **requestPermission**: Solicitar permisos dinámicamente

## Cómo Solicitar Permisos en Flutter

### Ejemplo de Uso:

```dart
import 'package:permission_handler/permission_handler.dart';

// Solicitar permiso de ubicación
PermissionStatus status = await Permission.location.request();

// Verificar estado
if (status.isGranted) {
  // Permiso concedido
} else {
  // Permiso denegado
}
```

## Permisos por Versión de Android

### Android 6.0+ (API 23+)

- Permisos peligrosos requieren solicitud en tiempo de ejecución
- Usar `permission_handler` para manejo dinámico

### Android 11+ (API 30+)

- `MANAGE_EXTERNAL_STORAGE` para acceso completo a archivos
- Cambios en el manejo de archivos

### Android 13+ (API 33+)

- Permisos granulares para fotos y videos
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`

## Solución de Problemas

### Error: "Permission denied"

1. Verificar que el permiso esté declarado en `AndroidManifest.xml`
2. Solicitar permiso en tiempo de ejecución
3. Verificar configuración del dispositivo

### Error: "Network security config"

1. Verificar archivo `network_security_config.xml`
2. Asegurar que `android:networkSecurityConfig` esté configurado
3. Verificar dominios permitidos

### Error: "Camera not available"

1. Verificar permisos de cámara
2. Verificar características de hardware
3. Probar en dispositivo físico

## Comandos Útiles

### Limpiar y Reconstruir:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### Verificar Permisos:

```bash
adb shell pm list permissions -d -g
adb shell dumpsys package com.example.techhubmobile
```

## Notas Importantes

1. **Testing**: Siempre probar en dispositivo físico
2. **Versiones**: Considerar compatibilidad con diferentes versiones de Android
3. **UX**: Explicar al usuario por qué se necesitan los permisos
4. **Fallbacks**: Manejar casos donde los permisos son denegados
