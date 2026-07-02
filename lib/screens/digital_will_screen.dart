import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

class DigitalWillScreen extends StatefulWidget {
  const DigitalWillScreen({super.key});

  @override
  DigitalWillScreenState createState() => DigitalWillScreenState();
}

class DigitalWillScreenState extends State<DigitalWillScreen> {
  final QuillController _controller = QuillController.basic();
  final CryptoService _crypto = CryptoService();
  final String _willDocId = 'user_will';
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasExistingWill = false;
  bool _isEditing = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadWill();
  }

  Future<void> _loadWill() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('digital_will')
          .doc(_willDocId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final encryptedContent = data['contentEncrypted'] as String?;
        if (encryptedContent != null && encryptedContent.isNotEmpty) {
          final decryptedJsonStr = _crypto.decryptString(encryptedContent, _crypto.masterAppKey);
          final decodedJson = jsonDecode(decryptedJsonStr);
          _controller.document = Document.fromJson(decodedJson);
          _hasExistingWill = true;
        }
      }
    } catch (e) {
      _errorMsg = 'Failed to load will: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWill() async {
    setState(() {
      _isSaving = true;
      _errorMsg = '';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final jsonStr = jsonEncode(_controller.document.toDelta().toJson());
      final encryptedContent = _crypto.encryptString(jsonStr, _crypto.masterAppKey);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('digital_will')
          .doc(_willDocId)
          .set({
        'contentEncrypted': encryptedContent,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _hasExistingWill = true;
        _isEditing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digital will saved securely!'), backgroundColor: Colors.greenAccent),
        );
      }
    } catch (e) {
      setState(() => _errorMsg = 'Failed to save will: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Digital Will', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Write a personal message to your nominees. This message is AES-256 encrypted and will only be revealed if your Dead Man\'s Switch timer expires.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_hasExistingWill && !_isEditing) ...[
                      // Preview Mode
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  Expanded(
                                    child: ImageFiltered(
                                      imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                      child: IgnorePointer(
                                        child: QuillEditor.basic(
                                          configurations: QuillEditorConfigurations(
                                            controller: _controller,
                                            sharedConfigurations: const QuillSharedConfigurations(
                                              locale: Locale('en'),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_outline, color: Color(0xFFC9A84C), size: 48),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Will is Encrypted & Locked',
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 24),
                                    GradientButton(
                                      text: 'Edit Will',
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Edit Mode
                      GlassContainer(
                        padding: const EdgeInsets.all(8),
                        child: QuillToolbar.simple(
                          configurations: QuillSimpleToolbarConfigurations(
                            controller: _controller,
                            sharedConfigurations: const QuillSharedConfigurations(
                              locale: Locale('en'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: QuillEditor.basic(
                            configurations: QuillEditorConfigurations(
                              controller: _controller,
                              sharedConfigurations: const QuillSharedConfigurations(
                                locale: Locale('en'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_errorMsg.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(_errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ],
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'Save Encrypted Will',
                        isLoading: _isSaving,
                        onPressed: _saveWill,
                      ),
                      if (_hasExistingWill) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _loadWill(); // Reload to discard changes
                            });
                          },
                          child: const Text('Cancel Edit', style: TextStyle(color: Colors.white54)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
