import 'package:flutter/material.dart';
import 'package:cryptaf/services/auth_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:cryptaf/screens/terms_screen.dart';
import 'package:cryptaf/screens/privacy_policy_screen.dart';
import 'package:cryptaf/screens/backup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/screens/login_screen.dart';
import 'package:cryptaf/screens/app_info_screen.dart';
import 'package:cryptaf/screens/gdpr_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cryptaf/services/cloudinary_service.dart';
import 'package:cryptaf/screens/assistant_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final CloudinaryService _cloudinary = CloudinaryService();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _nameController.text = _user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfilePicture() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isLoading = true);

      final String? photoUrl = await _cloudinary.uploadFile(
        'profile_${_user?.uid ?? 'user'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        file.bytes!,
      );

      if (photoUrl != null) {
        await _user?.updatePhotoURL(photoUrl);
        await _user?.reload();

        if (_user != null) {
          await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
            'photoUrl': photoUrl,
          }, SetOptions(merge: true));
        }

        if (mounted) {
          setState(() {
            _user = _auth.currentUser;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.greenAccent),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image to Cloudinary'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading profile picture: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _getInitials(String? name, String email) {
    if (name != null && name.isNotEmpty) {
      List<String> parts = name.split(' ');
      if (parts.length > 1) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    if (email.isEmpty) return 'U';
    return email[0].toUpperCase();
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    await _auth.updateDisplayName(_nameController.text);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _user = _auth.currentUser;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL your vault data, files, nominees and account. This cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final firestore = FirestoreService();
        await firestore.deleteAllUserData();
        await _auth.deleteAccount();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: ${e.toString()}'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFFC9A84C);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar
          GestureDetector(
            onTap: _pickAndUploadProfilePicture,
            child: Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: teal, width: 2),
                      boxShadow: [
                        BoxShadow(color: teal.withOpacity(0.3), blurRadius: 25, spreadRadius: 5),
                      ],
                    ),
                    child: ClipOval(
                      child: _user?.photoURL != null && _user!.photoURL!.isNotEmpty
                          ? Image.network(
                              _user!.photoURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: teal.withOpacity(0.2),
                                child: Center(
                                  child: Text(
                                    _getInitials(_user?.displayName, _user?.email ?? 'U'),
                                    style: const TextStyle(color: teal, fontSize: 40, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: teal.withOpacity(0.2),
                              child: Center(
                                child: Text(
                                  _getInitials(_user?.displayName, _user?.email ?? 'U'),
                                  style: const TextStyle(color: teal, fontSize: 40, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: teal,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, color: isDark ? const Color(0xFF0A0A0A) : Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email (Read Only)
                _buildFieldLabel('Email Address', subColor),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Text(
                    _user?.email ?? '',
                    style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16),
                  ),
                ),

                const SizedBox(height: 24),

                // Display Name
                _buildFieldLabel('Display Name', subColor),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(color: hintColor),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: teal),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Save Button
                GradientButton(
                  text: 'Update Profile',
                  isLoading: _isLoading,
                  onPressed: _updateProfile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),


          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Legal & Privacy',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, color: teal),
                  title: Text('Terms of Service', style: TextStyle(color: textColor)),
                  trailing: Icon(Icons.chevron_right, color: subColor),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                ),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined, color: teal),
                  title: Text('Privacy Policy', style: TextStyle(color: textColor)),
                  trailing: Icon(Icons.chevron_right, color: subColor),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tools',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome, color: teal),
                  title: Text('AI Assistant', style: TextStyle(color: textColor)),
                  trailing: Icon(Icons.chevron_right, color: subColor),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App & Support',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline, color: teal),
                  title: Text('App Info', style: TextStyle(color: textColor)),
                  trailing: Icon(Icons.chevron_right, color: subColor),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppInfoScreen())),
                ),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.gavel_outlined, color: teal),
                  title: Text('GDPR Rights', style: TextStyle(color: textColor)),
                  trailing: Icon(Icons.chevron_right, color: subColor),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GdprScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<DocumentSnapshot>(
            stream: _user != null ? FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots() : const Stream.empty(),
            builder: (context, snapshot) {
              String lastBackupStr = 'Never';
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null && data['lastBackupDate'] != null) {
                  final Timestamp ts = data['lastBackupDate'];
                  lastBackupStr = DateFormat('MMM dd, yyyy - hh:mm a').format(ts.toDate());
                }
              }

              return GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Management',
                      style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Backup: $lastBackupStr',
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cloud_download_outlined, color: teal),
                      title: Text('Backup & Restore', style: TextStyle(color: textColor)),
                      subtitle: Text('Export AES-256 encrypted vault archives', style: TextStyle(color: hintColor, fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: subColor),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(isDark ? 0.15 : 0.08),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _deleteAccount,
              child: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isTab) {
      return Scaffold(
        backgroundColor: bg,
        body: AnimatedBackground(child: content),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Profile', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(child: content),
    );
  }

  Widget _buildFieldLabel(String label, Color labelColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
