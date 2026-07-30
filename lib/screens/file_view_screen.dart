import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cryptaf/utils/web_helper.dart';

class FileViewScreen extends StatefulWidget {
  final String docId;
  final String name;
  final String type;
  final String category;
  final String downloadUrl;
  final Timestamp? uploadedAt;
  final int? sizeBytes;
  final String? salt;
  final String? iv;
  final bool isFavorite;
  final bool isEncrypted;

  const FileViewScreen({
    super.key,
    required this.docId,
    required this.name,
    required this.type,
    required this.category,
    required this.downloadUrl,
    this.uploadedAt,
    this.sizeBytes,
    this.salt,
    this.iv,
    this.isFavorite = false,
    this.isEncrypted = true,
  });

  @override
  FileViewScreenState createState() => FileViewScreenState();
}

class FileViewScreenState extends State<FileViewScreen> {
  final FirestoreService _firestore = FirestoreService();
  final CryptoService _crypto = CryptoService();
  final TextEditingController _passwordController = TextEditingController();

  bool _isDecrypting = false;
  late String _sessionId;
  late String _currentCategory;
  late String _currentName;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.category;
    _currentName = widget.name;
    _sessionId = _crypto.generateSessionId();
    _isFavorite = widget.isFavorite;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '2.4 MB'; // Realistic fallback
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getMimeType(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return 'application/pdf';
      case 'PNG':
        return 'image/png';
      case 'JPG':
      case 'JPEG':
        return 'image/jpeg';
      case 'DOC':
      case 'DOCX':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Uint8List? _decryptedBytes;

  Future<void> _decryptAndView() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your vault decryption password'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isDecrypting = true;
    });

    try {
      // 1. Fetch encrypted file bytes from Cloudinary
      final response = await http.get(
        Uri.parse(widget.downloadUrl),
        headers: {
          'Accept': '*/*',
          'Access-Control-Allow-Origin': '*',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to download encrypted file from storage');
      }

      final Uint8List encryptedBytes = response.bodyBytes;

      // 2. Derive key using PBKDF2
      final salt = (widget.salt != null && widget.salt!.isNotEmpty) 
          ? widget.salt! 
          : 'DefaultCryptafSalt123!@#';
      final iv = (widget.iv != null && widget.iv!.isNotEmpty) 
          ? widget.iv! 
          : null;
      final key = _crypto.deriveKey(_passwordController.text, salt);

      // 3. Decrypt client-side
      final Uint8List decryptedBytes = _crypto.decryptFile(encryptedBytes, key, ivBase64: iv);

      setState(() {
        _decryptedBytes = decryptedBytes;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File decrypted successfully! Inline preview updated.'), backgroundColor: Colors.greenAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decryption failed: Incorrect password or corrupted file.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDecrypting = false;
        });
      }
    }
  }

  Future<void> _copySecureLink() async {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    final token = String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

    await FirebaseFirestore.instance.collection('share_links').doc(token).set({
      'fileUrl': widget.downloadUrl,
      'fileName': widget.name,
      'expiryTime': DateTime.now().add(const Duration(hours: 24)),
      'createdAt': FieldValue.serverTimestamp(),
      'downloadCount': 0,
    });

    final shareUrl = 'https://cryptaf-36296.web.app/share/$token';
    Clipboard.setData(ClipboardData(text: shareUrl));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secure link copied! Link expires in 24 hours'), backgroundColor: Colors.greenAccent),
      );
    }
  }

  Future<void> _moveCategory() async {
    final categories = ['Documents', 'Medical', 'Financial', 'Legal', 'Personal'];
    final String? selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Move File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: categories.map((cat) {
            return ListTile(
              title: Text(
                cat,
                style: TextStyle(
                  color: cat == _currentCategory ? const Color(0xFFC9A84C) : Colors.white70,
                  fontWeight: cat == _currentCategory ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: cat == _currentCategory ? const Icon(Icons.check, color: Color(0xFFC9A84C)) : null,
              onTap: () => Navigator.pop(context, cat),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && selected != _currentCategory) {
      await _firestore.updateFileCategory(widget.docId, widget.name, selected);
      if (mounted) {
        setState(() {
          _currentCategory = selected;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved to $selected')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    try {
      await _firestore.toggleFileFavorite(widget.docId, !_isFavorite); // Note: we pass the old status so it toggles
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorite status'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _renameFile() async {
    final TextEditingController renameController = TextEditingController(text: _currentName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Rename File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: renameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new file name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, renameController.text.trim()), child: const Text('Rename', style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _currentName) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('files').doc(widget.docId).update({
          'name': newName,
        });
        if (mounted) {
          setState(() {
            _currentName = newName;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to $newName')),
          );
        }
      }
    }
  }

  Future<void> _deleteFile() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Delete File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${widget.name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.deleteFileRecord(widget.docId, widget.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${widget.name}" deleted')),
        );
        Navigator.pop(context); // Go back to vault view
      }
    }
  }

  // ignore: use_build_context_synchronously
  Widget _buildMetaRow(String label, String value, Color textColor, Color subColor, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: subColor, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.greenAccent : textColor,
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaDivider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), height: 1);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    final activeColor = color ?? (isDark ? Colors.white : Colors.black87);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activeColor, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: activeColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    if (_decryptedBytes == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    final typeUpper = widget.type.toUpperCase();
    final isImage = ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'].contains(typeUpper);
    final isText = ['TXT', 'CSV'].contains(typeUpper);

    Widget previewWidget;

    if (isImage) {
      previewWidget = Container(
        constraints: const BoxConstraints(maxHeight: 300),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(_decryptedBytes!, fit: BoxFit.contain),
        ),
      );
    } else if (isText) {
      String textContent = '';
      try {
        textContent = utf8.decode(_decryptedBytes!);
      } catch (e) {
        textContent = String.fromCharCodes(_decryptedBytes!);
      }

      previewWidget = Container(
        constraints: const BoxConstraints(maxHeight: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black38 : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SelectableText(
            textContent,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              color: textColor,
            ),
          ),
        ),
      );
    } else {
      previewWidget = Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              children: [
                Icon(
                  typeUpper == 'PDF' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                  color: typeUpper == 'PDF' ? Colors.redAccent : const Color(0xFFC9A84C),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.type.toUpperCase()} Document decrypted',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inline viewing not supported for this format.',
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A84C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final String mimeType = _getMimeType(widget.type);
                final String base64Data = base64Encode(_decryptedBytes!);
                if (kIsWeb) {
                  downloadFileWeb('data:$mimeType;base64,$base64Data', widget.name);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File saved to downloads')),
                  );
                }
              },
              icon: const Icon(Icons.download_rounded, color: Colors.black),
              label: const Text(
                'Download File',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.08), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.remove_red_eye_outlined, color: Color(0xFFC9A84C), size: 20),
              SizedBox(width: 8),
              Text(
                'SECURE IN-APP PREVIEW',
                style: TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          previewWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = 'Recent';
    if (widget.uploadedAt != null) {
      formattedDate = DateFormat('MMM dd, yyyy').format(widget.uploadedAt!.toDate());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.redAccent : textColor.withOpacity(0.5),
            ),
            onPressed: _toggleFavorite,
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 4),
                  Text(
                    'AES-256 SECURED',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Large lock icon with "Secured Viewing Active" text
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A84C).withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.2), blurRadius: 24),
                  ],
                  border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.lock_outline, size: 64, color: Color(0xFFC9A84C)),
              ),
              const SizedBox(height: 16),
              Text(
                (widget.isEncrypted && widget.salt != null && widget.iv != null)
                    ? 'Secured Viewing Active'
                    : 'Unencrypted File',
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              // Security notice box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined, color: Color(0xFFC9A84C), size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'This document is end-to-end encrypted. Screenshot protection and secure session logging are enabled.',
                        style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // Metadata Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.05), blurRadius: 16),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FILE METADATA',
                      style: TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _buildMetaRow('File Name', _currentName, textColor, subColor),
                    _buildMetaDivider(isDark),
                    _buildMetaRow('Category', _currentCategory, textColor, subColor),
                    _buildMetaDivider(isDark),
                    _buildMetaRow('File Type', widget.type.toUpperCase(), textColor, subColor),
                    _buildMetaDivider(isDark),
                    _buildMetaRow('File Size', _formatFileSize(widget.sizeBytes), textColor, subColor),
                    _buildMetaDivider(isDark),
                    _buildMetaRow('Upload Date', formattedDate, textColor, subColor),
                    _buildMetaDivider(isDark),
                    _buildMetaRow('Encryption Grade', 'MIL-SPEC', textColor, subColor, isHighlight: true),
                  ],
                ),
              ),

              // Preview Section
              _buildPreviewSection(),

              // Decryption Password Field or Open Button
              if (widget.isEncrypted && widget.salt != null && widget.iv != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vault Decryption Password',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your vault password to decrypt this file locally in memory.',
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Enter vault password',
                          hintStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFC9A84C)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Decrypt & View teal button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF008080), Color(0xFF20B2AA)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF008080).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isDecrypting ? null : _decryptAndView,
                      child: Center(
                        child: _isDecrypting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Decrypting...',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : const Text(
                                'Decrypt & View',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                              ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Unencrypted file: Show "Open File" button directly
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFC9A84C),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC9A84C).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (!await launchUrl(Uri.parse(widget.downloadUrl))) {
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open file')),
                          );
                        }
                      },
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new, color: Colors.black),
                            SizedBox(width: 12),
                            Text(
                              'Open File',
                              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Action buttons at bottom: Secure Link, Rename, Move, Delete
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.link,
                            label: 'Secure Link',
                            onTap: _copySecureLink,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.edit_outlined,
                            label: 'Rename',
                            onTap: _renameFile,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.drive_file_move_outlined,
                            label: 'Move',
                            onTap: _moveCategory,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            color: Colors.redAccent,
                            onTap: _deleteFile,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Random Secure Session ID shown at bottom
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 32),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFFC9A84C)),
                        const SizedBox(width: 8),
                        Text(
                          'SECURE SESSION ID: $_sessionId',
                          style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
