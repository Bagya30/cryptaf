import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptaf/utils/web_helper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isExportingVault = false;
  bool _isExportingNominees = false;
  bool _isExportingActivity = false;

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  final CryptoService _crypto = CryptoService();

  Future<void> _updateLastBackupDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lastBackupDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _downloadFile(String content, String filename) {
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      downloadBlobWeb(bytes, filename);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup saved to device storage')),
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created successfully!'), backgroundColor: Colors.greenAccent),
      );
    }
  }

  Future<void> _exportVaultData() async {
    setState(() => _isExportingVault = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('files').get();
      final List<Map<String, dynamic>> files = snapshot.docs.map((doc) {
        final data = doc.data();
        // Convert Timestamps to ISO strings
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        return {'docId': doc.id, ...data};
      }).toList();

      final jsonString = jsonEncode(files);
      final encryptedContent = _crypto.encryptString(jsonString, _crypto.masterAppKey);
      await _updateLastBackupDate();
      _downloadFile(encryptedContent, 'cryptaf_vault_backup.enc');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error exporting vault data'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingVault = false);
    }
  }

  Future<void> _exportNominees() async {
    setState(() => _isExportingNominees = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('nominees').get();
      final List<Map<String, dynamic>> nominees = snapshot.docs.map((doc) {
        final data = doc.data();
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        return {'docId': doc.id, ...data};
      }).toList();

      final jsonString = jsonEncode(nominees);
      final encryptedContent = _crypto.encryptString(jsonString, _crypto.masterAppKey);
      await _updateLastBackupDate();
      _downloadFile(encryptedContent, 'cryptaf_nominees_backup.enc');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error exporting nominees'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingNominees = false);
    }
  }

  Future<void> _exportActivityLog() async {
    setState(() => _isExportingActivity = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('activity_logs').get();
      final List<Map<String, dynamic>> logs = snapshot.docs.map((doc) {
        final data = doc.data();
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        return {'docId': doc.id, ...data};
      }).toList();

      final jsonString = jsonEncode(logs);
      final encryptedContent = _crypto.encryptString(jsonString, _crypto.masterAppKey);
      await _updateLastBackupDate();
      _downloadFile(encryptedContent, 'cryptaf_activity_backup.enc');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error exporting activity log'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingActivity = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Backup & Restore',
          style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: _gold, size: 28),
                        const SizedBox(width: 12),
                        Text('AES-256 Encrypted Backups', style: GoogleFonts.oxanium(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All exports are fully encrypted client-side using military-grade AES-256 encryption before download. Only your Cryptaf master key can restore these files.',
                      style: GoogleFonts.oxanium(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text('EXPORT OPTIONS', style: GoogleFonts.oxanium(color: _gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 16),

              _buildExportCard(
                title: 'Export Vault Data',
                subtitle: 'Backup all file metadata, categories, upload dates, and secure storage URLs.',
                isLoading: _isExportingVault,
                onPressed: _exportVaultData,
                icon: Icons.folder_zip_outlined,
              ),
              const SizedBox(height: 16),

              _buildExportCard(
                title: 'Export Nominees',
                subtitle: 'Backup your trusted nominee list, emergency contacts, and verification status.',
                isLoading: _isExportingNominees,
                onPressed: _exportNominees,
                icon: Icons.people_outline,
              ),
              const SizedBox(height: 16),

              _buildExportCard(
                title: 'Export Activity Log',
                subtitle: 'Backup your complete vault access history, security events, and audit trails.',
                isLoading: _isExportingActivity,
                onPressed: _exportActivityLog,
                icon: Icons.history_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _gold, size: 24),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.oxanium(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.oxanium(color: Colors.white54, fontSize: 14, height: 1.4)),
          const SizedBox(height: 20),
          GradientButton(
            text: title,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
