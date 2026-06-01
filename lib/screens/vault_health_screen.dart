import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cryptaf/utils/web_helper.dart';

class VaultHealthScreen extends StatefulWidget {
  const VaultHealthScreen({super.key});

  @override
  State<VaultHealthScreen> createState() => _VaultHealthScreenState();
}

class _VaultHealthScreenState extends State<VaultHealthScreen> {
  static const _gold = Color(0xFFC9A84C);
  final FirestoreService _firestore = FirestoreService();
  bool _isGenerating = false;

  int _calculateScore(bool has2FA, bool hasEmerg, int nomineeCount, int fileCount) {
    int score = 50; // Base score
    if (has2FA) score += 20;
    if (hasEmerg) score += 10;
    if (nomineeCount > 0) score += 15;
    if (fileCount > 0) score += 5;
    return score.clamp(0, 100);
  }

  List<String> _getRecommendations(bool has2FA, bool hasEmerg, int nomineeCount, int fileCount) {
    List<String> recs = [];
    if (!has2FA) recs.add('Enable Two-Factor Authentication in Security Settings.');
    if (!hasEmerg) recs.add('Enable Dead Man\'s Switch (Emergency Protocol).');
    if (nomineeCount == 0) recs.add('Add at least one Trusted Nominee for inheritance.');
    if (fileCount == 0) recs.add('Upload your first secure document.');
    if (recs.isEmpty) recs.add('Your vault is fully optimized and secure!');
    return recs;
  }

  Future<void> _generatePdfReport(int score, List<String> recs, int files, int nominees) async {
    setState(() => _isGenerating = true);
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Cryptaf Vault Health Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Generated on: ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.SizedBox(height: 32),
                  
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Overall Security Score:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$score / 100', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: score > 75 ? PdfColors.green : PdfColors.orange)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  
                  pw.Text('Vault Statistics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 12),
                  pw.Table(
                    children: [
                      pw.TableRow(children: [
                        pw.Text('Secure Files Encrypted:', style: const pw.TextStyle(fontSize: 14)),
                        pw.Text('$files', style: const pw.TextStyle(fontSize: 14)),
                      ]),
                      pw.TableRow(children: [
                        pw.Text('Trusted Nominees Added:', style: const pw.TextStyle(fontSize: 14)),
                        pw.Text('$nominees', style: const pw.TextStyle(fontSize: 14)),
                      ]),
                    ]
                  ),
                  pw.SizedBox(height: 32),
                  
                  pw.Text('Security Recommendations', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 12),
                  ...recs.map((r) {
                    PdfColor color = PdfColors.orange;
                    if (r.contains('optim')) {
                      color = PdfColors.green;
                    }
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Text(r, style: pw.TextStyle(fontSize: 14, color: color)),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final base64str = base64Encode(bytes);
      final url = 'data:application/pdf;base64,$base64str';
      
      if (kIsWeb) {
        downloadFileWeb(url, 'vault_health_report.pdf');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download available on web version')),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report generated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Vault Health Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.getSecuritySettings(),
          builder: (context, secSnap) {
            bool has2FA = false;
            if (secSnap.hasData && secSnap.data!.exists) {
              final d = secSnap.data!.data() as Map<String, dynamic>?;
              if (d != null) has2FA = d['twoFactorEnabled'] ?? false;
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.getEmergencySettings(),
              builder: (context, emergSnap) {
                bool hasEmerg = false;
                if (emergSnap.hasData && emergSnap.data!.exists) {
                  final d = emergSnap.data!.data() as Map<String, dynamic>?;
                  if (d != null) hasEmerg = d['emergencyEnabled'] ?? false;
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.getNominees(),
                  builder: (context, nomSnap) {
                    int nomineeCount = nomSnap.data?.docs.length ?? 0;

                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestore.getFiles(),
                      builder: (context, fileSnap) {
                        int fileCount = fileSnap.data?.docs.where((d) {
                          final data = d.data() as Map<String, dynamic>?;
                          return data != null && data['deleted'] != true;
                        }).length ?? 0;

                        final score = _calculateScore(has2FA, hasEmerg, nomineeCount, fileCount);
                        final recs = _getRecommendations(has2FA, hasEmerg, nomineeCount, fileCount);

                        Color scoreColor = Colors.greenAccent;
                        if (score < 50) scoreColor = Colors.redAccent;
                        else if (score < 80) scoreColor = Colors.orangeAccent;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GlassContainer(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          height: 80,
                                          child: CircularProgressIndicator(
                                            value: score / 100.0,
                                            backgroundColor: Colors.white12,
                                            color: scoreColor,
                                            strokeWidth: 8,
                                          ),
                                        ),
                                        Text('$score%', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Security Score', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text(
                                            score >= 80 ? 'Excellent' : (score >= 50 ? 'Needs Attention' : 'Critical'),
                                            style: TextStyle(color: scoreColor, fontSize: 22, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              const Text('Recommendations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ...recs.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      r.contains('optim') ? Icons.check_circle : Icons.warning_amber_rounded,
                                      color: r.contains('optim') ? Colors.greenAccent : _gold,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 48),

                              GradientButton(
                                text: 'Download PDF Report',
                                isLoading: _isGenerating,
                                onPressed: () => _generatePdfReport(score, recs, fileCount, nomineeCount),
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
        ),
      ),
    );
  }
}
