import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/cloudinary_service.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  _FileUploadScreenState createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final FirestoreService _firestore = FirestoreService();
  final CloudinaryService _cloudinary = CloudinaryService();
  final CryptoService _crypto = CryptoService();
  final TextEditingController _passwordController = TextEditingController();

  List<PlatformFile> selectedFiles = [];
  Map<String, String> uploadProgress = {};

  bool isEncrypted = true;
  bool isUploading = false;
  String selectedCategory = 'Documents';
  final List<String> categories = ['Documents', 'Medical', 'Financial', 'Legal'];

  bool _showStorageWarning = false;

  @override
  void initState() {
    super.initState();
    _calculateStorageUsed();
  }

  Future<void> _calculateStorageUsed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('files')
          .get();
      int total = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final int size = data['sizeBytes'] as int? ?? 0;
        total += size;
      }
      if (mounted) {
        setState(() {
          // 80% of 1GB (1GB = 1024 * 1024 * 1024 bytes = 1,073,741,824 bytes).
          // 80% of 1GB = 858,993,459 bytes.
          _showStorageWarning = total >= 858993459;
        });
      }
    } catch (e) {
      debugPrint('Error calculating storage used: $e');
    }
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);

    if (result != null) {
      setState(() {
        selectedFiles = result.files;
        uploadProgress = { for (var f in result.files) f.name : "Pending" };
      });
    }
  }

  Future<void> uploadFiles() async {
    if (selectedFiles.isEmpty) return;

    if (isEncrypted && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your vault encryption password'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      for (var file in selectedFiles) {
        if (file.bytes == null) continue;

        setState(() {
          uploadProgress[file.name] = "Encrypting...";
        });

        Uint8List bytesToUpload = file.bytes!;
        String? salt;
        String? iv;

        if (isEncrypted) {
          salt = _crypto.generateSalt();
          final key = _crypto.deriveKey(_passwordController.text, salt);
          final encResult = _crypto.encryptFile(file.bytes!, key, ivBase64: null);
          bytesToUpload = encResult.encryptedBytes;
          iv = encResult.iv;
        }

        setState(() {
          uploadProgress[file.name] = "Uploading...";
        });

        String? downloadUrl = await _cloudinary.uploadFile(file.name, bytesToUpload);

        String fileType = file.name.split('.').last.toUpperCase();
        await _firestore
            .uploadFileRecord(
              file.name,
              fileType,
              isEncrypted,
              downloadUrl: downloadUrl,
              sizeBytes: file.size,
              category: selectedCategory,
              salt: salt,
              iv: iv,
            )
            .timeout(const Duration(seconds: 60));

        setState(() {
          uploadProgress[file.name] = "Completed";
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('All files encrypted & uploaded successfully!'), backgroundColor: Theme.of(context).colorScheme.secondary),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Upload File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure your documents',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload files to your digital vault. They will be encrypted before leaving your device using Zero Knowledge Architecture.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 36),

              if (_showStorageWarning) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "You are using 80% of your vault storage",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File Selection Area
                    GestureDetector(
                      onTap: pickFiles,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: teal.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 60, color: teal),
                            const SizedBox(height: 16),
                            Text(
                              selectedFiles.isEmpty ? 'Tap to select files (Bulk Upload)' : '${selectedFiles.length} files selected',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Selected Files', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: selectedFiles.map((file) {
                            final status = uploadProgress[file.name] ?? "Pending";
                            Color statusColor = Colors.white54;
                            if (status == "Completed") statusColor = Colors.greenAccent;
                            if (status == "Uploading...") statusColor = const Color(0xFFC9A84C);
                            if (status == "Encrypting...") statusColor = Colors.blueAccent;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file_outlined, color: Color(0xFFC9A84C), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      file.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status,
                                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Category Selection
                    const Text('Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          dropdownColor: const Color(0xFF0A0A0A),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: categories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedCategory = newValue!;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Encryption Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: teal,
                      title: const Text('Zero Knowledge Encrypted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('PBKDF2 + AES-256 client-side encryption applied', style: TextStyle(color: Colors.white54)),
                      value: isEncrypted,
                      onChanged: (bool value) {
                        setState(() {
                          isEncrypted = value;
                        });
                      },
                    ),

                    if (isEncrypted) ...[
                      const SizedBox(height: 20),
                      const Text('Vault Encryption Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter your vault password',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFC9A84C)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Upload Button
                    GradientButton(
                      text: isEncrypted ? 'Encrypt & Upload' : 'Upload File',
                      isLoading: isUploading,
                      onPressed: selectedFiles.isEmpty ? null : uploadFiles,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
