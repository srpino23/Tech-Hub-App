import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../services/api_response.dart';
import '../utils/file_saver.dart' as file_saver;
import 'transfer_history_screen.dart';

enum InventoryType { main, recovered, team }

class MaterialSelection {
  final String materialId;
  final String materialName;
  final int quantity;
  final InventoryType source;
  final String? additionId;
  final String? condition;

  MaterialSelection({
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.source,
    this.additionId,
    this.condition,
  });

  Map<String, dynamic> toJson() {
    return {
      'materialId': materialId,
      'quantity': quantity.toString(),
      'source': source == InventoryType.main ? 'main' : 'recovered',
      if (additionId != null) 'additionId': additionId,
    };
  }
}

class InventoryScreen extends StatefulWidget {
  final AuthManager authManager;

  const InventoryScreen({super.key, required this.authManager});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  bool _isFabMenuOpen = false;

  List<Map<String, dynamic>> _mainInventory = [];
  List<Map<String, dynamic>> _recoveredInventory = [];
  List<Map<String, dynamic>> _teamInventory = [];
  List<Map<String, dynamic>> _teams = [];
  bool _isLoading = true;
  String? _selectedTeamId;

  // Variables para búsqueda
  final TextEditingController _searchMainController = TextEditingController();
  final TextEditingController _searchRecoveredController =
      TextEditingController();
  final TextEditingController _searchTeamController = TextEditingController();
  List<Map<String, dynamic>> _filteredMainInventory = [];
  List<Map<String, dynamic>> _filteredRecoveredInventory = [];
  List<Map<String, dynamic>> _filteredTeamInventory = [];

  // Variables para transferencia múltiple
  bool _isTransferMode = false;
  final Map<String, MaterialSelection> _selectedMaterials = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _searchMainController.addListener(_filterMainInventory);
    _searchRecoveredController.addListener(_filterRecoveredInventory);
    _searchTeamController.addListener(_filterTeamInventory);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimationController.dispose();
    _searchMainController.dispose();
    _searchRecoveredController.dispose();
    _searchTeamController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadMainInventory(),
      _loadRecoveredInventory(),
      _loadTeams(),
    ]);

    if (_teams.isNotEmpty && widget.authManager.teamId != null) {
      _selectedTeamId = widget.authManager.teamId;
      await _loadTeamInventory();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMainInventory() async {
    final response = await TechHubApiClient.getInventory(
      username: widget.authManager.userName!,
      password: widget.authManager.password!,
    );
    if (response.isSuccess && response.data != null) {
      setState(() {
        _mainInventory = response.data!;
        _filterMainInventory();
      });
    }
  }

  Future<void> _loadRecoveredInventory() async {
    final response = await TechHubApiClient.getRecoveredInventory(
      username: widget.authManager.userName!,
      password: widget.authManager.password!,
    );
    if (response.isSuccess && response.data != null) {
      setState(() {
        _recoveredInventory = response.data!;
        _filterRecoveredInventory();
      });
    }
  }

  Future<void> _loadTeams() async {
    final response = await TechHubApiClient.getTeams(
      username: widget.authManager.userName!,
      password: widget.authManager.password!,
    );
    if (response.isSuccess && response.data != null) {
      // Filtrar solo los equipos permitidos
      final allowedTeams = [
        'eq com 1',
        'eq com 2',
        'et',
        'mandar',
        'sistemy',
      ];
      final filteredTeams =
          response.data!.where((team) {
            final teamName = (team['name'] as String? ?? '').toLowerCase();
            return allowedTeams.any(
              (allowed) => allowed.toLowerCase() == teamName,
            );
          }).toList();

      setState(() {
        _teams = filteredTeams;
      });
    }
  }

  Future<void> _loadTeamInventory() async {
    if (_selectedTeamId == null) return;

    final response = await TechHubApiClient.getInventoryByTeam(
      username: widget.authManager.userName!,
      password: widget.authManager.password!,
      teamId: _selectedTeamId!,
    );
    if (response.isSuccess && response.data != null) {
      List<Map<String, dynamic>> teamMaterials = response.data!;

      // Enriquecer los materiales del equipo con nombres del inventario principal y recuperado
      for (var teamMaterial in teamMaterials) {
        final materialId = teamMaterial['materialId']?.toString();
        if (materialId != null) {
          // Buscar primero en el inventario principal
          final originalMaterial = _mainInventory.firstWhere(
            (material) => material['_id']?.toString() == materialId,
            orElse: () => <String, dynamic>{},
          );

          if (originalMaterial.isNotEmpty) {
            teamMaterial['name'] =
                originalMaterial['name'] ?? 'Material desconocido';
            teamMaterial['isRecovered'] = false;
          } else {
            // Si no se encuentra en principal, buscar en recuperados
            final recoveredMaterial = _recoveredInventory.firstWhere(
              (material) => material['_id']?.toString() == materialId,
              orElse: () => <String, dynamic>{},
            );

            if (recoveredMaterial.isNotEmpty) {
              teamMaterial['name'] =
                  '♻️ ${recoveredMaterial['name'] ?? 'Material recuperado'}';
              teamMaterial['isRecovered'] = true;
            } else {
              teamMaterial['name'] = 'Material no encontrado (ID: $materialId)';
              teamMaterial['isRecovered'] = false;
            }
          }
        } else {
          teamMaterial['name'] = teamMaterial['name'] ?? 'Sin nombre';
          teamMaterial['isRecovered'] = false;
        }
      }

      setState(() {
        _teamInventory = teamMaterials;
        _filterTeamInventory();
      });
    }
  }

  void _filterMainInventory() {
    final query = _searchMainController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMainInventory = _mainInventory;
      } else {
        _filteredMainInventory =
            _mainInventory.where((material) {
              final name = (material['name'] as String? ?? '').toLowerCase();
              return name.contains(query);
            }).toList();
      }
    });
  }

  void _filterRecoveredInventory() {
    final query = _searchRecoveredController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRecoveredInventory = _recoveredInventory;
      } else {
        _filteredRecoveredInventory =
            _recoveredInventory.where((material) {
              final name = (material['name'] as String? ?? '').toLowerCase();
              return name.contains(query);
            }).toList();
      }
    });
  }

  void _filterTeamInventory() {
    final query = _searchTeamController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTeamInventory = _teamInventory;
      } else {
        _filteredTeamInventory =
            _teamInventory.where((material) {
              final name = (material['name'] as String? ?? '').toLowerCase();
              return name.contains(query);
            }).toList();
      }
    });
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabMenuOpen = !_isFabMenuOpen;
      if (_isFabMenuOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _toggleTransferMode() {
    setState(() {
      _isTransferMode = !_isTransferMode;
      if (!_isTransferMode) {
        _selectedMaterials.clear();
      }
      // Cerrar el menú FAB al activar modo transferencia
      if (_isFabMenuOpen) {
        _isFabMenuOpen = false;
        _fabAnimationController.reverse();
      }
    });
  }

  void _toggleMaterialSelection(
    String materialId,
    String materialName,
    InventoryType source,
    int maxQuantity, {
    String? additionId,
    String? condition,
  }) {
    final key =
        '$source-$materialId${additionId != null ? "-$additionId" : ""}';

    setState(() {
      if (_selectedMaterials.containsKey(key)) {
        _selectedMaterials.remove(key);
      } else {
        _selectedMaterials[key] = MaterialSelection(
          materialId: materialId,
          materialName: materialName,
          quantity: 1, // Cantidad inicial
          source: source,
          additionId: additionId,
          condition: condition,
        );
      }
    });
  }

  void _updateMaterialQuantity(String key, int newQuantity) {
    setState(() {
      final current = _selectedMaterials[key];
      if (current != null) {
        _selectedMaterials[key] = MaterialSelection(
          materialId: current.materialId,
          materialName: current.materialName,
          quantity: newQuantity,
          source: current.source,
          additionId: current.additionId,
          condition: current.condition,
        );
      }
    });
  }

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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.orange,
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(LucideIcons.package), text: 'Principal'),
                  Tab(icon: Icon(LucideIcons.recycle), text: 'Recuperado'),
                  Tab(icon: Icon(LucideIcons.users), text: 'Equipos'),
                ],
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      )
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMainInventoryTab(),
                          _buildRecoveredInventoryTab(),
                          _buildTeamInventoryTab(),
                        ],
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildFloatingActionButtons() {
    if (_isTransferMode) {
      // Modo transferencia: botones específicos
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'confirmTransferButton',
            onPressed:
                _selectedMaterials.isEmpty ? null : _showBulkTransferDialog,
            backgroundColor: Colors.green,
            icon: const Icon(LucideIcons.send, color: Colors.white),
            label: Text(
              'Transferir (${_selectedMaterials.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'cancelTransferButton',
            onPressed: _toggleTransferMode,
            backgroundColor: Colors.red,
            child: const Icon(LucideIcons.x, color: Colors.white),
          ),
        ],
      );
    }

    // Modo normal: speed dial
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Botones secundarios con animación
        if (_isFabMenuOpen) ...[
          _buildSpeedDialOption(
            icon: LucideIcons.history,
            label: 'Historial',
            backgroundColor: Colors.purple,
            onPressed: () {
              _toggleFabMenu();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => TransferHistoryScreen(
                        authManager: widget.authManager,
                      ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildSpeedDialOption(
            icon: LucideIcons.download,
            label: 'Exportar',
            backgroundColor: Colors.blue,
            onPressed: () {
              _toggleFabMenu();
              _showExportMenu();
            },
          ),
          const SizedBox(height: 10),
          _buildSpeedDialOption(
            icon: LucideIcons.plus,
            label: 'Agregar',
            backgroundColor: Colors.orange,
            onPressed: () {
              _toggleFabMenu();
              _showAddMaterialDialog();
            },
          ),
          const SizedBox(height: 10),
          _buildSpeedDialOption(
            icon: LucideIcons.send,
            label: 'Transferir',
            backgroundColor: Colors.green,
            onPressed: () {
              _toggleFabMenu();
              _toggleTransferMode();
            },
          ),
          const SizedBox(height: 16),
        ],
        // Botón principal
        FloatingActionButton(
          heroTag: 'mainFabButton',
          onPressed: _toggleFabMenu,
          backgroundColor: Colors.orange,
          child: AnimatedRotation(
            turns: _isFabMenuOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _isFabMenuOpen ? LucideIcons.x : LucideIcons.menu,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialOption({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'fab_$label',
            onPressed: onPressed,
            backgroundColor: backgroundColor,
            mini: true,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInventoryTab() {
    return RefreshIndicator(
      onRefresh: _loadMainInventory,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(_searchMainController, 'Buscar materiales...'),
            const SizedBox(height: 16),
            _buildInventoryStats(_filteredMainInventory),
            const SizedBox(height: 16),
            Expanded(
              child: _buildMaterialList(
                _filteredMainInventory,
                InventoryType.main,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveredInventoryTab() {
    return RefreshIndicator(
      onRefresh: _loadRecoveredInventory,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(
              _searchRecoveredController,
              'Buscar materiales recuperados...',
            ),
            const SizedBox(height: 16),
            _buildRecoveredInventoryStats(),
            const SizedBox(height: 16),
            Expanded(child: _buildRecoveredMaterialList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInventoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTeamSelector(),
          const SizedBox(height: 16),
          _buildSearchField(_searchTeamController, 'Buscar materiales...'),
          const SizedBox(height: 16),
          if (_selectedTeamId != null) ...[
            _buildInventoryStats(_filteredTeamInventory),
            const SizedBox(height: 16),
            Expanded(
              child: _buildMaterialList(
                _filteredTeamInventory,
                InventoryType.team,
              ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text(
                  'Selecciona un equipo para ver su inventario',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search, color: Colors.orange),
          suffixIcon:
              controller.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () {
                      controller.clear();
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.users,
              color: Colors.orange.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Seleccionar Equipo',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              initialValue: _selectedTeamId,
              items:
                  _teams.map((team) {
                    return DropdownMenuItem<String>(
                      value: team['_id'].toString(),
                      child: Text(team['name'] ?? 'Sin nombre'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTeamId = value;
                  _teamInventory = [];
                });
                if (value != null) {
                  _loadTeamInventory();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStats(List<Map<String, dynamic>> inventory) {
    int totalItems = inventory.length;
    int totalQuantity = inventory.fold(0, (sum, item) {
      var quantity = item['quantity'];
      int quantityInt = 0;
      if (quantity is int) {
        quantityInt = quantity;
      } else if (quantity is String) {
        quantityInt = int.tryParse(quantity) ?? 0;
      }
      return sum + quantityInt;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Materiales',
              totalItems.toString(),
              LucideIcons.package,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Cantidad Total',
              totalQuantity.toString(),
              LucideIcons.hash,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveredInventoryStats() {
    int totalMaterials = _filteredRecoveredInventory.length;
    int totalAdditions = _filteredRecoveredInventory.fold(0, (sum, material) {
      final additions = material['additions'] as List? ?? [];
      return sum + additions.length;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Materiales',
              totalMaterials.toString(),
              LucideIcons.package,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Unidades',
              totalAdditions.toString(),
              LucideIcons.layers,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveredMaterialList() {
    if (_filteredRecoveredInventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                LucideIcons.recycle,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchRecoveredController.text.isEmpty
                  ? 'No hay materiales recuperados'
                  : 'No se encontraron resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchRecoveredController.text.isEmpty
                  ? 'Crea un material recuperado usando el botón +'
                  : 'Intenta con otro término de búsqueda',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredRecoveredInventory.length,
      itemBuilder: (context, index) {
        final material = _filteredRecoveredInventory[index];
        return _buildRecoveredMaterialCard(material);
      },
    );
  }

  Widget _buildRecoveredMaterialCard(Map<String, dynamic> material) {
    final name = material['name'] as String? ?? 'Sin nombre';
    final additions = material['additions'] as List? ?? [];
    final materialId = material['_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            LucideIcons.recycle,
            color: Colors.green.shade700,
            size: 24,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          '${additions.length} unidades',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        trailing:
            !_isTransferMode
                ? PopupMenuButton<String>(
                  onSelected:
                      (value) =>
                          _handleRecoveredMaterialAction(value, material),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.history,
                                size: 16,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Ver Historial',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add',
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.plus,
                                size: 16,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text('Agregar Unidad'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(LucideIcons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Editar Material'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.trash,
                                size: 16,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                )
                : null,
        children:
            additions.map<Widget>((addition) {
              return _buildAdditionCard(materialId, name, addition);
            }).toList(),
      ),
    );
  }

  Widget _buildAdditionCard(
    String materialId,
    String materialName,
    Map<String, dynamic> addition,
  ) {
    final quantity = addition['quantity']?.toString() ?? '1';
    final status = addition['status']?.toString() ?? 'recuperado';
    final condition = addition['condition']?.toString() ?? 'regular';
    final additionId = addition['_id']?.toString() ?? '';
    final notes = addition['notes']?.toString() ?? '';

    Color statusColor = _getStatusColor(status);
    Color conditionColor = _getConditionColor(condition);

    // Lógica de selección para modo transferencia
    final selectionKey = '${InventoryType.recovered}-$materialId-$additionId';
    final isSelected = _selectedMaterials.containsKey(selectionKey);
    final maxQuantity = int.tryParse(quantity) ?? 1;

    Color cardColor = Colors.grey.shade50;
    if (isSelected && _isTransferMode) {
      cardColor = Colors.green.shade50;
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border:
            isSelected && _isTransferMode
                ? Border.all(color: Colors.green, width: 2)
                : Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Checkbox en modo transferencia (solo si no está transferido)
              if (_isTransferMode && status != 'transferido')
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleMaterialSelection(
                      materialId,
                      materialName,
                      InventoryType.recovered,
                      maxQuantity,
                      additionId: additionId,
                      condition: condition,
                    );
                  },
                  activeColor: Colors.green,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: conditionColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            condition.toUpperCase(),
                            style: TextStyle(
                              color: conditionColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cantidad: $quantity',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Notas: $notes',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Ocultar menú en modo transferencia
              if (!_isTransferMode)
                PopupMenuButton<String>(
                  onSelected:
                      (value) => _handleAdditionAction(
                        value,
                        materialId,
                        additionId,
                        addition,
                      ),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit_status',
                          child: Row(
                            children: [
                              Icon(LucideIcons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Cambiar Estado'),
                            ],
                          ),
                        ),
                        if (status != 'transferido') ...[
                          const PopupMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.arrowRight,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text('Transferir'),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.trash,
                                size: 16,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
            ],
          ),
          // Input de cantidad cuando está seleccionado en modo transferencia
          if (isSelected && _isTransferMode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Cantidad a transferir:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1-$maxQuantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final newQty = int.tryParse(value);
                      if (newQty != null &&
                          newQty > 0 &&
                          newQty <= maxQuantity) {
                        _updateMaterialQuantity(selectionKey, newQty);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'recuperado':
        return Colors.orange;
      case 'reacondicionado':
        return Colors.green;
      case 'deposito':
        return Colors.blue;
      case 'transferido':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'bueno':
        return Colors.green;
      case 'regular':
        return Colors.orange;
      case 'malo':
        return Colors.red;
      case 'irreparable':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMaterialList(
    List<Map<String, dynamic>> materials,
    InventoryType type,
  ) {
    if (materials.isEmpty) {
      return Center(
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
                LucideIcons.packageOpen,
                size: 64,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay materiales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega materiales usando el botón +',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        return _buildMaterialCard(material, type);
      },
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material, InventoryType type) {
    final quantityRaw = material['quantity'];
    int quantity = 0;
    if (quantityRaw is int) {
      quantity = quantityRaw;
    } else if (quantityRaw is String) {
      quantity = int.tryParse(quantityRaw) ?? 0;
    }
    final name = material['name'] as String? ?? 'Sin nombre';
    final isRecovered = material['isRecovered'] as bool? ?? false;
    final materialId =
        material['_id']?.toString() ?? material['materialId']?.toString() ?? '';

    final selectionKey = '$type-$materialId';
    final isSelected = _selectedMaterials.containsKey(selectionKey);

    // Colores diferentes para materiales recuperados
    Color cardColor = Colors.white;
    Color iconBackgroundColor = Colors.orange.shade100;
    Color iconColor = Colors.orange.shade700;
    IconData iconData = LucideIcons.package;

    if (isRecovered && type == InventoryType.team) {
      iconBackgroundColor = Colors.green.shade100;
      iconColor = Colors.green.shade700;
      iconData = LucideIcons.recycle;
      cardColor = Colors.green.shade50;
    }

    // Si está seleccionado, cambiar color de borde
    if (isSelected && _isTransferMode) {
      cardColor = Colors.green.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border:
            isSelected && _isTransferMode
                ? Border.all(color: Colors.green, width: 2)
                : (isRecovered && type == InventoryType.team
                    ? Border.all(color: Colors.green.shade200, width: 1)
                    : null),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading:
                _isTransferMode && type != InventoryType.team
                    ? Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleMaterialSelection(
                          materialId,
                          name,
                          type,
                          quantity,
                        );
                      },
                      activeColor: Colors.green,
                    )
                    : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconData, color: iconColor, size: 24),
                    ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cantidad: $quantity',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                if (isRecovered && type == InventoryType.team) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'MATERIAL RECUPERADO',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing:
                _isTransferMode && type != InventoryType.team
                    ? null
                    : PopupMenuButton<String>(
                      onSelected:
                          (value) =>
                              _handleMaterialAction(value, material, type),
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'history',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.history,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Ver Historial',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                            if (type != InventoryType.team) ...[
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                            ],
                            if (type != InventoryType.team) ...[
                              const PopupMenuItem(
                                value: 'move',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.arrowRight, size: 16),
                                    SizedBox(width: 8),
                                    Text('Transferir'),
                                  ],
                                ),
                              ),
                            ],
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.trash,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.moreVertical,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
          ),
          // Campo de cantidad cuando está seleccionado en modo transferencia
          if (isSelected && _isTransferMode && type != InventoryType.team)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Cantidad a transferir',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(LucideIcons.hash),
                  helperText: 'Máximo: $quantity',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final newQuantity = int.tryParse(value) ?? 1;
                  if (newQuantity > 0 && newQuantity <= quantity) {
                    _updateMaterialQuantity(selectionKey, newQuantity);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  void _handleMaterialAction(
    String action,
    Map<String, dynamic> material,
    InventoryType type,
  ) {
    switch (action) {
      case 'history':
        _showMaterialHistoryDialog(material, type);
        break;
      case 'edit':
        _showEditMaterialDialog(material, type);
        break;
      case 'move':
        _showTransferMaterialDialog(material, type);
        break;
      case 'delete':
        _showDeleteMaterialDialog(material, type);
        break;
    }
  }

  void _showAddMaterialDialog() {
    String materialName = '';
    int quantity = 0;
    int selectedTab = _tabController.index;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.plus, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Text(
                  selectedTab == 1 ? 'Crear Recuperado' : 'Agregar Material',
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Nombre del Material',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(LucideIcons.package),
                  ),
                  onChanged: (value) => materialName = value,
                ),
                if (selectedTab != 1) ...[
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(LucideIcons.hash),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => quantity = int.tryParse(value) ?? 0,
                  ),
                ],
                if (selectedTab == 1) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Se creará el material base con una unidad. Luego podrás agregar unidades individuales.',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    () => _createMaterial(materialName, quantity, selectedTab),
                child: Text(
                  selectedTab == 1 ? 'Crear' : 'Agregar',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _createMaterial(String name, int quantity, int tab) async {
    if (name.isEmpty) {
      _showSnackBar('Por favor ingresa un nombre válido', isError: true);
      return;
    }

    // Para materiales principales, validar cantidad > 0
    if (tab == 0 && quantity <= 0) {
      _showSnackBar('Por favor ingresa una cantidad válida', isError: true);
      return;
    }

    try {
      ApiResponse<Map<String, dynamic>> response;

      if (tab == 0) {
        response = await TechHubApiClient.createMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          name: name,
          quantity: quantity,
        );
      } else if (tab == 1) {
        // Para materiales recuperados, crear con cantidad mínima de 1 pero totalQuantity 0
        response = await TechHubApiClient.createRecoveredMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          name: name,
          quantity: 1,
        );
      } else {
        _showSnackBar(
          'No se puede crear materiales en esta pestaña',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        if (tab == 1) {
          _showSnackBar(
            'Material recuperado creado. Ahora puedes agregar unidades.',
          );
        } else {
          _showSnackBar('Material creado exitosamente');
        }
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al crear material',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al crear material: $e', isError: true);
    }
  }

  void _showEditMaterialDialog(
    Map<String, dynamic> material,
    InventoryType type,
  ) {
    String materialName = material['name'] ?? '';
    final quantityRaw = material['quantity'];
    int quantity = 0;
    if (quantityRaw is int) {
      quantity = quantityRaw;
    } else if (quantityRaw is String) {
      quantity = int.tryParse(quantityRaw) ?? 0;
    }
    final materialId = material['_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.edit, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Editar Material'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Nombre del Material',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(LucideIcons.package),
                  ),
                  controller: TextEditingController(text: materialName),
                  onChanged: (value) => materialName = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(LucideIcons.hash),
                  ),
                  controller: TextEditingController(text: quantity.toString()),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantity = int.tryParse(value) ?? 0,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    () =>
                        _editMaterial(materialId, materialName, quantity, type),
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _editMaterial(
    String id,
    String name,
    int quantity,
    InventoryType type,
  ) async {
    if (name.isEmpty || quantity <= 0) {
      _showSnackBar(
        'Por favor ingresa un nombre y cantidad válidos',
        isError: true,
      );
      return;
    }

    try {
      ApiResponse<Map<String, dynamic>> response;

      if (type == InventoryType.main) {
        response = await TechHubApiClient.editMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          id: id,
          name: name,
          quantity: quantity,
        );
      } else if (type == InventoryType.recovered) {
        response = await TechHubApiClient.editRecoveredMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          id: id,
          name: name,
          quantity: quantity,
        );
      } else {
        _showSnackBar(
          'No se puede editar materiales del inventario de equipo',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Material actualizado exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al actualizar material',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al actualizar material: $e', isError: true);
    }
  }

  void _showTransferMaterialDialog(
    Map<String, dynamic> material,
    InventoryType type,
  ) {
    String? selectedTeamId;
    int transferQuantity = 1;
    final quantityRaw = material['quantity'];
    int maxQuantity = 0;
    if (quantityRaw is int) {
      maxQuantity = quantityRaw;
    } else if (quantityRaw is String) {
      maxQuantity = int.tryParse(quantityRaw) ?? 0;
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.arrowRight,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Transferir Material'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Material: ${material['name'] ?? 'Sin nombre'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('Cantidad disponible: $maxQuantity'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Equipo Destino',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.users),
                        ),
                        initialValue: selectedTeamId,
                        items:
                            _teams.map((team) {
                              return DropdownMenuItem<String>(
                                value: team['_id'].toString(),
                                child: Text(team['name'] ?? 'Sin nombre'),
                              );
                            }).toList(),
                        onChanged:
                            (value) => setState(() => selectedTeamId = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Cantidad a transferir',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.hash),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged:
                            (value) =>
                                transferQuantity = int.tryParse(value) ?? 1,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          selectedTeamId != null
                              ? () => _transferMaterial(
                                material,
                                selectedTeamId!,
                                transferQuantity,
                                type,
                              )
                              : null,
                      child: const Text(
                        'Transferir',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _transferMaterial(
    Map<String, dynamic> material,
    String teamId,
    int quantity,
    InventoryType type,
  ) async {
    final materialId = material['_id']?.toString() ?? '';

    final quantityRaw = material['quantity'];
    int maxQuantity = 0;
    if (quantityRaw is int) {
      maxQuantity = quantityRaw;
    } else if (quantityRaw is String) {
      maxQuantity = int.tryParse(quantityRaw) ?? 0;
    }

    if (quantity <= 0 || quantity > maxQuantity) {
      _showSnackBar('Cantidad inválida', isError: true);
      return;
    }

    try {
      ApiResponse<Map<String, dynamic>> response;

      if (type == InventoryType.main) {
        response = await TechHubApiClient.moveToAnotherInventory(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          change: 'Transferencia a equipo',
          materialId: materialId,
          quantity: quantity,
          teamId: teamId,
        );
      } else if (type == InventoryType.recovered) {
        response = await TechHubApiClient.transferToTeam(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          materialId: materialId,
          additionId: '', // This might need to be handled differently
          quantity: quantity,
          teamId: teamId,
          change: 'Transferencia desde inventario recuperado',
        );
      } else {
        _showSnackBar(
          'Transferencia no disponible para este tipo de inventario',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Material transferido exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al transferir material',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al transferir material: $e', isError: true);
    }
  }

  void _showDeleteMaterialDialog(
    Map<String, dynamic> material,
    InventoryType type,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.trash, color: Colors.red.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Eliminar Material'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Estás seguro de que quieres eliminar "${material['name']}"?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _deleteMaterial(material, type),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteMaterial(
    Map<String, dynamic> material,
    InventoryType type,
  ) async {
    final materialId =
        material['materialId']?.toString() ?? material['_id']?.toString() ?? '';

    try {
      ApiResponse<Map<String, dynamic>> response;

      if (type == InventoryType.main) {
        response = await TechHubApiClient.deleteMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          id: materialId,
        );
      } else if (type == InventoryType.recovered) {
        response = await TechHubApiClient.deleteRecoveredMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          id: materialId,
        );
      } else if (type == InventoryType.team) {
        // Eliminar material del equipo
        if (_selectedTeamId == null) {
          _showSnackBar('No se ha seleccionado un equipo', isError: true);
          return;
        }

        response = await TechHubApiClient.removeMaterialFromTeam(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          teamId: _selectedTeamId!,
          materialId: materialId,
        );
      } else {
        _showSnackBar('Tipo de inventario no reconocido', isError: true);
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Material eliminado exitosamente');

        // Si es de equipo, recargar solo el inventario del equipo seleccionado
        if (type == InventoryType.team) {
          await _loadTeamInventory();
        } else {
          _loadData();
        }
      } else {
        _showSnackBar(
          response.error ?? 'Error al eliminar material',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al eliminar material: $e', isError: true);
    }
  }

  void _handleRecoveredMaterialAction(
    String action,
    Map<String, dynamic> material,
  ) {
    switch (action) {
      case 'history':
        _showRecoveredMaterialHistoryDialog(material);
        break;
      case 'add':
        _showAddUnitsDialog(material);
        break;
      case 'edit':
        _showEditRecoveredMaterialDialog(material);
        break;
      case 'delete':
        _showDeleteRecoveredMaterialDialog(material);
        break;
    }
  }

  void _handleAdditionAction(
    String action,
    String materialId,
    String additionId,
    Map<String, dynamic> addition,
  ) {
    switch (action) {
      case 'edit_status':
        _showEditAdditionStatusDialog(materialId, additionId, addition);
        break;
      case 'transfer':
        _showTransferAdditionDialog(materialId, additionId, addition);
        break;
      case 'delete':
        _showDeleteAdditionDialog(materialId, additionId);
        break;
    }
  }

  void _showAddUnitsDialog(Map<String, dynamic> material) {
    int quantity = 1;
    String condition = 'regular';
    String notes = '';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.plus,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Agregar Unidades'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Material: ${material['name'] ?? 'Sin nombre'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Cantidad a agregar',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.hash),
                          helperText: 'Cada unidad se agregará individualmente',
                          helperStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: '1'),
                        onChanged:
                            (value) => quantity = int.tryParse(value) ?? 1,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Condición',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.clipboard),
                        ),
                        initialValue: condition,
                        items: const [
                          DropdownMenuItem(
                            value: 'bueno',
                            child: Text('Bueno'),
                          ),
                          DropdownMenuItem(
                            value: 'regular',
                            child: Text('Regular'),
                          ),
                          DropdownMenuItem(value: 'malo', child: Text('Malo')),
                          DropdownMenuItem(
                            value: 'irreparable',
                            child: Text('Irreparable'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => condition = value ?? 'regular'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Notas (opcional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.fileText),
                        ),
                        maxLines: 2,
                        onChanged: (value) => notes = value,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          () => _addUnitsToRecoveredMaterial(
                            material,
                            quantity,
                            condition,
                            notes,
                          ),
                      child: const Text(
                        'Agregar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _addUnitsToRecoveredMaterial(
    Map<String, dynamic> material,
    int quantity,
    String condition,
    String notes,
  ) async {
    if (quantity <= 0) {
      _showSnackBar('Cantidad inválida', isError: true);
      return;
    }

    // Mostrar diálogo de progreso para cantidades > 1
    bool showProgressDialog = quantity > 1;
    if (showProgressDialog) {
      _showProgressDialog(quantity);
    }

    try {
      int successCount = 0;

      // Agregar unidades una por una
      for (int i = 0; i < quantity; i++) {
        // Cada petición individual con quantity: 1
        final response = await TechHubApiClient.createRecoveredMaterial(
          username: widget.authManager.userName!,
          password: widget.authManager.password!,
          name: material['name'] ?? '',
          quantity: 1,
          originalMaterialId: material['originalMaterialId']?.toString(),
        );

        if (response.isSuccess) {
          successCount++;
          // Actualizar progreso si hay diálogo
          if (showProgressDialog && mounted) {
            _updateProgressDialog(i + 1, quantity);
          }

          // Pequeña pausa para no saturar el servidor
          if (quantity > 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        } else {
          // Si falla una, cerrar diálogos y mostrar error específico
          if (!mounted) return;
          Navigator.pop(context); // Cerrar diálogo original
          if (showProgressDialog) {
            Navigator.pop(context); // Cerrar diálogo de progreso
          }

          _showSnackBar(
            'Error en unidad ${i + 1} de $quantity: ${response.error ?? "Error desconocido"}',
            isError: true,
          );

          if (successCount > 0) {
            await Future.delayed(const Duration(seconds: 2));
            _showSnackBar(
              'Se agregaron $successCount de $quantity unidades antes del error',
            );
            _loadData();
          }
          return;
        }
      }

      if (!mounted) return;

      // Cerrar diálogos
      Navigator.pop(context); // Cerrar diálogo original
      if (showProgressDialog) {
        Navigator.pop(context); // Cerrar diálogo de progreso
      }

      if (successCount == quantity) {
        if (quantity == 1) {
          _showSnackBar('Unidad agregada exitosamente');
        } else {
          _showSnackBar('$quantity unidades agregadas exitosamente');
        }
      } else {
        _showSnackBar(
          'Se agregaron $successCount de $quantity unidades solicitadas',
          isError: true,
        );
      }

      _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      if (showProgressDialog) {
        Navigator.pop(context);
      }
      _showSnackBar('Error al agregar unidades: $e', isError: true);
    }
  }

  void _showProgressDialog(int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.loader, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Agregando Unidades'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Agregando 0 de $total unidades...',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por favor espera, cada unidad se procesa individualmente.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );
  }

  void _updateProgressDialog(int current, int total) {
    // Actualizar el texto del diálogo
    if (mounted) {
      // Forzar rebuild del diálogo con nuevo texto
      Navigator.pop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.loader,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Agregando Unidades'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.orange,
                    value: current / total,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Agregando $current de $total unidades...',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por favor espera, cada unidad se procesa individualmente.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      );
    }
  }

  void _showEditAdditionStatusDialog(
    String materialId,
    String additionId,
    Map<String, dynamic> addition,
  ) {
    String status = addition['status']?.toString() ?? 'recuperado';
    String condition = addition['condition']?.toString() ?? 'regular';
    String notes = addition['notes']?.toString() ?? '';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.edit,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Cambiar Estado'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.activity),
                        ),
                        initialValue: status,
                        items: const [
                          DropdownMenuItem(
                            value: 'recuperado',
                            child: Text('Recuperado'),
                          ),
                          DropdownMenuItem(
                            value: 'reacondicionado',
                            child: Text('Reacondicionado'),
                          ),
                          DropdownMenuItem(
                            value: 'deposito',
                            child: Text('Depósito'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => status = value ?? 'recuperado'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Condición',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.clipboard),
                        ),
                        initialValue: condition,
                        items: const [
                          DropdownMenuItem(
                            value: 'bueno',
                            child: Text('Bueno'),
                          ),
                          DropdownMenuItem(
                            value: 'regular',
                            child: Text('Regular'),
                          ),
                          DropdownMenuItem(value: 'malo', child: Text('Malo')),
                          DropdownMenuItem(
                            value: 'irreparable',
                            child: Text('Irreparable'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => condition = value ?? 'regular'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Notas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.fileText),
                        ),
                        controller: TextEditingController(text: notes),
                        maxLines: 2,
                        onChanged: (value) => notes = value,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          () => _updateAdditionStatus(
                            materialId,
                            additionId,
                            status,
                            condition,
                            notes,
                          ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _updateAdditionStatus(
    String materialId,
    String additionId,
    String status,
    String condition,
    String notes,
  ) async {
    try {
      final response = await TechHubApiClient.updateAdditionStatus(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        materialId: materialId,
        additionId: additionId,
        status: status,
        condition: condition,
        notes: notes,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Estado actualizado exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al actualizar estado',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al actualizar estado: $e', isError: true);
    }
  }

  void _showTransferAdditionDialog(
    String materialId,
    String additionId,
    Map<String, dynamic> addition,
  ) {
    String? selectedTeamId;
    final quantity = int.tryParse(addition['quantity']?.toString() ?? '1') ?? 1;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.arrowRight,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Transferir Unidad'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Cantidad: $quantity',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('Estado: ${addition['status'] ?? 'N/A'}'),
                      Text('Condición: ${addition['condition'] ?? 'N/A'}'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Equipo Destino',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(LucideIcons.users),
                        ),
                        initialValue: selectedTeamId,
                        items:
                            _teams.map((team) {
                              return DropdownMenuItem<String>(
                                value: team['_id'].toString(),
                                child: Text(team['name'] ?? 'Sin nombre'),
                              );
                            }).toList(),
                        onChanged:
                            (value) => setState(() => selectedTeamId = value),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          selectedTeamId != null
                              ? () => _transferAddition(
                                materialId,
                                additionId,
                                quantity,
                                selectedTeamId!,
                              )
                              : null,
                      child: const Text(
                        'Transferir',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _transferAddition(
    String materialId,
    String additionId,
    int quantity,
    String teamId,
  ) async {
    try {
      final response = await TechHubApiClient.transferToTeam(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        materialId: materialId,
        additionId: additionId,
        quantity: quantity,
        teamId: teamId,
        change: 'Transferencia desde inventario recuperado',
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Unidad transferida exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al transferir unidad',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al transferir unidad: $e', isError: true);
    }
  }

  void _showDeleteAdditionDialog(String materialId, String additionId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.trash, color: Colors.red.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Eliminar Unidad'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  '¿Estás seguro de que quieres eliminar esta unidad?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Esta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _deleteAddition(materialId, additionId),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAddition(String materialId, String additionId) async {
    try {
      final response = await TechHubApiClient.deleteAddition(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        materialId: materialId,
        additionId: additionId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Unidad eliminada exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al eliminar unidad',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al eliminar unidad: $e', isError: true);
    }
  }

  void _showEditRecoveredMaterialDialog(Map<String, dynamic> material) {
    String materialName = material['name'] ?? '';
    final materialId = material['_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.edit, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Editar RMA'),
              ],
            ),
            content: TextField(
              decoration: InputDecoration(
                labelText: 'Nombre del Material',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(LucideIcons.package),
              ),
              controller: TextEditingController(text: materialName),
              onChanged: (value) => materialName = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    () => _editRecoveredMaterial(materialId, materialName),
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _editRecoveredMaterial(String id, String name) async {
    if (name.isEmpty) {
      _showSnackBar('Por favor ingresa un nombre válido', isError: true);
      return;
    }

    try {
      final response = await TechHubApiClient.editRecoveredMaterial(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        id: id,
        name: name,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Material actualizado exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al actualizar material',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al actualizar material: $e', isError: true);
    }
  }

  void _showDeleteRecoveredMaterialDialog(Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.trash, color: Colors.red.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Eliminar Material Recuperado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Estás seguro de que quieres eliminar "${material['name']}"?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se eliminarán todas las unidades asociadas. Esta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _deleteRecoveredMaterial(material),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteRecoveredMaterial(Map<String, dynamic> material) async {
    final materialId = material['_id']?.toString() ?? '';

    try {
      final response = await TechHubApiClient.deleteRecoveredMaterial(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        id: materialId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        _showSnackBar('Material eliminado exitosamente');
        _loadData();
      } else {
        _showSnackBar(
          response.error ?? 'Error al eliminar material',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al eliminar material: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(dynamic dateField) {
    try {
      if (dateField == null) return 'Fecha no disponible';

      DateTime date;
      if (dateField is Map && dateField.containsKey('\$date')) {
        final dateString = dateField['\$date'] as String;
        date = DateTime.parse(dateString);
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else if (dateField is DateTime) {
        date = dateField;
      } else {
        return 'Formato de fecha inválido';
      }

      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Error al formatear fecha';
    }
  }

  void _showMaterialHistoryDialog(
    Map<String, dynamic> material,
    InventoryType type,
  ) {
    final name = material['name'] as String? ?? 'Sin nombre';
    final history = material['history'] as List? ?? [];
    final creationDate = material['date'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.history, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Historial',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Creado: ${_formatDate(creationDate)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Historial de Movimientos:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No hay movimientos registrados',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final entry = history[history.length - 1 - index];
                          final change =
                              entry['change'] as String? ?? 'Sin descripción';
                          final quantity = entry['quantity']?.toString() ?? '0';
                          final date = entry['date'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        quantity,
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        change,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.clock,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(date),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _showRecoveredMaterialHistoryDialog(Map<String, dynamic> material) {
    final name = material['name'] as String? ?? 'Sin nombre';
    final history = material['history'] as List? ?? [];
    final additions = material['additions'] as List? ?? [];
    final creationDate = material['date'];

    // Combinar el historial del material con el historial de cada addition
    List<Map<String, dynamic>> allHistory = [];

    // Agregar historial del material
    for (var entry in history) {
      allHistory.add({
        'type': 'material',
        'change': entry['change'],
        'quantity': entry['quantity'],
        'date': entry['date'],
      });
    }

    // Agregar historial de cada addition
    for (var addition in additions) {
      final additionHistory = addition['history'] as List? ?? [];
      for (var entry in additionHistory) {
        allHistory.add({
          'type': 'addition',
          'change': entry['change'],
          'quantity': entry['quantity'],
          'date': entry['date'],
        });
      }
    }

    // Ordenar por fecha (más reciente primero)
    allHistory.sort((a, b) {
      try {
        final dateA = _parseDateForSort(a['date']);
        final dateB = _parseDateForSort(b['date']);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.history,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Historial',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.recycle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Creado: ${_formatDate(creationDate)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.layers,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total de unidades: ${additions.length}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Historial de Movimientos:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (allHistory.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No hay movimientos registrados',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allHistory.length,
                        itemBuilder: (context, index) {
                          final entry = allHistory[index];
                          final change =
                              entry['change'] as String? ?? 'Sin descripción';
                          final quantity = entry['quantity']?.toString() ?? '0';
                          final date = entry['date'];
                          final type = entry['type'] as String;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  type == 'material'
                                      ? Colors.green.shade50
                                      : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    type == 'material'
                                        ? Colors.green.shade200
                                        : Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            type == 'material'
                                                ? Colors.green.shade200
                                                : Colors.blue.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        quantity,
                                        style: TextStyle(
                                          color:
                                              type == 'material'
                                                  ? Colors.green.shade900
                                                  : Colors.blue.shade900,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        change,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.clock,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(date),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  DateTime _parseDateForSort(dynamic dateField) {
    if (dateField == null) return DateTime(1970);

    if (dateField is Map && dateField.containsKey('\$date')) {
      final dateString = dateField['\$date'] as String;
      return DateTime.parse(dateString);
    } else if (dateField is String) {
      return DateTime.parse(dateField);
    } else if (dateField is DateTime) {
      return dateField;
    }

    return DateTime(1970);
  }

  Future<void> _exportToExcel() async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      final currentTab = _tabController.index;

      // Determinar qué datos exportar según la pestaña activa
      if (currentTab == 0) {
        // Exportar inventario principal
        _exportMainInventoryToExcel(excel);
      } else if (currentTab == 1) {
        // Exportar inventario recuperado
        _exportRecoveredInventoryToExcel(excel);
      } else {
        // Exportar inventario de equipos
        _exportTeamInventoryToExcel(excel);
      }

      // Guardar archivo
      final bytes = excel.encode();
      if (bytes == null) {
        _showSnackBar('Error al generar archivo Excel', isError: true);
        return;
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'inventario_$timestamp.xlsx';

      // Compartir el archivo directamente
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );

      _showSnackBar('Excel generado exitosamente');
    } catch (e) {
      _showSnackBar('Error al exportar a Excel: $e', isError: true);
    }
  }

  void _exportMainInventoryToExcel(excel_pkg.Excel excel) {
    final sheet = excel['Inventario Principal'];

    // Encabezados
    sheet.appendRow([
      excel_pkg.TextCellValue('Nombre'),
      excel_pkg.TextCellValue('Cantidad'),
      excel_pkg.TextCellValue('Fecha Creación'),
      excel_pkg.TextCellValue('Total Movimientos'),
    ]);

    int totalMateriales = 0;
    int totalCantidad = 0;
    int totalMovimientos = 0;

    // Datos
    for (var material in _filteredMainInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final quantity = material['quantity']?.toString() ?? '0';
      final date = _formatDate(material['date']);
      final history = material['history'] as List? ?? [];

      sheet.appendRow([
        excel_pkg.TextCellValue(name),
        excel_pkg.TextCellValue(quantity),
        excel_pkg.TextCellValue(date),
        excel_pkg.IntCellValue(history.length),
      ]);

      totalMateriales++;
      totalCantidad += int.tryParse(quantity) ?? 0;
      totalMovimientos += history.length;
    }

    // Estadísticas
    sheet.appendRow([]);
    sheet.appendRow([excel_pkg.TextCellValue('ESTADÍSTICAS')]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Materiales:'),
      excel_pkg.IntCellValue(totalMateriales),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Cantidad Total:'),
      excel_pkg.IntCellValue(totalCantidad),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Movimientos:'),
      excel_pkg.IntCellValue(totalMovimientos),
    ]);

    // Hoja de historial - Recopilar todos los movimientos
    final allMovements = <Map<String, dynamic>>[];

    for (var material in _filteredMainInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final history = material['history'] as List? ?? [];

      for (var entry in history) {
        allMovements.add({
          'materialName': name,
          'change': entry['change'] ?? 'Sin descripción',
          'quantity': entry['quantity']?.toString() ?? '0',
          'date': entry['date'],
          'dateFormatted': _formatDate(entry['date']),
        });
      }
    }

    // Ordenar por fecha (más recientes primero)
    allMovements.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      try {
        final parsedA = DateTime.parse(dateA.toString());
        final parsedB = DateTime.parse(dateB.toString());
        return parsedB.compareTo(
          parsedA,
        ); // Orden descendente (más recientes primero)
      } catch (e) {
        return 0;
      }
    });

    // Hoja de historial
    final historySheet = excel['Historial Movimientos'];
    historySheet.appendRow([
      excel_pkg.TextCellValue('Fecha'),
      excel_pkg.TextCellValue('Material'),
      excel_pkg.TextCellValue('Cambio'),
      excel_pkg.TextCellValue('Cantidad'),
    ]);

    // Exportar todos los movimientos ordenados
    for (var movement in allMovements) {
      historySheet.appendRow([
        excel_pkg.TextCellValue(movement['dateFormatted']),
        excel_pkg.TextCellValue(movement['materialName']),
        excel_pkg.TextCellValue(movement['change']),
        excel_pkg.TextCellValue(movement['quantity']),
      ]);
    }
  }

  void _exportRecoveredInventoryToExcel(excel_pkg.Excel excel) {
    final sheet = excel['Inventario Recuperado'];

    // Encabezados
    sheet.appendRow([
      excel_pkg.TextCellValue('Nombre'),
      excel_pkg.TextCellValue('Unidades'),
      excel_pkg.TextCellValue('Fecha Creación'),
      excel_pkg.TextCellValue('Total Movimientos'),
    ]);

    int totalMateriales = 0;
    int totalUnidades = 0;
    int totalMovimientos = 0;

    // Datos
    for (var material in _filteredRecoveredInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final additions = material['additions'] as List? ?? [];
      final date = _formatDate(material['date']);
      final history = material['history'] as List? ?? [];

      sheet.appendRow([
        excel_pkg.TextCellValue(name),
        excel_pkg.IntCellValue(additions.length),
        excel_pkg.TextCellValue(date),
        excel_pkg.IntCellValue(history.length),
      ]);

      totalMateriales++;
      totalUnidades += additions.length;
      totalMovimientos += history.length;
    }

    // Estadísticas
    sheet.appendRow([]);
    sheet.appendRow([excel_pkg.TextCellValue('ESTADÍSTICAS')]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Materiales:'),
      excel_pkg.IntCellValue(totalMateriales),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Unidades:'),
      excel_pkg.IntCellValue(totalUnidades),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Movimientos:'),
      excel_pkg.IntCellValue(totalMovimientos),
    ]);

    // Hoja de historial - Recopilar todos los movimientos
    final allMovements = <Map<String, dynamic>>[];

    for (var material in _filteredRecoveredInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final history = material['history'] as List? ?? [];
      final additions = material['additions'] as List? ?? [];

      // Historial del material
      for (var entry in history) {
        allMovements.add({
          'materialName': name,
          'type': 'Material',
          'change': entry['change'] ?? 'Sin descripción',
          'quantity': entry['quantity']?.toString() ?? '0',
          'date': entry['date'],
          'dateFormatted': _formatDate(entry['date']),
        });
      }

      // Historial de additions
      for (var addition in additions) {
        final additionHistory = addition['history'] as List? ?? [];
        for (var entry in additionHistory) {
          allMovements.add({
            'materialName': name,
            'type': 'Unidad',
            'change': entry['change'] ?? 'Sin descripción',
            'quantity': entry['quantity']?.toString() ?? '0',
            'date': entry['date'],
            'dateFormatted': _formatDate(entry['date']),
          });
        }
      }
    }

    // Ordenar por fecha (más recientes primero)
    allMovements.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      try {
        final parsedA = DateTime.parse(dateA.toString());
        final parsedB = DateTime.parse(dateB.toString());
        return parsedB.compareTo(
          parsedA,
        ); // Orden descendente (más recientes primero)
      } catch (e) {
        return 0;
      }
    });

    // Hoja de historial
    final historySheet = excel['Historial Movimientos'];
    historySheet.appendRow([
      excel_pkg.TextCellValue('Fecha'),
      excel_pkg.TextCellValue('Material'),
      excel_pkg.TextCellValue('Tipo'),
      excel_pkg.TextCellValue('Cambio'),
      excel_pkg.TextCellValue('Cantidad'),
    ]);

    // Exportar todos los movimientos ordenados
    for (var movement in allMovements) {
      historySheet.appendRow([
        excel_pkg.TextCellValue(movement['dateFormatted']),
        excel_pkg.TextCellValue(movement['materialName']),
        excel_pkg.TextCellValue(movement['type']),
        excel_pkg.TextCellValue(movement['change']),
        excel_pkg.TextCellValue(movement['quantity']),
      ]);
    }
  }

  void _exportTeamInventoryToExcel(excel_pkg.Excel excel) {
    if (_selectedTeamId == null) {
      _showSnackBar('Por favor selecciona un equipo', isError: true);
      return;
    }

    final selectedTeam = _teams.firstWhere(
      (team) => team['_id'].toString() == _selectedTeamId,
      orElse: () => {'name': 'Equipo Desconocido'},
    );
    final teamName = selectedTeam['name'] ?? 'Equipo Desconocido';

    final sheet = excel['Inventario $teamName'];

    // Encabezados
    sheet.appendRow([
      excel_pkg.TextCellValue('Nombre'),
      excel_pkg.TextCellValue('Cantidad'),
      excel_pkg.TextCellValue('Tipo'),
    ]);

    int totalMateriales = 0;
    int totalCantidad = 0;
    int totalRecuperados = 0;

    // Datos
    for (var material in _filteredTeamInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final quantity = material['quantity']?.toString() ?? '0';
      final isRecovered = material['isRecovered'] as bool? ?? false;

      sheet.appendRow([
        excel_pkg.TextCellValue(name),
        excel_pkg.TextCellValue(quantity),
        excel_pkg.TextCellValue(isRecovered ? 'Recuperado' : 'Normal'),
      ]);

      totalMateriales++;
      totalCantidad += int.tryParse(quantity) ?? 0;
      if (isRecovered) totalRecuperados++;
    }

    // Estadísticas
    sheet.appendRow([]);
    sheet.appendRow([excel_pkg.TextCellValue('ESTADÍSTICAS')]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Equipo:'),
      excel_pkg.TextCellValue(teamName),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Materiales:'),
      excel_pkg.IntCellValue(totalMateriales),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Cantidad Total:'),
      excel_pkg.IntCellValue(totalCantidad),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Materiales Recuperados:'),
      excel_pkg.IntCellValue(totalRecuperados),
    ]);
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      final currentTab = _tabController.index;

      // Determinar qué datos exportar según la pestaña activa
      if (currentTab == 0) {
        await _exportMainInventoryToPDF(pdf);
      } else if (currentTab == 1) {
        await _exportRecoveredInventoryToPDF(pdf);
      } else {
        await _exportTeamInventoryToPDF(pdf);
      }

      // Guardar y compartir PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      _showSnackBar('PDF generado exitosamente');
    } catch (e) {
      _showSnackBar('Error al exportar a PDF: $e', isError: true);
    }
  }

  Future<void> _exportMainInventoryToPDF(pw.Document pdf) async {
    int totalMateriales = _filteredMainInventory.length;
    int totalCantidad = _filteredMainInventory.fold(0, (sum, item) {
      final quantity = item['quantity'];
      int quantityInt = 0;
      if (quantity is int) {
        quantityInt = quantity;
      } else if (quantity is String) {
        quantityInt = int.tryParse(quantity) ?? 0;
      }
      return sum + quantityInt;
    });
    int totalMovimientos = _filteredMainInventory.fold(0, (sum, item) {
      final history = item['history'] as List? ?? [];
      return sum + history.length;
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Inventario Principal',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ESTADÍSTICAS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Total de Materiales: $totalMateriales'),
                  pw.Text('Cantidad Total: $totalCantidad'),
                  pw.Text('Total de Movimientos: $totalMovimientos'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'LISTADO DE MATERIALES',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Nombre', 'Cantidad', 'Fecha Creación', 'Movimientos'],
              data:
                  _filteredMainInventory.map((material) {
                    final name = material['name'] ?? 'Sin nombre';
                    final quantity = material['quantity']?.toString() ?? '0';
                    final date = _formatDate(material['date']);
                    final history = material['history'] as List? ?? [];
                    return [name, quantity, date, history.length.toString()];
                  }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    // Página de historial - Recopilar todos los movimientos
    final allMovements = <Map<String, dynamic>>[];

    for (var material in _filteredMainInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final history = material['history'] as List? ?? [];

      for (var entry in history) {
        allMovements.add({
          'materialName': name,
          'change': entry['change'] ?? 'Sin descripción',
          'quantity': entry['quantity']?.toString() ?? '0',
          'date': entry['date'],
          'dateFormatted': _formatDate(entry['date']),
        });
      }
    }

    // Ordenar por fecha (más recientes primero)
    allMovements.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      try {
        final parsedA = DateTime.parse(dateA.toString());
        final parsedB = DateTime.parse(dateB.toString());
        return parsedB.compareTo(
          parsedA,
        ); // Orden descendente (más recientes primero)
      } catch (e) {
        return 0;
      }
    });

    // Tomar solo los últimos 10 movimientos
    final last10Movements = allMovements.take(10).toList();

    if (last10Movements.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Últimos 10 Movimientos',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Material', 'Cambio', 'Cantidad'],
                data:
                    last10Movements.map((movement) {
                      return [
                        movement['dateFormatted'],
                        movement['materialName'],
                        movement['change'],
                        movement['quantity'],
                      ];
                    }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.orange,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                },
              ),
            ];
          },
        ),
      );
    }
  }

  Future<void> _exportRecoveredInventoryToPDF(pw.Document pdf) async {
    int totalMateriales = _filteredRecoveredInventory.length;
    int totalUnidades = _filteredRecoveredInventory.fold(0, (sum, item) {
      final additions = item['additions'] as List? ?? [];
      return sum + additions.length;
    });
    int totalMovimientos = _filteredRecoveredInventory.fold(0, (sum, item) {
      final history = item['history'] as List? ?? [];
      return sum + history.length;
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Inventario Recuperado',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.green),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ESTADÍSTICAS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Total de Materiales: $totalMateriales'),
                  pw.Text('Total de Unidades: $totalUnidades'),
                  pw.Text('Total de Movimientos: $totalMovimientos'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'LISTADO DE MATERIALES',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Nombre', 'Unidades', 'Fecha Creación', 'Movimientos'],
              data:
                  _filteredRecoveredInventory.map((material) {
                    final name = material['name'] ?? 'Sin nombre';
                    final additions = material['additions'] as List? ?? [];
                    final date = _formatDate(material['date']);
                    final history = material['history'] as List? ?? [];
                    return [
                      name,
                      additions.length.toString(),
                      date,
                      history.length.toString(),
                    ];
                  }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    // Página de historial - Recopilar todos los movimientos
    final allMovements = <Map<String, dynamic>>[];

    for (var material in _filteredRecoveredInventory) {
      final name = material['name'] ?? 'Sin nombre';
      final history = material['history'] as List? ?? [];
      final additions = material['additions'] as List? ?? [];

      // Historial del material
      for (var entry in history) {
        allMovements.add({
          'materialName': name,
          'type': 'Material',
          'change': entry['change'] ?? 'Sin descripción',
          'quantity': entry['quantity']?.toString() ?? '0',
          'date': entry['date'],
          'dateFormatted': _formatDate(entry['date']),
        });
      }

      // Historial de additions
      for (var addition in additions) {
        final additionHistory = addition['history'] as List? ?? [];
        for (var entry in additionHistory) {
          allMovements.add({
            'materialName': name,
            'type': 'Unidad',
            'change': entry['change'] ?? 'Sin descripción',
            'quantity': entry['quantity']?.toString() ?? '0',
            'date': entry['date'],
            'dateFormatted': _formatDate(entry['date']),
          });
        }
      }
    }

    // Ordenar por fecha (más recientes primero)
    allMovements.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      try {
        final parsedA = DateTime.parse(dateA.toString());
        final parsedB = DateTime.parse(dateB.toString());
        return parsedB.compareTo(
          parsedA,
        ); // Orden descendente (más recientes primero)
      } catch (e) {
        return 0;
      }
    });

    // Tomar solo los últimos 10 movimientos
    final last10Movements = allMovements.take(10).toList();

    if (last10Movements.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Últimos 10 Movimientos',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Movimientos ordenados del más reciente al más antiguo',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Material', 'Tipo', 'Cambio', 'Cantidad'],
                data:
                    last10Movements.map((movement) {
                      return [
                        movement['dateFormatted'],
                        movement['materialName'],
                        movement['type'],
                        movement['change'],
                        movement['quantity'],
                      ];
                    }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                },
              ),
            ];
          },
        ),
      );
    }
  }

  Future<void> _exportTeamInventoryToPDF(pw.Document pdf) async {
    if (_selectedTeamId == null) {
      _showSnackBar('Por favor selecciona un equipo', isError: true);
      return;
    }

    final selectedTeam = _teams.firstWhere(
      (team) => team['_id'].toString() == _selectedTeamId,
      orElse: () => {'name': 'Equipo Desconocido'},
    );
    final teamName = selectedTeam['name'] ?? 'Equipo Desconocido';

    int totalMateriales = _filteredTeamInventory.length;
    int totalCantidad = _filteredTeamInventory.fold(0, (sum, item) {
      final quantity = item['quantity'];
      int quantityInt = 0;
      if (quantity is int) {
        quantityInt = quantity;
      } else if (quantity is String) {
        quantityInt = int.tryParse(quantity) ?? 0;
      }
      return sum + quantityInt;
    });
    int totalRecuperados =
        _filteredTeamInventory.where((m) => m['isRecovered'] == true).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Inventario de Equipo: $teamName',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ESTADÍSTICAS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Equipo: $teamName'),
                  pw.Text('Total de Materiales: $totalMateriales'),
                  pw.Text('Cantidad Total: $totalCantidad'),
                  pw.Text('Materiales Recuperados: $totalRecuperados'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'LISTADO DE MATERIALES',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Nombre', 'Cantidad', 'Tipo'],
              data:
                  _filteredTeamInventory.map((material) {
                    final name = material['name'] ?? 'Sin nombre';
                    final quantity = material['quantity']?.toString() ?? '0';
                    final isRecovered =
                        material['isRecovered'] as bool? ?? false;
                    return [
                      name,
                      quantity,
                      isRecovered ? 'Recuperado' : 'Normal',
                    ];
                  }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );
  }

  void _showExportMenu() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.download,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Exportar Inventario'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.fileSpreadsheet,
                      color: Colors.green.shade700,
                    ),
                  ),
                  title: const Text('Exportar a Excel'),
                  subtitle: const Text('Archivo .xlsx con hojas de datos'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToExcel();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.fileText,
                      color: Colors.red.shade700,
                    ),
                  ),
                  title: const Text('Exportar a PDF'),
                  subtitle: const Text('Documento PDF formateado'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToPDF();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  void _showBulkTransferDialog() {
    if (_selectedMaterials.isEmpty) {
      _showSnackBar('Selecciona al menos un material', isError: true);
      return;
    }

    String? selectedTeamId;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.send,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Transferencia Múltiple'),
                    ],
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Materiales seleccionados: ${_selectedMaterials.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Lista de materiales seleccionados
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _selectedMaterials.length,
                              itemBuilder: (context, index) {
                                final selection =
                                    _selectedMaterials.values.toList()[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      selection.materialName,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Cantidad: ${selection.quantity} | Origen: ${selection.source == InventoryType.main ? "Principal" : "Recuperado"}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Selector de equipo
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Equipo Destino',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(LucideIcons.users),
                            ),
                            initialValue: selectedTeamId,
                            items:
                                _teams.map((team) {
                                  return DropdownMenuItem<String>(
                                    value: team['_id'].toString(),
                                    child: Text(team['name'] ?? 'Sin nombre'),
                                  );
                                }).toList(),
                            onChanged:
                                (value) =>
                                    setState(() => selectedTeamId = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          selectedTeamId != null
                              ? () => _executeBulkTransfer(selectedTeamId!)
                              : null,
                      child: const Text(
                        'Transferir',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _executeBulkTransfer(String teamId) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Preparar datos
      final materials =
          _selectedMaterials.values.map((m) => m.toJson()).toList();

      // Ejecutar transferencia
      final response = await TechHubApiClient.bulkTransferToTeam(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        userId: widget.authManager.userId!,
        teamId: teamId,
        materials: materials,
        notes: 'Transferencia múltiple desde app móvil',
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading
      Navigator.pop(context); // Cerrar diálogo

      if (response.isSuccess) {
        final receiptData = response.data!;
        final receiptId = receiptData['receipt']?['_id'] ?? '';
        final receiptNumber = receiptData['receipt']?['receiptNumber'] ?? '';

        _showSnackBar('Transferencia exitosa. Remito: $receiptNumber');

        // Limpiar selecciones y salir del modo transferencia
        setState(() {
          _selectedMaterials.clear();
          _isTransferMode = false;
        });

        // Recargar datos
        _loadData();

        // Mostrar opciones de descarga
        _showDownloadReceiptDialog(receiptId, receiptNumber);
      } else {
        _showSnackBar(
          response.error ?? 'Error al realizar la transferencia',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showDownloadReceiptDialog(String receiptId, String receiptNumber) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Text('Transferencia Exitosa'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remito $receiptNumber generado correctamente',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Deseas descargar el remito?',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                child: const Text('Cerrar', style: TextStyle(fontSize: 13)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _downloadReceipt(receiptId, receiptNumber, 'pdf');
                },
                icon: const Icon(
                  LucideIcons.fileText,
                  color: Colors.white,
                  size: 14,
                ),
                label: const Text(
                  'PDF',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _downloadReceipt(receiptId, receiptNumber, 'excel');
                },
                icon: const Icon(
                  LucideIcons.fileSpreadsheet,
                  color: Colors.white,
                  size: 14,
                ),
                label: const Text(
                  'Excel',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _downloadReceipt(
    String receiptId,
    String receiptNumber,
    String format,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response =
          format == 'pdf'
              ? await TechHubApiClient.downloadReceiptPDF(
                username: widget.authManager.userName!,
                password: widget.authManager.password!,
                receiptId: receiptId,
              )
              : await TechHubApiClient.downloadReceiptExcel(
                username: widget.authManager.userName!,
                password: widget.authManager.password!,
                receiptId: receiptId,
              );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess && response.data != null) {
        // Guardar archivo
        await _saveFile(response.data!, receiptNumber, format);
        _showSnackBar('Remito descargado exitosamente');
      } else {
        _showSnackBar(
          response.error ?? 'Error al descargar remito',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _saveFile(
    Uint8List bytes,
    String receiptNumber,
    String format,
  ) async {
    try {
      final extension = format == 'pdf' ? 'pdf' : 'xlsx';
      final fileName = 'remito-$receiptNumber.$extension';

      final result = await file_saver.saveFile(bytes, fileName, format);
      _showSnackBar(result);
    } catch (e) {
      _showSnackBar('Error al guardar archivo: $e', isError: true);
    }
  }
}
