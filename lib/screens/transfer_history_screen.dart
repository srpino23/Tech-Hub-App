import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../utils/file_saver.dart' as file_saver;

class TransferHistoryScreen extends StatefulWidget {
  final AuthManager authManager;

  const TransferHistoryScreen({super.key, required this.authManager});

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await TechHubApiClient.getTransferReceipts(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
      );

      if (response.isSuccess) {
        setState(() {
          _receipts = response.data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.error ?? 'Error al cargar remitos';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _downloadReceipt(String receiptId, String receiptNumber, String format) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final response = format == 'pdf'
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
      Navigator.pop(context); // Cerrar loading

      if (response.isSuccess) {
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

  Future<void> _saveFile(Uint8List bytes, String receiptNumber, String format) async {
    try {
      final extension = format == 'pdf' ? 'pdf' : 'xlsx';
      final fileName = 'remito-$receiptNumber.$extension';

      final result = await file_saver.saveFile(bytes, fileName, format);
      _showSnackBar(result);
    } catch (e) {
      _showSnackBar('Error al guardar archivo: $e', isError: true);
    }
  }

  void _showDownloadDialog(String receiptId, String receiptNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(LucideIcons.download, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Text('Descargar Remito'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remito $receiptNumber',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '¿En qué formato deseas descargarlo?',
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              Navigator.pop(context);
              _downloadReceipt(receiptId, receiptNumber, 'pdf');
            },
            icon: const Icon(LucideIcons.fileText, color: Colors.white, size: 14),
            label: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              Navigator.pop(context);
              _downloadReceipt(receiptId, receiptNumber, 'excel');
            },
            icon: const Icon(LucideIcons.fileSpreadsheet, color: Colors.white, size: 14),
            label: const Text('Excel', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final receiptNumber = receipt['receiptNumber'] ?? 'N/A';
    final teamName = receipt['teamName'] ?? 'Desconocido';
    final userName = receipt['userName'] ?? 'Desconocido';
    final materialsCount = receipt['materialsCount'] ?? 0;
    final dateStr = receipt['date'];

    DateTime? date;
    if (dateStr != null) {
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        // Si falla el parsing, date queda null
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDownloadDialog(receipt['_id'], receiptNumber),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.fileText,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiptNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.download,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.users, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Equipo: $teamName',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(LucideIcons.user, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usuario: $userName',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(LucideIcons.package, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    '$materialsCount materiales transferidos',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Transferencias'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadReceipts,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadReceipts,
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _receipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.inbox,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay remitos de transferencia',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReceipts,
                      child: ListView.builder(
                        itemCount: _receipts.length,
                        itemBuilder: (context, index) {
                          return _buildReceiptCard(_receipts[index]);
                        },
                      ),
                    ),
    );
  }
}
