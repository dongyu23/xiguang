import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> nextAudioCapturePath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/xiguang_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
}

Future<String?> audioPathToDataUrl(String path, [String mime = 'audio/mp4']) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
