import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _verificationTimer;

  static const _gold = Color(0xFFC9A84C);

  @override
  void initState() {
    super.initState();
    // Periodically check if email is verified
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          timer.cancel();
          if (mounted) {
            // Force recreation of authStateChanges stream or navigate to main app layout
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 30;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldownSeconds > 0 || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        _startCooldown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email resent successfully!'), backgroundColor: Colors.greenAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send verification email: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 80,
                    color: _gold,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Your Email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oxanium(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please verify your email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oxanium(fontSize: 16, color: _gold, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to ${widget.email}. Check your inbox and click the link.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oxanium(fontSize: 14, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 36),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _gold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Waiting for verification...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.oxanium(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 28),
                        GradientButton(
                          text: _cooldownSeconds > 0
                              ? 'Resend Email ($_cooldownSeconds s)'
                              : 'Resend Email',
                          isLoading: _isSending,
                          onPressed: _cooldownSeconds > 0 ? null : _resendVerificationEmail,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white54, size: 16),
                      label: Text(
                        'Sign Out / Back to Login',
                        style: GoogleFonts.oxanium(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
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
