import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_manager.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'services/location_service.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final AuthManager _authManager = AuthManager();
  late LocationService _locationService;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService(_authManager);
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _authManager.addListener(() {
      if (_authManager.isLoggedIn) {
        _locationService.startLocationUpdates();
      } else {
        _locationService.stopLocationUpdates();
      }
    });

    // Start immediately if already logged in
    if (_authManager.isLoggedIn) {
      _locationService.startLocationUpdates();
    }
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
          if (_authManager.isLoggedIn) {
            return HomeScreen(authManager: _authManager);
          } else {
            return LoginScreen(authManager: _authManager);
          }
        },
      ),
    );
  }
}
