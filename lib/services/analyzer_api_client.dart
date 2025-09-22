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

  // =======================
  // Endpoints de Historial Operativo
  // =======================

  static Future<ApiResponse<List<Map<String, dynamic>>>>
  getOperationalHistory() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/operationalHistory/getOperationalHistory'),
            headers: _jsonHeaders,
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
  
  static Future<ApiResponse<List<Map<String, dynamic>>>> getOperationalHistoryByLiable({
    required String liable,
  }) async {
    try {
      // Obtener todos los datos de operational history
      final response = await http
          .get(
            Uri.parse('$baseUrl/operationalHistory/getOperationalHistory'),
            headers: _jsonHeaders,
          )
          .timeout(timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _handleResponse<List<Map<String, dynamic>>>(
          response,
          (data) {
            if (data is List) {
              // Filtrar y transformar los datos para el liable específico
              final filteredData = data.where((entry) {
                final liableOperability = entry['liableOperability'] as List<dynamic>? ?? [];
                return liableOperability.any((e) => e['liable'] == liable);
              }).map((entry) {
                final liableOperability = entry['liableOperability'] as List<dynamic>? ?? [];
                final liableEntry = liableOperability.firstWhere(
                  (e) => e['liable'] == liable,
                  orElse: () => null,
                );

                // Crear entrada con la operatividad específica del liable
                return {
                  ...Map<String, dynamic>.from(entry),
                  'generalOperability': liableEntry?['percentage'] ?? 0,
                  'selectedLiable': liable,
                  'selectedLiableData': liableEntry,
                };
              }).toList();

              return filteredData;
            } else if (data is Map && data.containsKey('data') && data['data'] is List) {
              final listData = List<Map<String, dynamic>>.from(data['data']);

              // Aplicar el mismo filtrado
              final filteredData = listData.where((entry) {
                final liableOperability = entry['liableOperability'] as List<dynamic>? ?? [];
                return liableOperability.any((e) => e['liable'] == liable);
              }).map((entry) {
                final liableOperability = entry['liableOperability'] as List<dynamic>? ?? [];
                final liableEntry = liableOperability.firstWhere(
                  (e) => e['liable'] == liable,
                  orElse: () => null,
                );

                return {
                  ...Map<String, dynamic>.from(entry),
                  'generalOperability': liableEntry?['percentage'] ?? 0,
                  'selectedLiable': liable,
                  'selectedLiableData': liableEntry,
                };
              }).toList();

              return filteredData;
            } else {
              return [];
            }
          },
        );
      } else {
        // Si falla, devolver error
        return _handleResponse<List<Map<String, dynamic>>>(
          response,
          (data) => [],
        );
      }
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // =======================
  // Endpoints de Status Reports
  // =======================

  static Future<ApiResponse<Map<String, dynamic>>> getLastStatusReport() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status/last'), headers: _jsonHeaders)
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getStatusReportsByType({
    required String type,
    int limit = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/status/type/$type?limit=$limit'),
            headers: _jsonHeaders,
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

  static Future<ApiResponse<Map<String, dynamic>>> getAllStatusReports({
    int page = 1,
    int limit = 20,
    String? type,
    String? severity,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null) 'type': type,
        if (severity != null) 'severity': severity,
      };
      final uri = Uri.parse('$baseUrl/status/all').replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: _jsonHeaders)
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
        if (data != null) {
          try {
            return ApiResponse.success(converter(data));
          } catch (e) {
            return ApiResponse.error('Error converting response data: $e');
          }
        } else {
          return ApiResponse.error('Respuesta vacía del servidor');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          final message = errorData['message'] ?? 'Error ${response.statusCode}';
          return ApiResponse.error(message);
        } catch (e) {
          return ApiResponse.error('Error ${response.statusCode}');
        }
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

  // =======================
  // Endpoints de Video Streaming
  // =======================

  static const String streamBaseUrl =
      'https://74280601d366.sn.mynetname.net/analyzer/api/stream';
  static const String websocketUrl =
      'wss://74280601d366.sn.mynetname.net/test/ws';

  // Iniciar stream en el servidor antes de conectar por WebSocket
  static Future<ApiResponse<Map<String, dynamic>>> startStream({
    required String cameraId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$streamBaseUrl/start/$cameraId'),
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