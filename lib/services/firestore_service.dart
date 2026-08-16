import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static StreamSubscription<DocumentSnapshot>? _persistentListener;
  static String? _persistentListenerUid;
  static Completer<DocumentSnapshot>? _initialSnapshotCompleter;
  static DocumentSnapshot? _latestSnapshot;
  static StreamSubscription<User?>? _authStateListener;
  static final List<_SnapshotWaiter> _snapshotWaiters = [];

  String? get currentUserId => _auth.currentUser?.uid;

  void _ensurePersistentListener() {
    final uid = currentUserId;
    if (uid == null) {
      cancelPersistentListener();
      return;
    }

    if (_persistentListener != null && _persistentListenerUid == uid) {
      return; // Already listening for this user
    }

    cancelPersistentListener(); // Cancel any previous listener for different user

    _persistentListenerUid = uid;
    _initialSnapshotCompleter = Completer<DocumentSnapshot>();
    _latestSnapshot = null;

    // Start tracking auth state changes if not already
    _authStateListener ??= _auth.authStateChanges().listen((user) {
      if (user == null || user.uid != _persistentListenerUid) {
        cancelPersistentListener();
      }
    });

    _persistentListener = _db
        .collection('users')
        .doc(uid)
        .collection('publicMeta')
        .doc('info')
        .snapshots()
        .listen(
      (snapshot) {
        _latestSnapshot = snapshot;
        if (_initialSnapshotCompleter != null &&
            !_initialSnapshotCompleter!.isCompleted) {
          _initialSnapshotCompleter!.complete(snapshot);
        }

        _snapshotWaiters.removeWhere((waiter) {
          if (waiter.predicate(snapshot)) {
            if (!waiter.completer.isCompleted) {
              waiter.completer.complete(snapshot);
            }
            return true;
          }
          return false;
        });
      },
      onError: (e) {
        debugPrint('Persistent listener error: $e');
        if (_initialSnapshotCompleter != null &&
            !_initialSnapshotCompleter!.isCompleted) {
          _initialSnapshotCompleter!.completeError(e);
        }
        for (var waiter in _snapshotWaiters) {
          if (!waiter.completer.isCompleted) {
            waiter.completer.completeError(e);
          }
        }
        _snapshotWaiters.clear();
      },
    );
  }

  static void cancelPersistentListener() {
    _persistentListener?.cancel();
    _persistentListener = null;
    _persistentListenerUid = null;
    _latestSnapshot = null;
    if (_initialSnapshotCompleter != null &&
        !_initialSnapshotCompleter!.isCompleted) {
      _initialSnapshotCompleter!.completeError(Exception("Listener cancelled"));
    }
    _initialSnapshotCompleter = null;
    for (var waiter in _snapshotWaiters) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(Exception("Listener cancelled"));
      }
    }
    _snapshotWaiters.clear();
  }

  // --- Files Collection ---
  Future<void> uploadFileRecord(
      String fileName, String fileType, bool isEncrypted,
      {String? downloadUrl,
      int? sizeBytes,
      String category = 'Documents',
      String? salt,
      String? iv,
      bool isInheritable = false,
      Map<String, dynamic>? nomineeWrappedDEK,
      Map<String, dynamic>? ownerWrappedDEK}) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('files').add({
      'name': fileName,
      'type': fileType,
      'encrypted': isEncrypted,
      'category': category,
      'isInheritable': isInheritable,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (salt != null) 'salt': salt,
      if (iv != null) 'iv': iv,
      if (nomineeWrappedDEK != null) 'nomineeWrappedDEK': nomineeWrappedDEK,
      if (ownerWrappedDEK != null) 'ownerWrappedDEK': ownerWrappedDEK,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
        type: 'file_upload', details: 'Uploaded $fileName ($category)');
    await updateSetupStep('uploadFirstFile');
  }

  Future<void> _deleteFromCloudinary(String downloadUrl) async {
    // Client-side deletion from Cloudinary is disabled.
    // We removed CLOUDINARY_API_SECRET from the client for security.
    // To re-enable this, implement a Firebase Cloud Function that uses the
    // Admin SDK/Cloudinary Node SDK with the secret stored securely.
    debugPrint(
        'Client-side Cloudinary deletion is disabled (requires backend)');
  }

  Future<void> deleteFileRecord(String docId, String fileName) async {
    if (currentUserId == null) return;
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('files')
          .doc(docId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        data['deletedAt'] = FieldValue.serverTimestamp();
        await _db
            .collection('users')
            .doc(currentUserId)
            .collection('trash')
            .doc(docId)
            .set(data);
        await _db
            .collection('users')
            .doc(currentUserId)
            .collection('files')
            .doc(docId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error moving to trash: $e');
    }
    await logActivity(
        type: 'file_delete', details: 'Moved file to trash: $fileName');
  }

  Future<void> permanentDeleteFile(String docId, String fileName) async {
    if (currentUserId == null) return;
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('trash')
          .doc(docId)
          .get();
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
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('trash')
        .doc(docId)
        .delete();
    await logActivity(
        type: 'file_permanent_delete',
        details: 'Permanently deleted file: $fileName');
  }

  Future<void> updateFileCategory(
      String docId, String fileName, String newCategory) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('files')
        .doc(docId)
        .update({
      'category': newCategory,
    });
    await logActivity(
        type: 'file_move', details: 'Moved $fileName to $newCategory');
  }

  Future<void> toggleFileFavorite(String docId, bool currentStatus) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('files')
        .doc(docId)
        .update({
      'favorite': !currentStatus,
    });
    await logActivity(
      type: 'file_favorite_toggle',
      details: '${!currentStatus ? 'Favorited' : 'Unfavorited'} file',
    );
  }

  Stream<QuerySnapshot> getFiles({String? category}) {
    if (currentUserId == null) return const Stream.empty();
    Query query =
        _db.collection('users').doc(currentUserId).collection('files');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
      return query.snapshots(); // orderBy with where requires a composite index
    }
    return query.orderBy('uploadedAt', descending: true).snapshots();
  }

  // --- Nominees Collection ---
  Future<void> addNominee(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    final email = data['email'] as String;
    final docId = email.toLowerCase().trim();

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('nominees')
        .doc(docId)
        .set({
      ...data,
      'uid': null, // Will be bound by the nominee upon first authentication
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'verified': true, // Vault owner verified intent
    });
    await logActivity(
        type: 'nominee_added', details: 'Added ${data['name']} as nominee');
    await updateSetupStep('addNominee');
  }

  Future<void> migrateLegacyNominees() async {
    if (currentUserId == null) return;
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('nominees')
          .get();

      final batch = _db.batch();
      bool hasMigrations = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['migratedToCanonical'] == true) continue;

        final email = data['email'] as String?;
        if (email == null || email.isEmpty) continue;

        final normalizedEmail = email.toLowerCase().trim();

        // If the document ID is not already the canonical ID
        if (doc.id != normalizedEmail) {
          final canonicalRef = _db
              .collection('users')
              .doc(currentUserId)
              .collection('nominees')
              .doc(normalizedEmail);

          final canonicalDoc = await canonicalRef.get();

          // Do not overwrite an existing canonical record
          if (!canonicalDoc.exists) {
            batch.set(canonicalRef, {
              'email': email,
              'name': data['name'] ?? '',
              'relationship': data['relationship'] ?? '',
              'uid': data['uid'], // preserve existing binding securely
              'addedAt': data['addedAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'verified': data['verified'] ?? true,
            });
          }

          // Delete the legacy record now that canonical exists
          batch.delete(doc.reference);

          hasMigrations = true;
        }
      }

      if (hasMigrations) {
        await batch.commit();
        await logActivity(
            type: 'nominee_migrated',
            details: 'Migrated legacy nominees to deterministic bindings.');
      }
    } catch (e) {
      // Catch individual errors but don't crash startup if called aggressively
      debugPrint('Legacy nominee migration error: $e');
    }
  }

  Future<void> resetNomineeBinding(String email) async {
    if (currentUserId == null) return;
    final normalizedEmail = email.toLowerCase().trim();

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('nominees')
        .doc(normalizedEmail)
        .update({
      'uid': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logActivity(
        type: 'nominee_binding_reset',
        details: 'Reset access binding for nominee');
  }

  Future<void> updateNominee(String docId, Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('nominees')
        .doc(docId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
        type: 'nominee_updated', details: 'Updated nominee: ${data['name']}');
  }

  Future<void> removeNominee(String docId, String name) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('nominees')
        .doc(docId)
        .delete();
    await logActivity(
        type: 'nominee_removed', details: 'Removed nominee: $name');
  }

  Stream<QuerySnapshot> getNominees({String? userId}) {
    final uid = userId ?? currentUserId;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('nominees')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  // --- Emergency Settings (Dead Man's Switch) ---
  Future<void> updateEmergencySettings(bool isEnabled) async {
    if (currentUserId == null) return;

    // First update the core status
    await _db.collection('users').doc(currentUserId).update({
      'emergencyEnabled': isEnabled,
      'emergencyStatus': isEnabled ? 'active' : 'disabled',
    });

    final docRef = _db
        .collection('users')
        .doc(currentUserId)
        .collection('publicMeta')
        .doc('info');

    if (isEnabled) {
      final currentDoc = await docRef.get();
      int currentDuration = 168;

      if (currentDoc.exists &&
          currentDoc.data()?.containsKey('emergencyDurationHours') == true) {
        currentDuration =
            currentDoc.data()?['emergencyDurationHours'] as int? ?? 168;
      } else {
        // Fallback to legacy root doc to prevent overwriting user's old config
        final rootDoc = await _db.collection('users').doc(currentUserId).get();
        if (rootDoc.exists &&
            rootDoc.data()?.containsKey('emergencyDurationHours') == true) {
          currentDuration =
              rootDoc.data()?['emergencyDurationHours'] as int? ?? 168;
        }
      }

      _ensurePersistentListener();

      final completer = Completer<DocumentSnapshot>();
      final waiter = _SnapshotWaiter(completer, (snap) {
        if (snap.metadata.hasPendingWrites) return false;
        final snapData = snap.data() as Map<String, dynamic>?;
        if (snapData == null) return false;

        final newResetAt = snapData['emergencyResetAt'];
        if (newResetAt is! Timestamp) return false;

        return true;
      });

      _snapshotWaiters.add(waiter);

      try {
        // Step 1: Write the server timestamp anchor
        await docRef.set({
          'emergencyEnabled': true,
          'emergencyStatus': 'active',
          'emergencyDurationHours': currentDuration,
          'emergencyResetAt': FieldValue.serverTimestamp(),
          'emergencyDeadline': null,
        }, SetOptions(merge: true));

        // Handle race condition where _latestSnapshot already processed this
        final latest = _latestSnapshot;
        if (!completer.isCompleted &&
            latest != null &&
            waiter.predicate(latest)) {
          completer.complete(latest);
        }

        // Step 2: Wait for confirmation
        final confirmedSnap = await completer.future.timeout(
          const Duration(seconds: 15),
        );

        final confirmedData = confirmedSnap.data() as Map<String, dynamic>;

        // Step 3: Derive deadline from confirmed server timestamp and configured duration
        final serverResetAt = confirmedData['emergencyResetAt'] as Timestamp;
        final confirmedDuration =
            confirmedData['emergencyDurationHours'] as int? ?? currentDuration;
        final deadline =
            serverResetAt.toDate().add(Duration(hours: confirmedDuration));

        // Step 4: Write exact calculated deadline
        await docRef.update({
          'emergencyDeadline': Timestamp.fromDate(deadline),
        });
      } finally {
        _snapshotWaiters.remove(waiter);
      }
    } else {
      await docRef.set({
        'emergencyEnabled': false,
        'emergencyStatus': 'disabled',
        'emergencyResetAt': FieldValue.delete(),
        'emergencyDeadline': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> setEmergencyDuration(int newHours) async {
    final uid = currentUserId;
    if (uid == null) return;

    _ensurePersistentListener();

    final docRef =
        _db.collection('users').doc(uid).collection('publicMeta').doc('info');

    final completer = Completer<DocumentSnapshot>();
    final waiter = _SnapshotWaiter(completer, (snap) {
      if (snap.metadata.hasPendingWrites) return false;
      final snapData = snap.data() as Map<String, dynamic>?;
      if (snapData == null) return false;

      final newResetAt = snapData['emergencyResetAt'];
      if (newResetAt is! Timestamp) return false;

      // Make sure the duration matches our requested duration to avoid race with another write
      final confirmedDuration = snapData['emergencyDurationHours'] as int?;
      if (confirmedDuration != newHours) return false;

      return true;
    });

    _snapshotWaiters.add(waiter);

    try {
      // STEP 1 - Update duration and reset timestamp, clear deadline during transition
      await docRef.set({
        'emergencyDurationHours': newHours,
        'emergencyResetAt': FieldValue.serverTimestamp(),
        'emergencyDeadline': null,
      }, SetOptions(merge: true));

      // Handle race condition where _latestSnapshot already processed this
      final latest = _latestSnapshot;
      if (!completer.isCompleted &&
          latest != null &&
          waiter.predicate(latest)) {
        completer.complete(latest);
      }

      // STEP 2 - Wait for confirmation
      final confirmedSnap = await completer.future.timeout(
        const Duration(seconds: 15),
      );

      final confirmedData = confirmedSnap.data() as Map<String, dynamic>;

      // STEP 3 - Derive deadline from confirmed server timestamp and newly configured duration
      final serverResetAt = confirmedData['emergencyResetAt'] as Timestamp;
      final deadline = serverResetAt.toDate().add(Duration(hours: newHours));

      // STEP 4 - Write exact calculated deadline
      await docRef.update({
        'emergencyDeadline': Timestamp.fromDate(deadline),
      });

      await logActivity(
          type: 'emergency_duration_changed',
          details: 'Dead Man\'s Switch duration updated to \$newHours hours');
    } finally {
      _snapshotWaiters.remove(waiter);
    }
  }

  Future<void> resetEmergencyTimer() async {
    if (currentUserId == null) return;
    final docRef = _db
        .collection('users')
        .doc(currentUserId)
        .collection('publicMeta')
        .doc('info');
    final doc = await docRef.get();

    if (doc.exists && doc.data()?['emergencyEnabled'] == true) {
      // Step 1: Write the server timestamp anchor
      await docRef.update({
        'emergencyResetAt': FieldValue.serverTimestamp(),
        'emergencyStatus': 'active',
      });

      // Step 2: Read back to compute and write the exact valid deadline
      final updatedDoc = await docRef.get();
      final resetTime =
          (updatedDoc.data()?['emergencyResetAt'] as Timestamp?)?.toDate();
      if (resetTime != null) {
        final durationHours =
            updatedDoc.data()?['emergencyDurationHours'] as int? ?? 168;
        final deadline = resetTime.add(Duration(hours: durationHours));

        await docRef.update({
          'emergencyDeadline': Timestamp.fromDate(deadline),
        });
      }

      await logActivity(
          type: 'emergency_reset', details: 'Dead Man\'s Switch timer reset');
    }
  }

  Future<void> markEmergencyExpired() async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set({
      'emergencyStatus': 'expired',
    }, SetOptions(merge: true));

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('publicMeta')
        .doc('info')
        .set({
      'emergencyStatus': 'expired',
    }, SetOptions(merge: true));

    await logActivity(
        type: 'emergency_triggered',
        details: 'Vault access transfer initiated (Timer Expired)');
  }

  Stream<DocumentSnapshot> getEmergencySettings() {
    if (currentUserId == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('publicMeta')
        .doc('info')
        .snapshots();
  }

  Future<void> updateLastActive() async {
    final uid = currentUserId;
    if (uid == null) return;

    _ensurePersistentListener(); // Workaround for Firebase JS SDK 12.12.0 ca9/b815 bug

    try {
      final docRef =
          _db.collection('users').doc(uid).collection('publicMeta').doc('info');

      // Use the latest snapshot from the persistent listener instead of a transient .get()
      if (_latestSnapshot == null) {
        if (_initialSnapshotCompleter == null) return;
        await _initialSnapshotCompleter!.future;
      }

      final doc = _latestSnapshot;
      if (doc == null || !doc.exists || doc.data() == null) return;
      final data = doc.data() as Map<String, dynamic>;

      if (data['emergencyEnabled'] == true) {
        final oldResetAt = data['emergencyResetAt'] as Timestamp?;

        final completer = Completer<DocumentSnapshot>();
        final waiter = _SnapshotWaiter(completer, (snap) {
          if (snap.metadata.hasPendingWrites) return false;
          final snapData = snap.data() as Map<String, dynamic>?;
          if (snapData == null) return false;

          final newResetAt = snapData['emergencyResetAt'];
          if (newResetAt is! Timestamp) return false;

          // Must correspond to the newly completed reset, not the previous value
          if (oldResetAt != null && newResetAt.compareTo(oldResetAt) <= 0) {
            return false;
          }

          return true;
        });

        _snapshotWaiters.add(waiter);

        try {
          // STEP 1 - RESET USING SERVER TIMESTAMP
          await docRef.update({
            'emergencyResetAt': FieldValue.serverTimestamp(),
            'emergencyDeadline': null, // Intentionally null during transition
          });

          // Race-safe fallback:
          // after update completes, also examine _latestSnapshot.
          // If it already contains the confirmed new server reset and
          // completer is not completed, complete it manually.
          final latest = _latestSnapshot;
          if (!completer.isCompleted &&
              latest != null &&
              waiter.predicate(latest)) {
            completer.complete(latest);
          }

          final confirmedSnap = await completer.future.timeout(
            const Duration(seconds: 15),
          );

          final confirmedData = confirmedSnap.data() as Map<String, dynamic>;

          // STEP 3 - DERIVE DEADLINE FROM SERVER VALUE
          final serverResetAt = confirmedData['emergencyResetAt'] as Timestamp;
          final confirmedDuration =
              confirmedData['emergencyDurationHours'] as int? ?? 168;
          final deadline =
              serverResetAt.toDate().add(Duration(hours: confirmedDuration));

          await docRef.update({
            'emergencyDeadline': Timestamp.fromDate(deadline),
          });
        } finally {
          _snapshotWaiters.remove(waiter);
        }
      }
    } catch (e) {
      // If STEP 1 succeeds but STEP 2 fails, emergencyDeadline remains null, denying access.
      debugPrint('Error updating last active time: $e');
    }
  }

  // --- Security Settings ---
  Future<void> updateSecuritySettings(bool twoFactor, bool biometrics,
      {String? totpSecret}) async {
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
    final otp = (100000 + Random.secure().nextInt(900000)).toString();

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('nominee_otps')
        .doc(email)
        .set({
      'otp': otp,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
    });

    // In a real app, this would be sent via Email service

    return otp;
  }

  Future<bool> verifyNomineeOTP(String email, String otp) async {
    if (currentUserId == null) return false;

    final doc = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('nominee_otps')
        .doc(email)
        .get();
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
  Future<void> addPasswordEntry(
      String website, String username, String encryptedPassword) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('passwords')
        .add({
      'website': website,
      'username': username,
      'encryptedPassword': encryptedPassword,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
        type: 'password_added', details: 'Added password for $website');
  }

  Future<void> deletePasswordEntry(String docId, String website) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('passwords')
        .doc(docId)
        .delete();
    await logActivity(
        type: 'password_deleted', details: 'Deleted password for $website');
  }

  Stream<QuerySnapshot> getPasswordEntries() {
    if (currentUserId == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('passwords')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Secure Notes ---
  Future<void> addNoteEntry(
      String encryptedTitle, String encryptedContent) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).collection('notes').add({
      'title': encryptedTitle,
      'content': encryptedContent,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
        type: 'note_added', details: 'Added secure encrypted note');
    await updateSetupStep('writeSecureNote');
  }

  Future<void> deleteNoteEntry(String docId) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('notes')
        .doc(docId)
        .delete();
    await logActivity(
        type: 'note_deleted', details: 'Deleted secure encrypted note');
  }

  Stream<QuerySnapshot> getNoteEntries() {
    if (currentUserId == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Activity Logs ---
  Future<void> logActivity(
      {required String type,
      required String details,
      String? ipAddress,
      String? deviceInfo}) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('activity_logs')
        .add({
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
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> updateSetupStep(String stepKey) async {
    if (currentUserId == null) return;
    try {
      await _db.collection('users').doc(currentUserId).set({
        'setupProgress': {
          stepKey: true,
        },
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

      final dbProgress =
          userData['setupProgress'] as Map<String, dynamic>? ?? {};

      // 1. Files (exclude deleted files)
      bool hasFiles = dbProgress['uploadFirstFile'] == true;
      if (!hasFiles) {
        try {
          final filesSnap = await _db
              .collection('users')
              .doc(currentUserId)
              .collection('files')
              .get();
          hasFiles = filesSnap.docs.any((d) => d.data()['deleted'] != true);
        } catch (e) {
          debugPrint('Error fetching files for setup progress: $e');
        }
      }

      // 2. Nominees
      bool hasNominees = dbProgress['addNominee'] == true;
      if (!hasNominees) {
        try {
          final nomineesSnap = await _db
              .collection('users')
              .doc(currentUserId)
              .collection('nominees')
              .limit(1)
              .get();
          hasNominees = nomineesSnap.docs.isNotEmpty;
        } catch (e) {
          debugPrint('Error fetching nominees for setup progress: $e');
        }
      }

      // 3. 2FA
      bool has2FA = dbProgress['enable2FA'] == true ||
          (userData['twoFactorEnabled'] == true);

      // 4. PIN
      bool hasPin = dbProgress['setVaultPin'] == true ||
          (userData['vaultPin'] != null &&
              userData['vaultPin'].toString().isNotEmpty);

      // 5. Notes
      bool hasNotes = dbProgress['writeSecureNote'] == true;
      if (!hasNotes) {
        try {
          final notesSnap = await _db
              .collection('users')
              .doc(currentUserId)
              .collection('notes')
              .limit(1)
              .get();
          hasNotes = notesSnap.docs.isNotEmpty;
        } catch (e) {
          debugPrint('Error fetching notes for setup progress: $e');
        }
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
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('trash')
        .snapshots();
  }

  Future<void> moveToTrash(String docId, String fileName) async {
    await deleteFileRecord(docId, fileName);
  }

  Future<void> restoreFile(String docId, String fileName) async {
    if (currentUserId == null) return;
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('trash')
          .doc(docId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        data.remove('deletedAt');
        data.remove('deleted');
        await _db
            .collection('users')
            .doc(currentUserId)
            .collection('files')
            .doc(docId)
            .set(data);
        await _db
            .collection('users')
            .doc(currentUserId)
            .collection('trash')
            .doc(docId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error restoring file: $e');
    }
    await logActivity(
        type: 'file_restore', details: 'Restored $fileName from Trash');
  }

  Future<void> cleanExpiredTrash() async {
    if (currentUserId == null) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('trash')
          .get();
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
    final files =
        await _db.collection('users').doc(uid).collection('files').get();
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
    final nominees =
        await _db.collection('users').doc(uid).collection('nominees').get();
    for (var doc in nominees.docs) {
      await doc.reference.delete();
    }

    // Delete activity logs collection
    final logs = await _db
        .collection('users')
        .doc(uid)
        .collection('activity_logs')
        .get();
    for (var doc in logs.docs) {
      await doc.reference.delete();
    }

    // Delete passwords collection
    final passwords =
        await _db.collection('users').doc(uid).collection('passwords').get();
    for (var doc in passwords.docs) {
      await doc.reference.delete();
    }

    // Delete notes collection
    final notes =
        await _db.collection('users').doc(uid).collection('notes').get();
    for (var doc in notes.docs) {
      await doc.reference.delete();
    }

    // Delete user doc
    await _db.collection('users').doc(uid).delete();
  }

  // --- Expiry Documents Collection ---
  Future<void> addExpiryDocument(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('expiry_docs')
        .add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
        type: 'expiry_add', details: 'Added tracking for ${data['title']}');
  }

  Stream<QuerySnapshot> getExpiryDocuments() {
    if (currentUserId == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(currentUserId)
        .collection('expiry_docs')
        .orderBy('expiryDate')
        .snapshots();
  }

  Future<void> deleteExpiryDocument(String docId, String title) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('expiry_docs')
        .doc(docId)
        .delete();
    await logActivity(
        type: 'expiry_delete', details: 'Deleted tracker for $title');
  }
}

class _SnapshotWaiter {
  final Completer<DocumentSnapshot> completer;
  final bool Function(DocumentSnapshot) predicate;
  _SnapshotWaiter(this.completer, this.predicate);
}
