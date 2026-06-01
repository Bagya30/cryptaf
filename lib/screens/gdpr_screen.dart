import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/solid_button.dart';

class GdprScreen extends StatelessWidget {
  const GdprScreen({super.key});

  static const _gold = Color(0xFFC9A84C);

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
          'GDPR Rights',
          style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your GDPR Data Rights',
                      style: GoogleFonts.oxanium(
                        color: _gold,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Under the General Data Protection Regulation (GDPR), users have extensive control over how their data is handled. As a secure, zero-knowledge platform, we prioritize your data privacy by design.',
                      style: GoogleFonts.oxanium(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    _buildRightSection(
                      title: '1. Right to Access Your Data',
                      desc: 'You have the right to request access to the personal data we hold about you. Since all vault data is encrypted with keys we do not possess, you can view your own decrypted files and keys directly inside the Cryptaf application interface.',
                      icon: Icons.visibility_outlined,
                    ),

                    _buildRightSection(
                      title: '2. Right to Export Your Data (Portability)',
                      desc: 'You have the right to receive a copy of your personal data in a structured, commonly used format. You can export all your vault files, nominee settings, and activity history as an encrypted JSON archive at any time from the "Backup & Restore" menu.',
                      icon: Icons.share_outlined,
                    ),

                    _buildRightSection(
                      title: '3. Right to Delete Your Data (Erasure)',
                      desc: 'You have the "Right to be Forgotten". You can request the permanent deletion of your account and all associated cloud backups. This is available in your profile settings via the "Delete Account" button, which permanently deletes all Firestore entries, metadata, and uploaded Cloudinary files.',
                      icon: Icons.delete_outline_rounded,
                    ),

                    _buildRightSection(
                      title: '4. Data Retention Policy',
                      desc: 'We retain your personal data only as long as your account remains active. If you initiate account deletion, your vault files, profile data, activity logs, and encryption settings are completely purged from our cloud storage and databases within 24 hours.',
                      icon: Icons.hourglass_empty_rounded,
                    ),

                    _buildRightSection(
                      title: '5. Contact for GDPR Inquiries',
                      desc: 'For any queries regarding your GDPR rights, data protection policies, or to make specific compliance requests, please email us directly at gdpr@cryptaf.app.',
                      icon: Icons.contact_mail_outlined,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0A0A),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SolidButton(
                text: 'I Understand',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSection({required String title, required String desc, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withOpacity(0.3)),
              ),
              child: Icon(icon, color: _gold, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.oxanium(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: GoogleFonts.oxanium(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
