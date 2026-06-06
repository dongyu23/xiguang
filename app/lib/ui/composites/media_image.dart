import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'media_file_image_stub.dart'
    if (dart.library.io) 'media_file_image_io.dart';

class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    required this.fallback,
  });

  final String source;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return fallback;
    if (_isRemote(value)) {
      return Image.network(value, fit: fit, errorBuilder: (_, __, ___) {
        return fallback;
      });
    }
    final bytes = _dataUrlBytes(value);
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, errorBuilder: (_, __, ___) {
        return fallback;
      });
    }
    return localFileImage(value, fit: fit) ?? fallback;
  }

  bool _isRemote(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  Uint8List? _dataUrlBytes(String value) {
    if (!value.startsWith('data:image/')) return null;
    final comma = value.indexOf(',');
    if (comma == -1 || !value.substring(0, comma).contains(';base64')) {
      return null;
    }
    try {
      return base64Decode(value.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }
}
