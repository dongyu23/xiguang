import 'dart:io';

import 'package:flutter/widgets.dart';

Widget? localFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return Image.file(file, fit: fit);
}
