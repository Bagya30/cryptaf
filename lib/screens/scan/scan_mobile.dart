import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../services/crypto_service.dart';
import '../../widgets/solid_button.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  Uint8List? _capturedBytes;
  bool _isProcessing = false;
  String _selectedCategory = 'Documents';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      setState(() {
        _capturedBytes = bytes;
      });
    } catch (e) {
      debugPrint('Take picture error: $e');
    }
  }

  void _showCategorySelection() {
    final TextEditingController passwordController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: const Color(0xFFC9A84C).withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: const Color(0xFFC9A84C).withOpacity(0.4)),
                      ),
                    ),
                    items: ['Documents', 'Medical', 'Financial', 'Legal']
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Vault Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter vault password',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: const Color(0xFFC9A84C).withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: const Color(0xFFC9A84C).withOpacity(0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SolidButton(
                    text: _isProcessing ? 'Saving...' : 'Save to Vault',
                    isLoading: _isProcessing,
                    onPressed: () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your vault password'), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                      if (_isProcessing) return;
                      setModalState(() {
                        _isProcessing = true;
                      });
                      setState(() {
                        _isProcessing = true;
                      });

                      try {
                        final CryptoService crypto = CryptoService();
                        final isValid = await crypto.verifyVaultPassword(passwordController.text);
                        if (!isValid) {
                          if (mounted) {
                            setModalState(() => _isProcessing = false);
                            setState(() => _isProcessing = false);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Incorrect vault password'), backgroundColor: Colors.redAccent),
                            );
                          }
                          return;
                        }

                        final salt = crypto.generateSalt();
                        final key = crypto.deriveKey(passwordController.text, salt);
                        final encResult = crypto.encryptFile(_capturedBytes!, key, ivBase64: null);

                        final String fileName = 'Scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final url = await CloudinaryService().uploadFile(fileName, encResult.encryptedBytes);

                        if (url != null) {
                          await FirestoreService().uploadFileRecord(
                            fileName,
                            'image/jpeg',
                            true,
                            downloadUrl: url,
                            sizeBytes: encResult.encryptedBytes.length,
                            category: _selectedCategory,
                            salt: salt,
                            iv: encResult.iv,
                          );

                          if (mounted) {
                            // ignore: use_build_context_synchronously
                            Navigator.pop(ctx); // pop modal
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Document scanned and saved to vault!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.pop(context); // pop scan screen
                          }
                        } else {
                          if (mounted) {
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Upload failed. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Save error: $e');
                      } finally {
                        if (mounted) {
                          setModalState(() {
                            _isProcessing = false;
                          });
                          setState(() {
                            _isProcessing = false;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Scan Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _capturedBytes != null
          ? Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_capturedBytes!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _capturedBytes = null;
                            });
                          },
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SolidButton(
                          text: 'Use Photo',
                          onPressed: _showCategorySelection,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _isInitialized
              ? Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SolidButton(
                        text: 'Capture Photo',
                        onPressed: _takePicture,
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
                ),
    );
  }
}
