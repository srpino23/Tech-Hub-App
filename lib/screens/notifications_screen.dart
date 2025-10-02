import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analyzer_api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];
  String? _selectedType;
  String? _selectedSeverity;

  final List<String> _types = ['status_report', 'stabilization_alert', 'zone_alert', 'system_alert'];
  final List<String> _severities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await AnalyzerApiClient.getAllStatusReports(
        type: _selectedType,
        severity: _selectedSeverity,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(response.data!['reports'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Error loading reports';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'status_report':
        return LucideIcons.barChart3;
      case 'stabilization_alert':
        return LucideIcons.alertTriangle;
      case 'zone_alert':
        return LucideIcons.mapPin;
      case 'system_alert':
        return LucideIcons.settings;
      default:
        return LucideIcons.bell;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedType,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ..._types.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.replaceAll('_', ' ').toUpperCase()),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                      _loadReports();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Severidad',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedSeverity,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ..._severities.map((severity) => DropdownMenuItem(
                        value: severity,
                        child: Text(severity.toUpperCase()),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSeverity = value);
                      _loadReports();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Lista de reportes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadReports,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _reports.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.bellOff, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No hay notificaciones'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _reports.length,
                            itemBuilder: (context, index) {
                              final report = _reports[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getSeverityColor(report['severity'] ?? 'low'),
                                    child: Icon(
                                      _getTypeIcon(report['type'] ?? ''),
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    report['message'] ?? 'Sin mensaje',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tipo: ${report['type']?.replaceAll('_', ' ').toUpperCase() ?? 'Desconocido'}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Fecha: ${_formatDate(report['date'] ?? '')}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (report['zone'] != null)
                                        Text(
                                          'Zona: ${report['zone']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getSeverityColor(report['severity'] ?? 'low'),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (report['severity'] ?? 'low').toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    // Mostrar detalles del reporte
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(report['type']?.replaceAll('_', ' ').toUpperCase() ?? 'Notificación'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(report['message'] ?? 'Sin mensaje'),
                                              const SizedBox(height: 16),
                                              Text('Severidad: ${report['severity'] ?? 'low'}'),
                                              Text('Fecha: ${_formatDate(report['date'] ?? '')}'),
                                              if (report['zone'] != null)
                                                Text('Zona: ${report['zone']}'),
                                              if (report['statistics'] != null) ...[
                                                const SizedBox(height: 16),
                                                const Text('Estadísticas:', style: TextStyle(fontWeight: FontWeight.bold)),
                                                Text('Total cámaras: ${report['statistics']['totalCameras'] ?? 0}'),
                                                Text('Cámaras online: ${report['statistics']['onlineCameras'] ?? 0}'),
                                                Text('Cámaras offline: ${report['statistics']['offlineCameras'] ?? 0}'),
                                                Text('Porcentaje offline: ${(report['statistics']['offlinePercentage'] ?? 0).toStringAsFixed(2)}%'),
                                              ],
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Cerrar'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}