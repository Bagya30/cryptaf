import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cryptaf/screens/terms_screen.dart';
import 'package:cryptaf/screens/privacy_policy_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  static const _gold = Color(0xFFC9A84C);

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@cryptaf.app',
      queryParameters: {
        'subject': 'Cryptaf Support Request',
      },
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

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
          'App Info',
          style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_outlined,
                      color: _gold,
                      size: 50,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cryptaf',
                style: GoogleFonts.oxanium(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Zero Knowledge Vault',
                style: GoogleFonts.oxanium(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Version 1.0.0 (Build 1)',
                style: GoogleFonts.oxanium(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 40),

              // Links List
              GlassContainer(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: _gold),
                      title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.description_outlined, color: _gold),
                      title: const Text('Terms of Service', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: _gold),
                      title: const Text('Open Source Licenses', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Cryptaf',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(Icons.shield_outlined, color: _gold, size: 48),
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: _gold),
                      title: const Text('Contact Support', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('support@cryptaf.app', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: _launchEmail,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              Text(
                '© 2026 Cryptaf. All rights reserved.',
                style: GoogleFonts.oxanium(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
