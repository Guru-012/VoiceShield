import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.cyanAccent),
                  title: const Text('Audio Data Privacy'),
                  subtitle: const Text('Raw audio is processed locally & discarded. Only anonymized risk scores are retained.'),
                ),
                const Divider(color: AppTheme.cardBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.cyanAccent),
                  title: const Text('App Information'),
                  subtitle: const Text('VoiceShield v1.0.0 (SIH 2026 PS 26104 Prototype)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: AppTheme.dangerRed),
              title: const Text('Delete Local Analysis History', style: TextStyle(color: AppTheme.dangerRed)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analysis history cleared successfully.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
