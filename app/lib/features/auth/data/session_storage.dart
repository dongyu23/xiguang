import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

class StoredAuthSession {
  const StoredAuthSession({
    required this.session,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final AuthSession session;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

class SessionStorage {
  const SessionStorage([this._secureStorage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _secureStorage;

  static const _authKey = 'xiguang.auth_bundle';
  // Legacy keys for migration
  static const _legacyKeys = [
    'xiguang.access_token',
    'xiguang.refresh_token',
    'xiguang.expires_at',
    'xiguang.user.id',
    'xiguang.user.public_id',
    'xiguang.user.username',
    'xiguang.user.nickname',
    'xiguang.user.avatar_key',
    'xiguang.user.ai_enabled',
    'xiguang.user.privacy_mode',
  ];

  Future<StoredAuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    // Try bundled read first
    final bundle = await _readBundle();
    if (bundle != null) return _parseBundle(bundle);

    // Fallback: legacy multi-key migration
    final accessToken = await _readLegacySecret(prefs, _legacyKeys[0]);
    final refreshToken = await _readLegacySecret(prefs, _legacyKeys[1]);
    final expiresRaw = await _readLegacySecret(prefs, _legacyKeys[2]);
    if (accessToken == null || refreshToken == null || expiresRaw == null) {
      return null;
    }
    final session = AuthSession(
      id: prefs.getInt(_legacyKeys[3]) ?? 0,
      publicId: prefs.getString(_legacyKeys[4]) ?? '',
      username: prefs.getString(_legacyKeys[5]) ?? '',
      nickname: prefs.getString(_legacyKeys[6]) ?? '试光者',
      avatarKey: prefs.getString(_legacyKeys[7]) ?? '',
      aiEnabled: prefs.getBool(_legacyKeys[8]) ?? false,
      privacyMode: prefs.getString(_legacyKeys[9]) ?? 'private',
    );
    final stored = StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.tryParse(expiresRaw) ?? DateTime.now(),
      session: session,
    );
    // Migrate to bundle format
    await save(stored);
    return stored;
  }

  Future<void> save(StoredAuthSession value) async {
    final bundle = jsonEncode({
      'at': value.accessToken,
      'rt': value.refreshToken,
      'exp': value.expiresAt.toIso8601String(),
      'id': value.session.id,
      'pid': value.session.publicId,
      'u': value.session.username,
      'n': value.session.nickname,
      'ak': value.session.avatarKey,
      'ai': value.session.aiEnabled,
      'pm': value.session.privacyMode,
    });
    await _writeBundle(bundle);
  }

  Future<void> delete() async {
    try {
      await _secureStorage.delete(key: _authKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    // Also clean up legacy keys
    for (final key in _legacyKeys) {
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {}
      await prefs.remove(key);
      await prefs.remove('$key.fallback');
    }
  }

  Future<String?> _readBundle() async {
    try {
      final value = await _secureStorage.read(key: _authKey);
      if (value != null) return value;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authKey);
  }

  Future<void> _writeBundle(String bundle) async {
    try {
      await _secureStorage.write(key: _authKey, value: bundle);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authKey, bundle);
    }
  }

  StoredAuthSession? _parseBundle(String bundle) {
    try {
      final decoded = jsonDecode(bundle) as Map<String, dynamic>;
      return StoredAuthSession(
        accessToken: decoded['at'] as String? ?? '',
        refreshToken: decoded['rt'] as String? ?? '',
        expiresAt: DateTime.tryParse(decoded['exp'] as String? ?? '') ?? DateTime.now(),
        session: AuthSession(
          id: decoded['id'] as int? ?? 0,
          publicId: decoded['pid'] as String? ?? '',
          username: decoded['u'] as String? ?? '',
          nickname: decoded['n'] as String? ?? '试光者',
          avatarKey: decoded['ak'] as String? ?? '',
          aiEnabled: decoded['ai'] as bool? ?? false,
          privacyMode: decoded['pm'] as String? ?? 'private',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readLegacySecret(
      SharedPreferences prefs, String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value != null) return value;
    } catch (_) {}
    return prefs.getString('$key.fallback');
  }
}
