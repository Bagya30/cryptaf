import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/screens/login_screen.dart';

class InactivityTimerService {
  Timer? _inactivityTimer;
  Timer? _countdownTimer;
  BuildContext? _context;
  bool _isWarningOpen = false;

  void start(BuildContext context) {
    _context = context;
    reset();
  }

  void reset() {
    if (_isWarningOpen) return;

    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();

    // 4 minutes = 240 seconds
    _inactivityTimer = Timer(const Duration(minutes: 4), _showWarningDialog);
  }

  void _showWarningDialog() {
    if (_context == null || !(_context!.mounted)) return;

    _isWarningOpen = true;
    int remainingSeconds = 60;

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (remainingSeconds > 1) {
                setDialogState(() {
                  remainingSeconds--;
                });
              } else {
                timer.cancel();
                _logout(dialogContext);
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF0A0A0A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white12),
              ),
              title: Row(
                children: const [
                  Icon(Icons.timer_outlined, color: Color(0xFFC9A84C), size: 28),
                  SizedBox(width: 12),
                  Text('Inactivity Warning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You will be logged out in 60 seconds due to inactivity.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$remainingSeconds s',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tap stay logged in to continue your secure session.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFFC9A84C).withOpacity(0.5)),
                      ),
                    ),
                    onPressed: () {
                      _countdownTimer?.cancel();
                      _countdownTimer = null;
                      _isWarningOpen = false;
                      Navigator.pop(dialogContext);
                      reset();
                    },
                    child: const Text('Stay Logged In', style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout(BuildContext dialogContext) async {
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    _isWarningOpen = false;

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext); // Close dialog
    }

    await FirebaseAuth.instance.signOut();

    if (_context != null && _context!.mounted) {
      Navigator.pushReplacement(
        _context!,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void dispose() {
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
  }
}
