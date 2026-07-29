import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';

class EmergencyProfileScreen extends StatefulWidget {
  final String userId;

  const EmergencyProfileScreen({super.key, required this.userId});

  @override
  State<EmergencyProfileScreen> createState() => _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState extends State<EmergencyProfileScreen> {
  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error launching call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('EMERGENCY MEDICAL PROFILE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: AnimatedBackground(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('medicalProfile')
              .doc('profile')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || !snapshot.data!.exists || snapshot.data!.data() == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GlassContainer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.redAccent.withOpacity(0.8)),
                        const SizedBox(height: 16),
                        const Text(
                          'No Emergency Profile Found',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The requested medical profile does not exist or has been removed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bloodGroup = data['bloodGroup'] ?? 'N/A';
            final allergies = data['allergies'] ?? 'None specified';
            final emergencyName = data['emergencyName'] ?? 'N/A';
            final emergencyPhone = data['emergencyPhone'] ?? '';
            final doctorName = data['doctorName'] ?? 'N/A';
            final doctorPhone = data['doctorPhone'] ?? '';
            final conditions = data['medicalConditions'] ?? 'None specified';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Blood Group Card (Large Red)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 20),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.bloodtype, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'BLOOD GROUP',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bloodGroup.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Emergency Contact Card (Green)
                  GlassContainer(
                    borderColor: Colors.greenAccent.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.phone_in_talk, color: Colors.greenAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('EMERGENCY CONTACT', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(emergencyName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        if (emergencyPhone.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _makeCall(emergencyPhone),
                            icon: const Icon(Icons.call, size: 18),
                            label: Text('Call $emergencyPhone', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Allergies Card (Orange)
                  GlassContainer(
                    borderColor: Colors.orangeAccent.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('ALLERGIES', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(allergies, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Doctor Info Card (Blue)
                  GlassContainer(
                    borderColor: Colors.blueAccent.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.medical_information, color: Colors.blueAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('PRIMARY DOCTOR', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(doctorName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        if (doctorPhone.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blueAccent),
                              foregroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _makeCall(doctorPhone),
                            icon: const Icon(Icons.call, size: 18),
                            label: Text('Call Doctor: $doctorPhone', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Medical Conditions Card
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Text('MEDICAL CONDITIONS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(conditions, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
