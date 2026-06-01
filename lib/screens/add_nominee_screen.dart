import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/services/cloudinary_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/widgets/gradient_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class AddNomineeScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AddNomineeScreen({super.key, this.docId, this.existingData});

  @override
  State<AddNomineeScreen> createState() => _AddNomineeScreenState();
}

enum NomineeStep { details, emailOtp, mobileOtp }

class _AddNomineeScreenState extends State<AddNomineeScreen> {
  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  final FirestoreService _firestore = FirestoreService();
  final CloudinaryService _cloudinary = CloudinaryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _mobileOtpCtrl = TextEditingController();

  NomineeStep _currentStep = NomineeStep.details;
  String _relationship = 'Spouse';
  String _trustLevel = 'Primary Nominee';

  // Email OTP
  String? _sentEmailOtp;
  bool _isSendingEmailOtp = false;
  bool _emailVerified = false;

  // Mobile OTP
  String? _verificationId; // For Mobile
  ConfirmationResult? _confirmationResult; // For Web
  bool _isSendingMobileOtp = false;
  bool _mobileVerified = false;


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
      _mobileVerified = d['mobileVerified'] ?? false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _otpCtrl.dispose();
    _mobileOtpCtrl.dispose();
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

  // ── Step 1: Send Email OTP ───────────────────────────────────────────────

  Future<void> _sendEmailOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = (100000 + Random().nextInt(900000)).toString();
    final email = _emailCtrl.text.trim();

    setState(() => _isSendingEmailOtp = true);

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': 'service_ojzr03j',
          'template_id': 'template_j7plaal',
          'user_id': 'swqxQASivvKsrJjvQ',
          'template_params': {
            'email': email,
            'passcode': otp,
            'time': '15 minutes',
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _startTimer();
        setState(() {
          _sentEmailOtp = otp;
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

  // ── Step 2: Verify Email OTP ──────────────────────────────────────────────

  void _verifyEmailOtp() {
    if (_otpCtrl.text.trim() == _sentEmailOtp) {
      setState(() {
        _emailVerified = true;
        _currentStep = NomineeStep.mobileOtp;
      });
      _sendMobileOtp();
    } else {
      _showError('Incorrect Email OTP');
    }
  }

  // ── Step 3: Send Mobile OTP ───────────────────────────────────────────────

  Future<void> _sendMobileOtp() async {
    final phone = _phoneCtrl.text.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _showError('Enter a valid 10-digit mobile number');
      return;
    }
    final tenDigits = digits.substring(digits.length - 10);
    final formattedPhone = '+91$tenDigits';

    setState(() => _isSendingMobileOtp = true);

    try {
      final String accountSid = 'AC73850f840509fcbb6936e196308e34da';
      final String authToken = '4aca988f67128bfc261859d718239bdd';
      final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'));

      final response = await http.post(
        Uri.parse('https://verify.twilio.com/v2/Services/VA701db52176290489d6104c4acaf8faf2/Verifications'),
        headers: {
          'Authorization': basicAuth,
        },
        body: {
          'To': formattedPhone,
          'Channel': 'sms',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isSendingMobileOtp = false;
        });
        _startTimer();
        _showSnackbar('OTP sent to $formattedPhone', Icons.phone_android_outlined);
      } else {
        setState(() => _isSendingMobileOtp = false);
        _showError('Failed to send OTP (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isSendingMobileOtp = false);
      _showError('Network error: $e');
    }
  }

  // ── Step 4: Verify Mobile OTP ─────────────────────────────────────────────

  Future<void> _verifyMobileOtp() async {
    final code = _mobileOtpCtrl.text.trim();
    if (code.length != 6) {
      _showError('Enter 6-digit code');
      return;
    }

    final phone = _phoneCtrl.text.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _showError('Enter a valid 10-digit mobile number');
      return;
    }
    final tenDigits = digits.substring(digits.length - 10);
    final formattedPhone = '+91$tenDigits';

    setState(() => _isSaving = true);

    try {
      final String accountSid = 'AC73850f840509fcbb6936e196308e34da';
      final String authToken = '4aca988f67128bfc261859d718239bdd';
      final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'));

      final response = await http.post(
        Uri.parse('https://verify.twilio.com/v2/Services/VA701db52176290489d6104c4acaf8faf2/VerificationCheck'),
        headers: {
          'Authorization': basicAuth,
        },
        body: {
          'To': formattedPhone,
          'Code': code,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'approved') {
          setState(() {
            _mobileVerified = true;
            _isSaving = false;
          });
          _showSnackbar('Mobile Verified!', Icons.check_circle_outline);
          _saveNominee();
        } else {
          setState(() => _isSaving = false);
          _showError('Invalid OTP. Please try again.');
        }
      } else {
        setState(() => _isSaving = false);
        _showError('Verification failed (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Verification error: $e');
    }
  }


  // ── Final Save ────────────────────────────────────────────────────────────

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
      'mobileVerified': _mobileVerified,
      'verified': _emailVerified && _mobileVerified,
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

  // ── Build UI ──────────────────────────────────────────────────────────────

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
      case NomineeStep.mobileOtp:
        return _buildOtpView(
          title: 'Mobile Verification',
          subtitle: 'Enter the code sent to ${_phoneCtrl.text}',
          controller: _mobileOtpCtrl,
          icon: Icons.phone_android_outlined,
          onResend: _sendMobileOtp,
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
                suffix: _mobileVerified ? const Icon(Icons.check_circle, color: _gold, size: 20) : null),
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
    bool isLoading = _isSaving || _isSendingEmailOtp || _isSendingMobileOtp;

    switch (_currentStep) {
      case NomineeStep.details:
        label = _isEditMode ? 'Save Changes' : 'Verify Email';
        action = _isEditMode ? _saveNominee : _sendEmailOtp;
        break;
      case NomineeStep.emailOtp:
        label = 'Verify Email';
        action = _verifyEmailOtp;
        break;
      case NomineeStep.mobileOtp:
        label = 'Verify Mobile';
        action = _verifyMobileOtp;
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
