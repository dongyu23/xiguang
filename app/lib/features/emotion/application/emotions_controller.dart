import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/emotion_color.dart';
import '../domain/user_emotion.dart';

export '../../../app/providers.dart' show emotionRepositoryProvider;
export '../domain/emotion_color.dart' show autoColorForEmotionName;

/// 选择器首屏最多展示的心绪数（7 个 + 1 个"更多"按钮 = 4×2 网格）。
const maxShownEmotions = 7;

final emotionsProvider =
    AsyncNotifierProvider<EmotionsController, List<UserEmotion>>(
  EmotionsController.new,
);

class DuplicateEmotionNameException implements Exception {
  const DuplicateEmotionNameException();
}

class EmotionsController extends AsyncNotifier<List<UserEmotion>> {
  @override
  Future<List<UserEmotion>> build() {
    return ref.watch(emotionRepositoryProvider).getAll();
  }

  Future<UserEmotion> addCustom(String name,
      {String? description, String? soundKey}) async {
    final emotions = await future;
    _ensureUnique(emotions, name);
    state = const AsyncLoading<List<UserEmotion>>().copyWithPrevious(state);
    try {
      final repository = ref.read(emotionRepositoryProvider);
      final id = await repository.addCustom(name,
          description: description, soundKey: soundKey);
      final emotion = UserEmotion(
        id: id,
        name: name,
        color: autoColorForEmotionName(name),
        description: description ?? '',
        isDefault: false,
        sortOrder: emotions.length,
        soundKey: soundKey,
      );
      state = AsyncData([...emotions, emotion]);
      return emotion;
    } catch (error, stackTrace) {
      state = AsyncError<List<UserEmotion>>(error, stackTrace)
          .copyWithPrevious(AsyncData(emotions));
      rethrow;
    }
  }

  Future<void> save({
    required UserEmotion existing,
    required String name,
    required Color color,
    required String description,
    String? soundKey,
    bool clearSound = false,
  }) async {
    final emotions = await future;
    _ensureUnique(emotions, name, excludingId: existing.id);
    final updated = existing.copyWith(
      name: name,
      color: color,
      description: description,
      soundKey: soundKey,
      clearSound: clearSound,
    );
    state = const AsyncLoading<List<UserEmotion>>().copyWithPrevious(state);
    try {
      await ref.read(emotionRepositoryProvider).update(updated);
      state = AsyncData([
        for (final emotion in emotions)
          if (emotion.id == updated.id) updated else emotion,
      ]);
    } catch (error, stackTrace) {
      state = AsyncError<List<UserEmotion>>(error, stackTrace)
          .copyWithPrevious(AsyncData(emotions));
      rethrow;
    }
  }

  Future<void> delete(UserEmotion emotion) async {
    final emotions = await future;
    state = const AsyncLoading<List<UserEmotion>>().copyWithPrevious(state);
    try {
      await ref.read(emotionRepositoryProvider).delete(emotion.id);
      state = AsyncData([
        for (final item in emotions)
          if (item.id != emotion.id) item,
      ]);
    } catch (error, stackTrace) {
      state = AsyncError<List<UserEmotion>>(error, stackTrace)
          .copyWithPrevious(AsyncData(emotions));
      rethrow;
    }
  }

  Future<void> toggleHidden(UserEmotion emotion) async {
    final emotions = await future;
    final newHidden = !emotion.hidden;
    state = const AsyncLoading<List<UserEmotion>>().copyWithPrevious(state);
    try {
      await ref
          .read(emotionRepositoryProvider)
          .setHidden(emotion.id, newHidden);
      state = AsyncData([
        for (final e in emotions)
          if (e.id == emotion.id) e.copyWith(hidden: newHidden) else e,
      ]);
    } catch (error, stackTrace) {
      state = AsyncError<List<UserEmotion>>(error, stackTrace)
          .copyWithPrevious(AsyncData(emotions));
      rethrow;
    }
  }

  void _ensureUnique(
    List<UserEmotion> emotions,
    String name, {
    int? excludingId,
  }) {
    if (emotions.any(
      (emotion) => emotion.name == name && emotion.id != excludingId,
    )) {
      throw const DuplicateEmotionNameException();
    }
  }
}
