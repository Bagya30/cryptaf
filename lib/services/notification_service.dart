import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  Future<void> init(BuildContext context) async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Request permission
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Notification permission: ${settings.authorizationStatus}');

      if (kIsWeb && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Push notifications work fully on Android app. Web notifications require browser permission.',
              style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFC9A84C))),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // 2. Get FCM token and save to Firestore
      try {
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey: kIsWeb ? 'BH1X8m1vB_z...mock_or_real_vapid_key' : null,
        );
        if (token != null) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'fcmToken': token,
              'fcmUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('FCM getToken error (expected if web push not fully configured): $e');
      }

      // 3. Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (context.mounted && message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.notification!.title ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
                  const SizedBox(height: 4),
                  Text(message.notification!.body ?? '', style: const TextStyle(color: Colors.white)),
                ],
              ),
              backgroundColor: const Color(0xFF141414),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFC9A84C))),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> sendNotification({required String title, required String body, String? targetUid, BuildContext? context}) async {
    // Save to Firestore notifications subcollection
    try {
      final uid = targetUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      debugPrint('Failed to save notification to Firestore: $e');
    }

    // In a full production app, this triggers a Cloud Function / backend endpoint.
    // For local reliability and demo verification across web & mobile, we also simulate the message arrival locally if in foreground.
    try {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: const Color(0xFF141414),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFC9A84C))),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Send notification error: $e');
    }
  }
}
