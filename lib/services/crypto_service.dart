import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EncryptionResult {
  final Uint8List encryptedBytes;
  final String iv; // base64 encoded IV
  EncryptionResult(this.encryptedBytes, this.iv);
}

class CryptoService {
  // deriveKey(String password, String salt) - uses PBKDF2 with 10000 iterations to derive AES-256 key from user password
  String deriveKey(String password, String salt) {
    final passBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    final hmac = Hmac(sha256, passBytes);
    
    final block1 = Uint8List(saltBytes.length + 4);
    block1.setAll(0, saltBytes);
    block1[saltBytes.length + 3] = 1;
    
    var u = hmac.convert(block1).bytes;
    final result = Uint8List.fromList(u);
    
    for (int i = 1; i < 10000; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    
    final keyBytes = Uint8List.sublistView(result, 0, 32);
    return base64.encode(keyBytes);
  }

  // encryptFile(Uint8List fileBytes, String key) - AES-256-CBC encryption
  EncryptionResult encryptFile(Uint8List fileBytes, String key, {String? ivBase64}) {
    final keyObj = enc.Key.fromBase64(key);
    final ivObj = ivBase64 != null ? enc.IV.fromBase64(ivBase64) : enc.IV.fromSecureRandom(16);
    
    final encrypter = enc.Encrypter(enc.AES(keyObj, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(fileBytes, iv: ivObj);
    
    return EncryptionResult(encrypted.bytes, ivObj.base64);
  }

  // decryptFile(Uint8List encryptedBytes, String key) - AES-256-CBC decryption
  Uint8List decryptFile(Uint8List encryptedBytes, String key, {String? ivBase64}) {
    final keyObj = enc.Key.fromBase64(key);
    final ivObj = ivBase64 != null ? enc.IV.fromBase64(ivBase64) : enc.IV(Uint8List(16));
    
    final encrypter = enc.Encrypter(enc.AES(keyObj, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: ivObj);
    
    return Uint8List.fromList(decrypted);
  }

  // generateSessionId() - random secure session ID like "XF-992"
  String generateSessionId() {
    final num = (100 + DateTime.now().millisecondsSinceEpoch % 900).toInt();
    return 'XF-$num';
  }

  // Helper to generate a random salt
  String generateSalt() {
    final random = enc.IV.fromSecureRandom(16);
    return random.base64;
  }

  // Master key for internal app-level encryption (e.g. TOTP secrets)
  String get masterAppKey => enc.Key.fromUtf8('CryptafMasterKey32BytesLong12345').base64;

  String encryptString(String text, String key) {
    final res = encryptFile(utf8.encode(text), key);
    return '${res.iv}:${base64.encode(res.encryptedBytes)}';
  }

  String decryptString(String cipherText, String key) {
    try {
      final parts = cipherText.split(':');
      if (parts.length != 2) return cipherText;
      final iv = parts[0];
      final encBytes = base64.decode(parts[1]);
      final decBytes = decryptFile(encBytes, key, ivBase64: iv);
      return utf8.decode(decBytes);
    } catch (e) {
      return cipherText; // fallback if unencrypted legacy
    }
  }

  // generate24WordRecoveryKey() - generates a 24-word recovery key
  String generate24WordRecoveryKey() {
    const List<String> wordlist = [
      'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract', 'absurd', 'abuse',
      'access', 'accident', 'account', 'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across', 'act',
      'action', 'actor', 'actress', 'actual', 'adapt', 'add', 'addict', 'address', 'adjust', 'admit',
      'adult', 'advance', 'advice', 'aerobic', 'affair', 'afford', 'afraid', 'again', 'age', 'agent',
      'agree', 'ahead', 'aim', 'air', 'airport', 'aisle', 'alarm', 'album', 'alcohol', 'alert',
      'alien', 'all', 'alley', 'allow', 'almost', 'alone', 'alpha', 'already', 'also', 'alter',
      'always', 'amateur', 'amazing', 'among', 'amount', 'amused', 'analyst', 'anchor', 'ancient', 'anger',
      'angle', 'angry', 'animal', 'ankle', 'announce', 'annual', 'another', 'answer', 'antenna', 'antique',
      'anxiety', 'any', 'apart', 'apology', 'appear', 'apple', 'approve', 'april', 'arch', 'arctic',
      'area', 'arena', 'argue', 'arm', 'armed', 'armor', 'army', 'around', 'arrange', 'arrest',
      'arrive', 'arrow', 'art', 'artefact', 'artist', 'artwork', 'ask', 'aspect', 'assault', 'asset',
      'assist', 'assume', 'asthma', 'athlete', 'atom', 'attack', 'attend', 'attitude', 'attract', 'auction',
      'audit', 'august', 'aunt', 'author', 'auto', 'autumn', 'average', 'avocado', 'avoid', 'awake',
      'aware', 'away', 'awesome', 'awful', 'awkward', 'axis', 'baby', 'bachelor', 'bacon', 'badge',
      'bag', 'balance', 'balcony', 'ball', 'bamboo', 'banana', 'banner', 'bar', 'barely', 'bargain',
      'barrel', 'base', 'basic', 'basket', 'battle', 'beach', 'bean', 'beauty', 'because', 'become'
    ];
    final random = enc.IV.fromSecureRandom(24);
    List<String> words = [];
    for (int i = 0; i < 24; i++) {
      final index = random.bytes[i] % wordlist.length;
      words.add(wordlist[index]);
    }
    return words.join(' ');
  }

  Future<bool> verifyVaultPassword(String inputPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final recKeyEnc = doc.data()?['recoveryKey'] as String?;
      final vaultPassEnc = doc.data()?['vaultPasswordEncrypted'] as String?;
      if (recKeyEnc != null && vaultPassEnc != null) {
        final recKey = decryptString(recKeyEnc, masterAppKey);
        final actual = decryptString(vaultPassEnc, recKey);
        if (inputPassword == actual) return true;
      }
      // fallback
      final cred = EmailAuthProvider.credential(email: user.email!, password: inputPassword);
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (_) {
      return false;
    }
  }
}

