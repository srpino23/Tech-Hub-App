import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'api_response.dart';

class TechHubApiClient {
  static const String baseUrl =
      'https://74280601d366.sn.mynetname.net/techhub/api';
  static const Duration timeoutDuration = Duration(seconds: 30);
  static const Duration longTimeoutDuration = Duration(
    minutes: 5,
  ); // Para operaciones con archivos

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
    String?
    userId, // Nuevo parámetro opcional para filtrar por usuario específico
  }) async {
    try {
      String url = '$baseUrl/report/getReportsByTeam?page=$page&limit=$limit${userId != null ? '&userId=$userId' : ''}';

      final response = await http
          .post(
            Uri.parse(url),
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

  // Delete report
  static Future<ApiResponse<Map<String, dynamic>>> deleteReport({
    required String reportId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/report/deleteReport'),
            headers: _jsonHeaders,
            body: json.encode({'reportId': reportId}),
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

  static Future<ApiResponse<List<Map<String, dynamic>>>> getRecoveredInventory({
    String? status,
  }) async {
    try {
      String url = '$baseUrl/recoveredInventory/getRecoveredInventory${status != null ? '?status=$status' : ''}';

      final response = await http
          .get(Uri.parse(url), headers: _jsonHeaders)
          .timeout(timeoutDuration);

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) => List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // Main Inventory endpoints
  static Future<ApiResponse<Map<String, dynamic>>> createMaterial({
    required String name,
    required int quantity,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/createMaterial'),
            headers: _jsonHeaders,
            body: json.encode({'name': name, 'quantity': quantity}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> editMaterial({
    required String id,
    required String name,
    required int quantity,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/editMaterial'),
            headers: _jsonHeaders,
            body: json.encode({'id': id, 'name': name, 'quantity': quantity}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteMaterial({
    required String id,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/deleteMaterial'),
            headers: _jsonHeaders,
            body: json.encode({'id': id}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> addToInventory({
    required String change,
    required String materialId,
    required int quantity,
    required String name,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/addToInventory'),
            headers: _jsonHeaders,
            body: json.encode({
              'change': change,
              'materialId': materialId,
              'quantity': quantity,
              'name': name,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> removeFromInventory({
    required String change,
    required String materialId,
    required int quantity,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/removeFromInventory'),
            headers: _jsonHeaders,
            body: json.encode({
              'change': change,
              'materialId': materialId,
              'quantity': quantity,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> moveToAnotherInventory({
    required String change,
    required String materialId,
    required int quantity,
    required String teamId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/moveToAnotherInventory'),
            headers: _jsonHeaders,
            body: json.encode({
              'change': change,
              'materialId': materialId,
              'quantity': quantity,
              'teamId': teamId,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> returnToInventory({
    required String change,
    required String materialId,
    required int quantity,
    required String teamId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/returnToInventory'),
            headers: _jsonHeaders,
            body: json.encode({
              'change': change,
              'materialId': materialId,
              'quantity': quantity,
              'teamId': teamId,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>>
  returnReconditionedToRecovered({
    required String change,
    required String materialId,
    required int quantity,
    required String teamId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/returnReconditionedToRecovered'),
            headers: _jsonHeaders,
            body: json.encode({
              'change': change,
              'materialId': materialId,
              'quantity': quantity,
              'teamId': teamId,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getInventoryTeam({
    required String teamId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/inventory/getInventoryTeam'),
            headers: _jsonHeaders,
            body: json.encode({'teamId': teamId}),
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

  // Recovered Inventory endpoints
  static Future<ApiResponse<Map<String, dynamic>>> createRecoveredMaterial({
    required String name,
    required int quantity,
    String? originalMaterialId,
  }) async {
    try {
      final body = <String, dynamic>{'name': name, 'quantity': quantity};
      if (originalMaterialId != null) {
        body['originalMaterialId'] = originalMaterialId;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/recoveredInventory/createRecoveredMaterial'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> editRecoveredMaterial({
    required String id,
    String? name,
    int? quantity,
  }) async {
    try {
      final body = <String, dynamic>{'id': id};
      if (name != null) body['name'] = name;
      if (quantity != null) body['quantity'] = quantity;

      final response = await http
          .post(
            Uri.parse('$baseUrl/recoveredInventory/editRecoveredMaterial'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteRecoveredMaterial({
    required String id,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/recoveredInventory/deleteRecoveredMaterial'),
            headers: _jsonHeaders,
            body: json.encode({'id': id}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteAddition({
    required String materialId,
    required String additionId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/recoveredInventory/deleteAddition'),
            headers: _jsonHeaders,
            body: json.encode({
              'materialId': materialId,
              'additionId': additionId,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateAdditionStatus({
    required String materialId,
    required String additionId,
    required String status,
    String? condition,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'materialId': materialId,
        'additionId': additionId,
        'status': status,
      };
      if (condition != null) body['condition'] = condition;
      if (notes != null) body['notes'] = notes;

      final response = await http
          .post(
            Uri.parse('$baseUrl/recoveredInventory/updateAdditionStatus'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> transferToTeam({
    required String materialId,
    required String additionId,
    required int quantity,
    required String teamId,
    required String change,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/recoveredInventory/transferToTeam'),
            headers: _jsonHeaders,
            body: json.encode({
              'materialId': materialId,
              'additionId': additionId,
              'quantity': quantity,
              'teamId': teamId,
              'change': change,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getRecoveredMaterialById({
    required String id,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/recoveredInventory/getRecoveredMaterial/$id'),
            headers: _jsonHeaders,
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getTeamMaterialDetails({
    required String teamId,
    required String materialName,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/recoveredInventory/getTeamMaterialDetails/$teamId/$materialName',
            ),
            headers: _jsonHeaders,
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  // Team endpoints
  static Future<ApiResponse<Map<String, dynamic>>> createTeam({
    required String name,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/team/createTeam'),
            headers: _jsonHeaders,
            body: json.encode({'name': name}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> editTeam({
    required String id,
    required String name,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/team/editTeam'),
            headers: _jsonHeaders,
            body: json.encode({'id': id, 'name': name}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteTeam({
    required String id,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/team/deleteTeam'),
            headers: _jsonHeaders,
            body: json.encode({'id': id}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> addToTeam({
    required String teamId,
    required String userId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/team/addToTeam'),
            headers: _jsonHeaders,
            body: json.encode({'teamId': teamId, 'userId': userId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> removeFromTeam({
    required String teamId,
    required String userId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/team/removeFromTeam'),
            headers: _jsonHeaders,
            body: json.encode({'teamId': teamId, 'userId': userId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> moveToAnotherTeam({
    required String teamId,
    required String userId,
    required String newTeamId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/team/moveToAnotherTeam'),
            headers: _jsonHeaders,
            body: json.encode({
              'teamId': teamId,
              'userId': userId,
              'newTeamId': newTeamId,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
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
    String? cameraName,
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
      if (cameraName != null) body['cameraName'] = cameraName;
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
    String? cameraName,
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
      return await _retryOperation(
        () async {
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
          if (connectivity != null) {
            request.fields['connectivity'] = connectivity;
          }
          if (cameraName != null) request.fields['cameraName'] = cameraName;
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
              } else if (image.runtimeType.toString().contains(
                'WebFileWrapper',
              )) {
                // Handle legacy web files
                final bytes =
                    await (image as dynamic).readAsBytes() as List<int>;
                final file = http.MultipartFile.fromBytes(
                  'images',
                  bytes,
                  filename: (image as dynamic).fileName as String,
                );
                request.files.add(file);
              } else if (image is PlatformFile) {
                // Handle PlatformFile (new universal approach)
                final platformFile = image;
                if (platformFile.bytes != null &&
                    platformFile.bytes!.isNotEmpty) {
                  final file = http.MultipartFile.fromBytes(
                    'images',
                    platformFile.bytes!,
                    filename: platformFile.name,
                  );
                  request.files.add(file);
                }
              }
            }
          }

          // Usar timeout más largo para operaciones con archivos
          final streamedResponse = await request.send().timeout(
            longTimeoutDuration,
          );
          final response = await http.Response.fromStream(streamedResponse);

          return _handleResponse<ReportResponse>(
            response,
            (data) => ReportResponse.fromJson(data),
          );
        },
        maxRetries: 2,
        delay: const Duration(seconds: 3),
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
        // Handle 204 No Content responses
        if (response.statusCode == 204 || response.body.isEmpty) {
          // For 204 responses, return a success with empty data or default value
          if (T == Map<String, dynamic>) {
            return ApiResponse.success(
              converter({
                'success': true,
                'message': 'Operation completed successfully',
              }),
            );
          }
          return ApiResponse.success(converter({}));
        }

        final data = json.decode(response.body);
        return ApiResponse.success(converter(data));
      } else {
        try {
          final errorData = json.decode(response.body);
          final message =
              errorData['message'] ?? 'Error ${response.statusCode}';
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

  // Función auxiliar para retry automático
  static Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }

        // Solo hacer retry en casos específicos
        if (e.toString().contains('TimeoutException') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection reset')) {
          await Future.delayed(delay);
          continue;
        }

        // Para otros errores, no hacer retry
        rethrow;
      }
    }

    throw Exception('Max retries exceeded');
  }

  static Future<ApiResponse<Map<String, dynamic>>> createTask({
    required String team,
    required String title,
    required String location,
    required String toDo,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/task/createTask'),
            headers: _jsonHeaders,
            body: json.encode({
              'team': team,
              'title': title,
              'location': location,
              'toDo': toDo,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> editTask({
    required String taskId,
    required String team,
    required String title,
    required String location,
    required String toDo,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{
        'taskId': taskId,
        'team': team,
        'title': title,
        'location': location,
        'toDo': toDo,
      };
      if (status != null) body['status'] = status;

      final response = await http
          .put(
            Uri.parse('$baseUrl/task/editTask'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteTask({
    required String taskId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/task/deleteTask'),
            headers: _jsonHeaders,
            body: json.encode({'taskId': taskId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> markTaskCompleted({
    required String taskId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/task/markCompleted'),
            headers: _jsonHeaders,
            body: json.encode({'taskId': taskId}),
          )
          .timeout(timeoutDuration);

      return _handleResponse<Map<String, dynamic>>(response, (data) => data);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }
}
