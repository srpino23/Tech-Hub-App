import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/techhub_api_client.dart';
import 'services/analyzer_api_client.dart';

class AuthManager extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userName;
  String? _userSurname;
  String? _userFullName;
  String? _userId;
  String? _teamName;
  String? _teamId;
  bool _isLoading = false;
  bool _hasNewNotifications = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;
  String? get userSurname => _userSurname;
  String? get userFullName => _userFullName;
  String? get userId => _userId;
  String? get teamName => _teamName;
  String? get teamId => _teamId;
  bool get isLoading => _isLoading;
  bool get hasNewNotifications => _hasNewNotifications;

  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userNameKey = 'user_name';
  static const String _userSurnameKey = 'user_surname';
  static const String _userFullNameKey = 'user_full_name';
  static const String _userIdKey = 'user_id';
  static const String _teamNameKey = 'team_name';
  static const String _teamIdKey = 'team_id';
  static const String _hasNewNotificationsKey = 'has_new_notifications';

  AuthManager() {
    _loadSavedLoginState();
  }

  Future<void> _loadSavedLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      _userName = prefs.getString(_userNameKey);
      _userSurname = prefs.getString(_userSurnameKey);
      _userFullName = prefs.getString(_userFullNameKey);
      _userId = prefs.getString(_userIdKey);
      _teamName = prefs.getString(_teamNameKey);
      _teamId = prefs.getString(_teamIdKey);
      _hasNewNotifications = prefs.getBool(_hasNewNotificationsKey) ?? false;
      notifyListeners();
    } catch (e) {
      // Error loading saved state, continue with default values
    }
  }

  Future<Map<String, String?>?> _fetchUserTeam(String userId) async {
    try {
      final response = await TechHubApiClient.getTeams();

      if (response.isSuccess && response.data != null) {
        for (var team in response.data!) {
          if (team['users'] is List) {
            List<String> users = List<String>.from(team['users']);
            if (users.contains(userId)) {
              return {
                'name': team['name']?.toString(),
                'id': team['_id']?.toString(),
              };
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> login(String name, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await TechHubApiClient.login(
        name: name,
        password: password,
      );

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;

        // Verificar si los datos del usuario están directamente en la respuesta o en un objeto 'user'
        Map<String, dynamic>? userData;
        if (responseData['user'] != null) {
          userData = responseData['user'];
        } else if (responseData['name'] != null &&
            responseData['surname'] != null) {
          userData = responseData;
        }

        if (userData == null) {
          _isLoading = false;
          notifyListeners();
          return 'Error: No se encontraron los datos del usuario en la respuesta del servidor';
        }

        final userName = userData['name']?.toString() ?? 'Usuario';
        final userSurname = userData['surname']?.toString() ?? '';
        final fullName = '$userName $userSurname'.trim();
        final userId = userData['_id']?.toString() ?? '';

        // Fetch user's team
        String? teamName;
        String? teamId;
        if (userId.isNotEmpty) {
          final teamData = await _fetchUserTeam(userId);
          if (teamData != null) {
            teamName = teamData['name'];
            teamId = teamData['id'];
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userNameKey, userName);
        await prefs.setString(_userSurnameKey, userSurname);
        await prefs.setString(_userFullNameKey, fullName);
        await prefs.setString(_userIdKey, userId);
        if (teamName != null) {
          await prefs.setString(_teamNameKey, teamName);
        }
        if (teamId != null) {
          await prefs.setString(_teamIdKey, teamId);
        }
        await prefs.setBool(_hasNewNotificationsKey, _hasNewNotifications);

        _isLoggedIn = true;
        _userName = userName;
        _userSurname = userSurname;
        _userFullName = fullName;
        _userId = userId;
        _teamName = teamName;
        _teamId = teamId;
        _isLoading = false;
        notifyListeners();

        // Verificar reportes nuevos después del login
        await checkForNewReports();

        return null; // Success, no error message
      } else {
        _isLoading = false;
        notifyListeners();
        return response.error ??
            'Credenciales incorrectas. Verifique su usuario y contraseña.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Error de conexión. Verifique su conexión a internet e inténtelo de nuevo.';
    }
  }

  Future<void> checkForNewReports() async {
    try {
      // Obtener el último reporte de status_report
      final statusReportResponse = await AnalyzerApiClient.getLastStatusReport();
      if (statusReportResponse.isSuccess && statusReportResponse.data != null) {
        final report = statusReportResponse.data!;
        final reportId = report['_id'];
        final prefs = await SharedPreferences.getInstance();
        final lastStatusReportId = prefs.getString('last_status_report_id');

        if (lastStatusReportId != reportId) {
          // Nuevo reporte, mostrar notificación
          _hasNewNotifications = true;
          await prefs.setString('last_status_report_id', reportId);
          notifyListeners();
        }
      }

      // Obtener reportes de stabilization_alert
      final stabilizationReportsResponse = await AnalyzerApiClient.getStatusReportsByType(type: 'stabilization_alert', limit: 10);
      if (stabilizationReportsResponse.isSuccess && stabilizationReportsResponse.data != null) {
        final reports = stabilizationReportsResponse.data!;
        final prefs = await SharedPreferences.getInstance();

        for (final report in reports) {
          final zone = report['zone'];
          if (zone != null) {
            final reportId = report['_id'];
            final key = 'last_stabilization_alert_${zone}_id';
            final lastId = prefs.getString(key);

            if (lastId != reportId) {
              // Nuevo reporte para esta zona
              _hasNewNotifications = true;
              await prefs.setString(key, reportId);
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      // Error checking reports, continue silently
    }
  }

  Future<void> markNotificationsAsRead() async {
    if (_hasNewNotifications) {
      _hasNewNotifications = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasNewNotificationsKey, false);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userSurnameKey);
      await prefs.remove(_userFullNameKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_teamNameKey);
      await prefs.remove(_teamIdKey);
      await prefs.remove(_hasNewNotificationsKey);

      _isLoggedIn = false;
      _userName = null;
      _userSurname = null;
      _userFullName = null;
      _userId = null;
      _teamName = null;
      _teamId = null;
      notifyListeners();
    } catch (e) {
      // Error during logout, but continue anyway
    }
  }
}
