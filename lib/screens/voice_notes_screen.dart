import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptaf/services/crypto_service.dart';
import 'package:cryptaf/services/cloudinary_service.dart';
import 'package:cryptaf/widgets/animated_background.dart';
import 'package:cryptaf/widgets/glass_container.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class VoiceNotesScreen extends StatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  _VoiceNotesScreenState createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final CryptoService _crypto = CryptoService();
  final CloudinaryService _cloudinary = CloudinaryService();
  
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isUploading = false;
  String _currentlyPlayingId = '';
  
  Timer? _recordTimer;
  int _recordDuration = 0;
  
  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<bool> _requestMicPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      // Fallback - try to initialize without permission check
      return true;
    }
  }

  Future<void> _initAudio() async {
    try {
      if (!kIsWeb) {
        final granted = await _requestMicPermission();
        if (!granted) {
          throw Exception('Microphone permission not granted');
        }
      }
      try {
        await _recorder.openRecorder();
      } catch (e) {
        debugPrint('Audio init error: $e');
      }
      await _player.openPlayer();
      setState(() {
        _isRecorderInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize audio: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  void _startRecordTimer() {
    _recordDuration = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    try {
      final String filePath = 'voice_note_temp.m4a';
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacMP4,
      );
      setState(() {
        _isRecording = true;
      });
      _startRecordTimer();
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    try {
      _stopRecordTimer();
      final String? path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });

      if (path != null) {
        Uint8List audioBytes;
        if (kIsWeb) {
          final res = await http.get(Uri.parse(path));
          audioBytes = res.bodyBytes;
        } else {
          // On mobile, read file from path
          final uri = Uri.parse(path);
          final res = await http.get(uri); // Workaround for simple bytes reading
          audioBytes = res.bodyBytes;
        }

        // Encrypt audio
        final salt = _crypto.generateSalt();
        final key = _crypto.deriveKey(_crypto.masterAppKey, salt);
        final encResult = _crypto.encryptFile(audioBytes, key, ivBase64: null);
        
        final fileName = 'voicenote_${DateTime.now().millisecondsSinceEpoch}';
        final url = await _cloudinary.uploadFile(fileName, encResult.encryptedBytes);
        
        if (url != null) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('voice_notes')
                .add({
              'downloadUrl': url,
              'salt': salt,
              'iv': encResult.iv,
              'duration': _recordDuration,
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice note saved securely!'), backgroundColor: Colors.greenAccent),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save voice note: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _playVoiceNote(String docId, String url, String salt, String iv) async {
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = '';
      });
      if (_currentlyPlayingId == docId) return; // Toggle play/pause behavior
    }

    setState(() {
      _currentlyPlayingId = docId;
      _isPlaying = true;
    });

    try {
      final res = await http.get(Uri.parse(url));
      final key = _crypto.deriveKey(_crypto.masterAppKey, salt);
      final decryptedBytes = _crypto.decryptFile(res.bodyBytes, key, ivBase64: iv);

      // On web, we can play from a data URI
      final base64Audio = base64Encode(decryptedBytes);
      final mime = kIsWeb ? 'audio/webm' : 'audio/mp4';
      final dataUri = 'data:$mime;base64,$base64Audio';

      await _player.startPlayer(
        fromURI: dataUri,
        codec: Codec.aacMP4,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentlyPlayingId = '';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Voice Notes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Record a secure voice note for your nominees.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_isUploading)
                      const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)))
                    else
                      GestureDetector(
                        onTap: _isRecording ? _stopRecordingAndUpload : _startRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _isRecording ? Colors.redAccent.withOpacity(0.2) : const Color(0xFFC9A84C).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording ? Colors.redAccent : const Color(0xFFC9A84C).withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: _isRecording ? Colors.redAccent : const Color(0xFFC9A84C),
                            size: 48,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording ? 'Recording... ${_formatDuration(_recordDuration)}' : 'Tap to Record',
                      style: TextStyle(
                        color: _isRecording ? Colors.redAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (kIsWeb)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A84C).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFFC9A84C)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFFC9A84C)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ðŸ¤– Voice recording is available on Android app only',
                        style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Your Saved Notes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('voice_notes')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No voice notes yet.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final duration = data['duration'] as int? ?? 0;
                      final ts = data['createdAt'] as Timestamp?;
                      final timeStr = ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : 'Recently';
                      
                      final bool isThisPlaying = _isPlaying && _currentlyPlayingId == doc.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: GestureDetector(
                            onTap: () {
                              _playVoiceNote(doc.id, data['downloadUrl'], data['salt'], data['iv']);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isThisPlaying ? const Color(0xFFC9A84C).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isThisPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: isThisPlaying ? const Color(0xFFC9A84C) : Colors.white,
                              ),
                            ),
                          ),
                          title: Text('Note from $timeStr', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Duration: ${_formatDuration(duration)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
