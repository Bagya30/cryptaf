import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';

class MedicalEmergencyScreen extends StatefulWidget {
  const MedicalEmergencyScreen({super.key});

  @override
  State<MedicalEmergencyScreen> createState() => _MedicalEmergencyScreenState();
}

class _MedicalEmergencyScreenState extends State<MedicalEmergencyScreen> {
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorPhoneController = TextEditingController();
  final _conditionsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _profileExists = false;
  bool _isEditing = false;
  String? _qrUrl;

  @override
  void initState() {
    super.initState();
    _loadMedicalProfile();
  }

  @override
  void dispose() {
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medicalProfile')
          .doc('profile')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _bloodGroupController.text = data['bloodGroup'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _emergencyNameController.text = data['emergencyName'] ?? '';
        _emergencyPhoneController.text = data['emergencyPhone'] ?? '';
        _doctorNameController.text = data['doctorName'] ?? '';
        _doctorPhoneController.text = data['doctorPhone'] ?? '';
        _conditionsController.text = data['medicalConditions'] ?? '';
        _qrUrl = 'https://cryptaf-36296.web.app/emergency.html?uid=$uid';
        _profileExists = true;
        _isEditing = false;
      } else {
        _profileExists = false;
        _isEditing = true;
      }
    } catch (e) {
      debugPrint('Error loading medical profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMedicalProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final profileData = {
        'bloodGroup': _bloodGroupController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'emergencyName': _emergencyNameController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'doctorName': _doctorNameController.text.trim(),
        'doctorPhone': _doctorPhoneController.text.trim(),
        'medicalConditions': _conditionsController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medicalProfile')
          .doc('profile')
          .set(profileData, SetOptions(merge: true));

      setState(() {
        _qrUrl = 'https://cryptaf-36296.web.app/emergency.html?uid=$uid';
        _profileExists = true;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical profile saved successfully!'),
            backgroundColor: Colors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const redAccent = Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Medical Emergency QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: redAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Red Emergency Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: redAccent.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(color: redAccent.withOpacity(0.15), blurRadius: 16),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_hospital_rounded, color: redAccent, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EMERGENCY MEDICAL CARD',
                                  style: TextStyle(color: redAccent, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Critical health details for first responders',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This information will be visible to anyone who scans your QR code - no login required.',
                              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_profileExists && !_isEditing) ...[
                      // QR ONLY VIEW MODE
                      GlassContainer(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: redAccent),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.water_drop_outlined, color: redAccent, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Blood: ${_bloodGroupController.text.isEmpty ? "N/A" : _bloodGroupController.text.toUpperCase()}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_emergencyNameController.text.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.greenAccent),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_outline, color: Colors.greenAccent, size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _emergencyNameController.text,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Your Public Emergency QR Code',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Scan this QR code with any camera to view your public emergency card.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: redAccent.withOpacity(0.2), blurRadius: 20),
                                ],
                              ),
                              child: QrImageView(
                                data: _qrUrl!,
                                version: QrVersions.auto,
                                size: 220.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              _qrUrl!,
                              style: const TextStyle(color: redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // FORM EDIT MODE
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              label: 'Blood Group',
                              controller: _bloodGroupController,
                              hint: 'e.g. O+, A-, AB+',
                              icon: Icons.water_drop_outlined,
                              iconColor: redAccent,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Allergies',
                              controller: _allergiesController,
                              hint: 'e.g. Penicillin, Peanuts, Latex',
                              icon: Icons.warning_amber_rounded,
                              iconColor: Colors.orangeAccent,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Emergency Contact Name',
                              controller: _emergencyNameController,
                              hint: 'e.g. Jane Doe (Spouse)',
                              icon: Icons.person_outline,
                              iconColor: Colors.greenAccent,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Emergency Contact Phone',
                              controller: _emergencyPhoneController,
                              hint: 'e.g. +1 555-0199',
                              icon: Icons.phone_outlined,
                              iconColor: Colors.greenAccent,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Primary Doctor Name',
                              controller: _doctorNameController,
                              hint: 'e.g. Dr. Smith',
                              icon: Icons.medical_information_outlined,
                              iconColor: Colors.blueAccent,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Primary Doctor Phone',
                              controller: _doctorPhoneController,
                              hint: 'e.g. +1 555-0122',
                              icon: Icons.phone_outlined,
                              iconColor: Colors.blueAccent,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Medical Conditions',
                              controller: _conditionsController,
                              hint: 'e.g. Asthma, Diabetes, Pacemaker',
                              icon: Icons.assignment_outlined,
                              iconColor: Colors.purpleAccent,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                  shadowColor: redAccent.withOpacity(0.5),
                                ),
                                onPressed: _isSaving ? null : _saveMedicalProfile,
                                child: _isSaving
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.qr_code_2, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            'Save & Generate Emergency QR',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            if (_profileExists) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                    });
                                  },
                                  child: const Text('Cancel Edit', style: TextStyle(color: Colors.white54)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: iconColor.withOpacity(0.3), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: iconColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
