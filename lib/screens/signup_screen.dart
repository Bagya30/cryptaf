import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/auth_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/screens/terms_screen.dart';
import 'package:cryptaf/screens/privacy_policy_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/screens/email_verification_screen.dart';
import 'package:cryptaf/screens/dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            error = 'Google Sign-In canceled or failed.';
          });
        }
        return;
      }

      // Check if user document already exists in Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // First time Google Signup: generate recovery key
        final crypto = CryptoService();
        final recoveryKey = crypto.generate24WordRecoveryKey();
        final encryptedRecoveryKey = crypto.encryptString(recoveryKey, crypto.masterAppKey);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'twoFactorEnabled': false,
          'biometricsEnabled': false,
          'recoveryKey': encryptedRecoveryKey,
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() => _isLoading = false);
          // Show recovery key dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF0A0A0A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                  SizedBox(width: 10),
                  Text('Save Recovery Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IMPORTANT: Write down these 24 words and store them in a secure offline location. This is your ONLY way to recover your account if you lose your master password.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A84C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3)),
                    ),
                    child: SelectableText(
                      recoveryKey,
                      style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5, height: 1.5),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    _navigateAfterGoogleSignIn(user);
                  },
                  child: const Text('I Have Saved It Securely', style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _navigateAfterGoogleSignIn(user);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          error = 'Google Sign-In error: $e';
        });
      }
    }
  }

  void _navigateAfterGoogleSignIn(User user) {
    if (user.emailVerified) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: user.email ?? '')),
        (route) => false,
      );
    }
  }

  int _passwordStrength() {
    if (password.length >= 8 &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#$&*~]'))) {
      return 2;
    }
    if (password.length >= 6 && password.contains(RegExp(r'[0-9]'))) {
      return 1;
    }
    return 0;
  }

  Widget _buildStrengthBar() {
    if (password.isEmpty) return const SizedBox.shrink();
    final strength = _passwordStrength();
    final labels = ['Weak', 'Medium', 'Strong'];
    final colors = [Colors.redAccent, Colors.orangeAccent, const Color(0xFFC9A84C)];
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: (strength + 1) / 3,
              backgroundColor: Colors.white12,
              color: colors[strength],
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text(labels[strength], style: TextStyle(color: colors[strength], fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC9A84C), width: 1.5),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFFC9A84C), size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 64,
                      color: Color(0xFFC9A84C),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oxanium(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join Cryptaf secure digital vault',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oxanium(fontSize: 15, color: Colors.white54),
                    ),
                    const SizedBox(height: 36),
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Email Address', Icons.email_outlined),
                            validator: (val) => val!.isEmpty ? 'Enter email' : null,
                            onChanged: (val) => setState(() => email = val),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Password', Icons.lock_outline),
                            validator: (val) => val!.length < 6 ? 'Min 6 characters' : null,
                            onChanged: (val) => setState(() => password = val),
                          ),
                          _buildStrengthBar(),
                          const SizedBox(height: 28),
                          GradientButton(
                            text: 'Create Account',
                            isLoading: _isLoading,
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _isLoading = true);
                                dynamic result = await _auth.registerWithEmailAndPassword(email, password);
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  if (result == null) {
                                    setState(() => error = 'Could not sign up with those credentials.');
                                  } else {
                                    final crypto = CryptoService();
                                    final recoveryKey = crypto.generate24WordRecoveryKey();
                                    final encryptedRecoveryKey = crypto.encryptString(recoveryKey, crypto.masterAppKey);

                                    await FirebaseFirestore.instance.collection('users').doc(result.uid).set({
                                      'email': email,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'twoFactorEnabled': false,
                                      'biometricsEnabled': false,
                                      'recoveryKey': encryptedRecoveryKey,
                                    }, SetOptions(merge: true));

                                    if (mounted) {
                                      showDialog(
                                        // ignore: use_build_context_synchronously
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(0xFF0A0A0A),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                                          title: const Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                                              SizedBox(width: 10),
                                              Text('Save Recovery Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                            ],
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'IMPORTANT: Write down these 24 words and store them in a secure offline location. This is your ONLY way to recover your account if you lose your master password.',
                                                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                              ),
                                              const SizedBox(height: 20),
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFC9A84C).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3)),
                                                ),
                                                child: SelectableText(
                                                  recoveryKey,
                                                  style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5, height: 1.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context); // Pop dialog
                                                final user = FirebaseAuth.instance.currentUser;
                                                if (user != null) {
                                                  try {
                                                    await user.sendEmailVerification();
                                                  } catch (e) {
                                                    debugPrint('Error sending verification email: $e');
                                                  }
                                                  if (mounted) {
                                                    Navigator.pushReplacement(
                                                      // ignore: use_build_context_synchronously
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => EmailVerificationScreen(email: user.email ?? ''),
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  if (mounted) Navigator.pop(context);
                                                }
                                              },
                                              child: const Text('I Have Saved It Securely', style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white12)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('OR', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(child: Divider(color: Colors.white12)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                              height: 20,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white),
                            ),
                            label: Text('Continue with Google', style: GoogleFonts.oxanium(fontWeight: FontWeight.bold)),
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                          ),
                        ],
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                    ],
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text('By creating an account you agree to our ', style: GoogleFonts.oxanium(color: Colors.white54, fontSize: 12)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                            child: Text('Terms of Service', style: GoogleFonts.oxanium(color: const Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                          Text(' and ', style: GoogleFonts.oxanium(color: Colors.white54, fontSize: 12)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                            child: Text('Privacy Policy', style: GoogleFonts.oxanium(color: const Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Already have an account? Log In',
                          style: GoogleFonts.oxanium(color: const Color(0xFFC9A84C), fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
