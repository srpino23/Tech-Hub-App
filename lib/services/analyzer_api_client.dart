import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_response.dart';

class AnalyzerApiClient {
  static const String baseUrl =
      'https://74280601d366.sn.mynetname.net/analyzer/api';
  static const String cameraEndpoint = '$baseUrl/camera';
  static const String serverEndpoint = '$baseUrl/server';
  static const Duration timeoutDuration = Duration(seconds: 30);

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  static Future<ApiResponse<List<Map<String, dynamic>>>> getCameras({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$cameraEndpoint/getCameras'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) => List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getCameraById({
    required String username,
    required String password,
    required String cameraId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$cameraEndpoint/getCamera/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // =======================
  // Endpoints de Cámaras CRUD
  // =======================

  static Future<ApiResponse<Map<String, dynamic>>> addCamera({
    required String username,
    required String password,
    required Map<String, dynamic> cameraData,
  }) async {
    try {
      final body = {'username': username, 'password': password, ...cameraData};
      final response = await http
          .post(
            Uri.parse('$cameraEndpoint/addCamera'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateCamera({
    required String username,
    required String password,
    required String cameraId,
    required Map<String, dynamic> cameraData,
  }) async {
    try {
      final body = {'username': username, 'password': password, ...cameraData};
      final response = await http
          .put(
            Uri.parse('$cameraEndpoint/updateCamera/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteCamera({
    required String username,
    required String password,
    required String cameraId,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$cameraEndpoint/deleteCamera/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateCameraStatus({
    required String username,
    required String password,
    required String cameraId,
    required String status,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$cameraEndpoint/updateStatus/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode({
              'username': username,
              'password': password,
              'status': status,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // =======================
  // Endpoints de Servidores
  // =======================

  static Future<ApiResponse<List<Map<String, dynamic>>>> getServers({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$serverEndpoint/getServers'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) => List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getServerById({
    required String username,
    required String password,
    required String serverId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$serverEndpoint/getServer/$serverId'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> addServer({
    required String username,
    required String password,
    required Map<String, dynamic> serverData,
  }) async {
    try {
      final body = {'username': username, 'password': password, ...serverData};
      final response = await http
          .post(
            Uri.parse('$serverEndpoint/addServer'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateServer({
    required String username,
    required String password,
    required String serverId,
    required Map<String, dynamic> serverData,
  }) async {
    try {
      final body = {'username': username, 'password': password, ...serverData};
      final response = await http
          .put(
            Uri.parse('$serverEndpoint/updateServer/$serverId'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteServer({
    required String username,
    required String password,
    required String serverId,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$serverEndpoint/deleteServer/$serverId'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateServerStatus({
    required String username,
    required String password,
    required String serverId,
    required String status,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$serverEndpoint/updateStatus/$serverId'),
            headers: _jsonHeaders,
            body: json.encode({
              'username': username,
              'password': password,
              'status': status,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // =======================
  // Endpoints de Historial Operativo
  // =======================

  static Future<ApiResponse<List<Map<String, dynamic>>>> getOperationalHistory({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/operationalHistory/getOperationalHistory'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) => List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // =======================
  // Endpoints de Video Streaming
  // =======================

  static const String streamBaseUrl =
      'https://74280601d366.sn.mynetname.net/analyzer/api/stream';
  static const String websocketUrl =
      'wss://74280601d366.sn.mynetname.net/test/ws';

  // Iniciar stream en el servidor antes de conectar por WebSocket
  static Future<ApiResponse<Map<String, dynamic>>> startStream({
    required String username,
    required String password,
    required String cameraId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$streamBaseUrl/start/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static String getWebSocketUrl(String cameraId) {
    return '$websocketUrl?camera=$cameraId';
  }

  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic) converter,
  ) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return ApiResponse.success(converter(data));
      } else {
        final errorData = json.decode(response.body);
        final message = errorData['message'] ?? 'Error ${response.statusCode}';
        return ApiResponse.error(message);
      }
    } catch (e) {
      return ApiResponse.error('Error parsing response: $e');
    }
  }

  static String _getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Network error: Check your internet connection';
    } else if (error is HttpException) {
      return 'HTTP error: ${error.message}';
    } else if (error.toString().contains('TimeoutException')) {
      return 'Request timeout: The server is taking too long to respond';
    } else {
      return 'Unexpected error: ${error.toString()}';
    }
  }
}
