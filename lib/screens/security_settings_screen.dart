import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/totp_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:cryptaf/services/cloudinary_service.dart';
import 'package:intl/intl.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  _SecuritySettingsScreenState createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final TOTPService _totp = TOTPService();
  final CryptoService _crypto = CryptoService();

  bool twoFactorEnabled = false;
  bool biometricsEnabled = false;

  late AnimationController _gearController;

  @override
  void initState() {
    super.initState();
    _loadBiometricPref();
    _gearController = AnimationController(vsync: this, duration: const Duration(milliseconds: 8000))..repeat();
  }

  @override
  void dispose() {
    _gearController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricPref() async {
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
        });
      }
    }
  }

  void _show2FASetupDialog(BuildContext context, bool currentBiometrics) {
    final secret = _totp.generateTOTPSecret();
    final email = FirebaseAuth.instance.currentUser?.email ?? 'user@cryptaf.com';
    final qrData = _totp.generateQRCodeData(secret, email);
    final TextEditingController codeController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Setup 2FA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan this QR code with Google Authenticator or any TOTP app.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 180,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Secret: $secret',
                  style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter 6-digit code to confirm',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 4),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  text: 'Verify & Enable',
                  isLoading: isVerifying,
                  onPressed: () async {
                    if (codeController.text.length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a 6-digit code'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }

                    setDialogState(() {
                      isVerifying = true;
                    });

                    await Future.delayed(const Duration(milliseconds: 500));

                    final isValid = _totp.verifyTOTP(secret, codeController.text);

                    if (isValid) {
                      final encryptedSecret = _crypto.encryptString(secret, _crypto.masterAppKey);
                      await _firestore.updateSecuritySettings(true, currentBiometrics, totpSecret: encryptedSecret);
                      if (mounted) {
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('2FA Enabled successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    } else {
                      setDialogState(() {
                        isVerifying = false;
                      });
                      if (mounted) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid code. Please try again.'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetPinDialog(BuildContext context) {
    final TextEditingController pinController = TextEditingController();
    String errorMsg = '';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Set Vault PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter a 4-digit PIN to lock your vault during inactivity.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  counterText: '',
                ),
              ),
              if (errorMsg.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              GradientButton(
                text: 'Save PIN',
                isLoading: isSaving,
                onPressed: () async {
                  if (pinController.text.length != 4 || int.tryParse(pinController.text) == null) {
                    setDialogState(() => errorMsg = 'Please enter a valid 4-digit PIN');
                    return;
                  }

                  setDialogState(() {
                    isSaving = true;
                    errorMsg = '';
                  });

                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final encPin = _crypto.encryptString(pinController.text, _crypto.masterAppKey);
                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'vaultPin': encPin,
                      }, SetOptions(merge: true));

                      if (mounted) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vault PIN set successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    }
                  } catch (e) {
                    setDialogState(() {
                      errorMsg = 'Failed to save PIN: $e';
                      isSaving = false;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetDuressPasswordDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();
    bool isSaving = false;
    String errorMsg = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Set Duress Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter a secondary login password. If entered at the login screen, Cryptaf will load a completely empty fake vault and silently email a security alert to protect you.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Duress Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm Duress Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (errorMsg.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              GradientButton(
                text: 'Save Duress Password',
                isLoading: isSaving,
                onPressed: () async {
                  if (passwordController.text.length < 6) {
                    setDialogState(() => errorMsg = 'Password must be at least 6 characters');
                    return;
                  }
                  if (passwordController.text != confirmController.text) {
                    setDialogState(() => errorMsg = 'Passwords do not match');
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final encDuress = _crypto.encryptString(passwordController.text, _crypto.masterAppKey);
                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'duressPassword': encDuress,
                      }, SetOptions(merge: true));

                      if (mounted) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Duress password set successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    }
                  } catch (e) {
                    setDialogState(() {
                      isSaving = false;
                      errorMsg = 'Failed to save duress password: $e';
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGoogleOrPasskey = user?.providerData.any((p) => p.providerId != 'password') ?? false;

    if (isGoogleOrPasskey) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
          title: const Text('Change Master Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Password change not available for Google accounts. Please use Google account settings.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
      return;
    }

    final TextEditingController currentPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isUpdating = false;
    String errorMsg = '';
    double strength = 0.0;
    Color strengthColor = Colors.redAccent;

    void calculateStrength(String pass) {
      double s = 0.0;
      if (pass.length >= 8) s += 0.25;
      if (pass.contains(RegExp(r'[A-Z]'))) s += 0.25;
      if (pass.contains(RegExp(r'[0-9]'))) s += 0.25;
      if (pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) s += 0.25;

      Color c = Colors.redAccent;
      if (s == 0.5) c = Colors.orangeAccent;
      if (s == 0.75) c = Colors.yellowAccent;
      if (s == 1.0) c = Colors.greenAccent;

      strength = s;
      strengthColor = c;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Change Master Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: currentPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter current password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('New Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    setDialogState(() {
                      calculateStrength(val);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text('Password Strength: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: strength,
                        backgroundColor: Colors.white12,
                        color: strengthColor,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Confirm New Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),

                if (errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 24),

                GradientButton(
                  text: 'Update Password',
                  isLoading: isUpdating,
                  onPressed: () async {
                    if (currentPassController.text.isEmpty || newPassController.text.isEmpty || confirmPassController.text.isEmpty) {
                      setDialogState(() => errorMsg = 'Please fill in all fields');
                      return;
                    }
                    if (newPassController.text != confirmPassController.text) {
                      setDialogState(() => errorMsg = 'New passwords do not match');
                      return;
                    }
                    if (strength < 0.5) {
                      setDialogState(() => errorMsg = 'Please choose a stronger password');
                      return;
                    }

                    setDialogState(() {
                      isUpdating = true;
                      errorMsg = '';
                    });

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null || user.email == null) {
                        throw Exception('No authenticated user found');
                      }

                      // Reauthenticate
                      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassController.text);
                      await user.reauthenticateWithCredential(cred);

                      // Update password
                      await user.updatePassword(newPassController.text);

                      if (mounted) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Master password updated successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        isUpdating = false;
                        errorMsg = 'Failed to update password: ${e.toString().split(']').last.trim()}';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeVaultPasswordDialog(BuildContext context) {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    bool isReencrypting = false;
    String statusMsg = '';
    String errorMsg = '';
    int totalFiles = 0;
    int processedFiles = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Change Vault Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will decrypt and re-encrypt ALL your stored vault files using your new password. Please do not close the app during this process.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Text('Old Vault Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: oldPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter old vault password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('New Vault Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter new vault password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (isReencrypting) ...[
                  const SizedBox(height: 24),
                  Text(statusMsg, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: totalFiles > 0 ? processedFiles / totalFiles : null,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFC9A84C),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Text('$processedFiles of $totalFiles files processed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
                if (errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Start Re-encryption',
                  isLoading: isReencrypting,
                  onPressed: () async {
                    if (oldPassController.text.isEmpty || newPassController.text.isEmpty) {
                      setDialogState(() => errorMsg = 'Please fill in both fields');
                      return;
                    }

                    setDialogState(() {
                      isReencrypting = true;
                      errorMsg = '';
                      statusMsg = 'Fetching files list...';
                    });

                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) throw Exception('No authenticated user');

                      final filesSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('files').get();
                      final docs = filesSnapshot.docs;

                      setDialogState(() {
                        totalFiles = docs.length;
                        processedFiles = 0;
                        statusMsg = totalFiles == 0 ? 'No files to re-encrypt.' : 'Starting re-encryption...';
                      });

                      final CloudinaryService cloudinary = CloudinaryService();

                      for (var doc in docs) {
                        final data = doc.data();
                        final String name = data['name'] ?? 'file';
                        final bool encrypted = data['encrypted'] ?? true;
                        final String? downloadUrl = data['downloadUrl'] as String?;
                        final String? salt = data['salt'] as String?;
                        final String? iv = data['iv'] as String?;

                        if (encrypted && downloadUrl != null && salt != null) {
                          setDialogState(() {
                            statusMsg = 'Downloading $name...';
                          });

                          final res = await http.get(Uri.parse(downloadUrl));
                          if (res.statusCode != 200) throw Exception('Failed to download $name');

                          setDialogState(() {
                            statusMsg = 'Re-encrypting $name...';
                          });

                          final oldKey = _crypto.deriveKey(oldPassController.text, salt);
                          Uint8List decryptedBytes;
                          try {
                            decryptedBytes = _crypto.decryptFile(res.bodyBytes, oldKey, ivBase64: iv);
                          } catch (_) {
                            throw Exception('Incorrect old password for file: $name');
                          }

                          final newSalt = _crypto.generateSalt();
                          final newKey = _crypto.deriveKey(newPassController.text, newSalt);
                          final encResult = _crypto.encryptFile(decryptedBytes, newKey, ivBase64: null);

                          setDialogState(() {
                            statusMsg = 'Uploading re-encrypted $name...';
                          });

                          final newUrl = await cloudinary.uploadFile(name, encResult.encryptedBytes);
                          if (newUrl == null) throw Exception('Failed to upload re-encrypted $name');

                          await doc.reference.update({
                            'downloadUrl': newUrl,
                            'salt': newSalt,
                            'iv': encResult.iv,
                            'sizeBytes': encResult.encryptedBytes.length,
                          });
                        }

                        setDialogState(() {
                          processedFiles++;
                        });
                      }

                      // Save encrypted vault password with recovery key
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                      final recoveryKeyEnc = userDoc.data()?['recoveryKey'] as String?;
                      if (recoveryKeyEnc != null && recoveryKeyEnc.isNotEmpty) {
                        final recoveryKey = _crypto.decryptString(recoveryKeyEnc, _crypto.masterAppKey);
                        final encVal = _crypto.encryptString(newPassController.text, recoveryKey);
                        await userDoc.reference.update({
                          'vaultPasswordEncrypted': encVal,
                        });
                      }

                      if (mounted) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All vault files re-encrypted successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        isReencrypting = false;
                        errorMsg = 'Re-encryption error: ${e.toString().replaceAll('Exception: ', '')}';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (!isReencrypting)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
          ],
        ),
      ),
    );
  }

  void _showForgotVaultPasswordDialog(BuildContext context) {
    final TextEditingController recoveryKeyController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    bool isReencrypting = false;
    String statusMsg = '';
    String errorMsg = '';
    int totalFiles = 0;
    int processedFiles = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Forgot Vault Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your 24-word recovery key to reset your vault password and re-encrypt your stored files.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Text('24-Word Recovery Key', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: recoveryKeyController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter 24 words separated by spaces',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('New Vault Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter new vault password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (isReencrypting) ...[
                  const SizedBox(height: 24),
                  Text(statusMsg, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: totalFiles > 0 ? processedFiles / totalFiles : null,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFC9A84C),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Text('$processedFiles of $totalFiles files processed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
                if (errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Reset & Re-encrypt',
                  isLoading: isReencrypting,
                  onPressed: () async {
                    final cleanKey = recoveryKeyController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                    if (cleanKey.isEmpty || newPassController.text.isEmpty) {
                      setDialogState(() => errorMsg = 'Please fill in both fields');
                      return;
                    }
                    if (cleanKey.split(' ').length != 24) {
                      setDialogState(() => errorMsg = 'Recovery key must be exactly 24 words');
                      return;
                    }

                    setDialogState(() {
                      isReencrypting = true;
                      errorMsg = '';
                      statusMsg = 'Verifying recovery key...';
                    });

                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) throw Exception('No authenticated user');

                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                      final storedKeyEnc = userDoc.data()?['recoveryKey'] as String?;
                      if (storedKeyEnc == null || storedKeyEnc.isEmpty) {
                        throw Exception('No recovery key set for this account.');
                      }

                      final decStoredKey = _crypto.decryptString(storedKeyEnc, _crypto.masterAppKey).trim().toLowerCase();
                      if (cleanKey != decStoredKey) {
                        throw Exception('Invalid recovery key. Please check your backup phrase.');
                      }

                      // Try to decrypt vault password
                      final vaultPassEnc = userDoc.data()?['vaultPasswordEncrypted'] as String?;
                      String? oldVaultPassword;
                      if (vaultPassEnc != null && vaultPassEnc.isNotEmpty) {
                        try {
                          oldVaultPassword = _crypto.decryptString(vaultPassEnc, decStoredKey);
                        } catch (_) {
                          // Ignore
                        }
                      }

                      final filesSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('files').get();
                      final docs = filesSnapshot.docs;

                      setDialogState(() {
                        totalFiles = docs.length;
                        processedFiles = 0;
                        statusMsg = totalFiles == 0 ? 'Resetting password...' : 'Decrypting and re-encrypting vault...';
                      });

                      final CloudinaryService cloudinary = CloudinaryService();

                      for (var doc in docs) {
                        final data = doc.data();
                        final String name = data['name'] ?? 'file';
                        final bool encrypted = data['encrypted'] ?? true;
                        final String? downloadUrl = data['downloadUrl'] as String?;
                        final String? salt = data['salt'] as String?;
                        final String? iv = data['iv'] as String?;

                        if (encrypted && downloadUrl != null && salt != null) {
                          setDialogState(() {
                            statusMsg = 'Processing $name...';
                          });

                          // Download encrypted file
                          final res = await http.get(Uri.parse(downloadUrl));
                          if (res.statusCode == 200) {
                            Uint8List? decryptedBytes;
                            // Attempt to decrypt using recovered old vault password
                            if (oldVaultPassword != null) {
                              try {
                                final oldKey = _crypto.deriveKey(oldVaultPassword, salt);
                                decryptedBytes = _crypto.decryptFile(res.bodyBytes, oldKey, ivBase64: iv);
                              } catch (_) {}
                            }

                            if (decryptedBytes != null) {
                              final newSalt = _crypto.generateSalt();
                              final newKey = _crypto.deriveKey(newPassController.text, newSalt);
                              final encResult = _crypto.encryptFile(decryptedBytes, newKey, ivBase64: null);

                              final newUrl = await cloudinary.uploadFile(name, encResult.encryptedBytes);
                              if (newUrl != null) {
                                await doc.reference.update({
                                  'downloadUrl': newUrl,
                                  'salt': newSalt,
                                  'iv': encResult.iv,
                                  'sizeBytes': encResult.encryptedBytes.length,
                                });
                              }
                            }
                          }
                        }

                        setDialogState(() {
                          processedFiles++;
                        });
                      }

                      // Update the new encrypted vault password using the recovery key
                      final newEncVaultPass = _crypto.encryptString(newPassController.text, decStoredKey);
                      await userDoc.reference.update({
                        'vaultPasswordEncrypted': newEncVaultPass,
                      });

                      if (mounted) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vault encryption password reset and files re-encrypted successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        isReencrypting = false;
                        errorMsg = 'Recovery failed: ${e.toString().replaceAll('Exception: ', '')}';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (!isReencrypting)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Security Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          RotationTransition(
            turns: _gearController,
            child: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.settings, color: Colors.white54),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.getSecuritySettings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: teal));
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              twoFactorEnabled = data['twoFactorEnabled'] ?? false;
              if (kIsWeb) {
                biometricsEnabled = false;
              } else {
                biometricsEnabled = data['biometricsEnabled'] ?? biometricsEnabled;
              }
            }
          }

          return AnimatedBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account Protection',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (twoFactorEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.shield, size: 14, color: Colors.greenAccent),
                              SizedBox(width: 6),
                              Text(
                                '2FA ENABLED',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassContainer(
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeColor: teal,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Two-Factor Authentication (2FA)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Require an extra code when logging in', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          value: twoFactorEnabled,
                          onChanged: (bool value) {
                            if (value) {
                              _show2FASetupDialog(context, biometricsEnabled);
                            } else {
                              _firestore.updateSecuritySettings(false, biometricsEnabled, totpSecret: null);
                            }
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Biometric Login', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Coming Soon', style: TextStyle(color: Colors.white24, fontSize: 13)),
                          trailing: const Icon(Icons.fingerprint, color: Colors.white24),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Change Account Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Update your master login password', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: () => _showChangePasswordDialog(context),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Change Vault Password (Re-encryption)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Re-encrypt all vault files with a new password', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: () => _showChangeVaultPasswordDialog(context),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Forgot Vault Password? (Recovery)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Reset your vault password using your 24-word recovery key', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: () => _showForgotVaultPasswordDialog(context),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Set Vault PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Set a 4-digit PIN to lock your vault', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: () => _showSetPinDialog(context),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Set Duress Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Set a secondary login password for duress safety', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: () => _showSetDuressPasswordDialog(context),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('View Recovery Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Backup your 24-word account recovery phrase', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                          onTap: () async {
                            final docData = snapshot.data!.data() as Map<String, dynamic>?;
                            String? encryptedKey = docData?['recoveryKey'] as String?;
                            String decryptedKey = '';

                            if (encryptedKey == null || encryptedKey.isEmpty) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final newKey = _crypto.generate24WordRecoveryKey();
                                encryptedKey = _crypto.encryptString(newKey, _crypto.masterAppKey);
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                  'recoveryKey': encryptedKey,
                                }, SetOptions(merge: true));
                                decryptedKey = newKey;
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error: No authenticated user found.'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }
                            } else {
                              decryptedKey = _crypto.decryptString(encryptedKey, _crypto.masterAppKey);
                            }

                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF0A0A0A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.shield_outlined, color: Color(0xFFC9A84C), size: 28),
                                      SizedBox(width: 10),
                                      Text('24-Word Recovery Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Store these 24 words in a secure offline location. Never share them with anyone.',
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
                                          decryptedKey,
                                          style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5, height: 1.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close', style: TextStyle(color: Colors.white54)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Sessions',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF0A0A0A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                              title: const Text('Logout All Devices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: const Text('This will force logout across all active devices and sessions. Are you sure?', style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                'forceLogoutAll': true,
                                'activeSessions': [],
                              }, SetOptions(merge: true));
                              if (mounted) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('All devices logged out successfully.'), backgroundColor: Colors.greenAccent),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                        label: const Text('Logout All Devices', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final docData = snapshot.data!.data() as Map<String, dynamic>?;
                      final List<dynamic> sessions = docData?['activeSessions'] as List<dynamic>? ?? [];

                      if (sessions.isEmpty) {
                        return GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: const Center(
                            child: Text('No active sessions tracked.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ),
                        );
                      }

                      return GlassContainer(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final map = sessions[index] as Map<String, dynamic>;
                            final device = map['device'] ?? 'Unknown Device';
                            final ip = map['ip'] ?? 'Unknown IP';
                            final ts = map['loginTime'] as Timestamp?;
                            final timeStr = ts != null ? DateFormat('MMM dd, hh:mm a').format(ts.toDate()) : 'Recently';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFFC9A84C).withOpacity(0.15), shape: BoxShape.circle),
                                child: const Icon(Icons.computer, color: Color(0xFFC9A84C), size: 20),
                              ),
                              title: Text(device, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('IP: $ip', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                                  const SizedBox(height: 2),
                                  Text('Logged in: $timeStr', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
