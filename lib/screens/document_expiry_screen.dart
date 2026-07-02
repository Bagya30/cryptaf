import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DocumentExpiryScreen extends StatefulWidget {
  const DocumentExpiryScreen({super.key});

  @override
  State<DocumentExpiryScreen> createState() => _DocumentExpiryScreenState();
}

class _DocumentExpiryScreenState extends State<DocumentExpiryScreen> {
  static const _gold = Color(0xFFC9A84C);
  final FirestoreService _firestore = FirestoreService();
  final Set<String> _sentAlerts = {};

  Future<void> _addDocument() async {
    final titleController = TextEditingController();
    final typeController = TextEditingController(text: 'Passport');
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 30));

    final types = ['Passport', 'Driving License', 'Insurance', 'Aadhaar', 'PAN', 'Visa', 'Other'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0A0A0A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12),
              ),
              title: const Text('Track Document Expiry', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Document Name',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _gold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: typeController.text,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _gold)),
                      ),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            typeController.text = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expiry Date', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      subtitle: Text(
                        selectedDate != null ? DateFormat('MMM dd, yyyy').format(selectedDate!) : 'Select Date',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.calendar_month, color: _gold),
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: _gold,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1A1A1A),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (dt != null) {
                          setDialogState(() {
                            selectedDate = dt;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && titleController.text.isNotEmpty && selectedDate != null) {
      await _firestore.addExpiryDocument({
        'title': titleController.text.trim(),
        'type': typeController.text,
        'expiryDate': Timestamp.fromDate(selectedDate!),
        'alertSent': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document added successfully')));
      }
    }
  }

  Future<void> _checkAndSendAlert(String docId, Map<String, dynamic> data, int daysRemaining) async {
    final alertSent = data['alertSent'] ?? false;
    if (daysRemaining <= 30 && daysRemaining > 0 && !alertSent && !_sentAlerts.contains(docId)) {
      _sentAlerts.add(docId);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          await http.post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': dotenv.env['EMAILJS_SERVICE_ID_CRYPTAF'] ?? '',
              'template_id': dotenv.env['EMAILJS_TEMPLATE_ID_DOCUMENT_EXPIRY'] ?? '', // using existing template for generic alerts if possible, or fallback
              'user_id': dotenv.env['EMAILJS_USER_ID_DOCUMENT_EXPIRY'] ?? '',
              'template_params': {
                'to_email': user.email,
                'subject': 'Action Required: Document Expiring Soon',
                'message': 'Your document "${data['title']}" is expiring in $daysRemaining days on ${DateFormat('MMM dd, yyyy').format((data['expiryDate'] as Timestamp).toDate())}. Please review your vault.',
              }
            }),
          );
          // Mark as alert sent
          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('expiry_docs').doc(docId).update({'alertSent': true});
        } catch (e) {
          debugPrint('Failed to send expiry alert: $e');
        }
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
        title: const Text('Document Expiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.getExpiryDocuments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _gold));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
                    const SizedBox(height: 16),
                    const Text('No documents tracked', style: TextStyle(color: Colors.white38, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('Tap + to add a document expiry date', style: TextStyle(color: Colors.white24, fontSize: 13)),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            List<QueryDocumentSnapshot> activeDocs = [];
            List<QueryDocumentSnapshot> expiredDocs = [];

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['expiryDate'] as Timestamp?;
              if (ts != null) {
                final date = ts.toDate();
                final expDate = DateTime(date.year, date.month, date.day);
                if (expDate.isBefore(today)) {
                  expiredDocs.add(doc);
                } else {
                  activeDocs.add(doc);
                  
                  // Check and trigger alert asynchronously
                  final days = expDate.difference(today).inDays;
                  _checkAndSendAlert(doc.id, data, days);
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeDocs.isNotEmpty) ...[
                  const Text('Active Documents', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...activeDocs.map((doc) => _buildDocCard(doc, false)),
                  const SizedBox(height: 24),
                ],
                if (expiredDocs.isNotEmpty) ...[
                  const Text('Expired Documents', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...expiredDocs.map((doc) => _buildDocCard(doc, true)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _gold,
        onPressed: _addDocument,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildDocCard(QueryDocumentSnapshot doc, bool isExpired) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Document';
    final type = data['type'] ?? 'Other';
    final ts = data['expiryDate'] as Timestamp?;
    DateTime? date;
    int daysRemaining = 0;
    
    if (ts != null) {
      date = ts.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expDate = DateTime(date.year, date.month, date.day);
      daysRemaining = expDate.difference(today).inDays;
    }

    Color statusColor = Colors.white54;
    String statusText = '';
    
    if (isExpired) {
      statusColor = Colors.redAccent;
      statusText = 'Expired';
    } else {
      if (daysRemaining < 30) {
        statusColor = Colors.redAccent;
        statusText = 'Expiring soon ($daysRemaining days)';
      } else if (daysRemaining <= 90) {
        statusColor = Colors.orangeAccent;
        statusText = 'Expiring in $daysRemaining days';
      } else {
        statusColor = Colors.greenAccent;
        statusText = 'Valid for $daysRemaining days';
      }
    }

    IconData icon = Icons.description_outlined;
    if (type == 'Passport' || type == 'Visa') icon = Icons.flight_takeoff;
    if (type == 'Driving License') icon = Icons.directions_car_outlined;
    if (type == 'Insurance') icon = Icons.health_and_safety_outlined;
    if (type == 'Aadhaar' || type == 'PAN') icon = Icons.badge_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: statusColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(type, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white38),
          onPressed: () => _deleteDoc(doc.id, title),
        ),
      ),
    );
  }

  Future<void> _deleteDoc(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Delete Tracker', style: TextStyle(color: Colors.white)),
        content: Text('Stop tracking expiry for "$title"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteExpiryDocument(id, title);
    }
  }
}
