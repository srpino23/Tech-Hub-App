import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../services/api_response.dart';

class InventoryScreen extends StatefulWidget {
  final AuthManager authManager;

  const InventoryScreen({super.key, required this.authManager});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _mainInventory = [];
  List<Map<String, dynamic>> _recoveredInventory = [];
  List<Map<String, dynamic>> _teamInventory = [];
  List<Map<String, dynamic>> _teams = [];
  bool _isLoading = true;
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      });
    }
  }

  Future<void> _loadTeams() async {
    final response = await TechHubApiClient.getTeams(
      username: widget.authManager.userName!,
      password: widget.authManager.password!,
    );
    if (response.isSuccess && response.data != null) {
      setState(() {
        _teams = response.data!;
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
      });
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMaterialDialog(),
        backgroundColor: Colors.orange,
        child: const Icon(LucideIcons.plus, color: Colors.white),
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
            _buildInventoryStats(_mainInventory),
            const SizedBox(height: 16),
            Expanded(
              child: _buildMaterialList(_mainInventory, InventoryType.main),
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
          if (_selectedTeamId != null) ...[
            _buildInventoryStats(_teamInventory),
            const SizedBox(height: 16),
            Expanded(
              child: _buildMaterialList(_teamInventory, InventoryType.team),
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
              value: _selectedTeamId,
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
    int totalMaterials = _recoveredInventory.length;
    int totalAdditions = _recoveredInventory.fold(0, (sum, material) {
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
    if (_recoveredInventory.isEmpty) {
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
              'No hay materiales recuperados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea un material recuperado usando el botón +',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recoveredInventory.length,
      itemBuilder: (context, index) {
        final material = _recoveredInventory[index];
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
        trailing: PopupMenuButton<String>(
          onSelected:
              (value) => _handleRecoveredMaterialAction(value, material),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      Icon(LucideIcons.plus, size: 16, color: Colors.green),
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
                      Icon(LucideIcons.trash, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
        children:
            additions.map<Widget>((addition) {
              return _buildAdditionCard(materialId, addition);
            }).toList(),
      ),
    );
  }

  Widget _buildAdditionCard(String materialId, Map<String, dynamic> addition) {
    final quantity = addition['quantity']?.toString() ?? '1';
    final status = addition['status']?.toString() ?? 'recuperado';
    final condition = addition['condition']?.toString() ?? 'regular';
    final additionId = addition['_id']?.toString() ?? '';
    final notes = addition['notes']?.toString() ?? '';

    Color statusColor = _getStatusColor(status);
    Color conditionColor = _getConditionColor(condition);

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Row(
        children: [
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
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
                        Icon(LucideIcons.trash, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
          ),
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
            isRecovered && type == InventoryType.team
                ? Border.all(color: Colors.green.shade200, width: 1)
                : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMaterialAction(value, material, type),
          itemBuilder:
              (context) => [
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
                if (type == InventoryType.team) ...[
                  const PopupMenuItem(
                    value: 'return',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.arrowLeft,
                          size: 16,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Text('Retornar', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
                ],
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(LucideIcons.trash, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
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
    );
  }

  void _handleMaterialAction(
    String action,
    Map<String, dynamic> material,
    InventoryType type,
  ) {
    switch (action) {
      case 'edit':
        _showEditMaterialDialog(material, type);
        break;
      case 'move':
        _showTransferMaterialDialog(material, type);
        break;
      case 'return':
        _showReturnMaterialDialog(material);
        break;
      case 'delete':
        _showDeleteMaterialDialog(material, type);
        break;
    }
  }

  void _showReturnMaterialDialog(Map<String, dynamic> material) {
    final isRecovered = material['isRecovered'] as bool? ?? false;
    final materialName = material['name'] as String? ?? 'Sin nombre';
    final quantity = material['quantity'] ?? 0;

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
                    LucideIcons.arrowLeft,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Retornar Material'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRecovered ? LucideIcons.recycle : LucideIcons.package,
                  size: 48,
                  color: isRecovered ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Retornar "$materialName" al inventario ${isRecovered ? 'recuperado' : 'principal'}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cantidad: $quantity',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (isRecovered) ...[
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
                          LucideIcons.info,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Se retornará al inventario de materiales recuperados',
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
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _returnMaterialToInventory(material),
                child: const Text(
                  'Retornar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _returnMaterialToInventory(Map<String, dynamic> material) async {
    // Aquí implementarías la lógica para retornar el material
    // Por ahora solo mostramos un mensaje
    Navigator.pop(context);
    _showSnackBar('Función de retorno en desarrollo');
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
                        value: selectedTeamId,
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
    final materialId = material['_id']?.toString() ?? '';

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
      } else {
        _showSnackBar(
          'No se puede eliminar materiales del inventario de equipo',
          isError: true,
        );
        return;
      }

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

  void _handleRecoveredMaterialAction(
    String action,
    Map<String, dynamic> material,
  ) {
    switch (action) {
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
                        value: condition,
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
                        value: status,
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
                        value: condition,
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
                        value: selectedTeamId,
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
                const Text('Editar Material Recuperado'),
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
}

enum InventoryType { main, recovered, team }
