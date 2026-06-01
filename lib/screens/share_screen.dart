import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareScreen extends StatefulWidget {
  final String token;

  const ShareScreen({super.key, required this.token});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _isDownloading = false;

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  Future<void> _downloadFile(String url, String token) async {
    setState(() => _isDownloading = true);
    try {
      await FirebaseFirestore.instance.collection('share_links').doc(token).update({
        'downloadCount': FieldValue.increment(1),
      });
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch download URL'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error downloading file'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Cryptaf Secure Share',
          style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('share_links').doc(widget.token).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _gold));
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildErrorCard(
                    icon: Icons.error_outline,
                    title: 'Link Invalid',
                    message: 'This link is invalid or has been removed.',
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final Timestamp? expiryTimestamp = data['expiryTime'] as Timestamp?;
                final DateTime expiry = expiryTimestamp?.toDate() ?? DateTime.now().subtract(const Duration(days: 1));

                if (DateTime.now().isAfter(expiry)) {
                  return _buildErrorCard(
                    icon: Icons.timer_off_outlined,
                    title: 'Link Expired',
                    message: 'This secure link has expired.',
                  );
                }

                final String fileName = data['fileName'] ?? 'Secure Document';
                final String fileUrl = data['fileUrl'] ?? '';
                final int downloadCount = data['downloadCount'] ?? 0;
                final String formattedExpiry = DateFormat('MMM dd, yyyy - hh:mm a').format(expiry);

                return GlassContainer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: _gold.withOpacity(0.4), width: 2),
                          boxShadow: [
                            BoxShadow(color: _gold.withOpacity(0.2), blurRadius: 24),
                          ],
                        ),
                        child: const Icon(Icons.shield_outlined, size: 64, color: _gold),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        fileName,
                        style: GoogleFonts.oxanium(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.timer_outlined, 'Expires At', formattedExpiry),
                            const Divider(color: Colors.white12, height: 24),
                            _buildInfoRow(Icons.download_outlined, 'Downloads', '$downloadCount times'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientButton(
                        text: 'Download File',
                        isLoading: _isDownloading,
                        onPressed: () => _downloadFile(fileUrl, widget.token),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 20),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.oxanium(color: Colors.white54, fontSize: 14)),
        const Spacer(),
        Text(value, style: GoogleFonts.oxanium(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildErrorCard({required IconData icon, required String title, required String message}) {
    return GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.redAccent),
          const SizedBox(height: 24),
          Text(title, style: GoogleFonts.oxanium(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.oxanium(fontSize: 16, color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
