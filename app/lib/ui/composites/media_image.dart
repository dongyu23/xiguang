import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens/colors.dart';
import '../../app/providers.dart';
import 'media_file_image_stub.dart'
    if (dart.library.io) 'media_file_image_io.dart';

/// H4: LRU cache with max 30 entries to prevent unbounded memory growth
final _memoryCache = <String, Uint8List>{};
const _maxCacheEntries = 30;

void _evictCacheIfNeeded() {
  if (_memoryCache.length >= _maxCacheEntries) {
    _memoryCache.remove(_memoryCache.keys.first);
  }
}

/// 媒体图片组件 — 支持 base64/本地路径/网络URL，网络图片带缓存
class MediaImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final value = source.trim();
    if (value.isEmpty) return fallback;

    // Network URLs (http/https) or proxied paths (/media/ or users/ -> /media/)
    final api = ref.watch(apiClientProvider);
    final networkSource = _networkSource(value, api);
    final needsAuth =
        value.startsWith('users/') || value.startsWith('/media/users/');
    if (networkSource != null) {
      return CachedNetworkImage(
        imageUrl: networkSource,
        httpHeaders: needsAuth ? api.mediaAuthorizationHeaders : const {},
        fit: fit,
        placeholder: (_, __) => Container(
          color: AppColors.paper,
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.teaGreen,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => fallback,
      );
    }

    // Base64 data URLs — small ones sync, large ones async
    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma != -1 && value.substring(0, comma).contains(';base64')) {
        final base64Part = value.substring(comma + 1);
        // C5: Under 256KB → sync decode; over → async via compute
        if (base64Part.length < 256 * 1024) {
          final bytes = _decodeBase64Cached(value, base64Part);
          if (bytes != null) {
            return Image.memory(bytes,
                fit: fit, errorBuilder: (_, __, ___) => fallback);
          }
        } else {
          return _AsyncBase64Image(
            cacheKey: value,
            base64Part: base64Part,
            fit: fit,
            fallback: fallback,
          );
        }
      }
    }

    // Local file / asset
    return localFileImage(value, fit: fit) ?? fallback;
  }

  static Uint8List? _decodeBase64Cached(String cacheKey, String base64Part) {
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }
    try {
      final bytes = base64Decode(base64Part);
      if (bytes.lengthInBytes <= 5 * 1024 * 1024) {
        _evictCacheIfNeeded();
        _memoryCache[cacheKey] = bytes;
      }
      return bytes;
    } on FormatException {
      return null;
    }
  }

  String? _networkSource(String value, dynamic api) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/media/users/')) {
      return api.mediaObjectUrl(value.substring('/media/'.length));
    }
    if (value.startsWith('users/')) return api.mediaObjectUrl(value);
    return null;
  }
}

/// C5: Async base64 decode widget for large images (avoids blocking UI thread)
class _AsyncBase64Image extends StatefulWidget {
  const _AsyncBase64Image({
    required this.cacheKey,
    required this.base64Part,
    required this.fit,
    required this.fallback,
  });

  final String cacheKey;
  final String base64Part;
  final BoxFit fit;
  final Widget fallback;

  @override
  State<_AsyncBase64Image> createState() => _AsyncBase64ImageState();
}

class _AsyncBase64ImageState extends State<_AsyncBase64Image> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final bytes = await compute(base64Decode, widget.base64Part);
      if (!mounted) return;
      if (bytes.lengthInBytes <= 5 * 1024 * 1024) {
        _evictCacheIfNeeded();
        _memoryCache[widget.cacheKey] = bytes;
      }
      setState(() => _bytes = bytes);
    } catch (_) {
      // decode failed, show fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return Container(
        color: AppColors.paper,
        alignment: Alignment.center,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.teaGreen,
          ),
        ),
      );
    }
    return Image.memory(bytes,
        fit: widget.fit, errorBuilder: (_, __, ___) => widget.fallback);
  }
}
