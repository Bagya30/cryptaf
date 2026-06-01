import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptaf/screens/login_screen.dart';
import 'package:cryptaf/screens/signup_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/solid_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  Future<void> _completeOnboarding(Widget nextScreen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/images/logo.png', width: 40, height: 40),
                    if (_currentPage < 3)
                      TextButton(
                        onPressed: () {
                          _pageController.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                        },
                        child: Text('Skip', style: GoogleFonts.oxanium(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
                      )
                    else
                      const SizedBox(height: 48),
                  ],
                ),
              ),

              // PageView for Slides
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    // Slide 1
                    _buildSlide(
                      icon: Icons.shield_outlined,
                      title: 'Your Digital Legacy, Secured',
                      subtitle: 'Store your most important documents with military-grade AES-256 encryption',
                    ),
                    // Slide 2
                    _buildSlide(
                      icon: Icons.lock_outline,
                      secondIcon: Icons.fingerprint,
                      title: 'Zero Knowledge Security',
                      subtitle: 'Only YOU can decrypt your files. Not even Cryptaf can access your data',
                    ),
                    // Slide 3
                    _buildSlide(
                      icon: Icons.people_outline,
                      title: 'Nominee Management',
                      subtitle: 'Designate trusted nominees who can access your vault with our 72-hour Dead Man\'s Switch',
                    ),
                    // Slide 4
                    _buildSlide(
                      icon: Icons.rocket_launch_outlined,
                      title: 'Get Started',
                      subtitle: 'Join thousands securing their digital legacy',
                      isLastSlide: true,
                    ),
                  ],
                ),
              ),

              // Bottom Section: Dot Indicators & Navigation Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Dot Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? _gold : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // Buttons
                    if (_currentPage < 3)
                      SolidButton(
                        text: 'Next',
                        onPressed: () {
                          _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                        },
                      )
                    else
                      Column(
                        children: [
                          SolidButton(
                            text: 'Create Account',
                            onPressed: () => _completeOnboarding(const SignupScreen()),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _gold.withOpacity(0.5), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: _gold.withOpacity(0.05),
                              ),
                              onPressed: () => _completeOnboarding(const LoginScreen()),
                              child: Text(
                                'Login',
                                style: GoogleFonts.oxanium(
                                  color: _gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide({required IconData icon, IconData? secondIcon, required String title, required String subtitle, bool isLastSlide = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Icon Container with Glow
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withOpacity(0.1),
              border: Border.all(color: _gold.withOpacity(0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _gold.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: secondIcon != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 54, color: _gold),
                        const SizedBox(width: 8),
                        Icon(secondIcon, size: 54, color: _gold),
                      ],
                    )
                  : Icon(icon, size: 72, color: _gold),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1.0, 1.0), end: const Offset(1.05, 1.05), duration: 2.seconds),
          const SizedBox(height: 48),

          // Title
          Text(
            title,
            style: GoogleFonts.oxanium(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            subtitle,
            style: GoogleFonts.oxanium(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const Spacer(),
        ],
      ),
    );
  }
}
