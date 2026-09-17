import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardSurface,
                  border: Border.all(color: AppTheme.cyanAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyanAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.security,
                  size: 72,
                  color: AppTheme.cyanAccent,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'VoiceShield',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI Voice Impersonation Prevention',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.cyanAccent,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                color: AppTheme.cyanAccent,
                backgroundColor: AppTheme.cardSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
