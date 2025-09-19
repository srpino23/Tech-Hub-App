import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../auth_manager.dart';
import 'cameras_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'works_screen.dart';
import 'create_report_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthManager authManager;

  const HomeScreen({super.key, required this.authManager});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Widget _getBody() {
    if (widget.authManager.teamName == 'et') {
      switch (_currentIndex) {
        case 0:
          return DashboardScreen(authManager: widget.authManager);
        case 1:
          return MapScreen(authManager: widget.authManager);
        case 2:
          return InventoryScreen(authManager: widget.authManager);
        case 3:
          return WorksScreen(authManager: widget.authManager);
        case 4:
          return ProfileScreen(authManager: widget.authManager);
        default:
          return DashboardScreen(authManager: widget.authManager);
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return CamerasScreen(authManager: widget.authManager);
        case 1:
          return MapScreen(authManager: widget.authManager);
        case 2:
          return CreateReportScreen(authManager: widget.authManager);
        case 3:
          return WorksScreen(authManager: widget.authManager);
        case 4:
          return ProfileScreen(authManager: widget.authManager);
        default:
          return CamerasScreen(authManager: widget.authManager);
      }
    }
  }

  String _getTitle() {
    if (widget.authManager.teamName == 'et') {
      switch (_currentIndex) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Mapa';
        case 2:
          return 'Inventario';
        case 3:
          return 'Trabajos';
        case 4:
          return 'Perfil';
        default:
          return 'Cámaras';
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return 'Cámaras';
        case 1:
          return 'Mapa';
        case 2:
          return 'Crear Remito';
        case 3:
          return 'Trabajos';
        case 4:
          return 'Perfil';
        default:
          return 'Cámaras';
      }
    }
  }

  IconData _getTitleIcon() {
    if (widget.authManager.teamName == 'et') {
      switch (_currentIndex) {
        case 0:
          return LucideIcons.layoutDashboard;
        case 1:
          return LucideIcons.map;
        case 2:
          return LucideIcons.package;
        case 3:
          return LucideIcons.checkSquare;
        case 4:
          return LucideIcons.user;
        default:
          return LucideIcons.layoutDashboard;
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return LucideIcons.video;
        case 1:
          return LucideIcons.map;
        case 2:
          return LucideIcons.plus;
        case 3:
          return LucideIcons.checkSquare;
        case 4:
          return LucideIcons.user;
        default:
          return LucideIcons.video;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade50, Colors.white],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTitleIcon(),
                size: 24,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 15),
            Text(
              _getTitle(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.grey,
              ),
              onPressed: () {},
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade200.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.grey.shade50, Colors.white],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: _getBody(),
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.orange.shade50],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(
                      widget.authManager.teamName == 'et'
                          ? LucideIcons.layoutDashboard
                          : LucideIcons.video,
                    ),
                    onPressed: () => setState(() => _currentIndex = 0),
                    color: _currentIndex == 0 ? Colors.orange : Colors.grey,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.map),
                    onPressed: () => setState(() => _currentIndex = 1),
                    color: _currentIndex == 1 ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 60),
                  IconButton(
                    icon: const Icon(LucideIcons.checkSquare),
                    onPressed: () => setState(() => _currentIndex = 3),
                    color: _currentIndex == 3 ? Colors.orange : Colors.grey,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.user),
                    onPressed: () => setState(() => _currentIndex = 4),
                    color: _currentIndex == 4 ? Colors.orange : Colors.grey,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              left: MediaQuery.of(context).size.width / 2 - 28,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  icon: Icon(
                    widget.authManager.teamName == 'et'
                        ? LucideIcons.package
                        : LucideIcons.plus,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class _PlaceholderScreen extends StatelessWidget {
//   final String title;

//   const _PlaceholderScreen({required this.title});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: Colors.orange.shade100,
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Icon(
//               LucideIcons.construction,
//               size: 64,
//               color: Colors.orange.shade600,
//             ),
//           ),
//           const SizedBox(height: 24),
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey.shade800,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Pantalla en desarrollo',
//             style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
//           ),
//         ],
//       ),
//     );
//   }
// }
