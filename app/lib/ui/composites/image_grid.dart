import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/typography.dart';
import 'media_image.dart';

class ImageGrid extends StatelessWidget {
  const ImageGrid({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final images =
        urls.where((url) => !url.startsWith('audio-cue://')).toList();
    final audio = urls.where((url) => url.startsWith('audio-cue://')).toList();
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        ...images.map((url) => _PreviewImage(url: url)),
        ...audio.map((url) => _AudioPreview(url: url)),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return MediaImage(source: url, fallback: _fallback);
  }

  Widget get _fallback => Container(
        color: const Color(0xFFE9E1D5),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      );
}

class _AudioPreview extends StatelessWidget {
  const _AudioPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.teaGreen.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.teaGreen.withValues(alpha: .24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.graphic_eq_rounded, color: AppColors.teaGreen),
        const SizedBox(height: 6),
        Text(_label, style: AppText.caption),
      ]),
    );
  }

  String get _label {
    final seconds = _durationSeconds(url);
    if (seconds == null) return '声音';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  int? _durationSeconds(String source) {
    final uri = Uri.tryParse(source);
    final value = uri?.queryParameters['duration'];
    if (value != null) return int.tryParse(value);
    const legacyPrefix = 'audio-cue://duration=';
    if (source.startsWith(legacyPrefix)) {
      return int.tryParse(source.substring(legacyPrefix.length));
    }
    return value == null ? null : int.tryParse(value);
  }
}
