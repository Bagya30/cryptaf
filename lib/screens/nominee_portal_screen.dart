import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/solid_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:cryptaf/web_url_stub.dart' if (dart.library.html) 'dart:html'
    as html;

class NomineePortalScreen extends StatefulWidget {
  final String? vaultOwnerId;
  const NomineePortalScreen({super.key, this.vaultOwnerId});

  @override
  State<NomineePortalScreen> createState() => _NomineePortalScreenState();
}

class _NomineePortalScreenState extends State<NomineePortalScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _decryptPasswordController =
      TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _decryptFocusNode = FocusNode();

  final CryptoService _crypto = CryptoService();

  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _verifiedEmail;
  bool _isCheckingLink = false;
  DateTime? _lastLinkRequest;

  List<Map<String, dynamic>> _authorizedVaults = [];
  Map<String, dynamic>? _selectedVault;
  List<DocumentSnapshot> _vaultFiles = [];
  bool _isLoadingVault = false;

  static const _gold = Color(0xFFC9A84C);

  @override
  void initState() {
    super.initState();
    _checkEmailLink();
  }

  Future<void> _checkEmailLink() async {
    if (!kIsWeb) return;
    final url = html.window.location.href;
    if (FirebaseAuth.instance.isSignInWithEmailLink(url)) {
      setState(() => _isCheckingLink = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        String? email = prefs.getString('nominee_email_for_signin');

        if (email == null || email.isEmpty) {
          email = await _showEmailPromptDialog();
          if (email == null || email.isEmpty) {
            throw Exception('Email is required to complete sign-in.');
          }
        }

        final userCredential = await FirebaseAuth.instance.signInWithEmailLink(
          email: email,
          emailLink: url,
        );

        final user = userCredential.user;
        if (user == null) throw Exception('Sign-in failed.');

        await user.reload();
        final reloadedUser = FirebaseAuth.instance.currentUser;
        if (reloadedUser == null || !reloadedUser.emailVerified) {
          throw Exception('Account email is not verified.');
        }

        if (reloadedUser.email?.toLowerCase().trim() !=
            email.toLowerCase().trim()) {
          throw Exception('Signed in email does not match requested email.');
        }

        await prefs.remove('nominee_email_for_signin');

        await _bindAndValidateVault(reloadedUser);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sign-in failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
          ),
        );
      } finally {
        if (mounted) setState(() => _isCheckingLink = false);
      }
    }
  }

  Future<String?> _showEmailPromptDialog() async {
    final TextEditingController dialogEmailController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12)),
        title: const Text('Confirm Email',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Please enter your email to complete sign-in (you opened this link on a new device or browser).',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: dialogEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email Address',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
                context, dialogEmailController.text.trim().toLowerCase()),
            child: const Text('Confirm',
                style: TextStyle(color: Color(0xFFC9A84C))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _decryptPasswordController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _decryptFocusNode.dispose();
    super.dispose();
  }

  // Send Passwordless Email Link
  Future<void> _sendSignInLink() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your email address'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_lastLinkRequest != null &&
        DateTime.now().difference(_lastLinkRequest!).inSeconds < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please wait 60 seconds before requesting another link.'),
            backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final acs = ActionCodeSettings(
        url:
            'https://cryptaf-36296.web.app/nominee-access?vaultOwner=${widget.vaultOwnerId ?? ''}',
        handleCodeInApp: true,
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: acs,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nominee_email_for_signin', email);

      _lastLinkRequest = DateTime.now();

      setState(() {
        _otpSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'If this email is eligible, a secure sign-in link has been sent.'),
              backgroundColor: Colors.greenAccent,
              duration: Duration(seconds: 8)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to send sign-in link: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  // Bind UID and Validate Vault after successful link sign-in
  Future<void> _bindAndValidateVault(User user) async {
    final email = user.email!.toLowerCase().trim();

    if (widget.vaultOwnerId == null || widget.vaultOwnerId!.isEmpty) {
      throw Exception('Vault owner ID is required to access a vault.');
    }

    final nomineeDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.vaultOwnerId)
        .collection('nominees')
        .doc(email);

    final nomineeDoc = await nomineeDocRef.get();
    if (!nomineeDoc.exists) {
      throw Exception(
          'This account is not an authorized nominee for this vault.');
    }

    final data = nomineeDoc.data()!;
    final boundUid = data['uid'] as String?;

    if (boundUid == null) {
      // Bind UID securely according to firestore.rules
      await nomineeDocRef.update({'uid': user.uid});
    } else if (boundUid != user.uid) {
      throw Exception(
          'This nominee invitation is linked to another account. Ask the vault owner to reset the nominee access binding.');
    }

    // Now safely read the publicMeta info using the bound UID
    final userMetaDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.vaultOwnerId)
        .collection('publicMeta')
        .doc('info')
        .get();

    if (userMetaDoc.exists) {
      final userData = userMetaDoc.data();
      final isEnabled = userData?['emergencyEnabled'] ?? false;
      final status = userData?['emergencyStatus'] ?? 'disabled';
      final deadline = userData?['emergencyDeadline'] as Timestamp?;

      if (!isEnabled) {
        throw Exception(
            'Emergency access is currently disabled for this vault.');
      }

      bool isExpired = false;
      if (status == 'expired' ||
          (deadline != null && deadline.toDate().isBefore(DateTime.now()))) {
        isExpired = true;
      }

      setState(() {
        _verifiedEmail = email;
        _authorizedVaults = [
          {
            'uid': widget.vaultOwnerId,
            'email': 'Vault Owner',
            'name': 'Secured Vault',
            'isExpired': isExpired,
            'isEnabled': isEnabled,
          }
        ];
      });

      if (mounted) {
        if (!isExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Identity verified successfully! However, emergency access to vault files is still pending the security deadline.'),
                backgroundColor: Colors.orangeAccent),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Identity verified successfully!'),
                backgroundColor: Colors.greenAccent),
          );
        }
      }
    } else {
      throw Exception('Vault metadata not found.');
    }
  }

  // Load files of selected vault
  Future<void> _loadVault(Map<String, dynamic> vault) async {
    setState(() {
      _selectedVault = vault;
      _isLoadingVault = true;
      _vaultFiles = [];
    });

    if (vault['isEnabled'] == false || vault['isExpired'] == false) {
      setState(() {
        _isLoadingVault = false;
      });
      return;
    }

    try {
      final filesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(vault['uid'])
          .collection('files')
          .where('isInheritable', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();

      setState(() {
        _vaultFiles = filesSnap.docs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load files: $e'),
            backgroundColor: Colors.redAccent),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool obscureDecryptPass = true;
          return AlertDialog(
            backgroundColor: const Color(0xFF0A0A0A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white12)),
            title: Text('Decrypt $name',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: StatefulBuilder(
              builder: (context, setInnerState) => Column(
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
                    focusNode: _decryptFocusNode,
                    obscureText: obscureDecryptPass,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Decryption Password',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureDecryptPass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFFC9A84C),
                          size: 20,
                        ),
                        onPressed: () => setInnerState(
                            () => obscureDecryptPass = !obscureDecryptPass),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _decryptPasswordController.clear();
                },
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () async {
                  final password = _decryptPasswordController.text.trim();
                  if (password.isEmpty) return;

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Downloading and decrypting...')),
                  );

                  try {
                    final res = await http.get(Uri.parse(downloadUrl));
                    if (res.statusCode != 200) {
                      throw Exception('Download failed');
                    }

                    final key = _crypto.deriveKey(password, salt!);
                    final decBytes =
                        _crypto.decryptFile(res.bodyBytes, key, ivBase64: iv);

                    // Save or open decrypted bytes
                    final dataUri =
                        'data:application/octet-stream;base64,${base64.encode(decBytes)}';
                    await launchUrl(Uri.parse(dataUri));
                  } catch (e) {
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Decryption failed. Incorrect password.'),
                          backgroundColor: Colors.redAccent),
                    );
                  } finally {
                    _decryptPasswordController.clear();
                  }
                },
                child: const Text('Decrypt',
                    style:
                        TextStyle(color: _gold, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset:
          false, // Prevent aggressive viewport shrinking on mobile Chrome
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nominee Portal',
          style: GoogleFonts.oxanium(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: max(24.0, bottomInset + 24.0),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_verifiedEmail == null) ...[
                    // Verification Flow
                    GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 64, color: _gold),
                          const SizedBox(height: 16),
                          Text(
                            _isCheckingLink
                                ? 'Verifying Link...'
                                : 'Nominee Access Login',
                            style: GoogleFonts.oxanium(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_isCheckingLink)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: _gold),
                            )
                          else ...[
                            Text(
                              _otpSent
                                  ? 'Check your inbox for a sign-in link.'
                                  : 'Enter your registered nominee email to request vault access.',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            if (!_otpSent) ...[
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'Nominee Email',
                                  labelStyle:
                                      const TextStyle(color: Colors.white54),
                                  prefixIcon: const Icon(Icons.email_outlined,
                                      color: _gold),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white12)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white12)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: _gold)),
                                ),
                                onSubmitted: (_) => _sendSignInLink(),
                              ),
                              const SizedBox(height: 24),
                              SolidButton(
                                text: 'Send Sign-In Link',
                                isLoading: _isSendingOtp,
                                onPressed: _sendSignInLink,
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _sendSignInLink,
                                child: const Text('Resend Sign-In Link',
                                    style: TextStyle(color: _gold)),
                              ),
                            ],
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
                              style: GoogleFonts.oxanium(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _gold),
                            ),
                            TextButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                setState(() {
                                  _verifiedEmail = null;
                                  _selectedVault = null;
                                  _vaultFiles = [];
                                  _otpSent = false;
                                  _emailController.clear();
                                });
                              },
                              child: const Text('Logout',
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Vaults List
                        Text(
                          'Select Vault to Access',
                          style: GoogleFonts.oxanium(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _authorizedVaults.map((vault) {
                            final isSelected =
                                _selectedVault?['uid'] == vault['uid'];
                            return GestureDetector(
                              onTap: () => _loadVault(vault),
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                borderColor:
                                    isSelected ? _gold : Colors.white12,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_shared_outlined,
                                        color: _gold, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      vault['email'],
                                      style: TextStyle(
                                          color:
                                              isSelected ? _gold : Colors.white,
                                          fontWeight: FontWeight.bold),
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
                            style: GoogleFonts.oxanium(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedVault!['isEnabled'] == false)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                    'Emergency access is currently disabled.',
                                    style: TextStyle(color: Colors.white38),
                                    textAlign: TextAlign.center),
                              ),
                            )
                          else if (_selectedVault!['isExpired'] == false)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                    'Emergency access is not active yet. You will be able to access eligible inherited files after the owner\'s inactivity deadline.',
                                    style: TextStyle(color: Colors.white38),
                                    textAlign: TextAlign.center),
                              ),
                            )
                          else if (_isLoadingVault)
                            const Center(
                                child: CircularProgressIndicator(color: _gold))
                          else if (_vaultFiles.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                    'No inheritable files stored in this vault.',
                                    style: TextStyle(color: Colors.white38)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _vaultFiles.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = _vaultFiles[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['name'] ?? 'file';
                                final type = data['type'] ?? 'bin';
                                final category = data['category'] ?? 'General';
                                final encrypted = data['encrypted'] ?? true;

                                return GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
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
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '$category â€¢ ${type.toUpperCase()}',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        encrypted
                                            ? Icons.lock_outline
                                            : Icons.download_outlined,
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
          );
        }),
      ),
    );
  }
}
