import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cryptaf/services/auth_service.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/screens/signup_screen.dart';
import 'package:cryptaf/screens/dashboard_screen.dart';
import 'package:cryptaf/screens/setup_wizard_screen.dart';
import 'package:cryptaf/screens/share_screen.dart';
import 'package:cryptaf/screens/two_factor_verification_screen.dart';
import 'package:cryptaf/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/screens/email_verification_screen.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                  const SizedBox(width: 10),
                  const Text('Save Recovery Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
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
      prefixIcon: Icon(icon, color: Colors.white54, size: 22),
    );
  }

  Future<void> _sendLockoutEmail(String userEmail) async {
    try {
      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': 'service_ojzr03j',
          'template_id': 'template_j7plaal',
          'user_id': 'swqxQASivvKsrJjvQ',
          'template_params': {
            'email': userEmail,
            'passcode': 'BRUTE FORCE LOCKOUT ALERT: 5 failed login attempts detected. Your account has been temporarily locked for 30 minutes for security.',
            'time': '30 minutes',
          },
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Failed to send lockout email: $e');
    }
  }

  Future<void> _sendDuressAlertEmail(String userEmail) async {
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}';
      final message = "âš ï¸ DURESS WARNING: A duress login was initiated on your Cryptaf account. The app has displayed a fake empty vault to protect your data. Time: $timeStr.";

      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': 'service_ojzr03j',
          'template_id': 'template_login_alert',
          'user_id': 'swqxQASivvKsrJjvQ',
          'template_params': {
            'email': userEmail,
            'time': timeStr,
            'message': message,
            'passcode': message,
          },
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Failed to send duress alert email: $e');
    }
  }

  Future<void> _sendLoginAlertEmail(String userEmail) async {
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}';
      final message = "New login detected on your Cryptaf account. Time: $timeStr. If this wasn't you, change your password immediately.";

      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': 'service_ojzr03j',
          'template_id': 'template_login_alert',
          'user_id': 'swqxQASivvKsrJjvQ',
          'template_params': {
            'email': userEmail,
            'time': timeStr,
            'message': message,
            'passcode': message,
          },
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Failed to send login alert email: $e');
    }
  }

  Future<void> _sendSuspiciousLoginEmail(String userEmail, String ip, String timeStr) async {
    try {
      final message = "New device or location detected on your Cryptaf account. IP: $ip. Time: $timeStr. If this wasn't you, secure your account immediately.";

      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': 'service_ojzr03j',
          'template_id': 'template_login_alert',
          'user_id': 'swqxQASivvKsrJjvQ',
          'template_params': {
            'email': userEmail,
            'time': timeStr,
            'message': message,
            'passcode': message,
          },
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Failed to send suspicious login email: $e');
    }
  }

  Future<void> _handlePostLogin(String uid, String userEmail, bool twoFactorEnabled, String? encryptedSecret) async {
    String ipAddress = 'Unknown IP';
    try {
      final res = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        ipAddress = jsonDecode(res.body)['ip'] ?? 'Unknown IP';
      }
    } catch (e) {
      debugPrint('Failed to fetch IP: $e');
    }

    final String deviceInfo = kIsWeb ? 'Web Browser (Flutter Web)' : 'Mobile Client';

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userDoc = await userDocRef.get();
    final data = userDoc.data() ?? {};
    final String? lastIp = data['lastIp'] as String?;

    if (lastIp != null && lastIp != ipAddress && lastIp != 'Unknown IP' && ipAddress != 'Unknown IP') {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}';
      _sendSuspiciousLoginEmail(userEmail, ipAddress, timeStr);
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final sessionInfo = {
      'sessionId': sessionId,
      'device': deviceInfo,
      'ip': ipAddress,
      'loginTime': Timestamp.now(),
    };

    await userDocRef.set({
      'lastIp': ipAddress,
      'forceLogoutAll': false,
      'activeSessions': FieldValue.arrayUnion([sessionInfo]),
    }, SetOptions(merge: true));

    final FirestoreService firestore = FirestoreService();
    await firestore.logActivity(type: 'login', details: 'User logged in', ipAddress: ipAddress, deviceInfo: deviceInfo);

    if (twoFactorEnabled && encryptedSecret != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TwoFactorVerificationScreen(encryptedSecret: encryptedSecret),
          ),
        );
      }
    } else {
      NotificationService().sendNotification(
        title: 'Security Alert',
        body: 'ðŸ” New login to your Cryptaf account detected.',
        context: context,
      );
      final setupProgress = await firestore.getOrVerifySetupProgress();
      final completed = setupProgress.values.where((v) => v).length == 5;
      if (mounted) {
        if (completed) {
          final prefs = await SharedPreferences.getInstance();
          final pendingToken = prefs.getString('pending_share_token');
          if (pendingToken != null && pendingToken.isNotEmpty) {
            await prefs.remove('pending_share_token');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ShareScreen(token: pendingToken)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupWizardScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFC9A84C).withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC9A84C).withOpacity(0.3),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat())
                     .rotate(duration: 4.seconds),
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Color(0xFFC9A84C),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cryptaf',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome back to your secure vault',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 40),
                GlassContainer(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Email Address', Icons.email_outlined),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter an email';
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(val)) return 'Enter a valid email';
                            return null;
                          },
                          onChanged: (val) => setState(() => email = val),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Password', Icons.lock_outline),
                          obscureText: true,
                          validator: (val) => val!.length < 6 ? 'Password must be 6+ characters' : null,
                          onChanged: (val) => setState(() => password = val),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordDialog(context),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Color(0xFFC9A84C), fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          text: 'Log In',
                          isLoading: _isLoading,
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _isLoading = true);

                              final sanitizedEmail = email.toLowerCase().trim();
                              DocumentSnapshot<Map<String, dynamic>>? attemptDoc;
                              try {
                                attemptDoc = await FirebaseFirestore.instance.collection('login_attempts').doc(sanitizedEmail).get();

                                if (attemptDoc.exists) {
                                  final data = attemptDoc.data()!;
                                  final int lockedUntil = data['lockedUntil'] ?? 0;
                                  final now = DateTime.now().millisecondsSinceEpoch;
                                  if (now < lockedUntil) {
                                    final int remainingMinutes = ((lockedUntil - now) / 60000).ceil();
                                    setState(() {
                                      error = 'Account locked due to too many failed attempts. Try again in $remainingMinutes minutes.';
                                      _isLoading = false;
                                    });
                                    return;
                                  }
                                }
                              } catch (e) {
                                debugPrint('Brute force check error: $e');
                              }

                              final usersSnap = await FirebaseFirestore.instance
                                  .collection('users')
                                  .where('email', isEqualTo: sanitizedEmail)
                                  .limit(1)
                                  .get();

                              bool isDuressLogin = false;
                              if (usersSnap.docs.isNotEmpty) {
                                final userData = usersSnap.docs.first.data();
                                final String? encryptedDuressPassword = userData['duressPassword'] as String?;
                                if (encryptedDuressPassword != null && encryptedDuressPassword.isNotEmpty) {
                                  final crypto = CryptoService();
                                  try {
                                    final String decryptedDuress = crypto.decryptString(encryptedDuressPassword, crypto.masterAppKey);
                                    if (decryptedDuress == password) {
                                      isDuressLogin = true;
                                    }
                                  } catch (e) {
                                    debugPrint('Duress decrypt failed: $e');
                                  }
                                }
                              }

                              if (isDuressLogin) {
                                final anonResult = await FirebaseAuth.instance.signInAnonymously();
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  _sendDuressAlertEmail(email);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                                  );
                                }
                                return;
                              }

                              dynamic result = await _auth.signInWithEmailAndPassword(email, password);

                              if (mounted) {
                                if (result == null) {
                                  int attempts = 1;
                                  if (attemptDoc != null && attemptDoc.exists) {
                                    attempts = (attemptDoc.data()?['failedAttempts'] ?? 0) + 1;
                                  }
                                  int lockedUntil = 0;
                                  String errMsg = 'Invalid email or password.';

                                  if (attempts >= 5) {
                                    lockedUntil = DateTime.now().millisecondsSinceEpoch + (30 * 60 * 1000);
                                    errMsg = 'Account locked for 30 minutes due to 5 failed login attempts.';
                                    _sendLockoutEmail(email);
                                  } else if (attempts >= 3) {
                                    errMsg = 'Warning: $attempts failed login attempts. Account will lock after 5 fails.';
                                  }

                                  await FirebaseFirestore.instance.collection('login_attempts').doc(sanitizedEmail).set({
                                    'failedAttempts': attempts,
                                    'lockedUntil': lockedUntil,
                                  }, SetOptions(merge: true));

                                  setState(() {
                                    error = errMsg;
                                    _isLoading = false;
                                  });
                                } else {
                                  await FirebaseFirestore.instance.collection('login_attempts').doc(sanitizedEmail).set({
                                    'failedAttempts': 0,
                                    'lockedUntil': 0,
                                  }, SetOptions(merge: true));

                                  setState(() => _isLoading = false);
                                  _sendLoginAlertEmail(email);

                                  final doc = await FirebaseFirestore.instance.collection('users').doc(result.uid).get();
                                  final data = doc.data();
                                  final bool twoFactorEnabled = data?['twoFactorEnabled'] ?? false;
                                  final String? encryptedSecret = data?['totpSecret'] as String?;

                                  await _handlePostLogin(result.uid, email, twoFactorEnabled, encryptedSecret);
                                }
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
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
                            minimumSize: const Size(double.infinity, 50),
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
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14.0),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "New to Cryptaf?",
                      style: TextStyle(color: Colors.white54),
                    ),
                    TextButton(
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your email to receive a password reset link.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
               controller: resetEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Email Address', Icons.email_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (resetEmailController.text.isNotEmpty) {
                try {
                  await _auth.sendPasswordResetEmail(resetEmailController.text);
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset email sent to ${resetEmailController.text}'),
                      backgroundColor: const Color(0xFFC9A84C),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Send Link', style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
