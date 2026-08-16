import 'dart:async';

class AssistantService {
  final Map<String, List<String>> _responses = {
    'nominee': [
      "To manage your nominees, go to the 'Nominee Management' screen. You can add new nominees by entering their details like name, email, phone, relationship, and trust level. To delete a nominee, tap the delete icon at the bottom of their nominee card.",
      "Nominees are individuals you trust to access your vault in an emergency. You can add, view, and remove them directly from the Nominee Management screen.",
      "Adding a nominee ensures your digital legacy is protected. You can manage your list of trusted contacts in the Nominee Management section."
    ],
    'encryption': [
      "Cryptaf uses AES-256 (Advanced Encryption Standard with a 256-bit key), which is the global gold standard for data security. Your files are encrypted locally on your device before being uploaded, ensuring that not even we can see your data.",
      "Our 'Local-First' encryption model means your raw files never leave your device. We use AES-256 encryption which would take billions of years for a supercomputer to crack.",
      "Encryption happens at the moment of upload. We use the crypto library to apply AES-256 bit encryption to your byte streams before they are sent to secure cloud storage."
    ],
    'emergency': [
      "Emergency Access is governed by a configurable inactivity timer (defaults to 168 hours or 7 days). If you don't check into your vault before the timer expires, the system assumes an emergency and automatically grants vault access to your verified nominees.",
      "The inactivity timer is a fail-safe mechanism. It ensures your loved ones aren't locked out in a genuine emergency, while giving you plenty of time to regularly check in and reset the clock.",
      "You can configure your emergency settings in the 'Emergency Access' screen. This is where you can adjust your inactivity timer down to a minimum of 24 hours, or enable and disable the entire protocol."
    ],
    'upload': [
      "To upload a file, tap the 'Upload' button on your dashboard. You can choose from Documents, Images, and PDFs. Once selected, manually choose a category from the dropdown, choose your encryption settings, and tap the upload button.",
      "Cryptaf supports common formats like PDF, JPG, PNG, DOC, and DOCX. You must manually select a category for each upload—Documents, Medical, Financial, or Legal—to keep your vault organized.",
      "Uploading is simple: tap the '+' or 'Upload' button, pick your file, and assign a category. You can also toggle 'Zero Knowledge Encrypted' on or off for each file before uploading."
    ],
    'security': [
      "You can enhance your vault security by enabling Two-Factor Authentication (2FA) via a TOTP app in the 'Security Settings' screen.",
      "We highly recommend using Two-Factor Authentication (2FA). You can toggle this option in your Security Settings to add a powerful layer of protection beyond your master password.",
      "Security is our priority. In the Security Settings, you can manage how you access the app, including setting up multi-factor authentication."
    ],
    'vault': [
      "Your Cryptaf vault is a secure, categorized space for your most important life documents. Everything is encrypted end-to-end.",
      "The vault organizes your files into four main pillars: Financial, Medical, Legal, and Documents. You can search and manage them all from the 'My Vault' view.",
      "Think of the vault as your digital safe-deposit box. It's built on a zero-knowledge architecture, meaning only you have the keys.",
      "Your vault lets you safely store your files and securely pass them on. Sharing is handled strictly through the Dead Man's Switch, which grants your verified nominees access in an emergency."
    ],
    'default': [
      "That's outside what I can help with. I can only answer questions about Cryptaf, like encryption, nominees, uploading files, or the Dead Man's Switch.",
    ],
  };

  Future<String> askAssistant(String userMessage) async {
    final query = userMessage.toLowerCase();

    // Simulate thinking time
    await Future.delayed(const Duration(milliseconds: 900));

    if (_containsAny(query, [
      'nominee',
      'add nominee',
      'delete nominee',
      'edit nominee',
      'legacy',
      'trusted contact',
      'inherit',
      'give access to vault',
      'grant access'
    ])) {
      return _get('nominee');
    } else if (_containsAny(query, [
      'encrypt',
      'aes',
      'security',
      'protection',
      'safe',
      'secure',
      'hacked',
      'breach',
      'zero-knowledge',
      'zero knowledge'
    ])) {
      // Prioritize encryption if specific keywords are present
      if (_containsAny(query,
          ['encrypt', 'aes', '256', 'zero-knowledge', 'zero knowledge'])) {
        return _get('encryption');
      }
      return _get('security');
    } else if (_containsAny(query, [
      'emergency',
      'timer',
      '72 hour',
      '72-hour',
      'emergency access',
      'fail-safe',
      'failsafe',
      'locked out',
      'recover'
    ])) {
      return _get('emergency');
    } else if (_containsAny(query, [
      'upload',
      'file',
      'format',
      'pdf',
      'image',
      'add file',
      'save file',
      'save document',
      'document',
      'scan'
    ])) {
      return _get('upload');
    } else if (_containsAny(query, [
      'vault',
      'my data',
      'what is cryptaf',
      'what is the vault',
      'what is a vault',
      'how to use cryptaf',
      'how to use the vault',
      'organize',
      'folder'
    ])) {
      return _get('vault');
    } else if (_containsAny(query, [
      '2fa',
      'biometric',
      'faceid',
      'fingerprint',
      'mfa',
      'authenticator',
      'pin',
      'app lock',
      'vault lock',
      'password',
      'forgot password',
      'reset',
      'change password'
    ])) {
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
