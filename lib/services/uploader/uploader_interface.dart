import 'dart:typed_data';

abstract class BaseUploader {
  Future<String?> upload({
    required String url,
    required String fileName,
    required Uint8List fileBytes,
    required Map<String, String> fields,
  });
}
