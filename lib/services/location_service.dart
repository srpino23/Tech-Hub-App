import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../auth_manager.dart';

class LocationService {
  final AuthManager _authManager;
  Timer? _locationTimer;
  Position? _lastKnownPosition;

  static const String _updateLocationUrl =
      'https://74280601d366.sn.mynetname.net/techhub/api/user/updateUserLocation';

  // Update interval: every 30 seconds
  static const Duration _updateInterval = Duration(seconds: 30);

  LocationService(this._authManager);

  Future<void> startLocationUpdates() async {
    if (!_authManager.isLoggedIn) return;

    try {
      // Request location permissions
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        debugPrint('Location permission denied');
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      // Start periodic location updates
      _locationTimer?.cancel();
      _locationTimer = Timer.periodic(
        _updateInterval,
        (_) => _updateLocation(),
      );

      // Send initial location immediately
      await _updateLocation();

      debugPrint('Location tracking started');
    } catch (e) {
      debugPrint('Error starting location updates: $e');
    }
  }

  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
    debugPrint('Location tracking stopped');
  }

  Future<bool> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status != PermissionStatus.granted) {
        debugPrint('Location permission status: $status');
      }
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  Future<void> _updateLocation() async {
    if (!_authManager.isLoggedIn) return;

    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 10));

      // Check if position has changed significantly (to avoid unnecessary API calls)
      if (_lastKnownPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Only update if moved more than 10 meters or it's been 5 minutes
        if (distance < 10) {
          return;
        }
      }

      _lastKnownPosition = position;

      // Send location to API
      await _sendLocationToApi(position);
    } catch (e) {
      debugPrint('Error updating location: $e');

      // Try to use last known position if current location fails
      if (_lastKnownPosition != null) {
        await _sendLocationToApi(_lastKnownPosition!);
      }
    }
  }

  Future<void> _sendLocationToApi(Position position) async {
    if (!_authManager.isLoggedIn || _authManager.userId == null) return;

    try {
      final response = await http
          .post(
            Uri.parse(_updateLocationUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': _authManager.userId,
              'longitude': position.longitude.toString(),
              'latitude': position.latitude.toString(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint(
          'Location updated successfully: ${position.latitude}, ${position.longitude}',
        );
      } else {
        debugPrint('Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending location to API: $e');
    }
  }

  // Method to get current location on demand
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) return null;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }
}
