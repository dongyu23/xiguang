import 'package:flutter_riverpod/flutter_riverpod.dart';

class CaptureDraft {
  const CaptureDraft({
    this.text = '',
    this.emotion = '说不清',
    this.tags = const [],
  });

  final String text;
  final String emotion;
  final List<String> tags;
}

final captureDraftProvider = StateProvider<CaptureDraft>((ref) {
  return const CaptureDraft();
});
