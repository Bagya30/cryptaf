import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/solid_button.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Terms of Service',
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
                      'Cryptaf Terms of Service',
                      style: GoogleFonts.oxanium(fontSize: 24, fontWeight: FontWeight.bold, color: _gold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: May 18, 2026',
                      style: GoogleFonts.oxanium(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('1. Acceptance of Terms & App Usage'),
                    _paragraph(
                      'By downloading, accessing, or using Cryptaf, you agree to be bound by these Terms of Service. Cryptaf provides a secure digital vault and nominee management platform designed for storing sensitive personal and financial documents. You agree to use the service exclusively for lawful purposes.',
                    ),

                    _sectionTitle('2. User Responsibilities & Master Key Security'),
                    _paragraph(
                      'You are solely responsible for maintaining the confidentiality and security of your master password, vault PIN, and account credentials. Because Cryptaf operates on a zero-knowledge architecture, we cannot recover or reset your master password if lost. You acknowledge that losing your master password may result in permanent loss of access to your encrypted vault.',
                    ),

                    _sectionTitle('3. Vault Security & Encryption Standards'),
                    _paragraph(
                      'Cryptaf employs client-side AES-256 encryption. While we implement state-of-the-art security practices to protect your encrypted data containers, you acknowledge that no transmission over the Internet or electronic storage method is 100% secure. You agree to keep your device operating system and Cryptaf application updated to the latest versions.',
                    ),

                    _sectionTitle('4. Nominee Agreements & Transfer Protocols'),
                    _paragraph(
                      'You may designate trusted individuals as nominees to inherit access to your vault. By adding a nominee, you authorize Cryptaf to execute the transfer protocol upon verification of the trigger event. You represent and warrant that you have obtained explicit consent from each nominee to store their contact information.',
                    ),

                    _sectionTitle('5. Emergency Access & Dead Man\'s Switch Terms'),
                    _paragraph(
                      'The 72-hour Dead Man\'s Switch is an automated inactivity protocol. If enabled, the system monitors your account for active logins. If no login is detected for 72 consecutive hours, the emergency access protocol initiates, allowing verified nominees to request decryption keys. You are fully responsible for logging in periodically to reset the timer if you wish to prevent access transfer.',
                    ),

                    _sectionTitle('6. Limitation of Liability'),
                    _paragraph(
                      'To the maximum extent permitted by law, Cryptaf and its affiliates, directors, or employees shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data loss, or inability to access encrypted files resulting from forgotten passwords, device compromise, or service interruptions.',
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
