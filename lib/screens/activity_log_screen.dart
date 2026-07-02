import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends StatelessWidget {
  final FirestoreService _firestore = FirestoreService();

  ActivityLogScreen({super.key});

  IconData _getIcon(String type) {
    switch (type) {
      case 'login':
        return Icons.login_rounded;
      case 'signup':
        return Icons.person_add_rounded;
      case 'file_upload':
        return Icons.upload_file_rounded;
      case 'file_delete':
        return Icons.delete_sweep_rounded;
      case 'nominee_added':
        return Icons.person_add_alt_1_rounded;
      case 'nominee_removed':
        return Icons.person_remove_rounded;
      case 'timer_reset':
        return Icons.timer_rounded;
      case 'emergency_triggered':
        return Icons.warning_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'emergency_triggered':
        return Colors.redAccent;
      case 'file_delete':
        return Colors.orangeAccent;
      case 'timer_reset':
      case 'file_upload':
        return const Color(0xFFC9A84C);
      default:
        return Colors.white70;
    }
  }

  Widget _buildHeatmap(List<QueryDocumentSnapshot> docs) {
    DateTime now = DateTime.now();
    DateTime threeMonthsAgo = now.subtract(const Duration(days: 91));

    Map<String, int> activityMap = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['timestamp'];
      if (ts != null) {
        DateTime dt = ts.toDate();
        if (dt.isAfter(threeMonthsAgo)) {
          String key = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
          activityMap[key] = (activityMap[key] ?? 0) + 1;
        }
      }
    }

    List<Widget> columns = [];
    for (int w = 12; w >= 0; w--) {
      List<Widget> days = [];
      for (int d = 6; d >= 0; d--) {
        int daysAgo = (w * 7) + d;
        DateTime date = now.subtract(Duration(days: daysAgo));
        String key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        int count = activityMap[key] ?? 0;

        Color color = Colors.grey.withOpacity(0.2); // inactive
        if (count > 0) {
          if (count == 1) { color = Colors.green.shade800; }
          else if (count == 2) { color = Colors.green.shade600; }
          else if (count > 2) { color = Colors.green.shade400; }
        }

        days.add(
          Tooltip(
            message: '$count activities on ${DateFormat('MMM dd, yyyy').format(date)}',
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }
      columns.add(Column(children: days));
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vault Activity (Last 90 Days)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: columns,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Activity Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.getActivityLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    const Text('No activities logged yet', style: TextStyle(color: Colors.white38)),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildHeatmap(snapshot.data!.docs),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String type = data['type'] ?? 'unknown';
                      final String details = data['details'] ?? '';
                      final Timestamp? timestamp = data['timestamp'];
                      final String platform = data['platform'] ?? 'Web';
                      final String? ipAddress = data['ipAddress'] as String?;
                      final String? deviceInfo = data['deviceInfo'] as String?;

                      String timeStr = 'Just now';
                      if (timestamp != null) {
                        timeStr = DateFormat('MMM dd, hh:mm a').format(timestamp.toDate());
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4), width: 1.2),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.15), blurRadius: 12),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getColor(type).withOpacity(0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: _getColor(type).withOpacity(0.3), blurRadius: 8),
                                ],
                              ),
                              child: Icon(_getIcon(type), color: _getColor(type), size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    details,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                      const SizedBox(width: 8),
                                      const Text('•', style: TextStyle(color: Colors.white12)),
                                      const SizedBox(width: 8),
                                      Text(platform, style: TextStyle(color: const Color(0xFFC9A84C).withOpacity(0.8), fontSize: 11)),
                                    ],
                                  ),
                                  if (ipAddress != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.wifi, size: 12, color: Colors.white38),
                                        const SizedBox(width: 4),
                                        Text('IP: $ipAddress', style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                                        if (deviceInfo != null) ...[
                                          const SizedBox(width: 8),
                                          Text('($deviceInfo)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
