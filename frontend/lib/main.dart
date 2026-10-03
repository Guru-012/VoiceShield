import 'package:flutter/material.dart';
import 'package:frontend/screens/splash_screen.dart';
import 'package:frontend/screens/real_call_screen.dart';

import 'theme/app_theme.dart';

void main() {
  runApp(const VoiceShieldApp());
}

class VoiceShieldApp extends StatelessWidget {
  const VoiceShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceShield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}