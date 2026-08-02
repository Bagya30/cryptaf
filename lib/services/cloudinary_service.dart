import 'package:flutter/foundation.dart';
import 'uploader/uploader_mobile.dart'
    if (dart.library.html) 'uploader/uploader_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  Future<String?> uploadFile(String fileName, Uint8List fileBytes, {String resourceType = 'auto'}) async {
    try {
      if (_cloudName.isEmpty) {
        throw Exception('Cloudinary credentials not loaded - app_config.txt file may be missing or failed to load');
      }

      final uploadPreset = resourceType == 'raw' ? 'cryptaf_vault' : 'cryptaf_media';

      debugPrint('Cloudinary Upload Params -> url: https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload, preset: $uploadPreset');

      final uploader = PlatformUploader();
      
      return await uploader.upload(
        url: 'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
        fileName: fileName,
        fileBytes: fileBytes,
        fields: {
          'upload_preset': uploadPreset,
        },
      );
    } catch (e) {
      debugPrint('Cloudinary Exception: $e');
      rethrow;
    }
  }
}
