import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/crypto_service.dart';
import '../widgets/animated_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class PinLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const PinLockScreen({super.key, this.onUnlocked});

  @override
  PinLockScreenState createState() => PinLockScreenState();
}

class PinLockScreenState extends State<PinLockScreen> {
  String enteredPin = '';
  bool hasError = false;
  bool isChecking = false;
  String? savedPin;
  bool hasCustomPin = false;

  int failedAttempts = 0;
  DateTime? lockoutEndTime;
  Timer? lockoutTimer;
  String lockoutTimerText = '';

  @override
  void initState() {
    super.initState();
    _loadSavedPin();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTimeMs = prefs.getInt('pin_lockout_time');
    if (lockoutTimeMs != null) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimeMs);
      if (endTime.isAfter(DateTime.now())) {
        setState(() {
          lockoutEndTime = endTime;
        });
        _startLockoutCountdown();
      } else {
        await prefs.remove('pin_lockout_time');
      }
    }
  }

  void _startLockoutCountdown() {
    lockoutTimer?.cancel();
    _updateLockoutTimerText();
    lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (lockoutEndTime == null) {
        timer.cancel();
        return;
      }
      final remaining = lockoutEndTime!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pin_lockout_time');
        setState(() {
          lockoutEndTime = null;
          failedAttempts = 0;
          lockoutTimerText = '';
        });
      } else {
        _updateLockoutTimerText();
      }
    });
  }

  void _updateLockoutTimerText() {
    if (lockoutEndTime == null) return;
    final remaining = lockoutEndTime!.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    setState(() {
      lockoutTimerText = "Too many attempts. Try again in ${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _loadSavedPin() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data()?.containsKey('vaultPin') == true) {
          final encPin = doc.data()!['vaultPin'];
          if (encPin != null && encPin.toString().isNotEmpty) {
            savedPin = CryptoService().decryptString(encPin, CryptoService().masterAppKey);
            hasCustomPin = true;
          }
        }
      }
      if (savedPin == null || savedPin!.isEmpty) {
        savedPin = '';
        hasCustomPin = false;
      }
      if (mounted) {
        setState(() {});
        if (!hasCustomPin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No PIN set. Please set a PIN in Security Settings.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      savedPin = '';
      hasCustomPin = false;
      if (mounted) {
        setState(() {});
        if (!hasCustomPin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No PIN set. Please set a PIN in Security Settings.')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _verifyPin() async {
    if (enteredPin.length != 4 || isChecking || lockoutEndTime != null || !hasCustomPin) return;
    setState(() {
      isChecking = true;
      hasError = false;
    });

    await Future.delayed(const Duration(milliseconds: 300)); // slight delay for smooth UX

    if (enteredPin == savedPin) {
      if (mounted) {
        setState(() {
          failedAttempts = 0;
        });
        widget.onUnlocked?.call();
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        final newAttempts = failedAttempts + 1;
        setState(() {
          failedAttempts = newAttempts;
          hasError = true;
          enteredPin = '';
          isChecking = false;
        });

        if (newAttempts >= 3) {
          final endTime = DateTime.now().add(const Duration(minutes: 5));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('pin_lockout_time', endTime.millisecondsSinceEpoch);
          setState(() {
            lockoutEndTime = endTime;
          });
          _startLockoutCountdown();
        }
      }
    }
  }

  void _onDigitTap(String digit) {
    if (lockoutEndTime != null || !hasCustomPin) return;
    if (enteredPin.length < 4 && !isChecking) {
      setState(() {
        enteredPin += digit;
        hasError = false;
      });
      if (enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspaceTap() {
    if (lockoutEndTime != null || !hasCustomPin) return;
    if (enteredPin.isNotEmpty && !isChecking) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
        hasError = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent dismissing with back button
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: AnimatedBackground(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.lock_outline, size: 64, color: Color(0xFFC9A84C)),
                const SizedBox(height: 16),
                const Text(
                  'Enter your vault PIN',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  hasCustomPin ? 'Enter your 4-digit security PIN' : 'No PIN set. Please set a PIN in Security Settings.',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 48),

                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isEntered = index < enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEntered ? const Color(0xFFC9A84C) : Colors.white.withOpacity(0.1),
                        border: Border.all(color: isEntered ? const Color(0xFFC9A84C) : Colors.white24, width: 2),
                        boxShadow: isEntered ? [const BoxShadow(color: Color(0xFFC9A84C), blurRadius: 10)] : null,
                      ),
                    );
                  }),
                ).animate(target: hasError ? 1 : 0).shake(duration: 400.ms, hz: 6),

                if (lockoutEndTime != null) ...[
                  const SizedBox(height: 16),
                  Text(lockoutTimerText, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                ] else if (hasError) ...[
                  const SizedBox(height: 16),
                  const Text('Incorrect PIN. Please try again.', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ] else ...[
                  const SizedBox(height: 29),
                ],

                const Spacer(),

                // Number Pad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      _buildNumberRow(['1', '2', '3']),
                      const SizedBox(height: 16),
                      _buildNumberRow(['4', '5', '6']),
                      const SizedBox(height: 16),
                      _buildNumberRow(['7', '8', '9']),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 75),
                          _buildNumberButton('0'),
                          _buildPadButton(
                            child: const Icon(Icons.backspace_outlined, color: Colors.white54, size: 24),
                            onTap: _onBackspaceTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberButton(d)).toList(),
    );
  }

  Widget _buildNumberButton(String digit) {
    return _buildPadButton(
      child: Text(digit, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      onTap: () => _onDigitTap(digit),
    );
  }

  Widget _buildPadButton({required Widget child, required VoidCallback onTap}) {
    final isDisabled = lockoutEndTime != null;
    return Container(
      width: 75,
      height: 75,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: isDisabled ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.05),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          splashColor: const Color(0xFFC9A84C).withOpacity(0.3),
          highlightColor: const Color(0xFFC9A84C).withOpacity(0.1),
          child: Opacity(
            opacity: isDisabled ? 0.3 : 1.0,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
