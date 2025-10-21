import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:http/http.dart' as http;

class AccessRestrictionService {
  static final AccessRestrictionService _instance =
      AccessRestrictionService._internal();
  factory AccessRestrictionService() => _instance;
  AccessRestrictionService._internal();

  List<List<List<double>>>? _geofencePolygons;
  bool _initialized = false;
  // Guardamos el tiempo del servidor en UTC y el momento local (UTC) en que se obtuvo
  DateTime? _cachedServerTimeUtc;
  DateTime? _cachedLocalTimeUtc;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    await _loadGeofence();
    await _syncTimeWithServer();
    _initialized = true;
  }

  Future<void> _syncTimeWithServer() async {
    try {
      // Use HTTPS to avoid mixed-content / cleartext restrictions in mobile/web
      final uri = Uri.parse(
        'https://worldtimeapi.org/api/timezone/America/Argentina/Buenos_Aires',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final datetimeStr = data['datetime'] as String?;
          if (datetimeStr != null) {
            // Normalizamos a UTC la fecha devuelta por el servidor
            final serverDateTime = DateTime.parse(datetimeStr).toUtc();
            _cachedServerTimeUtc = serverDateTime;
            _cachedLocalTimeUtc = DateTime.now().toUtc();
            developer.log(
              'Time synced with server (UTC): $_cachedServerTimeUtc',
              name: 'AccessRestrictionService',
            );
            return;
          } else {
            developer.log(
              'Server response missing "datetime" field',
              name: 'AccessRestrictionService',
            );
          }
        } catch (e, st) {
          developer.log(
            'Error parsing time server response: $e\n$st',
            name: 'AccessRestrictionService',
          );
        }
      } else {
        developer.log(
          'Time server returned status ${response.statusCode}',
          name: 'AccessRestrictionService',
        );
      }
      // If we reach here, treat as failed to sync
      _cachedServerTimeUtc = null;
      _cachedLocalTimeUtc = null;
    } catch (e) {
      developer.log(
        'Error syncing time with server: $e',
        name: 'AccessRestrictionService',
      );
      _cachedServerTimeUtc = null;
      _cachedLocalTimeUtc = null;
    }
  }

  DateTime _getCurrentTime() {
    // Obtener la zona de Buenos Aires
    final buenosAires = tz.getLocation('America/Argentina/Buenos_Aires');
    // Si tenemos tiempo sincronizado con el servidor: calcular avance en UTC y convertir a TZ
    if (_cachedServerTimeUtc != null && _cachedLocalTimeUtc != null) {
      final elapsed = DateTime.now().toUtc().difference(_cachedLocalTimeUtc!);
      final currentServerUtc = _cachedServerTimeUtc!.add(elapsed);
      return tz.TZDateTime.from(currentServerUtc, buenosAires);
    }
    // Fallback a hora local del dispositivo en la zona especificada
    return tz.TZDateTime.now(buenosAires);
  }

  Future<void> _loadGeofence() async {
    try {
      final String geoJsonString = await rootBundle.loadString(
        'lib/assets/geojson/tres_de_febrero_limits.geojson',
      );
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);

      _geofencePolygons = [];
      final features = geoJson['features'] as List;

      for (var feature in features) {
        final geometry = feature['geometry'];
        if (geometry['type'] == 'MultiPolygon') {
          final coordinates = geometry['coordinates'] as List;
          for (var polygon in coordinates) {
            for (var ring in polygon) {
              final List<List<double>> points = [];
              for (var point in ring) {
                points.add([point[0] as double, point[1] as double]);
              }
              _geofencePolygons!.add(points);
            }
          }
        }
      }
    } catch (e) {
      developer.log(
        'Error loading geofence: $e',
        name: 'AccessRestrictionService',
      );
      _geofencePolygons = null;
    }
  }

  bool isWithinWorkingHours(String teamName) {
    // Usuarios del equipo 'et' y 'basic2' siempre tienen acceso
    if (teamName == 'et' || teamName == 'basic2') {
      return true;
    }

    // Obtener la hora actual (del servidor si está disponible)
    final now = _getCurrentTime();
    final hour = now.hour;

    // Horario laboral: 8 AM a 5 PM (17:00)
    return hour >= 8 && hour < 17;
  }

  Future<bool> isWithinGeofence(String teamName) async {
    // Usuarios del equipo 'et' y 'basic2' siempre tienen acceso
    if (teamName == 'et' || teamName == 'basic2') {
      return true;
    }

    if (_geofencePolygons == null || _geofencePolygons!.isEmpty) {
      // Si no se pudo cargar el geofence, permitir acceso
      return true;
    }

    try {
      // Comprobar permisos de ubicación de forma explícita antes de obtener posición
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          developer.log(
            'Location permission denied; allowing access by default',
            name: 'AccessRestrictionService',
          );
          return true;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Verificar si está dentro de alguno de los polígonos
      for (var polygon in _geofencePolygons!) {
        if (_isPointInPolygon(position.latitude, position.longitude, polygon)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      developer.log(
        'Error checking geofence: $e',
        name: 'AccessRestrictionService',
      );
      // En caso de error, permitir acceso
      return true;
    }
  }

  bool _isPointInPolygon(double lat, double lng, List<List<double>> polygon) {
    // polygon: list of [lon, lat]; function params: lat, lng
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final vLat = polygon[i][1];
      final vLng = polygon[i][0];
      final uLat = polygon[j][1];
      final uLng = polygon[j][0];

      // Comprobar si el rayo horizontal hacia la derecha cruza la arista
      final bool intersectsLngRange = (vLng > lng) != (uLng > lng);
      if (!intersectsLngRange) continue;

      final denom = (uLng - vLng);
      if (denom.abs() < 1e-12) {
        // Arista prácticamente horizontal respecto a la longitud: ignorar para evitar división por cero
        continue;
      }
      final xIntersect = vLat + (uLat - vLat) * (lng - vLng) / denom;
      if (lat < xIntersect) {
        inside = !inside;
      }
    }
    return inside;
  }

  String getCurrentTime() {
    final now = _getCurrentTime();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> refreshTime() async {
    await _syncTimeWithServer();
  }
}
