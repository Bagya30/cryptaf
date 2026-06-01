import 'dart:async';

class GeminiService {
  final Map<String, List<String>> _responses = {
    'nominee': [
      "To manage your nominees, go to 'Nominee Management' in the sidebar menu. You can add new nominees by entering their name. To delete a nominee, simply tap the delete icon next to their name in the list.",
      "Nominees are individuals you trust to access your vault in an emergency. You can add, view, and remove them directly from the Nominee Management screen.",
      "Adding a nominee ensures your digital legacy is protected. You can manage your list of trusted contacts in the Nominee Management section."
    ],
    'encryption': [
      "Cryptaf uses AES-256 (Advanced Encryption Standard with a 256-bit key), which is the global gold standard for data security. Your files are encrypted locally on your device before being uploaded, ensuring that not even we can see your data.",
      "Our 'Local-First' encryption model means your raw files never leave your device. We use AES-256 encryption which would take billions of years for a supercomputer to crack.",
      "Encryption happens at the moment of upload. We use the crypto library to apply AES-256 bit encryption to your byte streams before they are sent to secure cloud storage."
    ],
    'emergency': [
      "Emergency Access is governed by a 72-hour security timer. When a nominee requests access, you receive a notification and have 72 hours to approve or deny the request. If you don't respond, access is granted automatically.",
      "The 72-hour timer is a fail-safe mechanism. It gives you plenty of time to block unauthorized requests while ensuring your loved ones aren't locked out in a genuine emergency.",
      "You can configure your emergency settings in the 'Emergency Access' screen. This is where the 72-hour grace period is managed and where you can enable or disable the entire protocol."
    ],
    'upload': [
      "To upload a file, tap the 'Upload' button on your dashboard. You can choose from Documents, Images, and PDFs. Once selected, choose a category and tap 'Encrypt & Upload'.",
      "Cryptaf supports common formats like PDF, JPG, PNG, DOC, and DOCX. All uploads are automatically categorized into Documents, Medical, Financial, or Legal for easy organization.",
      "Uploading is simple: tap the '+' or 'Upload' button, pick your file, assign a category, and let our AES-256 engine handle the rest."
    ],
    'security': [
      "You can enhance your vault security by enabling Two-Factor Authentication (2FA) and Biometric Lock (FaceID/Fingerprint) in the 'Security Settings' screen.",
      "We recommend using both 2FA and Biometrics. You can toggle these options in your Security Settings to add layers of protection beyond your master password.",
      "Security is our priority. In the Security Settings, you can manage how you access the app, including biometrics and multi-factor authentication."
    ],
    'vault': [
      "Your Cryptaf vault is a secure, categorized space for your most important life documents. Everything is encrypted end-to-end.",
      "The vault organizes your files into four main pillars: Financial, Medical, Legal, and Documents. You can search and manage them all from the 'My Vault' view.",
      "Think of the vault as your digital safe-deposit box. It's built on a zero-knowledge architecture, meaning only you have the keys.",
      "Your vault lets you safely store and share files using temporary links with expirations, ensuring nothing stays public forever."
    ],
    'default': [
      "Cryptaf is built on the principle of 'Your Vault, Your Rules.' We use end-to-end AES-256 encryption and a zero-knowledge architecture to ensure your data is always private and secure.",
      "I'm here to help you navigate Cryptaf. You can ask me about file encryption, nominee management, emergency protocols, or how to secure your account.",
      "Security is at the heart of everything we do. Whether it's our local-first encryption or our smart emergency timers, your data is in safe hands.",
      "If you're unsure where to start, try uploading a test document, or setting up your 2FA and Biometric login in Security Settings."
    ],
  };

  Future<String> askAssistant(String userMessage) async {
    final query = userMessage.toLowerCase();
    
    // Simulate thinking time
    await Future.delayed(const Duration(milliseconds: 900));

    if (_containsAny(query, ['nominee', 'add nominee', 'delete nominee', 'edit nominee', 'legacy', 'trusted contact', 'inherit', 'give access'])) {
      return _get('nominee');
    } else if (_containsAny(query, ['encrypt', 'aes', 'security', 'protection', 'safe', 'secure', 'hacked', 'breach', 'zero-knowledge', 'zero knowledge'])) {
      // Prioritize encryption if specific keywords are present
      if (_containsAny(query, ['encrypt', 'aes', '256', 'zero-knowledge', 'zero knowledge'])) {
        return _get('encryption');
      }
      return _get('security');
    } else if (_containsAny(query, ['emergency', 'timer', '72', 'hour', 'access', 'fail-safe', 'failsafe', 'locked out', 'recover'])) {
      return _get('emergency');
    } else if (_containsAny(query, ['upload', 'file', 'format', 'pdf', 'image', 'add file', 'save', 'document', 'scan'])) {
      return _get('upload');
    } else if (_containsAny(query, ['vault', 'my data', 'what is', 'how to use', 'organize', 'folder'])) {
      return _get('vault');
    } else if (_containsAny(query, ['2fa', 'biometric', 'faceid', 'fingerprint', 'mfa', 'authenticator', 'pin', 'lock', 'password', 'forgot password', 'reset', 'change password'])) {
      return _get('security');
    }

    return _get('default');
  }

  bool _containsAny(String query, List<String> keywords) {
    return keywords.any((k) => query.contains(k));
  }

  String _get(String category) {
    final list = _responses[category]!;
    final index = DateTime.now().millisecondsSinceEpoch % list.length;
    return list[index];
  }
}
