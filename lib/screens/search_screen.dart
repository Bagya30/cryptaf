import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:cryptaf/screens/file_view_screen.dart';
import 'package:cryptaf/screens/nominee_screen.dart';
import 'package:cryptaf/screens/password_manager_screen.dart';
import 'package:cryptaf/screens/activity_log_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<DocumentSnapshot> _allFiles = [];
  List<DocumentSnapshot> _allNominees = [];
  List<DocumentSnapshot> _allPasswords = [];
  List<DocumentSnapshot> _allLogs = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('users').doc(uid).collection('files').get(),
        db.collection('users').doc(uid).collection('nominees').get(),
        db.collection('users').doc(uid).collection('passwords').get(),
        db.collection('users').doc(uid).collection('activity_logs').orderBy('timestamp', descending: true).limit(100).get(),
      ]);

      if (mounted) {
        setState(() {
          _allFiles = results[0].docs;
          _allNominees = results[1].docs;
          _allPasswords = results[2].docs;
          _allLogs = results[3].docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading search data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanQuery = _query.trim().toLowerCase();

    final filteredFiles = _allFiles.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final name = (data['name'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      return name.contains(cleanQuery) || category.contains(cleanQuery);
    }).toList();

    final filteredNominees = _allNominees.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      return name.contains(cleanQuery) || email.contains(cleanQuery);
    }).toList();

    final filteredPasswords = _allPasswords.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final website = (data['website'] ?? '').toString().toLowerCase();
      return website.contains(cleanQuery);
    }).toList();

    final filteredLogs = _allLogs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final details = (data['details'] ?? '').toString().toLowerCase();
      final type = (data['type'] ?? '').toString().toLowerCase();
      return details.contains(cleanQuery) || type.contains(cleanQuery);
    }).toList();

    final hasResults = filteredFiles.isNotEmpty ||
        filteredNominees.isNotEmpty ||
        filteredPasswords.isNotEmpty ||
        filteredLogs.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search vault, nominees, passwords...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _query = val;
            });
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white54),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
            ),
        ],
      ),
      body: AnimatedBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)))
            : _query.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 72, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        const Text('Enter search query', style: TextStyle(color: Colors.white38, fontSize: 16)),
                      ],
                    ),
                  )
                : !hasResults
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sentiment_dissatisfied_rounded, size: 72, color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            const Text('No matches found', style: TextStyle(color: Colors.white38, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (filteredFiles.isNotEmpty) ...[
                            _buildSectionHeader('Files', Icons.insert_drive_file_outlined),
                            ...filteredFiles.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildResultTile(
                                title: data['name'] ?? 'File',
                                subtitle: data['category'] ?? 'Documents',
                                icon: Icons.description_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FileViewScreen(
                                        docId: doc.id,
                                        name: data['name'] ?? '',
                                        type: data['type'] ?? '',
                                        category: data['category'] ?? 'Documents',
                                        downloadUrl: data['downloadUrl'] ?? '',
                                        uploadedAt: data['uploadedAt'],
                                        sizeBytes: data['sizeBytes'],
                                        salt: data['salt'],
                                        iv: data['iv'],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 20),
                          ],
                          if (filteredNominees.isNotEmpty) ...[
                            _buildSectionHeader('Nominees', Icons.people_outline_rounded),
                            ...filteredNominees.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildResultTile(
                                title: data['name'] ?? 'Nominee',
                                subtitle: data['email'] ?? '',
                                icon: Icons.person_outline_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NomineeScreen(),
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 20),
                          ],
                          if (filteredPasswords.isNotEmpty) ...[
                            _buildSectionHeader('Passwords', Icons.password_outlined),
                            ...filteredPasswords.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildResultTile(
                                title: data['website'] ?? 'Website',
                                subtitle: data['username'] ?? '',
                                icon: Icons.vpn_key_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PasswordManagerScreen(),
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 20),
                          ],
                          if (filteredLogs.isNotEmpty) ...[
                            _buildSectionHeader('Activity Logs', Icons.history_rounded),
                            ...filteredLogs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildResultTile(
                                title: data['details'] ?? 'Action',
                                subtitle: data['type'] ?? '',
                                icon: Icons.history_toggle_off_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ActivityLogScreen(),
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFC9A84C), size: 18),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFC9A84C),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
        ),
      ),
    );
  }
}
