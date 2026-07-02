import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/solid_button.dart';
import 'package:url_launcher/url_launcher.dart';

class NomineePortalScreen extends StatefulWidget {
  const NomineePortalScreen({super.key});

  @override
  State<NomineePortalScreen> createState() => _NomineePortalScreenState();
}

class _NomineePortalScreenState extends State<NomineePortalScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _decryptPasswordController = TextEditingController();
  final CryptoService _crypto = CryptoService();

  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _generatedOtp;
  String? _verifiedEmail;

  List<Map<String, dynamic>> _authorizedVaults = [];
  Map<String, dynamic>? _selectedVault;
  List<DocumentSnapshot> _vaultFiles = [];
  bool _isLoadingVault = false;

  static const _gold = Color(0xFFC9A84C);

  // Send Email OTP using EmailJS
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      // 1. Query Firestore Collection Group to find if this email is a nominee anywhere
      final nomineeQuery = await FirebaseFirestore.instance
          .collectionGroup('nominees')
          .where('email', isEqualTo: email)
          .get();

      if (nomineeQuery.docs.isEmpty) {
        throw Exception('You are not registered as a nominee for any Cryptaf vault.');
      }

      // Check if any matching vault owner has emergency enabled and status is expired
      List<Map<String, dynamic>> temporaryVaults = [];
      for (var doc in nomineeQuery.docs) {
        final parentRef = doc.reference.parent.parent;
        if (parentRef != null) {
          final userDoc = await parentRef.get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            final isEnabled = userData?['emergencyEnabled'] ?? false;
            final status = userData?['emergencyStatus'] ?? 'disabled';

            if (isEnabled && status == 'expired') {
              temporaryVaults.add({
                'uid': userDoc.id,
                'email': userData?['email'] ?? 'User Vault',
                'name': userData?['name'] ?? 'Cryptaf User',
              });
            }
          }
        }
      }

      if (temporaryVaults.isEmpty) {
        throw Exception('No active emergency vault access is currently available. Access is only granted when the owner\'s Dead Man\'s Switch timer expires.');
      }

      // Generate 6-digit OTP
      final randomOtp = (100000 + Random.secure().nextInt(900000)).toString();

      // Send via EmailJS
      final now = DateTime.now();
      final timeStr = "${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}";
      final message = "Your verification OTP for the Cryptaf Nominee Portal is $randomOtp. This OTP is valid for 10 minutes.";

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': dotenv.env['EMAILJS_SERVICE_ID'] ?? '',
          'template_id': dotenv.env['EMAILJS_TEMPLATE_ID_ALERT'] ?? '',
          'user_id': dotenv.env['EMAILJS_USER_ID'] ?? '',
          'template_params': {
            'email': email,
            'time': timeStr,
            'message': message,
            'passcode': randomOtp,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to send OTP email via server.');
      }

      setState(() {
        _generatedOtp = randomOtp;
        _otpSent = true;
        _authorizedVaults = temporaryVaults;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your email address!'), backgroundColor: Colors.greenAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() {
        _isSendingOtp = false;
      });
    }
  }

  // Verify OTP Entered
  void _verifyOtp() {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP received'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (enteredOtp == _generatedOtp) {
      setState(() {
        _verifiedEmail = _emailController.text.trim().toLowerCase();
        _otpSent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity verified successfully!'), backgroundColor: Colors.greenAccent),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please check and try again.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Load files of selected vault
  Future<void> _loadVault(Map<String, dynamic> vault) async {
    setState(() {
      _selectedVault = vault;
      _isLoadingVault = true;
      _vaultFiles = [];
    });

    try {
      final filesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(vault['uid'])
          .collection('files')
          .orderBy('uploadedAt', descending: true)
          .get();

      setState(() {
        _vaultFiles = filesSnap.docs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load files: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isLoadingVault = false;
      });
    }
  }

  // Decrypt and view file
  Future<void> _decryptFile(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'file';
    final downloadUrl = data['downloadUrl'] as String?;
    final encrypted = data['encrypted'] ?? true;
    final salt = data['salt'] as String?;
    final iv = data['iv'] as String?;

    if (downloadUrl == null) return;

    if (!encrypted) {
      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl));
      }
      return;
    }

    // Ask for password
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: Text('Decrypt $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the vault decryption password provided by the owner.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _decryptPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Decryption Password',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _decryptPasswordController.clear();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final password = _decryptPasswordController.text.trim();
              if (password.isEmpty) return;

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading and decrypting...')),
              );

              try {
                final res = await http.get(Uri.parse(downloadUrl));
                if (res.statusCode != 200) throw Exception('Download failed');

                final key = _crypto.deriveKey(password, salt!);
                final decBytes = _crypto.decryptFile(res.bodyBytes, key, ivBase64: iv);

                // Save or open decrypted bytes
                final dataUri = 'data:application/octet-stream;base64,${base64.encode(decBytes)}';
                await launchUrl(Uri.parse(dataUri));
              } catch (e) {
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Decryption failed. Incorrect password.'), backgroundColor: Colors.redAccent),
                );
              } finally {
                _decryptPasswordController.clear();
              }
            },
            child: const Text('Decrypt', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nominee Portal',
          style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_verifiedEmail == null) ...[
                    // Verification Flow
                    GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.shield_outlined, size: 64, color: _gold),
                          const SizedBox(height: 16),
                          Text(
                            _otpSent ? 'Enter Verification Code' : 'Nominee Access Login',
                            style: GoogleFonts.oxanium(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpSent
                                ? 'We have sent a verification code to ${_emailController.text}'
                                : 'Enter your registered nominee email to request vault access.',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (!_otpSent) ...[
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Nominee Email',
                                labelStyle: const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.email_outlined, color: _gold),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.03),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SolidButton(
                              text: 'Request Vault Access',
                              isLoading: _isSendingOtp,
                              onPressed: _sendOtp,
                            ),
                          ] else ...[
                            TextField(
                              controller: _otpController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: '6-Digit OTP',
                                labelStyle: const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.lock_outline, color: _gold),
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.03),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SolidButton(
                              text: 'Verify Identity',
                              onPressed: _verifyOtp,
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _sendOtp,
                              child: const Text('Resend OTP Email', style: TextStyle(color: _gold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Authenticated Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Welcome, Nominee',
                              style: GoogleFonts.oxanium(fontSize: 24, fontWeight: FontWeight.bold, color: _gold),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _verifiedEmail = null;
                                  _selectedVault = null;
                                  _vaultFiles = [];
                                });
                              },
                              child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Vaults List
                        Text(
                          'Select Vault to Access',
                          style: GoogleFonts.oxanium(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _authorizedVaults.map((vault) {
                            final isSelected = _selectedVault?['uid'] == vault['uid'];
                            return GestureDetector(
                              onTap: () => _loadVault(vault),
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                borderColor: isSelected ? _gold : Colors.white12,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_shared_outlined, color: _gold, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      vault['email'],
                                      style: TextStyle(color: isSelected ? _gold : Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 30),

                        // Vault Files List
                        if (_selectedVault != null) ...[
                          Text(
                            'Shared Vault Files (${_selectedVault!['email']})',
                            style: GoogleFonts.oxanium(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingVault)
                            const Center(child: CircularProgressIndicator(color: _gold))
                          else if (_vaultFiles.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text('No files stored in this vault.', style: TextStyle(color: Colors.white38)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _vaultFiles.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = _vaultFiles[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['name'] ?? 'file';
                                final type = data['type'] ?? 'bin';
                                final category = data['category'] ?? 'General';
                                final encrypted = data['encrypted'] ?? true;

                                return GlassContainer(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      type.toUpperCase() == 'PDF'
                                          ? Icons.picture_as_pdf_outlined
                                          : Icons.insert_drive_file_outlined,
                                      color: _gold,
                                      size: 32,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '$category â€¢ ${type.toUpperCase()}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        encrypted ? Icons.lock_outline : Icons.download_outlined,
                                        color: _gold,
                                      ),
                                      onPressed: () => _decryptFile(doc),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
