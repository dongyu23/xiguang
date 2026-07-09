import 'dart:ui' show Color;

import 'package:drift/drift.dart' show Value;

import '../../shared/data/local/app_database.dart';
import '../domain/audio_track.dart';
import '../domain/emotion_color.dart';
import '../domain/emotion_repository.dart';
import '../domain/emotion_sounds.dart';
import '../domain/user_emotion.dart';

class EmotionRepository implements EmotionRepositoryPort {
  EmotionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<UserEmotion>> getAll() async {
    final rows = await _db.getAllEmotions();
    return rows
        .map((e) => UserEmotion(
              id: e.id,
              name: e.name,
              color: Color(e.colorHex),
              description: e.description,
              isDefault: e.isDefault,
              sortOrder: e.sortOrder,
              soundKey: e.soundKey,
              isUserDefault: e.isUserDefault,
              hidden: e.hidden,
            ))
        .toList();
  }

  @override
  Future<int> addCustom(String name,
      {String? description, String? soundKey}) async {
    final order = await _db.maxEmotionSortOrder();
    return _db.insertEmotion(EmotionsCompanion.insert(
      name: name,
      colorHex: autoColorForEmotionName(name).toARGB32(),
      description: Value(description ?? ''),
      isDefault: const Value(false),
      sortOrder: Value(order + 1),
      soundKey: Value(soundKey),
    ));
  }

  @override
  Future<void> update(UserEmotion emotion) async {
    await _db.updateEmotion(EmotionsCompanion(
      id: Value(emotion.id),
      name: Value(emotion.name),
      colorHex: Value(emotion.color.toARGB32()),
      description: Value(emotion.description),
      isDefault: Value(emotion.isDefault),
      sortOrder: Value(emotion.sortOrder),
      soundKey: Value(emotion.soundKey),
      isUserDefault: Value(emotion.isUserDefault),
      hidden: Value(emotion.hidden),
    ));
  }

  @override
  Future<void> delete(int id) async {
    await _db.deleteEmotion(id);
  }

  @override
  Future<void> setUserDefault(int id) async {
    await _db.transaction(() async {
      await _db.clearUserDefaultEmotion();
      await _db.markUserDefaultEmotion(id);
    });
  }

  @override
  Future<void> setHidden(int id, bool hidden) async {
    await _db.setEmotionHidden(id, hidden);
  }

  // ── 音频库 ──

  @override
  Future<List<AudioTrack>> getAllAudioTracks() async {
    final builtin = emotionSounds
        .map((s) => AudioTrack(
              key: s.key,
              name: s.name,
              source: AudioTrackSource.builtin,
              assetPath: s.assetPath,
            ))
        .toList();
    final rows = await _db.getAllAudioTracks();
    final custom = rows
        .map((r) => AudioTrack(
              key: r.key,
              name: r.name,
              source: AudioTrackSource.custom,
              filePath: r.filePath,
              dbId: r.id,
            ))
        .toList();
    return [...builtin, ...custom];
  }

  @override
  Future<int> addAudioTrack({
    required String key,
    required String name,
    required String filePath,
  }) async {
    return _db.insertAudioTrack(AudioLibraryCompanion.insert(
      key: key,
      name: name,
      filePath: filePath,
    ));
  }

  @override
  Future<void> deleteAudioTrack(int id) async {
    await _db.deleteAudioTrack(id);
  }
}
