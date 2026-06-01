import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class PasswordManagerScreen extends StatefulWidget {
  final bool isTab;
  const PasswordManagerScreen({super.key, this.isTab = false});

  @override
  _PasswordManagerScreenState createState() => _PasswordManagerScreenState();
}

class _PasswordManagerScreenState extends State<PasswordManagerScreen> {
  final FirestoreService _firestore = FirestoreService();
  final CryptoService _crypto = CryptoService();

  final Set<String> _revealedPasswords = {};
  int _clipboardCountdown = 0;
  Timer? _clipboardTimer;

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  void _startClipboardCountdown() {
    _clipboardTimer?.cancel();
    setState(() {
      _clipboardCountdown = 30;
    });
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_clipboardCountdown > 1) {
          _clipboardCountdown--;
        } else {
          _clipboardCountdown = 0;
          Clipboard.setData(const ClipboardData(text: ''));
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clipboard cleared for security.'), backgroundColor: Colors.orangeAccent),
          );
        }
      });
    });
  }

  void _showAddPasswordDialog(BuildContext context) {
    final TextEditingController websiteCtrl = TextEditingController();
    final TextEditingController usernameCtrl = TextEditingController();
    final TextEditingController passwordCtrl = TextEditingController();
    bool isSaving = false;

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
          title: const Text('Add Password Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Website / App Name', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: websiteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Google, GitHub, Bank',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Username / Email', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. user@example.com',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Password', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter secret password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.vpn_key_outlined, size: 16, color: Color(0xFFC9A84C)),
                    label: const Text('Generate Password', style: TextStyle(color: Color(0xFFC9A84C), fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => _PasswordGeneratorDialog(
                          onPasswordSelected: (newPassword) {
                            passwordCtrl.text = newPassword;
                            setDialogState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                GradientButton(
                  text: 'Encrypt & Save',
                  isLoading: isSaving,
                  onPressed: () async {
                    if (websiteCtrl.text.isEmpty || usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      final encryptedPass = _crypto.encryptString(passwordCtrl.text, _crypto.masterAppKey);
                      await _firestore.addPasswordEntry(websiteCtrl.text.trim(), usernameCtrl.text.trim(), encryptedPass);

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password encrypted and saved successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving password: $e'), backgroundColor: Colors.redAccent),
                      );
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

  @override
  Widget build(BuildContext context) {
    final Widget content = StreamBuilder<QuerySnapshot>(
      stream: _firestore.getPasswordEntries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.password_outlined, size: 72, color: Colors.white24),
                const SizedBox(height: 16),
                const Text('No Passwords Stored', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Store your website logins securely with AES-256 encryption.', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC9A84C),
                    foregroundColor: const Color(0xFF0A0A0A),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showAddPasswordDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Password Manager',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A84C),
                      foregroundColor: const Color(0xFF0A0A0A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddPasswordDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('AES-256 encrypted passwords. Tap the eye icon or password to reveal.', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final website = data['website'] ?? 'Unknown';
                  final username = data['username'] ?? '';
                  final encryptedPass = data['encryptedPassword'] ?? '';
                  final isRevealed = _revealedPasswords.contains(docId);

                  String displayPass = '••••••••••••';
                  if (isRevealed) {
                    displayPass = _crypto.decryptString(encryptedPass, _crypto.masterAppKey);
                  }

                  return GlassContainer(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9A84C).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.2), blurRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.vpn_key_outlined, color: Color(0xFFC9A84C), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(website, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(username, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isRevealed) {
                                      _revealedPasswords.remove(docId);
                                    } else {
                                      _revealedPasswords.add(docId);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        displayPass,
                                        style: TextStyle(
                                          color: isRevealed ? const Color(0xFFC9A84C) : Colors.white54,
                                          fontSize: 13,
                                          fontWeight: isRevealed ? FontWeight.bold : FontWeight.normal,
                                          letterSpacing: isRevealed ? 1 : 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, color: Color(0xFFC9A84C)),
                          onPressed: () {
                            final decrypted = _crypto.decryptString(encryptedPass, _crypto.masterAppKey);
                            Clipboard.setData(ClipboardData(text: decrypted));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password copied to clipboard'), duration: Duration(seconds: 2)),
                            );
                            _startClipboardCountdown();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white38),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF0A0A0A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                                title: const Text('Delete Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: Text('Are you sure you want to delete the password for $website?', style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _firestore.deletePasswordEntry(docId, website);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Deleted password for $website'), backgroundColor: Colors.orangeAccent),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    final Widget finalBody = Stack(
      children: [
        content,
        if (_clipboardCountdown > 0)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderColor: const Color(0xFFC9A84C).withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFC9A84C), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Clipboard clears in ${_clipboardCountdown}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC9A84C),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (widget.isTab) {
      return finalBody;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Password Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(child: finalBody),
    );
  }
}

class _PasswordGeneratorDialog extends StatefulWidget {
  final ValueChanged<String> onPasswordSelected;
  const _PasswordGeneratorDialog({required this.onPasswordSelected});

  @override
  State<_PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<_PasswordGeneratorDialog> {
  int _length = 16;
  bool _useUppercase = true;
  bool _useLowercase = true;
  bool _useNumbers = true;
  bool _useSymbols = true;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    const uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
    const numberChars = '0123456789';
    const symbolChars = '!@#\$%^&*()_-+=<>?/[]{}|';

    String allowedChars = '';
    if (_useUppercase) allowedChars += uppercaseChars;
    if (_useLowercase) allowedChars += lowercaseChars;
    if (_useNumbers) allowedChars += numberChars;
    if (_useSymbols) allowedChars += symbolChars;

    if (allowedChars.isEmpty) {
      setState(() {
        _generatedPassword = '';
      });
      return;
    }

    final math.Random random = math.Random.secure();
    final password = List.generate(_length, (index) {
      return allowedChars[random.nextInt(allowedChars.length)];
    }).join('');

    setState(() {
      _generatedPassword = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A84C);
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Text('Generate Strong Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: gold.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _generatedPassword.isEmpty ? 'Select options' : _generatedPassword,
                            style: TextStyle(
                              color: _generatedPassword.isEmpty ? Colors.white30 : gold,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                          onPressed: _generatedPassword.isEmpty
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: _generatedPassword));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Generated password copied to clipboard')),
                                  );
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                          onPressed: _generatePassword,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Length', style: TextStyle(color: Colors.white70)),
                      Text('$_length', style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _length.toDouble(),
                    min: 8,
                    max: 32,
                    divisions: 24,
                    activeColor: gold,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setDialogState(() {
                        _length = val.round();
                      });
                      _generatePassword();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchTile('Uppercase (A-Z)', _useUppercase, (val) {
                    setDialogState(() => _useUppercase = val);
                    _generatePassword();
                  }),
                  _buildSwitchTile('Lowercase (a-z)', _useLowercase, (val) {
                    setDialogState(() => _useLowercase = val);
                    _generatePassword();
                  }),
                  _buildSwitchTile('Numbers (0-9)', _useNumbers, (val) {
                    setDialogState(() => _useNumbers = val);
                    _generatePassword();
                  }),
                  _buildSwitchTile('Symbols (!@#\$...)', _useSymbols, (val) {
                    setDialogState(() => _useSymbols = val);
                    _generatePassword();
                  }),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF0A0A0A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _generatedPassword.isEmpty
                        ? null
                        : () {
                            widget.onPasswordSelected(_generatedPassword);
                            Navigator.pop(context);
                          },
                    child: const Text('Use Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      value: value,
      activeColor: const Color(0xFFC9A84C),
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }
}
