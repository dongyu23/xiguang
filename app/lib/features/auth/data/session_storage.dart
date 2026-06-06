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

  static const _accessToken = 'xiguang.access_token';
  static const _refreshToken = 'xiguang.refresh_token';
  static const _expiresAt = 'xiguang.expires_at';
  static const _id = 'xiguang.user.id';
  static const _publicId = 'xiguang.user.public_id';
  static const _username = 'xiguang.user.username';
  static const _nickname = 'xiguang.user.nickname';
  static const _avatarKey = 'xiguang.user.avatar_key';
  static const _aiEnabled = 'xiguang.user.ai_enabled';
  static const _privacyMode = 'xiguang.user.privacy_mode';

  Future<StoredAuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = await _readSecret(prefs, _accessToken);
    final refreshToken = await _readSecret(prefs, _refreshToken);
    final expiresRaw = await _readSecret(prefs, _expiresAt);
    if (accessToken == null || refreshToken == null || expiresRaw == null) {
      return null;
    }
    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.tryParse(expiresRaw) ?? DateTime.now(),
      session: AuthSession(
        id: prefs.getInt(_id) ?? 0,
        publicId: prefs.getString(_publicId) ?? '',
        username: prefs.getString(_username) ?? '',
        nickname: prefs.getString(_nickname) ?? '试光者',
        avatarKey: prefs.getString(_avatarKey) ?? '',
        aiEnabled: prefs.getBool(_aiEnabled) ?? false,
        privacyMode: prefs.getString(_privacyMode) ?? 'private',
      ),
    );
  }

  Future<void> save(StoredAuthSession value) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeSecret(prefs, _accessToken, value.accessToken);
    await _writeSecret(prefs, _refreshToken, value.refreshToken);
    await _writeSecret(prefs, _expiresAt, value.expiresAt.toIso8601String());
    await prefs.setInt(_id, value.session.id);
    await prefs.setString(_publicId, value.session.publicId);
    await prefs.setString(_username, value.session.username);
    await prefs.setString(_nickname, value.session.nickname);
    await prefs.setString(_avatarKey, value.session.avatarKey);
    await prefs.setBool(_aiEnabled, value.session.aiEnabled);
    await prefs.setString(_privacyMode, value.session.privacyMode);
  }

  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _deleteSecret(prefs, _accessToken),
      _deleteSecret(prefs, _refreshToken),
      _deleteSecret(prefs, _expiresAt),
    ]);
    await Future.wait([
      prefs.remove(_id),
      prefs.remove(_publicId),
      prefs.remove(_username),
      prefs.remove(_nickname),
      prefs.remove(_avatarKey),
      prefs.remove(_aiEnabled),
      prefs.remove(_privacyMode),
    ]);
  }

  Future<String?> _readSecret(SharedPreferences prefs, String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value != null) return value;
    } catch (_) {
      // Web demos can run over plain LAN HTTP, where secure storage may fail.
    }
    return prefs.getString(_fallbackKey(key));
  }

  Future<void> _writeSecret(
      SharedPreferences prefs, String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      await prefs.remove(_fallbackKey(key));
    } catch (_) {
      await prefs.setString(_fallbackKey(key), value);
    }
  }

  Future<void> _deleteSecret(SharedPreferences prefs, String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // Keep logout reliable even when secure storage is unavailable.
    }
    await prefs.remove(_fallbackKey(key));
  }

  String _fallbackKey(String key) => '$key.fallback';
}
