import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';

class VaultSearchDelegate extends SearchDelegate {
  final FirestoreService firestore;

  VaultSearchDelegate({required this.firestore});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white70),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return Container(
        color: const Color(0xFF0A0A0A),
        child: const Center(
          child: Text('Search for files, nominees, or activities', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0A0A0A),
      child: FutureBuilder<Map<String, List<DocumentSnapshot>>>(
        future: _performSearch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
          }

          if (!snapshot.hasData || (snapshot.data!['files']!.isEmpty && snapshot.data!['nominees']!.isEmpty && snapshot.data!['logs']!.isEmpty)) {
            return const Center(
              child: Text('No results found', style: TextStyle(color: Colors.white38)),
            );
          }

          final files = snapshot.data!['files']!;
          final nominees = snapshot.data!['nominees']!;
          final logs = snapshot.data!['logs']!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (files.isNotEmpty) ...[
                _buildHeader('Files'),
                ...files.map((doc) => _buildResultTile(context, Icons.insert_drive_file, doc['name'], 'File • ${doc['category']}')),
              ],
              if (nominees.isNotEmpty) ...[
                _buildHeader('Nominees'),
                ...nominees.map((doc) => _buildResultTile(context, Icons.person, doc['name'], 'Nominee')),
              ],
              if (logs.isNotEmpty) ...[
                _buildHeader('Activities'),
                ...logs.map((doc) => _buildResultTile(context, Icons.history, doc['details'], 'Activity')),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, List<DocumentSnapshot>>> _performSearch() async {
    final lowerQuery = query.toLowerCase();

    // Fetch everything (for real-time filtering, this is simpler than complex Firestore queries)
    final filesSnap = await firestore.getFiles().first;
    final nomineesSnap = await firestore.getNominees().first;
    final logsSnap = await firestore.getActivityLogs().first;

    final filteredFiles = filesSnap.docs.where((doc) => doc['name'].toString().toLowerCase().contains(lowerQuery)).toList();
    final filteredNominees = nomineesSnap.docs.where((doc) => doc['name'].toString().toLowerCase().contains(lowerQuery)).toList();
    final filteredLogs = logsSnap.docs.where((doc) => doc['details'].toString().toLowerCase().contains(lowerQuery)).toList();

    return {
      'files': filteredFiles,
      'nominees': filteredNominees,
      'logs': filteredLogs,
    };
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      onTap: () {
        // Navigate based on type or just close
        close(context, null);
      },
    );
  }
}
