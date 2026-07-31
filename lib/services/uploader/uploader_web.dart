// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'uploader_interface.dart';

class PlatformUploader extends BaseUploader {
  @override
  Future<String?> upload({
    required String url,
    required String fileName,
    required Uint8List fileBytes,
    required Map<String, String> fields,
  }) async {
    final completer = Completer<String?>();
    final xhr = html.HttpRequest();

    xhr.timeout = 60000; // 60 seconds
    xhr.withCredentials = false;
    xhr.open('POST', url);

    final formData = html.FormData();
    
    // Add fields
    fields.forEach((key, value) {
      debugPrint('FormData append field -> $key: $value');
      formData.append(key, value);
    });

    // Add file as Blob
    final blob = html.Blob([fileBytes]);
    formData.appendBlob('file', blob, fileName);

    xhr.onLoad.listen((e) {
      if (xhr.status == 200) {
        final jsonResponse = json.decode(xhr.responseText!);
        completer.complete(jsonResponse['secure_url']);
      } else {
        final errText = xhr.responseText ?? 'No response text';
        debugPrint('Web Upload Failed: ${xhr.status} - $errText');
        completer.completeError('HTTP ${xhr.status}: $errText');
      }
    });

    xhr.onError.listen((e) {
      debugPrint('Web Upload Error: $e');
      completer.completeError('Network Error during Cloudinary upload');
    });

    xhr.onTimeout.listen((e) {
      debugPrint('Web Upload Timeout');
      completer.completeError('Cloudinary upload timed out');
    });

    xhr.send(formData);

    return completer.future;
  }
}
