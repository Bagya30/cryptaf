import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/screens/add_nominee_screen.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _gold = Color(0xFFFFD700);

class NomineeScreen extends StatefulWidget {
  final String? userId;
  final bool isTab;

  const NomineeScreen({super.key, this.userId, this.isTab = false});

  @override
  State<NomineeScreen> createState() => _NomineeScreenState();
}

class _NomineeScreenState extends State<NomineeScreen> {
  static const _bg = Color(0xFF0A0A0A);

  final FirestoreService _firestore = FirestoreService();



  void _goToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddNomineeScreen()),
    );
  }

  void _goToEdit(DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNomineeScreen(
          docId: doc.id,
          existingData: doc.data() as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: const Text('Remove Nominee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Remove $name? They will no longer have emergency vault access.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.removeNominee(id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<QuerySnapshot>(
      stream: _firestore.getNominees(userId: widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _gold),
                SizedBox(height: 20),
                Text('Fetching nominees...', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading nominees: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        final docs = rawDocs.toList();
        docs.sort((a, b) {
          final pA = (a.data() as Map<String, dynamic>)['priority'] as int? ?? 999;
          final pB = (b.data() as Map<String, dynamic>)['priority'] as int? ?? 999;
          if (pA != pB) return pA.compareTo(pB);
          return a.id.compareTo(b.id);
        });

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trusted Nominees',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (docs.length >= 5 ? Colors.redAccent : _gold).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (docs.length >= 5 ? Colors.redAccent : _gold).withOpacity(0.4)),
                    ),
                    child: Text(
                      '${docs.length} / 5',
                      style: TextStyle(
                        color: docs.length >= 5 ? Colors.redAccent : _gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage secure vault access transfer to your legal heirs.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: docs.isEmpty
                    ? _buildEmptyState()
                    : ReorderableListView.builder(
                        proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                        itemCount: docs.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = docs.removeAt(oldIndex);
                          docs.insert(newIndex, item);

                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final batch = FirebaseFirestore.instance.batch();
                            for (int i = 0; i < docs.length; i++) {
                              final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('nominees').doc(docs[i].id);
                              batch.update(docRef, {'priority': i + 1});
                            }
                            await batch.commit();
                          }
                        },
                        itemBuilder: (_, i) => _buildNomineeCard(docs[i], i + 1, ValueKey(docs[i].id)),
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.isTab) {
      return Scaffold(
        backgroundColor: _bg,
        body: AnimatedBackground(child: content),
        floatingActionButton: _buildFAB(),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nominee Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBackground(child: content),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.getNominees(userId: widget.userId),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return FloatingActionButton.extended(
          backgroundColor: count >= 5 ? Colors.white10 : _gold,
          onPressed: count >= 5
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nominee limit reached (Max 5)')),
                  )
              : _goToAdd,
          icon: Icon(Icons.person_add, color: count >= 5 ? Colors.white24 : const Color(0xFF0A0A0A)),
          label: Text(
            'Add Nominee',
            style: TextStyle(
              color: count >= 5 ? Colors.white24 : const Color(0xFF0A0A0A),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text('No nominees added yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap "Add Nominee" below to get started', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNomineeCard(DocumentSnapshot doc, int priority, Key key) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '—';
    final relationship = data['relationship'] ?? 'Family';
//     final trustLevel = data['trustLevel'] ?? 'Secondary';
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final emailVerified = data['emailVerified'] ?? false;
    final fullyVerified = emailVerified;

    int trustScore = 0;
    if (emailVerified) trustScore = 100;

    Color trustColor = Colors.greenAccent;
    String trustLabel = 'HIGH TRUST';
    if (trustScore < 100) {
      trustColor = Colors.redAccent;
      trustLabel = 'LOW TRUST';
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.15), blurRadius: 15, spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: trustScore / 100.0,
                      backgroundColor: Colors.white12,
                      color: trustColor,
                      strokeWidth: 3,
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: trustColor.withOpacity(0.15),
                    child: Icon(Icons.person, color: trustColor),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                        if (fullyVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 16, color: _gold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(relationship, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _priorityBadge(priority),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trustColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: trustColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      trustLabel,
                      style: TextStyle(color: trustColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badges Row
          Row(
            children: [
              _miniBadge(Icons.email, 'Email', emailVerified),
              const Spacer(),
              if (fullyVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('FULLY VERIFIED', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 20),
                    onPressed: () => _goToEdit(doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDelete(doc.id, name),
                  ),
                ],
              ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Last updated: ${DateFormat('MMM dd, yyyy').format(updatedAt)}',
              style: const TextStyle(color: Colors.white12, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label, bool isVerified) {
    final color = isVerified ? _gold : Colors.white24;
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _priorityBadge(int priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _gold),
      ),
      child: Text(
        'PRIORITY $priority',
        style: const TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
