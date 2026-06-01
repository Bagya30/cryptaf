import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/solid_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

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
          'Privacy Policy',
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
                      'Cryptaf Privacy Policy',
                      style: GoogleFonts.oxanium(fontSize: 24, fontWeight: FontWeight.bold, color: _gold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: May 18, 2026',
                      style: GoogleFonts.oxanium(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('1. Introduction & Zero-Knowledge Architecture'),
                    _paragraph(
                      'Cryptaf is built on a zero-knowledge security architecture. This means your files, documents, and vault items are encrypted client-side using military-grade AES-256 encryption before ever leaving your device. We do not have access to your master password, PIN, or private encryption keys, and cannot decrypt your stored data under any circumstances.',
                    ),

                    _sectionTitle('2. Data Collection & Usage'),
                    _paragraph(
                      'We collect minimal information necessary to provide and secure our services:\n'
                      '• Account Information: Email address used for authentication and communication.\n'
                      '• Security Metadata: Encrypted vault configuration, biometric preferences, and login attempt logs to prevent unauthorized access.\n'
                      '• Device Tokens: Firebase Cloud Messaging (FCM) tokens to deliver real-time security alerts and Dead Man\'s Switch warnings.',
                    ),

                    _sectionTitle('3. Encryption & Storage'),
                    _paragraph(
                      'All documents are encrypted on your device. The encrypted binary blobs are stored securely in cloud storage containers, while metadata is maintained in Firestore. Because the decryption keys remain exclusively on your device, your data is protected against unauthorized third-party access.',
                    ),

                    _sectionTitle('4. Nominee Data & Emergency Access'),
                    _paragraph(
                      'When you designate a nominee for your digital legacy, we store their contact details (email and encrypted phone numbers) to facilitate the 72-hour Dead Man\'s Switch protocol. Nominees only receive access to your vault if the emergency protocol is triggered and fully verified via multi-factor authentication.',
                    ),

                    _sectionTitle('5. Third-Party Services'),
                    _paragraph(
                      'We partner with industry-leading infrastructure providers to deliver secure and reliable services:\n'
                      '• Firebase (Google): For secure user authentication, Firestore database management, and cloud messaging.\n'
                      '• Cloudinary: For hosting encrypted document binary blobs and Aadhaar verification scans.\n'
                      '• Twilio: For delivering secure SMS one-time passwords (OTP) during nominee phone verification.',
                    ),

                    _sectionTitle('6. User Rights & Data Deletion'),
                    _paragraph(
                      'You retain absolute ownership and control over your data. You have the right to export your encrypted vault contents at any time. You may also request permanent deletion of your account and all associated cloud data directly from the Profile settings. Upon deletion, all encrypted files, nominee records, and metadata are permanently purged from our active servers.',
                    ),

                    _sectionTitle('7. Cookie Policy'),
                    _paragraph(
                      'Cryptaf uses local storage and cookies strictly to ensure core functionalities of the web interface. These include maintaining session authentication, keeping track of local theme preferences, security session timeouts, and caching layout metrics. We do not use advertising or tracking cookies, and no personal user behavior data is sent to external advertising networks.',
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: _bg,
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: SolidButton(
                text: 'Accept & Continue',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.oxanium(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Text(
      text,
      style: GoogleFonts.oxanium(fontSize: 15, color: Colors.white70, height: 1.6),
    );
  }
}
