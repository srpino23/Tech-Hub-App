import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth_manager.dart';
import '../services/analyzer_api_client.dart';

class DashboardScreen extends StatefulWidget {
  final AuthManager authManager;

  const DashboardScreen({super.key, required this.authManager});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _operationalHistory = [];
  List<Map<String, dynamic>> _cameras = [];

  Map<String, int> _generalStatus = {
    'online': 0,
    'warning': 0,
    'offline': 0,
    'maintenance': 0,
    'removed': 0,
  };

  List<Map<String, dynamic>> _zoneOperability = [];
  List<Map<String, dynamic>> _liableOperability = [];

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Establecer fechas por defecto: últimos 30 días
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        AnalyzerApiClient.getOperationalHistory(),
        AnalyzerApiClient.getCameras(),
      ]);

      final historyResponse = results[0];
      final camerasResponse = results[1];

      if (historyResponse.isSuccess && historyResponse.data != null) {
        _operationalHistory = List<Map<String, dynamic>>.from(
          historyResponse.data!,
        );
        if (_operationalHistory.isNotEmpty) {
          final latest = _operationalHistory.first;
          _zoneOperability = List<Map<String, dynamic>>.from(
            latest['zoneOperability'] ?? [],
          );
          _liableOperability = List<Map<String, dynamic>>.from(
            latest['liableOperability'] ?? [],
          );
        }
      }

      if (camerasResponse.isSuccess && camerasResponse.data != null) {
        _cameras = List<Map<String, dynamic>>.from(camerasResponse.data!);
        _calculateGeneralStatus();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar los datos: $e';
      });
    }
  }

  void _calculateGeneralStatus() {
    _generalStatus = {
      'online': 0,
      'warning': 0,
      'offline': 0,
      'maintenance': 0,
      'removed': 0,
    };

    for (var camera in _cameras) {
      final status = camera['status']?.toString().toLowerCase() ?? 'offline';
      if (_generalStatus.containsKey(status)) {
        _generalStatus[status] = _generalStatus[status]! + 1;
      } else {
        _generalStatus['offline'] = _generalStatus['offline']! + 1;
      }
    }
  }

  double _getGeneralOperabilityPercentage() {
    final totalOperationalCameras = _getTotalOperationalCameras();

    if (totalOperationalCameras == 0) return 0;

    // Solo las cámaras online y warning están realmente funcionando
    final functionalCameras =
        _generalStatus['online']! + _generalStatus['warning']!;

    // El porcentaje de operatividad es: cámaras funcionando / cámaras operacionales (sin retiradas)
    return (functionalCameras / totalOperationalCameras) * 100;
  }

  // Método auxiliar para obtener el total de cámaras operacionales (sin retiradas)
  int _getTotalOperationalCameras() {
    return _generalStatus['online']! +
        _generalStatus['warning']! +
        _generalStatus['offline']! +
        _generalStatus['maintenance']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Cargando dashboard...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: Colors.orange,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGeneralOperabilitySection(),
            const SizedBox(height: 24),
            _buildLiableOperabilitySection(),
            const SizedBox(height: 24),
            _buildZoneOperabilitySection(),
            const SizedBox(height: 24),
            _buildOperationalHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralOperabilitySection() {
    final totalOperationalCameras = _getTotalOperationalCameras();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.pieChart,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operatividad General',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_getGeneralOperabilityPercentage().round()}% operativo',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 160,
                    child:
                        totalOperationalCameras > 0
                            ? PieChart(
                              PieChartData(
                                sections: _buildGeneralPieChartSections(),
                                centerSpaceRadius: 30,
                                sectionsSpace: 2,
                              ),
                            )
                            : const Center(
                              child: Text(
                                'No hay datos disponibles',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildStatusIndicatorWithPercentage(
                        'En línea',
                        _generalStatus['online']!,
                        Colors.green,
                        totalOperationalCameras,
                      ),
                      _buildStatusIndicatorWithPercentage(
                        'Advertencia',
                        _generalStatus['warning']!,
                        Colors.orange,
                        totalOperationalCameras,
                      ),
                      _buildStatusIndicatorWithPercentage(
                        'Fuera de línea',
                        _generalStatus['offline']!,
                        Colors.red,
                        totalOperationalCameras,
                      ),
                      _buildStatusIndicatorWithPercentage(
                        'Mantenimiento',
                        _generalStatus['maintenance']!,
                        Colors.blue,
                        totalOperationalCameras,
                      ),
                      _buildStatusIndicatorOnlyCount(
                        'Retirada',
                        _generalStatus['removed']!,
                        Colors.grey,
                      ),
                      const Divider(),
                      _buildStatusIndicator(
                        'Total',
                        totalOperationalCameras,
                        Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneOperabilitySection() {
    // Ordenar zonas por nombre alfabéticamente para consistencia
    final sortedZones = List<Map<String, dynamic>>.from(_zoneOperability)..sort(
      (a, b) => (a['zone'] ?? '').toString().toLowerCase().compareTo(
        (b['zone'] ?? '').toString().toLowerCase(),
      ),
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.mapPin,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Operatividad por Zona',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            sortedZones.isNotEmpty
                ? Column(
                  children: [
                    for (int i = 0; i < sortedZones.length; i += 2)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            // Primera zona de la fila
                            Expanded(
                              child: _buildZoneProgressBar(sortedZones[i], i),
                            ),
                            // Espaciado entre columnas
                            const SizedBox(width: 16),
                            // Segunda zona de la fila (si existe)
                            Expanded(
                              child:
                                  i + 1 < sortedZones.length
                                      ? _buildZoneProgressBar(
                                        sortedZones[i + 1],
                                        i + 1,
                                      )
                                      : const SizedBox(), // Espacio vacío si es impar
                            ),
                          ],
                        ),
                      ),
                  ],
                )
                : const Center(
                  child: Text(
                    'No hay datos de zonas disponibles',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiableOperabilitySection() {
    // Mostrar todos los equipos, ordenados por nombre
    final sortedLiables = List<Map<String, dynamic>>.from(_liableOperability)
      ..sort(
        (a, b) => (a['liable'] ?? '').toString().toLowerCase().compareTo(
          (b['liable'] ?? '').toString().toLowerCase(),
        ),
      );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.users,
                    color: Colors.purple.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Operatividad por Equipo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            sortedLiables.isNotEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      // Determinar el número de columnas basado en el ancho disponible
                      final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                      
                      // Calcular el ancho máximo para evitar que se estire demasiado
                      final maxWidth = crossAxisCount * 150.0 + (crossAxisCount - 1) * 8.0 + 40.0; // 150px por carta + espaciado + padding
                      
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxWidth,
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: sortedLiables.length,
                            itemBuilder: (context, index) {
                              return _buildLiablePieChart(sortedLiables[index], index);
                            },
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      'No hay datos de equipos disponibles',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalHistorySection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.trendingUp,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Historial de Operatividad',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Selector de fechas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDateRange,
                      child: Text(
                        _startDate != null && _endDate != null
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : 'Seleccionar rango de fechas',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _selectDateRange,
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child:
                  _getFilteredOperationalHistory().isNotEmpty
                      ? LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: 10,
                            verticalInterval: 5,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              );
                            },
                            getDrawingVerticalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 0.5,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 5,
                                getTitlesWidget: (value, meta) {
                                  final filteredHistory =
                                      _getFilteredOperationalHistory();
                                  final index = value.toInt();
                                  if (index >= 0 &&
                                      index < filteredHistory.length &&
                                      index % 5 == 0) {
                                    try {
                                      final dateData =
                                          filteredHistory[index]['date'];
                                      DateTime date;

                                      if (dateData is Map &&
                                          dateData['\$date'] != null) {
                                        date = DateTime.parse(
                                          dateData['\$date'],
                                        );
                                      } else if (dateData is String) {
                                        date = DateTime.parse(dateData);
                                      } else {
                                        date = DateTime.now();
                                      }

                                      return Text(
                                        '${date.day}/${date.month}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      );
                                    } catch (e) {
                                      return Text(
                                        '$index',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      );
                                    }
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 10,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  );
                                },
                                reservedSize: 42,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          minX: 0,
                          maxX:
                              (_getFilteredOperationalHistory().length - 1)
                                  .toDouble(),
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _buildOperationalHistorySpots(),
                              isCurved: true,
                              color: Colors.green.shade600,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.green.shade600,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.shade100.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : const Center(
                        child: Text(
                          'No hay datos de historial disponibles',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildGeneralPieChartSections() {
    final sections = <PieChartSectionData>[];
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.blue,
    ];

    // Excluir las cámaras retiradas del gráfico
    final operationalStatuses = ['online', 'warning', 'offline', 'maintenance'];
    final totalOperationalCameras = operationalStatuses.fold<int>(
      0,
      (sum, status) => sum + _generalStatus[status]!,
    );

    for (int i = 0; i < operationalStatuses.length; i++) {
      final status = operationalStatuses[i];
      final count = _generalStatus[status]!;
      if (count > 0) {
        final percentage = totalOperationalCameras > 0 
            ? ((count / totalOperationalCameras) * 100).round() 
            : 0;
        sections.add(
          PieChartSectionData(
            color: colors[i],
            value: count.toDouble(),
            title: percentage >= 10 ? '$percentage%' : '',
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    }

    return sections;
  }

  List<FlSpot> _buildOperationalHistorySpots() {
    final spots = <FlSpot>[];
    final filteredHistory = _getFilteredOperationalHistory();

    for (int i = 0; i < filteredHistory.length; i++) {
      final entry = filteredHistory[i];
      final operability = (entry['generalOperability'] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), operability));
    }

    return spots;
  }

  List<Map<String, dynamic>> _getFilteredOperationalHistory() {
    if (_startDate == null || _endDate == null) return _operationalHistory;

    return _operationalHistory.where((entry) {
      try {
        final dateData = entry['date'];
        DateTime entryDate;

        if (dateData is Map && dateData['\$date'] != null) {
          entryDate = DateTime.parse(dateData['\$date']);
        } else if (dateData is String) {
          entryDate = DateTime.parse(dateData);
        } else {
          return false;
        }

        return entryDate.isAfter(
              _startDate!.subtract(const Duration(days: 1)),
            ) &&
            entryDate.isBefore(_endDate!.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange:
          _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
      // Textos personalizados en español
      helpText: 'Seleccionar rango',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      saveText: 'Guardar',
      errorFormatText: 'Formato de fecha inválido',
      errorInvalidText: 'Fecha inválida',
      errorInvalidRangeText: 'Rango de fechas inválido',
      fieldStartHintText: 'Fecha de inicio',
      fieldEndHintText: 'Fecha de fin',
      fieldStartLabelText: 'Fecha de inicio',
      fieldEndLabelText: 'Fecha de fin',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.orange),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildZoneProgressBar(Map<String, dynamic> zone, int index) {
    final percentage = zone['percentage'] ?? 0;
    final totalCameras = zone['totalCameras'] ?? 0;
    final onlineCameras = zone['onlineCameras'] ?? 0;
    final progress = percentage / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                zone['zone'] ?? 'Zona desconocida',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(_getZoneColor(index)),
          minHeight: 6,
        ),
        const SizedBox(height: 2),
        Text(
          '($onlineCameras/$totalCameras)',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildStatusIndicatorWithPercentage(
    String label,
    int count,
    Color color,
    int total,
  ) {
    final percentage = total > 0 ? ((count / total) * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicatorOnlyCount(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStatusCounts(List<Map<String, dynamic>> cameras) {
    final counts = {
      'online': 0,
      'warning': 0,
      'offline': 0,
      'maintenance': 0,
      'removed': 0,
    };
    
    for (var camera in cameras) {
      final status = camera['status']?.toString().toLowerCase() ?? 'offline';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      } else {
        counts['offline'] = counts['offline']! + 1;
      }
    }
    
    return counts;
  }

  Color _getZoneColor(int index) {
    final colors = [
      Colors.blue.shade600,
      Colors.teal.shade600,
      Colors.cyan.shade600,
      Colors.indigo.shade600,
      Colors.lightBlue.shade600,
      Colors.blueGrey.shade600,
      Colors.blue.shade400,
      Colors.teal.shade400,
    ];
    return colors[index % colors.length];
  }

  Widget _buildLiablePieChart(Map<String, dynamic> liable, int index) {
    final liableName = liable['liable'] ?? 'Equipo desconocido';
    
    // Filtrar cámaras por el liable (equipo responsable)
    final liableCameras = _cameras.where((camera) {
      final cameraLiable = camera['liable']?.toString().toLowerCase() ?? '';
      final targetLiable = liableName.toLowerCase();
      return cameraLiable == targetLiable;
    }).toList();
    
    // Calcular conteos por estado
    final statusCounts = _calculateStatusCounts(liableCameras);
    final onlineCameras = statusCounts['online'] ?? 0;
    final warningCameras = statusCounts['warning'] ?? 0;
    final offlineCameras = statusCounts['offline'] ?? 0;
    final maintenanceCameras = statusCounts['maintenance'] ?? 0;
    
    // Excluir las cámaras retiradas del total operacional
    final operationalCameras = onlineCameras + warningCameras + offlineCameras + maintenanceCameras;
    final percentage = operationalCameras > 0 ? ((onlineCameras / operationalCameras) * 100).round() : 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              liableName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: operationalCameras > 0
                  ? PieChart(
                      PieChartData(
                        sections: _buildLiablePieChartSections({
                          'onlineCameras': onlineCameras,
                          'warningCameras': warningCameras,
                          'offlineCameras': offlineCameras,
                          'maintenanceCameras': maintenanceCameras,
                        }),
                        centerSpaceRadius: 15,
                        sectionsSpace: 1,
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Sin datos',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '($onlineCameras/$operationalCameras)',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildLiablePieChartSections(Map<String, dynamic> liable) {
    final sections = <PieChartSectionData>[];
    final colors = [Colors.green, Colors.orange, Colors.red, Colors.blue];
    
    final onlineCameras = liable['onlineCameras'] ?? 0;
    final warningCameras = liable['warningCameras'] ?? 0;
    final offlineCameras = liable['offlineCameras'] ?? 0;
    final maintenanceCameras = liable['maintenanceCameras'] ?? 0;
    
    final values = [onlineCameras, warningCameras, offlineCameras, maintenanceCameras];
    final operationalTotal = values.fold<int>(0, (sum, value) => sum + (value as int));
    
    for (int i = 0; i < values.length; i++) {
      final count = values[i];
      if (count > 0) {
        final percentage = operationalTotal > 0 
            ? ((count / operationalTotal) * 100).round() 
            : 0;
        sections.add(
          PieChartSectionData(
            color: colors[i],
            value: count.toDouble(),
            title: percentage >= 10 ? '$percentage%' : '',
            radius: 25,
            titleStyle: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    }
    
    return sections;
  }

}
