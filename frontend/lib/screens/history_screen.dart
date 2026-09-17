import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _historyItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final items = await _apiService.getHistory();
    if (mounted) {
      setState(() {
        _historyItems = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyanAccent))
          : _historyItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No past voice analyses recorded yet.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historyItems.length,
                  itemBuilder: (context, index) {
                    final item = _historyItems[index];
                    final isHigh = item['risk_level'] == 'HIGH';
                    final isMed = item['risk_level'] == 'MEDIUM';
                    final color = isHigh
                        ? AppTheme.dangerRed
                        : (isMed ? AppTheme.warningAmber : AppTheme.safeGreen);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.2),
                          child: Icon(
                            isHigh ? Icons.warning : Icons.shield,
                            color: color,
                          ),
                        ),
                        title: Text(
                          item['filename'] ?? 'Audio File',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: ${item['timestamp']?.toString().substring(0, 10) ?? 'N/A'} • Risk: ${item['risk_score']}/100',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color, width: 1),
                          ),
                          child: Text(
                            item['voice_result'] ?? '',
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
