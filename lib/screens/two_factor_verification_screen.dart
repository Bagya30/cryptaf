import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/screens/login_screen.dart';
import 'package:cryptaf/screens/dashboard_screen.dart';
import 'package:cryptaf/screens/setup_wizard_screen.dart';
import 'package:cryptaf/services/totp_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/notification_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class TwoFactorVerificationScreen extends StatefulWidget {
  final String encryptedSecret;

  const TwoFactorVerificationScreen({super.key, required this.encryptedSecret});

  @override
  TwoFactorVerificationScreenState createState() => TwoFactorVerificationScreenState();
}

class TwoFactorVerificationScreenState extends State<TwoFactorVerificationScreen> {
  final TOTPService _totp = TOTPService();
  final CryptoService _crypto = CryptoService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  void _verifyCode() async {
    if (_codeController.text.length != 6) {
      setState(() => _error = 'Enter a 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Decrypt secret
    final secret = _crypto.decryptString(widget.encryptedSecret, _crypto.masterAppKey);
    final isValid = _totp.verifyTOTP(secret, _codeController.text);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (isValid) {
      final FirestoreService firestore = FirestoreService();
      await firestore.logActivity(type: 'login_2fa', details: 'User logged in with 2FA');
      if (!mounted) return;
      NotificationService().sendNotification(
        title: 'Security Alert',
        body: '🔐 New login to your Cryptaf account detected.',
        context: context,
      );
      final setupProgress = await firestore.getOrVerifySetupProgress();
      final completed = setupProgress.values.where((v) => v).length == 5;
      if (mounted) {
        if (completed) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupWizardScreen()),
          );
        }
      }
    } else {
      setState(() => _error = 'Invalid authenticator code. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ),
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.2), blurRadius: 24),
                    ],
                  ),
                  child: const Icon(Icons.security, size: 64, color: Color(0xFFC9A84C)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Two-Factor Authentication',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your authenticator code',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 36),
                GlassContainer(
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                      ],
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'Verify & Proceed',
                        isLoading: _isLoading,
                        onPressed: _verifyCode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
