import 'package:flutter/material.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/screens/vault_view_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  OtpScreenState createState() => OtpScreenState();
}

class OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final FirestoreService _firestore = FirestoreService();
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    bool success = await _firestore.verifyNomineeOTP(widget.email, otp);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AccessGrantedScreen(),
          ),
        );
      }
    } else {
      setState(() {
        _error = 'Invalid or expired OTP. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('OTP Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 80, color: Color(0xFFC9A84C)),
                const SizedBox(height: 30),
                const Text(
                  'Verification Code',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a 6-digit code to ${widget.email}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                GlassContainer(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) => _buildOtpBox(index)),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                      ],
                      const SizedBox(height: 36),
                      GradientButton(
                        text: 'Verify & Access Vault',
                        isLoading: _isLoading,
                        onPressed: _verifyOtp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white12),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFC9A84C)),
            borderRadius: BorderRadius.circular(8),
          ),
          fillColor: Colors.white.withOpacity(0.05),
          filled: true,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_controllers.every((c) => c.text.isNotEmpty)) {
            _verifyOtp();
          }
        },
      ),
    );
  }
}

class AccessGrantedScreen extends StatelessWidget {
  const AccessGrantedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Access Granted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: const AnimatedBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(24.0),
              child: GlassContainer(
                child: Column(
                  children: [
                    Icon(Icons.lock_open, color: Color(0xFFC9A84C), size: 60),
                    SizedBox(height: 16),
                    Text(
                      'Vault Unlocked',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You now have emergency access to all secure files.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: VaultViewScreen(),
            ),
          ],
        ),
      ),
    );
  }
}
