import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/screens/dashboard_screen.dart';
import 'package:cryptaf/screens/file_upload_screen.dart';
import 'package:cryptaf/screens/nominee_screen.dart';
import 'package:cryptaf/screens/security_settings_screen.dart';
import 'package:cryptaf/screens/secure_notes_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final FirestoreService _firestore = FirestoreService();
  bool _isLoading = true;
  Map<String, bool> _progress = {
    'uploadFirstFile': false,
    'addNominee': false,
    'enable2FA': false,
    'setVaultPin': false,
    'writeSecureNote': false,
  };

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    _checkProgress();
  }

  Future<void> _checkProgress() async {
    setState(() => _isLoading = true);
    final currentProgress = await _firestore.getOrVerifySetupProgress();
    if (mounted) {
      setState(() {
        _progress = currentProgress;
        _isLoading = false;
      });
    }
  }

  double get _completionPercent {
    final completedCount = _progress.values.where((v) => v).length;
    return (completedCount / 5.0) * 100;
  }

  void _navigateToFeature(String key) async {
    Widget target;
    if (key == 'uploadFirstFile') {
      target = const FileUploadScreen();
    } else if (key == 'addNominee') {
      target = const NomineeScreen(isTab: false);
    } else if (key == 'enable2FA' || key == 'setVaultPin') {
      target = const SecuritySettingsScreen();
    } else if (key == 'writeSecureNote') {
      target = const SecureNotesScreen(isTab: false);
    } else {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => target),
    );
    _checkProgress();
  }

  @override
  Widget build(BuildContext context) {
    final percent = _completionPercent;

    final steps = [
      {
        'key': 'uploadFirstFile',
        'title': 'Upload your first file',
        'subtitle': 'Securely backup a document, ID or finance statement.',
        'icon': Icons.cloud_upload_outlined,
      },
      {
        'key': 'addNominee',
        'title': 'Add a nominee',
        'subtitle': 'Assign a trusted contact for emergency access transfers.',
        'icon': Icons.person_add_alt_outlined,
      },
      {
        'key': 'enable2FA',
        'title': 'Enable 2FA',
        'subtitle': 'Add an authenticator OTP layer to guard your account.',
        'icon': Icons.security_outlined,
      },
      {
        'key': 'setVaultPin',
        'title': 'Set vault PIN',
        'subtitle': 'Create a fast 4-digit PIN for quick app unlocking.',
        'icon': Icons.pin_outlined,
      },
      {
        'key': 'writeSecureNote',
        'title': 'Write a secure note',
        'subtitle': 'Encrypt private logins, recovery words, or secret keys.',
        'icon': Icons.note_alt_outlined,
      },
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Security Setup Wizard',
          style: GoogleFonts.oxanium(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _gold))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.shield_outlined, color: _gold, size: 48)
                                .animate()
                                .scale(duration: 500.ms, curve: Curves.easeOutBack),
                            const SizedBox(height: 16),
                            Text(
                              'Secure Your Digital Legacy',
                              style: GoogleFonts.oxanium(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Establish trust protocols, encryption PINs, and designate key nominees to protect your assets under zero-knowledge privacy.',
                              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Completion Indicator Card
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your vault setup is ${percent.toInt()}% complete',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percent / 100.0,
                                      backgroundColor: Colors.white12,
                                      color: _gold,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${percent.toInt()}%',
                              style: GoogleFonts.oxanium(
                                color: _gold,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Checklist items
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: steps.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final step = steps[index];
                          final key = step['key'] as String;
                          final completed = _progress[key] ?? false;

                          return GestureDetector(
                            onTap: () => _navigateToFeature(key),
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (completed ? Colors.greenAccent : _gold).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      step['icon'] as IconData,
                                      color: completed ? Colors.greenAccent : _gold,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step['title'] as String,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            decoration: completed ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.white30,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          step['subtitle'] as String,
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Checkbox State
                                  Icon(
                                    completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: completed ? Colors.greenAccent : Colors.white24,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 100).ms, duration: 400.ms);
                        },
                      ),
                      const SizedBox(height: 32),

                      // Continue Button
                      GradientButton(
                        text: percent >= 100 ? 'Go to Dashboard' : 'Skip & Go to Dashboard',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const DashboardScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
