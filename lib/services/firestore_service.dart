import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // --- Files Collection ---
  Future<void> uploadFileRecord(String fileName, String fileType, bool isEncrypted, {String? downloadUrl, int? sizeBytes, String category = 'Documents', String? salt, String? iv}) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('files').add({
      'name': fileName,
      'type': fileType,
      'encrypted': isEncrypted,
      'category': category,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (salt != null) 'salt': salt,
      if (iv != null) 'iv': iv,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await logActivity(type: 'file_upload', details: 'Uploaded $fileName ($category)');
    await updateSetupStep('uploadFirstFile');
  }

  String _getPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      int versionIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i].startsWith('v') && RegExp(r'^v\d+$').hasMatch(pathSegments[i])) {
          versionIndex = i;
          break;
        }
      }
      
      List<String> publicIdSegments;
      if (versionIndex != -1 && versionIndex < pathSegments.length - 1) {
        publicIdSegments = pathSegments.sublist(versionIndex + 1);
      } else {
        publicIdSegments = [pathSegments.last];
      }
      
      final fullPublicId = publicIdSegments.join('/');
      if (fullPublicId.contains('.')) {
        final parts = fullPublicId.split('.');
        parts.removeLast();
        return parts.join('.');
      }
      return fullPublicId;
    } catch (e) {
      debugPrint('Error parsing public_id: $e');
      return '';
    }
  }

  Future<void> _deleteFromCloudinary(String downloadUrl) async {
    try {
      final publicId = _getPublicIdFromUrl(downloadUrl);
      if (publicId.isEmpty) return;

      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      const apiKey = '781795518437784';
      const apiSecret = 'KnYzuXmZb85IiFK-iEoVJz4fVPM';

      // construct signature: sorted alphabetically
      final stringToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final bytes = utf8.encode(stringToSign);
      final signature = sha1.convert(bytes).toString();

      final response = await http.delete(
        Uri.parse('https://api.cloudinary.com/v1_1/dbkwa74hv/image/destroy'),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );
      debugPrint('Cloudinary Deletion Status: ${response.statusCode}');
      debugPrint('Cloudinary Deletion Response: ${response.body}');
    } catch (e) {
      debugPrint('Failed to delete resource from Cloudinary: $e');
    }
  }

  Future<void> deleteFileRecord(String docId, String fileName) async {
    if (currentUserId == null) return;
    try {
      final doc = await _db.collection('users').doc(currentUserId).collection('files').doc(docId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['deletedAt'] = FieldValue.serverTimestamp();
        await _db.collection('users').doc(currentUserId).collection('trash').doc(docId).set(data);
        await _db.collection('users').doc(currentUserId).collection('files').doc(docId).delete();
      }
    } catch (e) {
      debugPrint('Error moving to trash: $e');
    }
    await logActivity(type: 'file_delete', details: 'Moved file to trash: $fileName');
  }

  Future<void> permanentDeleteFile(String docId, String fileName) async {
    if (currentUserId == null) return;
    try {
      final doc = await _db.collection('users').doc(currentUserId).collection('trash').doc(docId).get();
      if (doc.exists) {
        final data = doc.data();
        final downloadUrl = data?['downloadUrl'] as String?;
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _deleteFromCloudinary(downloadUrl);
        }
      }
    } catch (e) {
      debugPrint('Cloudinary pre-deletion error: $e');
    }
    await _db.collection('users').doc(currentUserId).collection('trash').doc(docId).delete();
    await logActivity(type: 'file_permanent_delete', details: 'Permanently deleted file: $fileName');
  }

  Future<void> updateFileCategory(String docId, String fileName, String newCategory) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('files').doc(docId).update({
      'category': newCategory,
    });
    await logActivity(type: 'file_move', details: 'Moved $fileName to $newCategory');
  }

  Future<void> toggleFileFavorite(String docId, bool currentStatus) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('files').doc(docId).update({
      'favorite': !currentStatus,
    });
    await logActivity(
      type: 'file_favorite_toggle',
      details: '${!currentStatus ? 'Favorited' : 'Unfavorited'} file',
    );
  }

  Stream<QuerySnapshot> getFiles({String? category}) {
    if (currentUserId == null) return const Stream.empty();
    Query query = _db.collection('users').doc(currentUserId).collection('files');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
      return query.snapshots(); // orderBy with where requires a composite index
    }
    return query.orderBy('uploadedAt', descending: true).snapshots();
  }

  // --- Nominees Collection ---
  Future<void> addNominee(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('nominees').add({
      ...data,
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'verified': true, // Verified via OTP before adding
    });
    await logActivity(type: 'nominee_added', details: 'Added ${data['name']} as nominee');
    await updateSetupStep('addNominee');
  }

  Future<void> updateNominee(String docId, Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('nominees').doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await logActivity(type: 'nominee_updated', details: 'Updated nominee: ${data['name']}');
  }

  Future<void> removeNominee(String docId, String name) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('nominees').doc(docId).delete();
    await logActivity(type: 'nominee_removed', details: 'Removed nominee: $name');
  }

  Stream<QuerySnapshot> getNominees({String? userId}) {
    final uid = userId ?? currentUserId;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).collection('nominees').orderBy('addedAt', descending: true).snapshots();
  }

  // --- Emergency Settings (Dead Man's Switch) ---
  Future<void> updateEmergencySettings(bool isEnabled) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set({
      'emergencyEnabled': isEnabled,
      'emergencyStatus': isEnabled ? 'active' : 'disabled',
      'activationTimestamp': isEnabled ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
  }

  Future<void> resetEmergencyTimer() async {
    if (currentUserId == null) return;
    // Only reset if enabled and not already expired
    final doc = await _db.collection('users').doc(currentUserId).get();
    if (doc.exists && doc.data()?['emergencyEnabled'] == true && doc.data()?['emergencyStatus'] != 'expired') {
      await _db.collection('users').doc(currentUserId).set({
        'activationTimestamp': FieldValue.serverTimestamp(),
        'emergencyStatus': 'active',
      }, SetOptions(merge: true));
      await logActivity(type: 'timer_reset', details: 'Dead Man\'s Switch timer reset via login');
    }
  }

  Future<void> markEmergencyExpired() async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set({
      'emergencyStatus': 'expired',
    }, SetOptions(merge: true));
    await logActivity(type: 'emergency_triggered', details: 'Vault access transfer initiated (Timer Expired)');
  }

  Stream<DocumentSnapshot> getEmergencySettings() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).snapshots();
  }

  Future<void> updateLastActive() async {
    if (currentUserId == null) return;
    try {
      await _db.collection('users').doc(currentUserId).set({
        'lastActiveTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating last active time: $e');
    }
  }

  // --- Security Settings ---
  Future<void> updateSecuritySettings(bool twoFactor, bool biometrics, {String? totpSecret}) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set({
      'twoFactorEnabled': twoFactor,
      'biometricsEnabled': biometrics,
      if (totpSecret != null) 'totpSecret': totpSecret,
    }, SetOptions(merge: true));
    if (twoFactor) {
      await updateSetupStep('enable2FA');
    }
  }

  Stream<DocumentSnapshot> getSecuritySettings() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).snapshots();
  }

  // --- Nominee Access (OTP) ---
  Future<String?> sendNomineeOTP(String email) async {
    if (currentUserId == null) return null;
    
    // Generate 6-digit OTP
    final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toInt().toString();
    
    await _db.collection('users').doc(currentUserId).collection('nominee_otps').doc(email).set({
      'otp': otp,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(Duration(minutes: 10)).millisecondsSinceEpoch,
    });
    
    // In a real app, this would be sent via Email service
    debugPrint("DEBUG: OTP for $email is $otp");
    return otp;
  }

  Future<bool> verifyNomineeOTP(String email, String otp) async {
    if (currentUserId == null) return false;
    
    final doc = await _db.collection('users').doc(currentUserId).collection('nominee_otps').doc(email).get();
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final savedOtp = data['otp'];
    final expiresAt = data['expiresAt'];
    
    if (savedOtp == otp && DateTime.now().millisecondsSinceEpoch < expiresAt) {
      // Clear OTP after successful verification
      await doc.reference.delete();
      return true;
    }
    return false;
  }

  // --- Password Manager ---
  Future<void> addPasswordEntry(String website, String username, String encryptedPassword) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('passwords').add({
      'website': website,
      'username': username,
      'encryptedPassword': encryptedPassword,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(type: 'password_added', details: 'Added password for $website');
  }

  Future<void> deletePasswordEntry(String docId, String website) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('passwords').doc(docId).delete();
    await logActivity(type: 'password_deleted', details: 'Deleted password for $website');
  }

  Stream<QuerySnapshot> getPasswordEntries() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).collection('passwords').orderBy('createdAt', descending: true).snapshots();
  }

  // --- Secure Notes ---
  Future<void> addNoteEntry(String encryptedTitle, String encryptedContent) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('notes').add({
      'title': encryptedTitle,
      'content': encryptedContent,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(type: 'note_added', details: 'Added secure encrypted note');
    await updateSetupStep('writeSecureNote');
  }

  Future<void> deleteNoteEntry(String docId) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('notes').doc(docId).delete();
    await logActivity(type: 'note_deleted', details: 'Deleted secure encrypted note');
  }

  Stream<QuerySnapshot> getNoteEntries() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).collection('notes').orderBy('createdAt', descending: true).snapshots();
  }

  // --- Activity Logs ---
  Future<void> logActivity({required String type, required String details, String? ipAddress, String? deviceInfo}) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('activity_logs').add({
      'type': type,
      'details': details,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
      'timestamp': FieldValue.serverTimestamp(),
      'platform': 'Web', // Defaulting to Web for now as per current environment
    });
  }

  Stream<QuerySnapshot> getActivityLogs() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).collection('activity_logs').orderBy('timestamp', descending: true).limit(50).snapshots();
  }

  Future<void> updateSetupStep(String stepKey) async {
    if (currentUserId == null) return;
    try {
      await _db.collection('users').doc(currentUserId).set({
        'setupProgress.$stepKey': true,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating setup progress step: $e');
    }
  }

  Future<Map<String, bool>> getOrVerifySetupProgress() async {
    final Map<String, bool> currentProgress = {
      'uploadFirstFile': false,
      'addNominee': false,
      'enable2FA': false,
      'setVaultPin': false,
      'writeSecureNote': false,
    };

    if (currentUserId == null) return currentProgress;

    try {
      final userDoc = await _db.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() ?? {};
      
      final dbProgress = userData['setupProgress'] as Map<String, dynamic>? ?? {};

      // 1. Files (exclude deleted files)
      bool hasFiles = dbProgress['uploadFirstFile'] == true;
      if (!hasFiles) {
        final filesSnap = await _db.collection('users').doc(currentUserId).collection('files').get();
        hasFiles = filesSnap.docs.any((d) => d.data()['deleted'] != true);
      }

      // 2. Nominees
      bool hasNominees = dbProgress['addNominee'] == true;
      if (!hasNominees) {
        final nomineesSnap = await _db.collection('users').doc(currentUserId).collection('nominees').limit(1).get();
        hasNominees = nomineesSnap.docs.isNotEmpty;
      }

      // 3. 2FA
      bool has2FA = dbProgress['enable2FA'] == true || (userData['twoFactorEnabled'] == true);

      // 4. PIN
      bool hasPin = dbProgress['setVaultPin'] == true || (userData['vaultPin'] != null && userData['vaultPin'].toString().isNotEmpty);

      // 5. Notes
      bool hasNotes = dbProgress['writeSecureNote'] == true;
      if (!hasNotes) {
        final notesSnap = await _db.collection('users').doc(currentUserId).collection('notes').limit(1).get();
        hasNotes = notesSnap.docs.isNotEmpty;
      }

      currentProgress['uploadFirstFile'] = hasFiles;
      currentProgress['addNominee'] = hasNominees;
      currentProgress['enable2FA'] = has2FA;
      currentProgress['setVaultPin'] = hasPin;
      currentProgress['writeSecureNote'] = hasNotes;

      // Update Firestore if any changed
      final Map<String, bool> updateMap = {};
      currentProgress.forEach((key, val) {
        if (dbProgress[key] != val) {
          updateMap[key] = val;
        }
      });

      if (updateMap.isNotEmpty) {
        await _db.collection('users').doc(currentUserId).set({
          'setupProgress': currentProgress,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error getting/verifying setup progress: $e');
    }

    return currentProgress;
  }

  // --- Trash Bin Support ---
  Stream<QuerySnapshot> getTrashedFiles() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).collection('trash').snapshots();
  }

  Future<void> moveToTrash(String docId, String fileName) async {
    await deleteFileRecord(docId, fileName);
  }

  Future<void> restoreFile(String docId, String fileName) async {
    if (currentUserId == null) return;
    try {
      final doc = await _db.collection('users').doc(currentUserId).collection('trash').doc(docId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data.remove('deletedAt');
        data.remove('deleted');
        await _db.collection('users').doc(currentUserId).collection('files').doc(docId).set(data);
        await _db.collection('users').doc(currentUserId).collection('trash').doc(docId).delete();
      }
    } catch (e) {
      debugPrint('Error restoring file: $e');
    }
    await logActivity(type: 'file_restore', details: 'Restored $fileName from Trash');
  }

  Future<void> cleanExpiredTrash() async {
    if (currentUserId == null) return;
    try {
      final snap = await _db.collection('users').doc(currentUserId).collection('trash').get();
      final now = DateTime.now();
      for (var doc in snap.docs) {
        final data = doc.data();
        final Timestamp? deletedAt = data['deletedAt'] as Timestamp?;
        if (deletedAt != null) {
          final difference = now.difference(deletedAt.toDate());
          if (difference.inDays >= 30) {
            await permanentDeleteFile(doc.id, data['name'] ?? 'Unknown File');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning expired trash: $e');
    }
  }

  Future<void> deleteAllUserData() async {
    if (currentUserId == null) return;
    final uid = currentUserId!;
    
    // Delete files collection
    final files = await _db.collection('users').doc(uid).collection('files').get();
    for (var doc in files.docs) {
      final data = doc.data();
      final downloadUrl = data['downloadUrl'] as String?;
      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        try {
          await _deleteFromCloudinary(downloadUrl);
        } catch (e) {
          debugPrint('Cloudinary deletion failed: $e');
        }
      }
      await doc.reference.delete();
    }
    
    // Delete nominees collection
    final nominees = await _db.collection('users').doc(uid).collection('nominees').get();
    for (var doc in nominees.docs) {
      await doc.reference.delete();
    }

    // Delete activity logs collection
    final logs = await _db.collection('users').doc(uid).collection('activity_logs').get();
    for (var doc in logs.docs) {
      await doc.reference.delete();
    }

    // Delete passwords collection
    final passwords = await _db.collection('users').doc(uid).collection('passwords').get();
    for (var doc in passwords.docs) {
      await doc.reference.delete();
    }

    // Delete notes collection
    final notes = await _db.collection('users').doc(uid).collection('notes').get();
    for (var doc in notes.docs) {
      await doc.reference.delete();
    }

    // Delete user doc
    await _db.collection('users').doc(uid).delete();
  }

  // --- Expiry Documents Collection ---
  Future<void> addExpiryDocument(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('expiry_docs').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(type: 'expiry_add', details: 'Added tracking for ${data['title']}');
  }

  Stream<QuerySnapshot> getExpiryDocuments() {
    if (currentUserId == null) return const Stream.empty();
    return _db.collection('users').doc(currentUserId).collection('expiry_docs').orderBy('expiryDate').snapshots();
  }

  Future<void> deleteExpiryDocument(String docId, String title) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('expiry_docs').doc(docId).delete();
    await logActivity(type: 'expiry_delete', details: 'Deleted tracker for $title');
  }
}
