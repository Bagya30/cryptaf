import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Color _getNotificationColor(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('warning') || lowerTitle.contains('danger') || lowerTitle.contains('alert')) {
      return Colors.redAccent;
    }
    if (lowerTitle.contains('nominee') || lowerTitle.contains('access')) {
      return Colors.orangeAccent;
    }
    return const Color(0xFFC9A84C); // Gold
  }

  IconData _getNotificationIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('warning') || lowerTitle.contains('alert')) {
      return Icons.warning_amber_rounded;
    }
    if (lowerTitle.contains('nominee') || lowerTitle.contains('access')) {
      return Icons.person_search_rounded;
    }
    if (lowerTitle.contains('login')) {
      return Icons.lock_person_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: Text('User not authenticated.', style: TextStyle(color: Colors.white70))),
      );
    }

    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF0A0A0A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.white12)),
                  title: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text('Are you sure you want to delete all notifications?', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final snap = await notificationsRef.get();
                final batch = FirebaseFirestore.instance.batch();
                for (var doc in snap.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: AnimatedBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: notificationsRef.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    const Text('No notifications', style: TextStyle(color: Colors.white38, fontSize: 18)),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final String title = data['title'] ?? 'Notification';
                final String body = data['body'] ?? '';
                final bool read = data['read'] ?? false;
                final Timestamp? ts = data['timestamp'];
                final String timeStr = ts != null
                    ? DateFormat('MMM dd, hh:mm a').format(ts.toDate())
                    : 'Recently';

                // Removed automatic mark as read in build method

                final color = _getNotificationColor(title);

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.redAccent.withOpacity(0.2),
                    child: const Icon(Icons.delete, color: Colors.redAccent),
                  ),
                  onDismissed: (direction) {
                    doc.reference.delete();
                  },
                  child: GestureDetector(
                    onTap: () {
                      if (!read) {
                        doc.reference.update({'read': true});
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Icon(_getNotificationIcon(title), color: color, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (!read)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blueAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  body,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        doc.reference.delete();
                                      },
                                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
