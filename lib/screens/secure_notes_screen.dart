import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class SecureNotesScreen extends StatefulWidget {
  final bool isTab;
  const SecureNotesScreen({super.key, this.isTab = false});

  @override
  State<SecureNotesScreen> createState() => _SecureNotesScreenState();
}

class _SecureNotesScreenState extends State<SecureNotesScreen> {
  final FirestoreService _firestore = FirestoreService();
  final CryptoService _crypto = CryptoService();

  final Set<String> _revealedNotes = {};

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  void _showAddNoteDialog(BuildContext context) {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController contentCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Create Secure Note',
            style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note Title', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Secret Seed Phrase, Personal Log',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Note Content', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: contentCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter note content...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Encrypt & Save Note',
                  isLoading: isSaving,
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      final encryptedTitle = _crypto.encryptString(titleCtrl.text.trim(), _crypto.masterAppKey);
                      final encryptedContent = _crypto.encryptString(contentCtrl.text.trim(), _crypto.masterAppKey);

                      await _firestore.addNoteEntry(encryptedTitle, encryptedContent);

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note encrypted and saved successfully!'), backgroundColor: Colors.greenAccent),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving note: $e'), backgroundColor: Colors.redAccent),
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

  void _showNoteDetails(BuildContext context, String title, String decryptedContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          title,
          style: GoogleFonts.oxanium(color: _gold, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                decryptedContent,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
              ),
            ],
          ),
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

  Future<bool> _promptVaultPassword() async {
    final TextEditingController passCtrl = TextEditingController();
    bool isChecking = false;
    String errorMsg = '';
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
          title: Text('Enter Vault Password', style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: isChecking ? null : () async {
                setDialogState(() {
                  isChecking = true;
                  errorMsg = '';
                });
                
                final isValid = await _crypto.verifyVaultPassword(passCtrl.text);
                if (isValid) {
                  if (mounted) Navigator.pop(context, true);
                } else {
                  setDialogState(() {
                    errorMsg = 'Incorrect password';
                    isChecking = false;
                  });
                }
              },
              child: isChecking 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _gold, strokeWidth: 2))
                : const Text('Unlock', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = StreamBuilder<QuerySnapshot>(
      stream: _firestore.getNoteEntries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.note_alt_outlined, size: 72, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  'No Secure Notes Stored',
                  style: GoogleFonts.oxanium(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Store confidential thoughts and codes securely with AES-256 encryption.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _bg,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showAddNoteDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text(
                    'Secure Notes',
                    style: GoogleFonts.oxanium(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _bg,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddNoteDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('AES-256 encrypted notes. Tap a note card to decrypt and view details.', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final encTitle = data['title'] ?? '';
                  final encContent = data['content'] ?? '';

                  final decTitle = _crypto.decryptString(encTitle, _crypto.masterAppKey);
                  final decContent = _crypto.decryptString(encContent, _crypto.masterAppKey);

                  final isRevealed = _revealedNotes.contains(doc.id);

                  return GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.note_alt_outlined, color: _gold, size: 28),
                      title: Text(
                        decTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          isRevealed ? decContent : '••••••••••••••••••••••••••••••••',
                          style: TextStyle(
                            color: isRevealed ? Colors.white70 : Colors.white38,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isRevealed ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () async {
                              if (isRevealed) {
                                setState(() {
                                  _revealedNotes.remove(doc.id);
                                });
                              } else {
                                final isValid = await _promptVaultPassword();
                                if (isValid) {
                                  setState(() {
                                    _revealedNotes.add(doc.id);
                                  });
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: _bg,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                                  title: const Text('Delete Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  content: const Text('Are you sure you want to permanently delete this note?', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _firestore.deleteNoteEntry(doc.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Note deleted')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        final isValid = await _promptVaultPassword();
                        if (isValid) {
                          _showNoteDetails(context, decTitle, decContent);
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (widget.isTab) {
      return Scaffold(
        backgroundColor: _bg,
        body: AnimatedBackground(child: content),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Secure Notes', style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(child: content),
    );
  }
}
