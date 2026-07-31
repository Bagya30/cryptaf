import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'uploader/uploader_mobile.dart'
    if (dart.library.html) 'uploader/uploader_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get _cloudName {
    final val = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    return (val != null && val.isNotEmpty) ? val : 'dbkwa74hv';
  }

  static String get _apiKey {
    final val = dotenv.env['CLOUDINARY_API_KEY'];
    return (val != null && val.isNotEmpty) ? val : '781795518437784';
  }

  static String get _apiSecret {
    final val = dotenv.env['CLOUDINARY_API_SECRET'];
    return (val != null && val.isNotEmpty) ? val : 'KnYzuXmZb85IiFK-iEoVJz4fVPM';
  }

  Future<String?> uploadFile(String fileName, Uint8List fileBytes, {String resourceType = 'auto'}) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      
      // Generate Signature
      final stringToSign = 'timestamp=$timestamp$_apiSecret';
      final bytes = utf8.encode(stringToSign);
      final digest = sha1.convert(bytes);
      final signature = digest.toString();

      debugPrint('Cloudinary Upload Params -> url: https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload, api_key: $_apiKey, timestamp: $timestamp');

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
