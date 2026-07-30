import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/auth_service.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/inactivity_timer_service.dart';
import 'package:cryptaf/screens/login_screen.dart';
import 'package:cryptaf/screens/nominee_screen.dart';
import 'package:cryptaf/screens/emergency_screen.dart';
import 'package:cryptaf/screens/file_upload_screen.dart';
import 'package:cryptaf/screens/vault_view_screen.dart';
import 'package:cryptaf/screens/security_settings_screen.dart';
import 'package:cryptaf/screens/assistant_screen.dart';
import 'package:cryptaf/screens/password_manager_screen.dart';
import 'package:cryptaf/screens/profile_screen.dart';
import 'package:cryptaf/screens/activity_log_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:cryptaf/screens/scan_screen.dart';

import 'package:cryptaf/services/notification_service.dart';
import 'package:cryptaf/screens/search_screen.dart';
import 'package:cryptaf/screens/notifications_screen.dart';
import 'package:cryptaf/screens/secure_notes_screen.dart';
import 'package:cryptaf/screens/setup_wizard_screen.dart';
import 'package:cryptaf/screens/trash_screen.dart';
import 'package:cryptaf/screens/document_expiry_screen.dart';
import 'package:cryptaf/screens/vault_health_screen.dart';
import 'package:cryptaf/screens/digital_will_screen.dart';
import 'package:cryptaf/screens/medical_emergency_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shell â€” owns the bottom nav and the IndexedStack of tab bodies
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _bg = Color(0xFF0A0A0A);

  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final InactivityTimerService _inactivityTimer = InactivityTimerService();
  User? _user;

  int _currentIndex = 0;

  StreamSubscription<DocumentSnapshot>? _userSub;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _inactivityTimer.start(context);
    NotificationService().init(context);

    final uid = _user?.uid;
    if (uid != null) {
      _userSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snapshot) {
        if (!mounted) return;
        final data = snapshot.data();
        if (data != null && data['forceLogoutAll'] == true) {
          _auth.signOut();
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    }
  }


  @override
  void dispose() {
    _userSub?.cancel();
    _inactivityTimer.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FileUploadScreen()),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = _auth.currentUser?.uid;

    int bodyIndex = 0;
    if (_currentIndex == 2) bodyIndex = 1;
    if (_currentIndex == 3) bodyIndex = 2;
    if (_currentIndex == 4) bodyIndex = 3;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Listener(
        onPointerDown: (_) => _inactivityTimer.reset(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: AnimatedBackground(
            child: IndexedStack(
              index: bodyIndex,
              children: [
                _VaultTab(user: _auth.currentUser, firestore: _firestore),
                NomineeScreen(userId: uid, isTab: true),
                const PasswordManagerScreen(isTab: true),
                const ProfileScreen(isTab: true),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = ['Cryptaf', 'Upload', 'Nominees', 'Passwords', 'Profile'];
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: _currentIndex == 0 ? GoldShimmerText(
        text: titles[_currentIndex],
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontSize: 18,
        ),
      ) : Text(
        titles[_currentIndex],
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;
            if (snapshot.hasData) {
              unreadCount = snapshot.data!.docs.length;
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70),
          tooltip: 'Sign out',
          onPressed: _signOut,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Vault'),
              _navItem(1, Icons.upload_file_outlined, Icons.upload_file, 'Upload'),
              _navItem(2, Icons.people_outline, Icons.people, 'Nominees'),
              _navItem(3, Icons.password_outlined, Icons.password, 'Passwords'),
              _navItem(4, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final bool isActive = _currentIndex == index;
    const active = Colors.white;
    const inactive = Color(0xFF222222);

    return Semantics(
      label: '$label Navigation',
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? active.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isActive ? Border.all(color: active.withOpacity(0.5), width: 1) : null,
            boxShadow: isActive
                ? [
                    BoxShadow(color: active.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? active : inactive,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? active : inactive,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Tab 0 â€” Vault (dashboard content)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _VaultTab extends StatefulWidget {
  final User? user;
  final FirestoreService firestore;

  const _VaultTab({required this.user, required this.firestore});

  @override
  State<_VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<_VaultTab> with TickerProviderStateMixin {
  static const _gold = Color(0xFFC9A84C);

  late AnimationController _floatLockController;
  late AnimationController _floatRingController;
  late AnimationController _floatFolderController;
  late AnimationController _floatPeopleController;
  late AnimationController _floatStorageController;
  late AnimationController _floatDocsController;
  late AnimationController _floatMedController;
  late AnimationController _floatFinController;
  late AnimationController _floatLegalController;

  late Animation<double> _floatLockAnim;
  late Animation<double> _floatRingAnim;
  late Animation<double> _floatFolderAnim;
  late Animation<double> _floatPeopleAnim;
  late Animation<double> _floatStorageAnim;
  late Animation<double> _floatDocsAnim;
  late Animation<double> _floatMedAnim;
  late Animation<double> _floatFinAnim;
  late Animation<double> _floatLegalAnim;

  late AnimationController _dot1Controller;
  late AnimationController _dot2Controller;
  late AnimationController _dot3Controller;

  late AnimationController _liquidController;

  @override
  void initState() {
    super.initState();
    
    Animation<double> createFloatAnim(AnimationController controller) {
      return CurvedAnimation(parent: controller, curve: Curves.easeInOut);
    }

    _floatLockController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _floatLockAnim = createFloatAnim(_floatLockController);

    _floatRingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _floatRingAnim = createFloatAnim(_floatRingController);

    _floatFolderController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _floatFolderAnim = createFloatAnim(_floatFolderController);

    _floatPeopleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);
    _floatPeopleAnim = createFloatAnim(_floatPeopleController);

    _floatStorageController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _floatStorageAnim = createFloatAnim(_floatStorageController);

    _floatDocsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _floatDocsAnim = createFloatAnim(_floatDocsController);

    _floatMedController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3100))..repeat(reverse: true);
    _floatMedAnim = createFloatAnim(_floatMedController);

    _floatFinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2700))..repeat(reverse: true);
    _floatFinAnim = createFloatAnim(_floatFinController);

    _floatLegalController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2900))..repeat(reverse: true);
    _floatLegalAnim = createFloatAnim(_floatLegalController);

    _dot1Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _dot2Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))..repeat();
    _dot3Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000))..repeat();

    _liquidController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..forward();
  }

  @override
  void dispose() {
    _floatLockController.dispose();
    _floatRingController.dispose();
    _floatFolderController.dispose();
    _floatPeopleController.dispose();
    _floatStorageController.dispose();
    _floatDocsController.dispose();
    _floatMedController.dispose();
    _floatFinController.dispose();
    _floatLegalController.dispose();
    
    _dot1Controller.dispose();
    _dot2Controller.dispose();
    _dot3Controller.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.firestore.getSecuritySettings(),
      builder: (context, secSnapshot) {
        bool twoFactor = false;
        bool biometrics = false;
        if (secSnapshot.hasData && secSnapshot.data!.exists) {
          final data = secSnapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            twoFactor = data['twoFactorEnabled'] ?? false;
            biometrics = data['biometricsEnabled'] ?? false;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: widget.firestore.getFiles(),
          builder: (context, filesSnapshot) {
            int totalFiles = 0;
            int totalBytes = 0;
            List<QueryDocumentSnapshot> recentFiles = [];

            if (filesSnapshot.hasData) {
              final allDocs = filesSnapshot.data!.docs;
              final docs = allDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>?;
                return d != null && d['deleted'] != true;
              }).toList();

              totalFiles = docs.length;
              recentFiles = docs.take(3).toList();
              for (var doc in docs) {
                final d = doc.data() as Map<String, dynamic>?;
                if (d != null && d['sizeBytes'] != null) {
                  totalBytes += (d['sizeBytes'] as num).toInt();
                }
              }
            }

            int securityScore = 50;
            if (twoFactor) securityScore += 25;
            if (biometrics) securityScore += 15;
            if (totalFiles > 0) securityScore += 10;

            return StreamBuilder<QuerySnapshot>(
              stream: widget.firestore.getNominees(),
              builder: (context, nomineesSnapshot) {
                int totalNominees = 0;
                int verifiedNominees = 0;
                if (nomineesSnapshot.hasData) {
                  final docs = nomineesSnapshot.data!.docs;
                  totalNominees = docs.length;
                  for (var doc in docs) {
                    final d = doc.data() as Map<String, dynamic>?;
                    if (d != null && d['verified'] == true) {
                      verifiedNominees++;
                    }
                  }
                }

                return StreamBuilder<DocumentSnapshot>(
                  stream: widget.firestore.getEmergencySettings(),
                  builder: (context, emergSnapshot) {
                    bool emergEnabled = false;
                    String emergStatus = 'disabled';
                    if (emergSnapshot.hasData && emergSnapshot.data!.exists) {
                      final data = emergSnapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        emergEnabled = data['emergencyEnabled'] ?? false;
                        emergStatus = data['emergencyStatus'] ?? 'disabled';
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: widget.firestore.getActivityLogs(),
                      builder: (context, logsSnapshot) {
                        List<QueryDocumentSnapshot> recentLogs = [];
                        if (logsSnapshot.hasData) {
                          recentLogs = logsSnapshot.data!.docs.take(5).toList();
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Setup Wizard Progress Card
                              FutureBuilder<Map<String, bool>>(
                                future: widget.firestore.getOrVerifySetupProgress(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const SizedBox.shrink();
                                  final progress = snapshot.data!;
                                  final completedCount = progress.values.where((v) => v).length;
                                  final percent = (completedCount / 5.0) * 100;
                                  
                                  if (percent >= 100) return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 24.0),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Vault Setup Progress',
                                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '${percent.toInt()}% Complete',
                                                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 6,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    width: constraints.maxWidth * (completedCount / 5.0),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(4),
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFF06B6D4), Color(0xFF67E8F9)],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Complete the setup wizard checklist to fully secure your account.',
                                            style: TextStyle(color: Colors.white70, fontSize: 13),
                                          ),
                                          const SizedBox(height: 14),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => const SetupWizardScreen()),
                                              );
                                            },
                                            icon: const Icon(Icons.auto_awesome, color: Color(0xFF06B6D4), size: 16),
                                            label: const Text(
                                              'Open Setup Wizard',
                                              style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // 1. Top Section (VAULT SECURED Card + Security Score ring)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: const Color(0xFFC9A84C), width: 0.5),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF111111), Color(0xFF1A1A1A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _floatLockAnim,
                                      builder: (context, child) {
                                        final offset = sin(_floatLockAnim.value * 2 * pi) * 4.0;
                                        return Transform.translate(
                                          offset: Offset(0, offset),
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.25), blurRadius: 12),
                                          ],
                                        ),
                                        child: const Icon(Icons.lock_outline, color: Color(0xFFC9A84C), size: 22),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'VAULT SECURED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              letterSpacing: 1.0,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Last sync: 2 mins ago',
                                            style: TextStyle(color: Colors.white54, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFC9A84C).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.5)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFC9A84C),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.4, duration: 1.seconds).fade(end: 0.5),
                                                const SizedBox(width: 5),
                                                const Text(
                                                  'SECURED',
                                                  style: TextStyle(
                                                    color: Color(0xFFC9A84C),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _floatRingAnim,
                                          builder: (context, child) {
                                            final offset = sin(_floatRingAnim.value * 2 * pi) * 4.0;
                                            return Transform.translate(
                                              offset: Offset(0, offset),
                                              child: child,
                                            );
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: 64,
                                                height: 64,
                                                child: const SizedBox().animate().custom(
                                                  duration: 1200.ms,
                                                  curve: Curves.easeOutCubic,
                                                  builder: (context, value, child) => AnimatedBuilder(
                                                    animation: _liquidController,
                                                    builder: (context, child) => CustomPaint(
                                                      painter: _LiquidPainter(
                                                        value: _liquidController.value,
                                                        percentage: value * (securityScore / 100),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('0').animate().custom(
                                                    duration: 1200.ms,
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, value, child) {
                                                      final val = (value * securityScore).round();
                                                      return Text('$val', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
                                                    },
                                                  ),
                                                  const Text('Score', style: TextStyle(color: Colors.white54, fontSize: 9)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text('Security Score', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ).animate(delay: 0.ms).fadeIn(duration: 600.ms, curve: Curves.easeOutCubic).slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                              const SizedBox(height: 24),

                              // 2. Stats Row (3 stat cards)
                              Row(
                                children: [
                                  Expanded(
                                    child: const SizedBox().animate().custom(
                                      duration: 1000.ms,
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        final count = (value * totalFiles).round();
                                        return _StatCard(title: 'Total Files', value: '$count', icon: Icons.folder_open, color: const Color(0xFF06B6D4), floatAnim: _floatFolderAnim);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: const SizedBox().animate().custom(
                                      duration: 1000.ms,
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        final count = (value * totalNominees).round();
                                        return _StatCard(title: 'Nominees', value: '$count', icon: Icons.people_outline, color: const Color(0xFFa855f7), floatAnim: _floatPeopleAnim);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: _StatCard(title: 'Storage', value: '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB', icon: Icons.cloud_outlined, color: const Color(0xFF22c55e), floatAnim: _floatStorageAnim)),
                                ],
                              ).animate(delay: 100.ms).fadeIn(duration: 600.ms, curve: Curves.easeOutCubic).slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                              const SizedBox(height: 28),

                              // Storage Status Card
                              Builder(
                                builder: (context) {
                                  const double totalQuotaBytes = 25.0 * 1024.0 * 1024.0 * 1024.0; // 25 GB
                                  final double usedMB = totalBytes / (1024.0 * 1024.0);
                                  final double percentage = totalBytes / totalQuotaBytes;

                                  Color progressColor = Colors.greenAccent;
                                  if (percentage > 0.8) {
                                    progressColor = Colors.redAccent;
                                  } else if (percentage > 0.5) {
                                    progressColor = Colors.orangeAccent;
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Storage Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 14),
                                      GlassContainer(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 60,
                                                  height: 60,
                                                  child: CircularProgressIndicator(
                                                    value: percentage.clamp(0.0, 1.0),
                                                    backgroundColor: Colors.white12,
                                                    color: progressColor,
                                                    strokeWidth: 6,
                                                  ),
                                                ),
                                                Text(
                                                  '${(percentage * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    color: progressColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Vault Storage Quota',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.9),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${usedMB.toStringAsFixed(1)} MB used of 25 GB',
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: percentage.clamp(0.0, 1.0),
                                                      backgroundColor: Colors.white12,
                                                      color: progressColor,
                                                      minHeight: 4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ).animate(delay: 200.ms).fadeIn(duration: 600.ms, curve: Curves.easeOutCubic).slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
                                },
                              ),

                              // 3. Quick Actions (4 buttons in a row)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 14),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _QuickActionButton(
                                          label: 'Upload',
                                          icon: Icons.upload_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileUploadScreen())),
                                        ).animate(delay: 0.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Scan',
                                          icon: Icons.document_scanner_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
                                        ).animate(delay: 80.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Notes',
                                          icon: Icons.note_alt_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecureNotesScreen())),
                                        ).animate(delay: 160.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Expiry',
                                          icon: Icons.timer_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentExpiryScreen())),
                                        ).animate(delay: 240.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Health',
                                          icon: Icons.health_and_safety_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultHealthScreen())),
                                        ).animate(delay: 320.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Share',
                                          icon: Icons.share_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultViewScreen())),
                                        ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Trash',
                                          icon: Icons.delete_outline,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())),
                                        ).animate(delay: 480.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Will',
                                          icon: Icons.history_edu_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalWillScreen())),
                                        ).animate(delay: 560.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Assistant',
                                          icon: Icons.psychology_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
                                        ).animate(delay: 640.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                        const SizedBox(width: 16),
                                        _QuickActionButton(
                                          label: 'Medical QR',
                                          icon: Icons.medical_services_outlined,
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalEmergencyScreen())),
                                        ).animate(delay: 720.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                                      ],
                                    ),
                                  ),
                                ],
                              ).animate(delay: 300.ms).fadeIn(duration: 600.ms, curve: Curves.easeOutCubic).slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                              const SizedBox(height: 28),

                              // 4. Recent Files (Horizontal scrollable list)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Recent Files', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  if (recentFiles.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultViewScreen(category: 'Documents'))),
                                      child: const Text('View All', style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (recentFiles.isEmpty)
                                const GlassContainer(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text('No files uploaded yet. Tap Upload to get started.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 130,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: recentFiles.length,
                                    separatorBuilder: (context, index) => const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      final doc = recentFiles[index];
                                      final data = doc.data() as Map<String, dynamic>?;
                                      final name = data?['name'] ?? 'Document.pdf';
                                      final cat = data?['category'] ?? 'Documents';
                                      final ts = data?['uploadedAt'] as Timestamp?;
                                      final timeStr = ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : 'Just now';

                                      return GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VaultViewScreen(category: cat))),
                                        child: GlassContainer(
                                          width: 180,
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                                    child: const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 20),
                                                  ),
                                                  const Icon(Icons.shield, color: Colors.white, size: 14),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 4),
                                                  Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 28),

                              _buildCategoriesSection(context),
                              const SizedBox(height: 28),

                              // 6. Dead Man's Switch Card
                              const Text('Dead Man\'s Switch', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                                              ),
                                              const SizedBox(width: 14),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Emergency Protocol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                                  const SizedBox(height: 2),
                                                  Text(emergEnabled ? 'Status: ${emergStatus.toUpperCase()}' : 'Status: INACTIVE', style: TextStyle(color: emergEnabled ? Colors.greenAccent : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const Icon(Icons.chevron_right, color: Colors.white38),
                                        ],
                                      ),
                                      if (emergEnabled) ...[
                                        const SizedBox(height: 16),
                                        const Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Countdown Progress', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                            Text('Active', style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: 0.75,
                                          backgroundColor: Colors.white12,
                                          color: _gold,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // 7. Nominee Verification Progress
                              const Text('Nominee Verification', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NomineeScreen())),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 60,
                                            height: 60,
                                            child: CircularProgressIndicator(
                                              value: totalNominees > 0 ? verifiedNominees / totalNominees : 0,
                                              backgroundColor: Colors.white12,
                                              color: const Color(0xFF4A90E2),
                                              strokeWidth: 6,
                                            ),
                                          ),
                                          Text(totalNominees > 0 ? '${(verifiedNominees / totalNominees * 100).round()}%' : '0%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Verification Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Text('$verifiedNominees of $totalNominees Nominees Verified', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white38),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // 8. Recent Activity Feed (Last 5 activity log entries)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Recent Activity Feed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  if (recentLogs.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityLogScreen())),
                                      child: const Text('View All', style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (recentLogs.isEmpty)
                                const GlassContainer(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text('No recent activity recorded.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  ),
                                )
                              else
                                GlassContainer(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: recentLogs.length,
                                    separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                                    itemBuilder: (context, index) {
                                      final doc = recentLogs[index];
                                      final data = doc.data() as Map<String, dynamic>?;
                                      final type = data?['type'] ?? 'info';
                                      final details = data?['details'] ?? 'System event';
                                      final ts = data?['timestamp'] as Timestamp?;
                                      final timeStr = ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : 'Just now';

                                      IconData iconData = Icons.info_outline;
                                      Color iconColor = Colors.white54;
                                      if (type.contains('upload')) { iconData = Icons.cloud_upload_outlined; iconColor = Colors.greenAccent; }
                                      else if (type.contains('delete')) { iconData = Icons.delete_outline; iconColor = Colors.redAccent; }
                                      else if (type.contains('nominee')) { iconData = Icons.people_outline; iconColor = const Color(0xFF4A90E2); }
                                      else if (type.contains('login')) { iconData = Icons.login_outlined; iconColor = Colors.white; }

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                                          child: Icon(iconData, color: iconColor, size: 20),
                                        ),
                                        title: Text(details, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                        subtitle: Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 28),

                              // 9. Security Insights card at bottom
                              const Text('Security Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                              GlassContainer(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Vault Recommendations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                              SizedBox(height: 2),
                                              Text('Enhance your account protection', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    if (!twoFactor) ...[
                                      _InsightItem(title: 'Enable Two-Factor Authentication', desc: 'Adds +25 points to your Security Score', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()))),
                                      const SizedBox(height: 12),
                                    ],
                                    if (totalNominees == 0) ...[
                                      _InsightItem(title: 'Add a Vault Nominee', desc: 'Ensures secure inheritance protocol for assets', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NomineeScreen()))),
                                      const SizedBox(height: 12),
                                    ],
                                    _InsightItem(
                                      title: 'Perform Routine Backup',
                                      desc: 'Verify offline backup of your 24-word recovery key',
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categories', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniCard('Documents', Icons.description_outlined, const Color(0xFF06B6D4), context, _floatDocsAnim),
            const SizedBox(width: 8),
            _miniCard('Medical', Icons.medical_services_outlined, const Color(0xFFef4444), context, _floatMedAnim),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniCard('Financial', Icons.account_balance_outlined, const Color(0xFFf59e0b), context, _floatFinAnim),
            const SizedBox(width: 8),
            _miniCard('Legal', Icons.gavel, const Color(0xFFa855f7), context, _floatLegalAnim),
          ],
        ),
      ],
    );
  }

  Widget _miniCard(String name, IconData icon, Color color, BuildContext context, [Animation<double>? floatAnim]) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VaultViewScreen(category: name))),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  Widget iconWidget = Icon(icon, color: color, size: 22);
                  if (floatAnim != null) {
                    iconWidget = AnimatedBuilder(
                      animation: floatAnim,
                      builder: (context, child) {
                        final offset = sin(floatAnim.value * 2 * pi) * 6.0;
                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: child,
                        );
                      },
                      child: iconWidget,
                    );
                  }
                  return iconWidget;
                }
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    StreamBuilder<QuerySnapshot>(
                      stream: widget.firestore.getFiles(category: name),
                      builder: (context, snapshot) {
                        int count = 0;
                        if (snapshot.hasData) {
                          count = snapshot.data!.docs.length;
                        }
                        return Text(
                          count == 1 ? '1 File' : '$count Files',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Animation<double>? floatAnim;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.floatAnim});

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: color, size: 20);
    if (floatAnim != null) {
      iconWidget = AnimatedBuilder(
        animation: floatAnim!,
        builder: (context, child) {
          final offset = sin(floatAnim!.value * 2 * pi) * 6.0;
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: iconWidget,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color = Colors.grey;

  const _QuickActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.3), width: 1.0),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _InsightItem({required this.title, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double value; // 0 to 1
  final double percentage; // target percentage

  _LiquidPainter({required this.value, required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    const gold = Color(0xFFC9A84C);
    
    // Background circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, Paint()..color = Colors.white12);

    // Liquid fill
    final currentLevel = percentage * value;
    if (currentLevel <= 0) return;

    final fillHeight = size.height * (1 - currentLevel);
    
    final path1 = Path();
    final path2 = Path();

    // Wave 1
    path1.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      path1.lineTo(x, fillHeight + sin((value * 4 * pi) + (x / size.width * 2 * pi)) * 4);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();

    // Wave 2
    path2.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      path2.lineTo(x, fillHeight + cos((value * 3 * pi) + (x / size.width * 2 * pi)) * 5);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height)));
    
    canvas.drawPath(path2, Paint()..color = gold.withOpacity(0.15));
    canvas.drawPath(path1, Paint()..color = gold.withOpacity(0.3));
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) => true;
}
