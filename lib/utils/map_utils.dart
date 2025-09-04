import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapUtils {
  // Configuración optimizada para evitar problemas de cache
  static TileLayer createOptimizedTileLayer() {
    return TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'com.example.techhub_mobile',
      maxZoom: 18,
      minZoom: 5,
      tileProvider: NetworkTileProvider(),
      // Configuraciones adicionales para optimizar el cache
      maxNativeZoom: 18,
    );
  }

  // Opciones de mapa optimizadas
  static MapOptions createOptimizedMapOptions({
    required double lat,
    required double lng,
    double zoom = 16.0,
  }) {
    return MapOptions(
      initialCenter: LatLng(lat, lng),
      initialZoom: zoom,
      maxZoom: 18.0,
      minZoom: 5.0,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      // Configuraciones adicionales para mejorar performance
      keepAlive: false, // Importante: no mantener alive cuando no es visible
    );
  }

  // Método para limpiar recursos de mapa de forma segura
  static void safeDisposeMapController(MapController? controller) {
    try {
      controller?.dispose();
    } catch (e) {
      // Silenciar errores de dispose para evitar crashes
      // En producción se debería usar un logger apropiado
      debugPrint('MapController dispose error: $e');
    }
  }
}