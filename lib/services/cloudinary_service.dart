import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'uploader/uploader_mobile.dart'
    if (dart.library.html) 'uploader/uploader_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get _apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  Future<String?> uploadFile(String fileName, Uint8List fileBytes, {String resourceType = 'auto'}) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      
      // Generate Signature
      final stringToSign = 'timestamp=$timestamp$_apiSecret';
      final bytes = utf8.encode(stringToSign);
      final digest = sha1.convert(bytes);
      final signature = digest.toString();

      final uploader = PlatformUploader();
      
      return await uploader.upload(
        url: 'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
        fileName: fileName,
        fileBytes: fileBytes,
        fields: {
          'api_key': _apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );
    } catch (e) {
      debugPrint('Cloudinary Exception: $e');
      rethrow;
    }
  }
}
