import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'auth_manager.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'services/location_service.dart';
import 'services/access_restriction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccessRestrictionService().initialize();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final AuthManager _authManager = AuthManager();
  final AccessRestrictionService _restrictionService =
      AccessRestrictionService();
  late LocationService _locationService;
  bool _isWithinWorkingHours = true;
  bool _isWithinGeofence = true;
  bool _isCheckingAccess = true;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService(_authManager);
    _startLocationTracking();
    _checkAccessRestrictions();
  }

  void _startLocationTracking() {
    _authManager.addListener(() {
      if (_authManager.isLoggedIn) {
        _locationService.startLocationUpdates();
        _checkAccessRestrictions();
      } else {
        _locationService.stopLocationUpdates();
      }
    });

    // Start immediately if already logged in
    if (_authManager.isLoggedIn) {
      _locationService.startLocationUpdates();
    }
  }

  Future<void> _checkAccessRestrictions() async {
    if (!_authManager.isLoggedIn) {
      setState(() {
        _isCheckingAccess = false;
      });
      return;
    }

    setState(() {
      _isCheckingAccess = true;
    });

    // Check working hours
    final withinHours = _restrictionService.isWithinWorkingHours(
      _authManager.teamName ?? '',
    );

    // Check geofence
    final withinGeofence = await _restrictionService.isWithinGeofence(
      _authManager.teamName ?? '',
    );

    setState(() {
      _isWithinWorkingHours = withinHours;
      _isWithinGeofence = withinGeofence;
      _isCheckingAccess = false;
    });
  }

  @override
  void dispose() {
    _locationService.stopLocationUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tech Hub',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIconColor: Colors.grey.shade400,
          suffixIconColor: Colors.grey.shade400,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          centerTitle: true,
        ),
      ),
      home: ListenableBuilder(
        listenable: _authManager,
        builder: (context, child) {
          if (!_authManager.isLoggedIn) {
            return LoginScreen(authManager: _authManager);
          }

          // Show loading while checking access
          if (_isCheckingAccess) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            );
          }

          // Check access restrictions
          if (!_isWithinWorkingHours) {
            return _OutOfWorkingHoursScreen(
              restrictionService: _restrictionService,
              onRetry: _checkAccessRestrictions,
            );
          }

          if (!_isWithinGeofence) {
            return _OutOfGeofenceScreen(onRetry: _checkAccessRestrictions);
          }

          return HomeScreen(authManager: _authManager);
        },
      ),
    );
  }
}

class _OutOfWorkingHoursScreen extends StatelessWidget {
  final AccessRestrictionService restrictionService;
  final VoidCallback onRetry;

  const _OutOfWorkingHoursScreen({
    required this.restrictionService,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.grey.shade50, Colors.white],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    LucideIcons.clock,
                    size: 64,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Fuera de Horario Laboral',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'El acceso a la aplicación está disponible',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'de 8:00 AM a 5:00 PM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hora actual: ${restrictionService.getCurrentTime()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 20),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutOfGeofenceScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _OutOfGeofenceScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.grey.shade50, Colors.white],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    LucideIcons.mapPinOff,
                    size: 64,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Fuera de Zona Permitida',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'El acceso a la aplicación está restringido',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'al municipio de Tres de Febrero',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 20,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ubicación fuera del área autorizada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 20),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
