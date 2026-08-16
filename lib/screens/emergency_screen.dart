import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final ScrollController _scrollController = ScrollController();

  int _durationHours = 168;
  bool _isUpdatingDuration = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _firestore.updateLastActive();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency Access',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          DateTime? deadline;
          int durationHours = 168;

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              isEnabled = data['emergencyEnabled'] ?? false;
              status = data['emergencyStatus'] ?? 'disabled';
              Timestamp? deadlineTs = data['emergencyDeadline'];
              deadline = deadlineTs?.toDate();

              durationHours = data['emergencyDurationHours'] ?? 168;
              if (durationHours < 24) {
                durationHours = 24;
              }
              _durationHours = durationHours;
            }
          }

          bool isExpired = false;
          if (isEnabled && deadline != null) {
            isExpired = DateTime.now().isAfter(deadline);
          } else if (isEnabled && status == 'expired') {
            // Fallback for informational status
            isExpired = true;
          }

          return AnimatedBackground(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Box — conditional on toggle state
                  if (isEnabled)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined,
                              color: Colors.redAccent, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'The Dead Man\'s Switch is active. If you don\'t check in for $_durationHours hours, your vault will be automatically shared with your nominees.',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: Colors.white38, size: 32),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Dead Man\'s Switch is currently disabled. Enable it below to activate the inactivity timer and protect your vault.',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 36),

                  // Toggle Switch
                  GlassContainer(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SwitchListTile(
                      activeColor: const Color(0xFFC9A84C),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dead Man\'s Switch',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      subtitle: const Text('Enable inactivity timer',
                          style: TextStyle(color: Colors.white54)),
                      value: isEnabled,
                      onChanged: _isToggling
                          ? null
                          : (bool value) async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() {
                                _isToggling = true;
                              });
                              try {
                                await _firestore.updateEmergencySettings(value);
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to update Dead Man\'s Switch: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isToggling = false;
                                  });
                                }
                              }
                            },
                      secondary: _isToggling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFC9A84C),
                              ),
                            )
                          : null,
                    ),
                  ),

                  if (isEnabled) ...[
                    const SizedBox(height: 16),
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inactivity Timeout',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Timer duration before release',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: [
                              if (_isUpdatingDuration)
                                const Padding(
                                  padding: EdgeInsets.only(right: 12.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFC9A84C)),
                                  ),
                                ),
                              DropdownButton<String>(
                                value: _durationHours == 24
                                    ? '24 Hours'
                                    : _durationHours == 48
                                        ? '48 Hours'
                                        : _durationHours == 72
                                            ? '72 Hours'
                                            : _durationHours == 720
                                                ? '30 Days'
                                                : '7 Days',
                                dropdownColor: const Color(0xFF0A0A0A),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Color(0xFFC9A84C)),
                                items: [
                                  '24 Hours',
                                  '48 Hours',
                                  '72 Hours',
                                  '7 Days',
                                  '30 Days'
                                ]
                                    .map((e) => DropdownMenuItem(
                                        value: e, child: Text(e)))
                                    .toList(),
                                onChanged: _isUpdatingDuration
                                    ? null
                                    : (val) async {
                                        int newHours = 168;
                                        if (val == '24 Hours') newHours = 24;
                                        if (val == '48 Hours') newHours = 48;
                                        if (val == '72 Hours') newHours = 72;
                                        if (val == '30 Days') newHours = 720;

                                        setState(() {
                                          _isUpdatingDuration = true;
                                          _durationHours = newHours;
                                        });

                                        try {
                                          await _firestore
                                              .setEmergencyDuration(newHours);
                                        } catch (e) {
                                          debugPrint(
                                              'Error updating duration: \$e');
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isUpdatingDuration = false;
                                            });
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Timer Display
                  if (isEnabled) ...[
                    if (deadline != null)
                      CountdownDisplay(
                        deadline: deadline,
                        initialIsExpired: isExpired,
                        onExpired:
                            () {}, // Client only updates UI, doesn't authorize expiry
                      )
                    else if (isExpired)
                      CountdownDisplay(
                        deadline: DateTime.now(),
                        initialIsExpired: true,
                        onExpired: () {},
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text(
                          'Arming timer securely...',
                          style: TextStyle(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic),
                        ),
                      )
                  ],

                  // Detailed Steps
                  if (isEnabled && !isExpired) ...[
                    const Text('Security Protocol',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildStep(
                        Icons.check_circle_outline,
                        'Step 1: Cryptaf monitors verified owner activity',
                        true),
                    _buildStep(
                        Icons.check_circle_outline,
                        'Step 2: The configured inactivity countdown begins after the latest activity',
                        true),
                    _buildStep(
                        Icons.radio_button_unchecked,
                        'Step 3: Eligible inherited files become accessible after the deadline',
                        false),
                    const SizedBox(height: 40),
                    const Text('Emergency QR Card',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
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
    final String uid = user?.uid ?? '';
    final String portalUrl =
        'https://cryptaf-36296.web.app/nominee-access?vaultOwner=$uid';

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
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(20)),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Cryptaf Emergency Access Card',
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 20),
                      pw.Text('Vault Owner: $userName',
                          style: const pw.TextStyle(fontSize: 18)),
                      pw.SizedBox(height: 30),
                      pw.Text(
                          'Scan the QR Code below to request emergency access:',
                          style: const pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 20),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: portalUrl,
                        width: 200,
                        height: 200,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text('Or visit: $portalUrl',
                          style: const pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 30),
                      pw.Text('Instructions:',
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('1. Go to the URL or scan the QR code.',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('2. Enter your verified email to request access.',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                          '3. Access will be granted after the Dead Man\'s Switch timer expires.',
                          style: const pw.TextStyle(fontSize: 12)),
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
          Icon(icon,
              color: isDone ? const Color(0xFFC9A84C) : Colors.white24,
              size: 20),
          const SizedBox(width: 16),
          Text(text,
              style: TextStyle(
                  color: isDone ? Colors.white : Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

class CountdownDisplay extends StatefulWidget {
  final DateTime deadline;
  final bool initialIsExpired;
  final VoidCallback onExpired;

  const CountdownDisplay({
    super.key,
    required this.deadline,
    required this.initialIsExpired,
    required this.onExpired,
  });

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _isExpired = widget.initialIsExpired;
    if (!_isExpired) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(CountdownDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline ||
        oldWidget.initialIsExpired != widget.initialIsExpired) {
      _isExpired = widget.initialIsExpired;
      if (!_isExpired) {
        if (_timer == null || !_timer!.isActive) {
          _startTimer();
        } else {
          _calculateRemainingTime();
        }
      } else {
        _timer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _calculateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _calculateRemainingTime();
      });
    });
  }

  void _calculateRemainingTime() {
    if (_isExpired) return;

    final expiryDate = widget.deadline;
    final now = DateTime.now();

    _remainingTime = expiryDate.difference(now);

    if (_remainingTime.isNegative) {
      _remainingTime = Duration.zero;
      if (!_isExpired) {
        _isExpired = true;
        _timer?.cancel();
        widget.onExpired();
      }
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
    return Center(
      child: Column(
        children: [
          Text(
            _isExpired ? 'PROTOCOL EXPIRED' : 'TIME UNTIL ACCESS TRANSFER',
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2),
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
                  Icon(Icons.emergency_share,
                      color: Colors.redAccent, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Access Transfer Initiated',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ] else if (_remainingTime.inHours < 24 &&
              _remainingTime.inSeconds > 0) ...[
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 22),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Your vault is scheduled to transfer in less than 24 hours.',
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            const SizedBox(height: 24),
            const Text(
              'Logging in resets this timer automatically.',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}
