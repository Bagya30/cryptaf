import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
// for kIsWeb
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddNomineeScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AddNomineeScreen({super.key, this.docId, this.existingData});

  @override
  State<AddNomineeScreen> createState() => _AddNomineeScreenState();
}

enum NomineeStep { details, emailOtp }

class _AddNomineeScreenState extends State<AddNomineeScreen> {
  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  final FirestoreService _firestore = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  NomineeStep _currentStep = NomineeStep.details;
  String _relationship = 'Spouse';
  String _trustLevel = 'Primary Nominee';

  // Email OTP
  bool _isSendingEmailOtp = false;
  bool _emailVerified = false;


  bool _isSaving = false;

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  final List<String> _relationships = [
    'Spouse', 'Parent', 'Child', 'Sibling', 'Friend', 'Lawyer', 'Other'
  ];
  final List<String> _trustLevels = [
    'Primary Nominee', 'Secondary Nominee', 'Emergency Contact'
  ];

  bool get _isEditMode => widget.docId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final d = widget.existingData!;
      _nameCtrl.text = d['name'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _phoneCtrl.text = d['phone'] ?? '';
      _addressCtrl.text = d['address'] ?? '';
      _relationship = d['relationship'] ?? 'Spouse';
      _trustLevel = d['trustLevel'] ?? 'Primary Nominee';
      _emailVerified = d['emailVerified'] ?? false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _canResend = false;
      _secondsRemaining = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  // â”€â”€ Step 1: Send Email OTP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _sendEmailOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = (100000 + Random().nextInt(900000)).toString();
    final email = _emailCtrl.text.trim();

    setState(() => _isSendingEmailOtp = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pendingOTPs')
            .doc(email)
            .set({
          'otp': otp,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
        });
      }

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': dotenv.env['EMAILJS_SERVICE_ID'] ?? '',
          'template_id': dotenv.env['EMAILJS_TEMPLATE_ID_DEFAULT'] ?? '',
          'user_id': dotenv.env['EMAILJS_USER_ID'] ?? '',
          'template_params': {
            'email': email,
            'passcode': otp,
            'time': '10 minutes',
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _startTimer();
        setState(() {
          _currentStep = NomineeStep.emailOtp;
          _isSendingEmailOtp = false;
        });
        _showSnackbar('OTP sent to $email', Icons.email_outlined);
      } else {
        setState(() => _isSendingEmailOtp = false);
        _showError('Email failed (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isSendingEmailOtp = false);
      _showError('Network error: $e');
    }
  }

  // â”€â”€ Step 2: Verify Email OTP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _verifyEmailOtp() async {
    final email = _emailCtrl.text.trim();
    final enteredOtp = _otpCtrl.text.trim();
    final user = _auth.currentUser;
    
    if (user == null) return;
    
    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pendingOTPs')
          .doc(email);
          
      final doc = await docRef.get();
      
      if (!doc.exists) {
        setState(() => _isSaving = false);
        _showError('No pending OTP found. Please resend.');
        return;
      }
      
      final data = doc.data()!;
      final storedOtp = data['otp'];
      final Timestamp expiresAt = data['expiresAt'];
      
      if (expiresAt.toDate().isBefore(DateTime.now())) {
        setState(() => _isSaving = false);
        _showError('OTP expired, please resend');
        return;
      }
      
      if (storedOtp == enteredOtp) {
        await docRef.delete();
        setState(() {
          _emailVerified = true;
          _isSaving = false;
        });
        _saveNominee();
      } else {
        setState(() => _isSaving = false);
        _showError('Invalid OTP');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Verification error: $e');
    }
  }


  // â”€â”€ Final Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _saveNominee() async {
    setState(() => _isSaving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'relationship': _relationship,
      'trustLevel': _trustLevel,
      'address': _addressCtrl.text.trim(),
      'emailVerified': _emailVerified,
      'verified': _emailVerified,
    };

    try {
      if (_isEditMode) {
        await _firestore.updateNominee(widget.docId!, data);
      } else {
        await _firestore.addNominee(data);
      }
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar(_isEditMode ? 'Nominee updated!' : 'Nominee added!', Icons.check_circle);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Save failed: $e');
    }
  }

  // â”€â”€ Build UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Nominee' : 'Nominee Verification',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case NomineeStep.details:
        return _buildDetailsForm();
      case NomineeStep.emailOtp:
        return _buildOtpView(
          title: 'Email Verification',
          subtitle: 'Enter the code sent to ${_emailCtrl.text}',
          controller: _otpCtrl,
          icon: Icons.mark_email_read_outlined,
          onResend: _sendEmailOtp,
        );
    }
  }

  Widget _buildDetailsForm() {
    return GlassContainer(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('PERSONAL INFORMATION'),
            const SizedBox(height: 16),
            _field(_nameCtrl, 'Full Name', Icons.person_outline),
            const SizedBox(height: 16),
            _field(_emailCtrl, 'Email Address', Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                suffix: _emailVerified ? const Icon(Icons.check_circle, color: _gold, size: 20) : null),
            const SizedBox(height: 16),
            _field(_phoneCtrl, 'Mobile (10 digits)', Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Enter a valid 10-digit mobile number';
                  return null;
                },
            ),
            const SizedBox(height: 24),
            _sectionHeader('ROLE & RELATIONSHIP'),
            const SizedBox(height: 16),
            _dropdown('Relationship', _relationship, _relationships, (v) => setState(() => _relationship = v!)),
            const SizedBox(height: 16),
            _dropdown('Trust Level', _trustLevel, _trustLevels, (v) => setState(() => _trustLevel = v!)),
            const SizedBox(height: 24),
            _sectionHeader('ADDITIONAL DETAILS'),
            const SizedBox(height: 16),
            _field(_addressCtrl, 'Physical Address (Optional)', Icons.location_on_outlined, maxLines: 3, validator: (v) => null),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpView({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onResend,
  }) {
    return GlassContainer(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(icon, size: 72, color: _gold),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 40),
          _otpInput(controller),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _canResend ? onResend : null,
            child: Text(
              _canResend ? 'Resend Code' : 'Resend in ${_secondsRemaining}s',
              style: TextStyle(color: _canResend ? _gold : Colors.white24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBottomAction() {
    String label = '';
    VoidCallback? action;
    bool isLoading = _isSaving || _isSendingEmailOtp;

    switch (_currentStep) {
      case NomineeStep.details:
        label = _isEditMode ? 'Save Changes' : 'Verify Email';
        action = _isEditMode ? _saveNominee : _sendEmailOtp;
        break;
      case NomineeStep.emailOtp:
        label = 'Verify Email';
        action = _verifyEmailOtp;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: GradientButton(
        text: label,
        isLoading: isLoading,
        onPressed: action,
      ),
    );
  }

  Widget _otpInput(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.05), letterSpacing: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _gold, width: 2)),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1, Widget? suffix, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: _gold, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold, width: 1.5)),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF0A0A0A),
          style: const TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5));
  }

  void _showSnackbar(String msg, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(icon, color: _bg, size: 20), const SizedBox(width: 12), Text(msg, style: const TextStyle(color: _bg))]),
        backgroundColor: _gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }
}
