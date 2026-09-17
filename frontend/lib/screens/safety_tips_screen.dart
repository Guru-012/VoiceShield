import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = [
      {
        'title': 'Never share OTP / PIN / Password over calls',
        'desc': 'Banks and government officials will NEVER request your secret OTP or passwords via a phone call.',
        'icon': Icons.lock_outline,
        'color': AppTheme.dangerRed,
      },
      {
        'title': 'Verify urgent money requests via another channel',
        'desc': 'If a friend, relative, or boss asks for emergency funds, hang up and call them directly on their known phone number.',
        'icon': Icons.phone_callback_outlined,
        'color': AppTheme.cyanAccent,
      },
      {
        'title': 'Be suspicious of artificial high-pressure urgency',
        'desc': 'Voice scammers create panic ("Account blocked in 10 mins", "Arrest warrant") to force quick rash decisions.',
        'icon': Icons.timer_outlined,
        'color': AppTheme.warningAmber,
      },
      {
        'title': 'Check for robotic or unnatural audio glitches',
        'desc': 'Listen for background room noise mismatches, sudden metallic pitch changes, or strange pauses in cloned voices.',
        'icon': Icons.graphic_eq,
        'color': AppTheme.safeGreen,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cyber Safety Tips'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final tip = tips[index];
          final color = tip['color'] as Color;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tip['icon'] as IconData, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tip['desc'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
