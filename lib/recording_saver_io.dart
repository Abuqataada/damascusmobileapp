import 'dart:convert';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('damascus_projects/recording_saver');

Future<String?> saveRecordingFromBase64({
  required String fileName,
  required String base64Data,
}) async {
  final normalized = base64Data.contains(',')
      ? base64Data.substring(base64Data.indexOf(',') + 1)
      : base64Data;
  final bytes = base64Decode(normalized);

  return _channel.invokeMethod<String>(
    'saveRecording',
    <String, dynamic>{
      'fileName': fileName,
      'bytes': Uint8List.fromList(bytes),
      'mimeType': 'video/webm',
    },
  );
}
