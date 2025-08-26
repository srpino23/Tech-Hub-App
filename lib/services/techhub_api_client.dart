import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_response.dart';

class TechHubApiClient {
  static const String baseUrl = 'http://172.25.67.77:1928/api';
  static const Duration timeoutDuration = Duration(seconds: 30);

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  static Future<ApiResponse<Map<String, dynamic>>> login({
    required String name,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/login'),
            headers: _jsonHeaders,
            body: json.encode({'name': name, 'password': password}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getUsers() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/user/getUsers'), headers: _jsonHeaders)
          .timeout(timeoutDuration);

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) => List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateUserLocation({
    required String userId,
    required String location,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/updateUserLocation'),
            headers: _jsonHeaders,
            body: json.encode({'userId': userId, 'location': location}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getTeams() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/team/getTeams'), headers: _jsonHeaders)
          .timeout(timeoutDuration);

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) => List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // Task and Report endpoints
  static Future<ApiResponse<Map<String, dynamic>>> getTasksByTeam({
    required String teamId,
    required int page,
    required int limit,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/task/getTasksByTeam?page=$page&limit=$limit'),
            headers: _jsonHeaders,
            body: json.encode({'teamId': teamId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getReportsByTeam({
    required String teamId,
    required int page,
    required int limit,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/report/getReportsByTeam?page=$page&limit=$limit',
            ),
            headers: _jsonHeaders,
            body: json.encode({'teamId': teamId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getInventory() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/inventory/getInventory'),
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

  static Future<ApiResponse<List<Map<String, dynamic>>>>
  getRecoveredInventory() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/recoveredInventory/getRecoveredInventory'),
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
