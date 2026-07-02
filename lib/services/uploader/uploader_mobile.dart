import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'uploader_interface.dart';

class PlatformUploader extends BaseUploader {
  @override
  Future<String?> upload({
    required String url,
    required String fileName,
    required Uint8List fileBytes,
    required Map<String, String> fields,
  }) async {
    var uri = Uri.parse(url);
    var request = http.MultipartRequest('POST', uri);

    fields.forEach((key, value) {
      request.fields[key] = value;
    });

    var multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType('application', 'octet-stream'),
    );

    request.files.add(multipartFile);

    var response = await request.send().timeout(const Duration(seconds: 60));
    var responseData = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'];
    } else {
      debugPrint('Mobile Upload Failed: ${response.statusCode} - $responseData');
      return null;
    }
  }
}
