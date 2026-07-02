import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptaf/services/firestore_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cryptaf/screens/file_view_screen.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class VaultViewScreen extends StatefulWidget {
  final String? category;

  const VaultViewScreen({super.key, this.category});

  @override
  VaultViewScreenState createState() => VaultViewScreenState();
}

class VaultViewScreenState extends State<VaultViewScreen> {
  final FirestoreService _firestore = FirestoreService();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showFavoritesOnly = false;

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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Medical':
        return Colors.redAccent;
      case 'Financial':
        return Colors.greenAccent;
      case 'Legal':
        return Colors.orangeAccent;
      default:
        return const Color(0xFFC9A84C); // Antique Gold
    }
  }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file URL')),
        );
      }
    }
  }

  Future<void> _deleteFile(String docId, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Delete File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$name"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.moveToTrash(docId, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" moved to trash')),
        );
      }
    }
  }

  Future<void> _generateShareLink(String fileUrl, String fileName) async {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    final token = String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

    await FirebaseFirestore.instance.collection('share_links').doc(token).set({
      'fileUrl': fileUrl,
      'fileName': fileName,
      'expiryTime': DateTime.now().add(const Duration(hours: 24)),
      'createdAt': FieldValue.serverTimestamp(),
      'downloadCount': 0,
    });

    final shareUrl = 'https://cryptaf-36296.web.app/share/$token';
    Clipboard.setData(ClipboardData(text: shareUrl));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secure link copied! Link expires in 24 hours'), backgroundColor: Colors.greenAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.category ?? 'My Vault', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search files...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFC9A84C)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  FilterChip(
                    selected: _showFavoritesOnly,
                    onSelected: (val) => setState(() => _showFavoritesOnly = val),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: _showFavoritesOnly ? Colors.redAccent : Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text('Favorites', style: TextStyle(color: _showFavoritesOnly ? Colors.redAccent : Colors.white54)),
                      ],
                    ),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    selectedColor: Colors.redAccent.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: _showFavoritesOnly ? Colors.redAccent.withOpacity(0.5) : Colors.white12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // File List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.getFiles(category: widget.category),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          const Text('Your vault is empty', style: TextStyle(color: Colors.white38, fontSize: 18)),
                        ],
                      ),
                    );
                  }

                  final allDocs = snapshot.data!.docs;
                  final nonDeletedDocs = allDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['deleted'] != true;
                  }).toList();

                  if (nonDeletedDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          const Text('Your vault is empty', style: TextStyle(color: Colors.white38, fontSize: 18)),
                        ],
                      ),
                    );
                  }

                  final docs = nonDeletedDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'].toString().toLowerCase();
                    final category = data.containsKey('category')
                        ? data['category'].toString().toLowerCase()
                        : 'documents';
                    final bool isFavorite = data['favorite'] == true;

                    if (_showFavoritesOnly && !isFavorite) return false;
                    return name.contains(_searchQuery) || category.contains(_searchQuery);
                  }).toList();

                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aFav = aData['favorite'] == true ? 1 : 0;
                    final bFav = bData['favorite'] == true ? 1 : 0;
                    if (aFav != bFav) {
                      return bFav.compareTo(aFav);
                    }
                    final aTime = aData['uploadedAt'] as Timestamp?;
                    final bTime = bData['uploadedAt'] as Timestamp?;
                    if (aTime != null && bTime != null) {
                      return bTime.compareTo(aTime);
                    }
                    return 0;
                  });

                  if (docs.isEmpty && _searchQuery.isNotEmpty) {
                    return const Center(
                      child: Text('No files match your search', style: TextStyle(color: Colors.white38)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name = data['name'];
                      final String type = data['type'];
                      final String category = data['category'] ?? 'Documents';
                      final bool encrypted = data['encrypted'] ?? true;
                      final String? downloadUrl = data['downloadUrl'];
                      final Timestamp? uploadedAt = data['uploadedAt'];
                      final int? sizeBytes = data['sizeBytes'] as int?;
                      final String? salt = data['salt'] as String?;
                      final String? iv = data['iv'] as String?;
                      final bool isFavorite = data['favorite'] == true;

                      String formattedDate = 'Recent';
                      if (uploadedAt != null) {
                        formattedDate = DateFormat('MMM dd, yyyy').format(uploadedAt.toDate());
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4), width: 1.2),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.15), blurRadius: 12),
                          ],
                        ),
                        child: ListTile(
                          onTap: downloadUrl != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FileViewScreen(
                                        docId: doc.id,
                                        name: name,
                                        type: type,
                                        category: category,
                                        downloadUrl: downloadUrl,
                                        uploadedAt: uploadedAt,
                                        sizeBytes: sizeBytes,
                                        salt: salt,
                                        iv: iv,
                                        isFavorite: isFavorite,
                                        isEncrypted: encrypted,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getFileColor(type).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: _getFileColor(type).withOpacity(0.3), blurRadius: 10),
                              ],
                            ),
                            child: Icon(_getFileIcon(type), color: _getFileColor(type)),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(category, style: TextStyle(color: _getCategoryColor(category), fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  const Text('•', style: TextStyle(color: Colors.white24)),
                                  const SizedBox(width: 8),
                                  Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                              if (encrypted) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.lock, size: 12, color: Color(0xFFC9A84C)),
                                    const SizedBox(width: 4),
                                    Text('Zero Knowledge Encrypted', style: TextStyle(color: const Color(0xFFC9A84C).withOpacity(0.8), fontSize: 11)),
                                  ],
                                ),
                              ]
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFavorite)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                                ),
                              if (downloadUrl != null) ...[
                                IconButton(
                                  icon: const Icon(Icons.share_outlined, color: Colors.greenAccent),
                                  onPressed: () => _generateShareLink(downloadUrl, name),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download_for_offline_outlined, color: Color(0xFFC9A84C)),
                                  onPressed: () => _openFile(downloadUrl),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white38),
                                onPressed: () => _deleteFile(doc.id, name),
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
}
