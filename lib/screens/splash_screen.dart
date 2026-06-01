import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cryptaf/main.dart'; // To access AuthenticationWrapper

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptaf/screens/biometric_screen.dart';
import 'package:cryptaf/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // 5 second fallback timeout
    Timer(const Duration(seconds: 5), () async {
      if (mounted && !_navigated) {
        _navigated = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          final onboardingDone = prefs.getBool('onboarding_done') ?? false;
          if (!onboardingDone && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
            return;
          }
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AuthenticationWrapper()),
          );
        }
      }
    });

    Timer(const Duration(seconds: 3), () async {
      if (!mounted || _navigated) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted || _navigated) return;
        final onboardingDone = prefs.getBool('onboarding_done') ?? false;
        final setupDone = prefs.getBool('biometric_setup_done') ?? false;

        if (mounted && !_navigated) {
          _navigated = true;
          if (!onboardingDone) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          } else if (!kIsWeb && !setupDone) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const BiometricScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => AuthenticationWrapper()),
            );
          }
        }
      } catch (e) {
        if (mounted && !_navigated) {
          _navigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AuthenticationWrapper()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .shimmer(duration: 1500.ms, color: const Color(0xFFC9A84C).withOpacity(0.5))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.05, 1.05),
                  duration: 1500.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 30),
            // App Name
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: 'Cryptaf'.length),
              duration: const Duration(milliseconds: 1000),
              builder: (context, value, child) {
                return Text(
                  'Cryptaf'.substring(0, value),
                  style: GoogleFonts.oxanium(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Tagline
            Text(
              'Zero Knowledge Vault',
              style: GoogleFonts.oxanium(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC9A84C),
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}
