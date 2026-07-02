import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/screens/otp_screen.dart';
import 'package:cryptaf/services/notification_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  EmergencyScreenState createState() => EmergencyScreenState();
}

class EmergencyScreenState extends State<EmergencyScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isExpired = false;
  bool _isSendingOtp = false;
  bool _hasSent24hWarning = false;
  int _durationHours = 168;
  DateTime? _lastActiveDate;

  @override
  void initState() {
    super.initState();
    _firestore.updateLastActive();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startTimer(DateTime activationDate, int durationHours) {
    _calculateRemainingTime(activationDate, durationHours);
    if (_timer != null && _timer!.isActive) return;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lastActiveDate != null) {
          _calculateRemainingTime(_lastActiveDate!, _durationHours);
        }
      });
    });
  }

  void _calculateRemainingTime(DateTime lastActiveDate, int durationHours) {
    final expiryDate = lastActiveDate.add(Duration(hours: durationHours));
    final now = DateTime.now();
    
    if (now.difference(lastActiveDate).inSeconds < 5) {
      _remainingTime = Duration(hours: durationHours);
    } else {
      _remainingTime = expiryDate.difference(now);
    }

    if (_remainingTime.isNegative) {
      _remainingTime = Duration.zero;
      if (!_isExpired) {
        _isExpired = true;
        _firestore.markEmergencyExpired();
        _notifyNomineesOfEmergency();
      }
      _timer?.cancel();
    } else if (_remainingTime.inHours < 24 && _remainingTime.inHours > 0) {
      if (!_hasSent24hWarning) {
        _hasSent24hWarning = true;
        NotificationService().sendNotification(
          title: 'Dead Man\'s Switch Warning',
          body: 'âš ï¸ Your vault will transfer in less than 24 hours! Open Cryptaf to reset.',
          context: context,
        );
      }
    }
  }

  Future<void> _notifyNomineesOfEmergency() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final userName = data?['name'] ?? user.displayName ?? user.email ?? 'User';

      final nomineesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('nominees')
          .get();

      for (var doc in nomineesSnap.docs) {
        final nomineeData = doc.data();
        final nomineeEmail = nomineeData['email'] as String?;
        if (nomineeEmail != null && nomineeEmail.isNotEmpty) {
          await _sendNomineeEmail(nomineeEmail, userName);
        }
      }
    } catch (e) {
      debugPrint('Failed to notify nominees: $e');
    }
  }

  Future<void> _sendNomineeEmail(String nomineeEmail, String userName) async {
    try {
      final now = DateTime.now();
      final timeStr = "${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}";
      final message = "You have been granted access to $userName's Cryptaf vault. Please visit cryptaf-36296.web.app to request access using your verified email.";

      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': dotenv.env['EMAILJS_SERVICE_ID'] ?? '',
          'template_id': dotenv.env['EMAILJS_TEMPLATE_ID_ALERT'] ?? '',
          'user_id': dotenv.env['EMAILJS_USER_ID'] ?? '',
          'template_params': {
            'email': nomineeEmail,
            'time': timeStr,
            'message': message,
            'passcode': message,
          },
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Failed to send email to nominee: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String days = duration.inDays.toString();
    String hours = twoDigits(duration.inHours.remainder(24));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${days}d ${hours}h ${minutes}m ${seconds}s";
  }

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.getEmergencySettings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: teal));
          }

          bool isEnabled = false;
          String status = 'disabled';
          DateTime? activationDate;

          int durationHours = 168;
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              isEnabled = data['emergencyEnabled'] ?? false;
              status = data['emergencyStatus'] ?? 'disabled';
              Timestamp? ts = data['activationTimestamp'];
              durationHours = data['emergencyDurationHours'] ?? 168;
              _durationHours = durationHours;

              if (isEnabled && status != 'expired') {
                activationDate = ts?.toDate();
                Timestamp? lastActiveTs = data['lastActiveTime'];
                DateTime lastActiveDate = lastActiveTs?.toDate() ?? activationDate ?? DateTime.now();
                _lastActiveDate = lastActiveDate;
                _startTimer(lastActiveDate, durationHours);
              } else {
                _timer?.cancel();
              }

              _isExpired = status == 'expired';
            }
          }

          return AnimatedBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'The Dead Man\'s Switch is a fail-safe. If you don\'t check in for $_durationHours hours, your vault will be automatically shared with your nominees.',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Toggle Switch
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SwitchListTile(
                      activeColor: const Color(0xFFC9A84C),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dead Man\'s Switch', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Enable inactivity timer', style: TextStyle(color: Colors.white54)),
                      value: isEnabled,
                      onChanged: (bool value) {
                        _firestore.updateEmergencySettings(value);
                        if (!value) {
                          _timer?.cancel();
                          _remainingTime = Duration.zero;
                        }
                      },
                    ),
                  ),

                  if (isEnabled) ...[
                    const SizedBox(height: 16),
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inactivity Timeout', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Timer duration before release', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                          DropdownButton<String>(
                            value: _durationHours == 24 ? '24 Hours' : _durationHours == 48 ? '48 Hours' : _durationHours == 72 ? '72 Hours' : _durationHours == 720 ? '30 Days' : '7 Days',
                            dropdownColor: const Color(0xFF0A0A0A),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFC9A84C)),
                            items: ['24 Hours', '48 Hours', '72 Hours', '7 Days', '30 Days']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                            onChanged: (val) async {
                              int newHours = 168;
                              if (val == '24 Hours') newHours = 24;
                              if (val == '48 Hours') newHours = 48;
                              if (val == '72 Hours') newHours = 72;
                              if (val == '30 Days') newHours = 720;
                              setState(() => _durationHours = newHours);
                              await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).set({
                                'emergencyDurationHours': newHours,
                              }, SetOptions(merge: true));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Timer Display
                  if (isEnabled) ...[
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _isExpired ? 'PROTOCOL EXPIRED' : 'TIME UNTIL ACCESS TRANSFER',
                            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                          const SizedBox(height: 20),
                          GlassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            child: Text(
                              _isExpired ? 'EXPIRED' : _formatDuration(_remainingTime),
                              style: TextStyle(
                                color: _isExpired ? Colors.redAccent : teal,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (_isExpired) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emergency_share, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Access Transfer Initiated',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                            // Nominee Access Section
                            GlassContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Nominee Access Request',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'If you are a designated nominee, enter your email to receive a verification code.',
                                    style: TextStyle(color: Colors.white54, fontSize: 14),
                                  ),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: _emailController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Nominee Email Address',
                                      hintStyle: const TextStyle(color: Colors.white38),
                                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.05),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  GradientButton(
                                    text: 'Send Verification Code',
                                    isLoading: _isSendingOtp,
                                    onPressed: () async {
                                      if (_emailController.text.isEmpty) return;
                                      setState(() => _isSendingOtp = true);
                                      await _firestore.sendNomineeOTP(_emailController.text);
                                      if (!mounted) return;
                                      NotificationService().sendNotification(
                                        title: 'Nominee Access Request',
                                        body: 'ðŸ‘¤ A nominee is attempting to access your vault.',
                                        // ignore: use_build_context_synchronously
                                        context: context,
                                      );
                                      setState(() => _isSendingOtp = false);
                                      if (mounted) {
                                        Navigator.push(
                                          // ignore: use_build_context_synchronously
                                          context,
                                          MaterialPageRoute(builder: (context) => OtpScreen(email: _emailController.text)),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 30),
                            const Text(
                              'Logging in resets this timer automatically.',
                              style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Detailed Steps
                  if (isEnabled && !_isExpired) ...[
                    const Text('Security Protocol', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildStep(Icons.check_circle_outline, 'Step 1: System monitors for login activity', true),
                    _buildStep(Icons.check_circle_outline, 'Step 2: $_durationHours-hour countdown starts after last login', true),
                    _buildStep(Icons.radio_button_unchecked, 'Step 3: Transfer keys to nominees on expiry', false),
                    const SizedBox(height: 40),
                    const Text('Emergency QR Card', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text(
                      'Print this card and give it to your trusted nominees or keep it in a safe place. It contains the portal link for them to request access.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Print Emergency Card',
                      onPressed: _printEmergencyCard,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _printEmergencyCard() async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? 'Vault Owner';
    const portalUrl = 'https://cryptaf-36296.web.app/nominee-portal';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(40),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Cryptaf Emergency Access Card', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 20),
                      pw.Text('Vault Owner: $userName', style: const pw.TextStyle(fontSize: 18)),
                      pw.SizedBox(height: 30),
                      pw.Text('Scan the QR Code below to request emergency access:', style: const pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 20),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: portalUrl,
                        width: 200,
                        height: 200,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text('Or visit: $portalUrl', style: const pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 30),
                      pw.Text('Instructions:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('1. Go to the URL or scan the QR code.', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('2. Enter your verified email to request access.', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('3. Access will be granted after the Dead Man\'s Switch timer expires.', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
        return pdf.save();
      },
    );
  }

  Widget _buildStep(IconData icon, String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: isDone ? const Color(0xFFC9A84C) : Colors.white24, size: 20),
          const SizedBox(width: 16),
          Text(text, style: TextStyle(color: isDone ? Colors.white : Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
