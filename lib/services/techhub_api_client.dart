import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_response.dart';

class TechHubApiClient {
  static const String baseUrl = 'http://74280601d366.sn.mynetname.net/test/api';
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

  // Get ALL tasks (for ET team)
  static Future<ApiResponse<Map<String, dynamic>>> getAllTasks({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/task/getTasks?page=$page&limit=$limit'),
            headers: _jsonHeaders,
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // Get ALL reports (for ET team)
  static Future<ApiResponse<Map<String, dynamic>>> getAllReports({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/report/getReports?page=$page&limit=$limit'),
            headers: _jsonHeaders,
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

  static Future<ApiResponse<List<Map<String, dynamic>>>> getInventoryByTeam({
    required String teamId,
  }) async {
    try {
      // Get all teams and find the specific team by ID
      final response = await http
          .get(Uri.parse('$baseUrl/team/getTeams'), headers: _jsonHeaders)
          .timeout(timeoutDuration);

      final result = _handleResponse<List<dynamic>>(
        response,
        (data) => List<dynamic>.from(data),
      );

      if (result.isSuccess && result.data != null) {
        final teams = result.data!;

        // Find the team with the matching ID
        final team = teams.firstWhere(
          (team) => team['_id']?.toString() == teamId,
          orElse: () => null,
        );

        if (team != null && team['materials'] != null) {
          final materials = team['materials'] as List;
          return ApiResponse.success(
            List<Map<String, dynamic>>.from(materials),
          );
        } else {
          return ApiResponse.error('Team not found or has no materials');
        }
      } else {
        return ApiResponse.error(result.error ?? 'Failed to get teams');
      }
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // Report endpoints
  static Future<ApiResponse<ReportResponse>> createReport({
    required String userId,
    required String startTime,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/report/createReport'),
            headers: _jsonHeaders,
            body: json.encode({'userId': userId, 'startTime': startTime}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<ReportResponse>(
        response,
        (data) => ReportResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<ReportResponse>> updateReport({
    required String reportId,
    String? status,
    String? teamId,
    String? supplies,
    String? toDo,
    String? typeOfWork,
    String? location,
    String? connectivity,
    String? db,
    String? buffers,
    String? bufferColor,
    String? hairColor,
    String? ap,
    String? st,
    String? ccq,
  }) async {
    try {
      final body = <String, dynamic>{'reportId': reportId};

      if (status != null) body['status'] = status;
      if (teamId != null) body['teamId'] = teamId;
      if (supplies != null) body['supplies'] = supplies;
      if (toDo != null) body['toDo'] = toDo;
      if (typeOfWork != null) body['typeOfWork'] = typeOfWork;
      if (location != null) body['location'] = location;
      if (connectivity != null) body['connectivity'] = connectivity;
      if (db != null) body['db'] = db;
      if (buffers != null) body['buffers'] = buffers;
      if (bufferColor != null) body['bufferColor'] = bufferColor;
      if (hairColor != null) body['hairColor'] = hairColor;
      if (ap != null) body['ap'] = ap;
      if (st != null) body['st'] = st;
      if (ccq != null) body['ccq'] = ccq;

      final response = await http
          .post(
            Uri.parse('$baseUrl/report/updateReport'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<ReportResponse>(
        response,
        (data) => ReportResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<ReportResponse>> finishReport({
    required String reportId,
    required String status,
    required String teamId,
    String? supplies,
    String? toDo,
    String? typeOfWork,
    String? endTime,
    String? location,
    String? connectivity,
    String? db,
    String? buffers,
    String? bufferColor,
    String? hairColor,
    String? ap,
    String? st,
    String? ccq,
    List<dynamic>? images,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/report/finishReport'),
      );

      // Add form fields
      request.fields['reportId'] = reportId;
      request.fields['status'] = status;
      request.fields['teamId'] = teamId;

      if (supplies != null) request.fields['supplies'] = supplies;
      if (toDo != null) request.fields['toDo'] = toDo;
      if (typeOfWork != null) request.fields['typeOfWork'] = typeOfWork;
      if (endTime != null) request.fields['endTime'] = endTime;
      if (location != null) request.fields['location'] = location;
      if (connectivity != null) request.fields['connectivity'] = connectivity;
      if (db != null) request.fields['db'] = db;
      if (buffers != null) request.fields['buffers'] = buffers;
      if (bufferColor != null) request.fields['bufferColor'] = bufferColor;
      if (hairColor != null) request.fields['hairColor'] = hairColor;
      if (ap != null) request.fields['ap'] = ap;
      if (st != null) request.fields['st'] = st;
      if (ccq != null) request.fields['ccq'] = ccq;

      // Add images if provided
      if (images != null) {
        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          if (image is File) {
            // Handle File objects (mobile/desktop)
            final file = await http.MultipartFile.fromPath(
              'images',
              image.path,
            );
            request.files.add(file);
          } else if (image.runtimeType.toString().contains('WebFileWrapper')) {
            // Handle legacy web files
            final bytes = await (image as dynamic).readAsBytes() as List<int>;
            final file = http.MultipartFile.fromBytes(
              'images',
              bytes,
              filename: (image as dynamic).fileName as String,
            );
            request.files.add(file);
          } else if (image.runtimeType.toString().contains('PlatformFile')) {
            // Handle PlatformFile (new universal approach)
            final platformFile = image as dynamic;
            if (platformFile.bytes != null && platformFile.bytes.isNotEmpty) {
              final file = http.MultipartFile.fromBytes(
                'images',
                platformFile.bytes as List<int>,
                filename: platformFile.name as String,
              );
              request.files.add(file);
            }
          }
        }
      }

      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse<ReportResponse>(
        response,
        (data) => ReportResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<ReportResponse>> getReportById({
    required String reportId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/report/getReportById'),
            headers: _jsonHeaders,
            body: json.encode({'reportId': reportId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<ReportResponse>(
        response,
        (data) => ReportResponse.fromJson(data),
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
