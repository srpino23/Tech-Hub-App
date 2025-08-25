import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_response.dart';

class AnalyzerApiClient {
  static const String baseUrl = 'http://74280601d366.sn.mynetname.net:2300/api';
  static const String cameraEndpoint = '$baseUrl/camera';
  static const String serverEndpoint = '$baseUrl/server';
  static const Duration timeoutDuration = Duration(seconds: 30);

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  static Future<ApiResponse<List<Map<String, dynamic>>>> getCameras() async {
    try {
      final response = await http
          .get(Uri.parse('$cameraEndpoint/getCameras'), headers: _jsonHeaders)
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
    required String cameraId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$cameraEndpoint/getCamera/$cameraId'),
            headers: _jsonHeaders,
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
    required Map<String, dynamic> cameraData,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$cameraEndpoint/addCamera'),
            headers: _jsonHeaders,
            body: json.encode(cameraData),
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
    required String cameraId,
    required Map<String, dynamic> cameraData,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$cameraEndpoint/updateCamera/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode(cameraData),
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
    required String cameraId,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$cameraEndpoint/deleteCamera/$cameraId'),
            headers: _jsonHeaders,
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
    required String cameraId,
    required String status,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$cameraEndpoint/updateStatus/$cameraId'),
            headers: _jsonHeaders,
            body: json.encode({'status': status}),
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

  static Future<ApiResponse<List<Map<String, dynamic>>>> getServers() async {
    try {
      final response = await http
          .get(Uri.parse('$serverEndpoint/getServers'), headers: _jsonHeaders)
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
    required String serverId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverEndpoint/getServer/$serverId'),
            headers: _jsonHeaders,
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
    required Map<String, dynamic> serverData,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$serverEndpoint/addServer'),
            headers: _jsonHeaders,
            body: json.encode(serverData),
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
    required String serverId,
    required Map<String, dynamic> serverData,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$serverEndpoint/updateServer/$serverId'),
            headers: _jsonHeaders,
            body: json.encode(serverData),
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
    required String serverId,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$serverEndpoint/deleteServer/$serverId'),
            headers: _jsonHeaders,
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
    required String serverId,
    required String status,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$serverEndpoint/updateStatus/$serverId'),
            headers: _jsonHeaders,
            body: json.encode({'status': status}),
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
