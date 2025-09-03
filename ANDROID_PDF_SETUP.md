# Configuración de Android para Descarga de PDFs

## Cambios Realizados

### 1. AndroidManifest.xml

- **Permisos modernos**: Reemplazados permisos obsoletos de almacenamiento
- **FileProvider**: Configurado para manejo seguro de archivos
- **Compatibilidad**: Agregado `requestLegacyExternalStorage="false"`

### 2. file_paths.xml

- **Rutas configuradas**: Directorios de descargas, documentos y archivos
- **Seguridad**: Solo rutas específicas y seguras

### 3. pdf_download_mobile.dart

- **Manejo de permisos**: Solicitud automática de permisos de almacenamiento
- **Directorios múltiples**: Intenta guardar en descargas públicas, fallback a privado
- **Mejor manejo de errores**: Logging y fallbacks robustos

### 4. build.gradle.kts

- **Compatibilidad**: Soporte para FileProvider y Android moderno
- **Empaquetado**: Exclusión de metadatos conflictivos

## Permisos Requeridos

### Android 10-12 (API 29-32)

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```

### Android 13+ (API 33+)

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

## Funcionalidades

### Descarga de PDFs

- Guarda en directorio de descargas público (si hay permisos)
- Fallback a directorio privado de la app
- Manejo automático de permisos

### Compartir PDFs

- Uso de FileProvider para compartir archivos
- Limpieza automática de archivos temporales
- Compatibilidad con apps de terceros

## Dependencias

### Flutter

- `permission_handler: ^12.0.1` - Manejo de permisos
- `path_provider: ^2.1.4` - Acceso a directorios
- `printing: ^5.13.2` - Generación y compartir PDFs

### Android

- `androidx.core.content.FileProvider` - Compartir archivos seguros
- `androidx.core:core:1.9.0+` - Soporte para FileProvider

## Notas Importantes

1. **Android 10+**: Los archivos se guardan en directorio privado por defecto
2. **Permisos granulares**: Android 13+ requiere permisos específicos por tipo de medio
3. **FileProvider**: Necesario para compartir archivos de forma segura
4. **Fallbacks**: Múltiples estrategias de guardado para máxima compatibilidad

## Testing

### Verificar Funcionalidad

1. Descargar PDF desde la app
2. Verificar que se guarde en descargas (con permisos)
3. Probar compartir PDF con otras apps
4. Verificar funcionamiento en diferentes versiones de Android

### Casos de Error

1. Sin permisos de almacenamiento
2. Directorio de descargas no accesible
3. Espacio insuficiente en almacenamiento
4. Apps de terceros no disponibles para compartir
