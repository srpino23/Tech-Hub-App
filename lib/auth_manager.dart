import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/techhub_api_client.dart';

class AuthManager extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userName;
  String? _userSurname;
  String? _userFullName;
  String? _userId;
  String? _teamName;
  String? _teamId;
  String? _password; // Guardamos la contraseña para autenticación en cada petición
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;
  String? get userSurname => _userSurname;
  String? get userFullName => _userFullName;
  String? get userId => _userId;
  String? get teamName => _teamName;
  String? get teamId => _teamId;
  String? get password => _password; // Getter para la contraseña
  bool get isLoading => _isLoading;

  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userNameKey = 'user_name';
  static const String _userSurnameKey = 'user_surname';
  static const String _userFullNameKey = 'user_full_name';
  static const String _userIdKey = 'user_id';
  static const String _teamNameKey = 'team_name';
  static const String _teamIdKey = 'team_id';
  static const String _passwordKey = 'user_password'; // Clave para la contraseña

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
      _password = prefs.getString(_passwordKey); // Cargar contraseña guardada
      notifyListeners();
    } catch (e) {
      // Error loading saved state, continue with default values
    }
  }

  Future<Map<String, String?>?> _fetchUserTeam(
    String userId,
    String username,
    String password,
  ) async {
    try {
      final response = await TechHubApiClient.getTeams(
        username: username,
        password: password,
      );

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
          final teamData = await _fetchUserTeam(userId, name, password);
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
        await prefs.setString(_passwordKey, password); // Guardar contraseña
        if (teamName != null) {
          await prefs.setString(_teamNameKey, teamName);
        }
        if (teamId != null) {
          await prefs.setString(_teamIdKey, teamId);
        }

        _isLoggedIn = true;
        _userName = userName;
        _userSurname = userSurname;
        _userFullName = fullName;
        _userId = userId;
        _password = password; // Guardar en memoria
        _teamName = teamName;
        _teamId = teamId;
        _isLoading = false;
        notifyListeners();
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
      await prefs.remove(_passwordKey); // Eliminar contraseña

      _isLoggedIn = false;
      _userName = null;
      _userSurname = null;
      _userFullName = null;
      _userId = null;
      _password = null; // Limpiar contraseña de memoria
      _teamName = null;
      _teamId = null;
      notifyListeners();
    } catch (e) {
      // Error during logout, but continue anyway
    }
  }
}
