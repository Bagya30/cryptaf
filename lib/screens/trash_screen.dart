import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:intl/intl.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final FirestoreService _firestore = FirestoreService();
  static const _gold = Color(0xFFC9A84C);
  static const _bg = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    // Silently purge files older than 30 days
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _firestore.cleanExpiredTrash();
      } catch (e) {
        debugPrint('Trash cleanup error: $e');
      }
    });
  }

  IconData _getFileIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'JPG':
      case 'PNG':
      case 'GIF':
      case 'JPEG':
        return Icons.image;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'MP4':
      case 'MOV':
        return Icons.videocam;
      case 'MP3':
      case 'WAV':
        return Icons.music_note;
      case 'ZIP':
      case 'RAR':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Colors.red;
      case 'JPG':
      case 'PNG':
      case 'GIF':
      case 'JPEG':
        return Colors.blue;
      case 'DOC':
      case 'DOCX':
        return Colors.blue;
      case 'MP4':
      case 'MOV':
        return Colors.purple;
      case 'MP3':
      case 'WAV':
        return Colors.green;
      case 'ZIP':
      case 'RAR':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _restoreFile(String docId, String name) async {
    await _firestore.restoreFile(docId, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored "$name" successfully'),
          backgroundColor: Colors.greenAccent,
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteFile(String docId, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Permanently Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete "$name"? This action is irreversible and the file will be destroyed.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.permanentDeleteFile(docId, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted "$name"'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Trash Bin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: Column(
          children: [
            // Warning banner
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orangeAccent, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Deleted files are kept in the trash bin for 30 days before being permanently deleted.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.getTrashedFiles(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _gold));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyTrash();
                  }

                  final trashedDocs = snapshot.data!.docs;

                  if (trashedDocs.isEmpty) {
                    return _buildEmptyTrash();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: trashedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = trashedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name = data['name'] ?? 'Unknown File';
                      final String type = data['type'] ?? 'Unknown';
                      final Timestamp? deletedAt = data['deletedAt'] as Timestamp?;

                      String deletedDateStr = 'Unknown date';
                      if (deletedAt != null) {
                        deletedDateStr = DateFormat('MMM dd, yyyy').format(deletedAt.toDate());
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _gold.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getFileColor(type).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_getFileIcon(type), color: _getFileColor(type)),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Deleted on: $deletedDateStr',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.settings_backup_restore, color: Colors.greenAccent),
                                tooltip: 'Restore file',
                                onPressed: () => _restoreFile(doc.id, name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                tooltip: 'Delete permanently',
                                onPressed: () => _permanentlyDeleteFile(doc.id, name),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTrash() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 72, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('Trash is empty', style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }
}
