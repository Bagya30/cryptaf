import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptaf/main.dart'; // For AuthenticationWrapper
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  Future<void> _enableBiometric() async {
    setState(() => _isAuthenticating = true);
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() => _isAuthenticating = false);
        _showError('Biometric login is available on Android app only');
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint or face to enable biometric security',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_setup_done', true);
        await prefs.setBool('biometric_enabled', true);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AuthenticationWrapper()),
          );
        }
      } else {
        setState(() => _isAuthenticating = false);
        _showError('Biometric authentication failed or was canceled.');
      }
    } on PlatformException catch (e) {
      setState(() => _isAuthenticating = false);
      _showError('Biometric not available on this device');
    } catch (e) {
      setState(() => _isAuthenticating = false);
      _showError('An unexpected error occurred: $e');
    }
  }

  Future<void> _skipBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_setup_done', true);
    await prefs.setBool('biometric_enabled', false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthenticationWrapper()),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC9A84C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                // Large fingerprint icon in a glowing circle (gold color)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(color: _gold.withOpacity(0.5), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fingerprint,
                      size: 64,
                      color: _gold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'Enable Biometric Security',
                  style: GoogleFonts.oxanium(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'Secure your digital vault with fingerprint or face recognition',
                  style: GoogleFonts.oxanium(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Feature Card 1
                _buildFeatureCard(
                  icon: Icons.bolt,
                  title: 'Instant Access',
                  subtitle: 'Unlock vault in 0.5 seconds',
                ),
                const SizedBox(height: 16),
                // Feature Card 2
                _buildFeatureCard(
                  icon: Icons.shield_outlined,
                  title: 'AES-256 Protection',
                  subtitle: 'Your biometric data never leaves this device',
                ),
                const Spacer(),
                // Enable Now Button
                GradientButton(
                  text: 'Enable Now',
                  isLoading: _isAuthenticating,
                  onPressed: _enableBiometric,
                ),
                const SizedBox(height: 16),
                // Skip for Now Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isAuthenticating ? null : _skipBiometric,
                    child: Text(
                      'Skip for Now',
                      style: GoogleFonts.oxanium(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Bottom text
                Text(
                  'Cryptaf cannot access your biometric data',
                  style: GoogleFonts.oxanium(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String subtitle}) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: _gold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.oxanium(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.oxanium(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
