import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> nextAudioCapturePath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/xiguang_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
}

Future<String?> audioPathToDataUrl(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return 'data:audio/wav;base64,${base64Encode(bytes)}';
}
