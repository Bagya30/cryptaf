import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
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
    xhr.open('POST', url);

    final formData = html.FormData();
    
    // Add fields
    fields.forEach((key, value) {
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
        debugPrint('Web Upload Failed: ${xhr.status} - ${xhr.responseText}');
        completer.complete(null);
      }
    });

    xhr.onError.listen((e) {
      debugPrint('Web Upload Error: $e');
      completer.complete(null);
    });

    xhr.send(formData);

    return completer.future;
  }
}
