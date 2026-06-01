import 'dart:math';
import 'package:otp/otp.dart';

class TOTPService {
  // Generate TOTP secret key for user (base32 encoded)
  String generateTOTPSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rnd = Random.secure();
    return List.generate(32, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  // Generate QR code data for Google Authenticator
  String generateQRCodeData(String secret, String userEmail) {
    final encodedEmail = Uri.encodeComponent(userEmail);
    return 'otpauth://totp/Cryptaf:$encodedEmail?secret=$secret&issuer=Cryptaf';
  }

  // Verify 6-digit TOTP code (time-based, 30 second window)
  bool verifyTOTP(String secret, String inputCode) {
    if (inputCode.length != 6) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Check current window, previous window (-30s), and next window (+30s) for clock drift
    for (int offset in [-30000, 0, 30000]) {
      final code = OTP.generateTOTPCodeString(
        secret,
        now + offset,
        isGoogle: true,
        algorithm: Algorithm.SHA1,
      );
      if (code == inputCode) {
        return true;
      }
    }
    return false;
  }
}
