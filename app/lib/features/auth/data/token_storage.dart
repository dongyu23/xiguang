import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/token.dart';

class TokenStorage {
  const TokenStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  Future<TokenPair?> read() async {
    final accessToken = await _storage.read(key: 'access_token');
    final refreshToken = await _storage.read(key: 'refresh_token');
    final expiresAt = await _storage.read(key: 'expires_at');
    if (accessToken == null || refreshToken == null || expiresAt == null) {
      return null;
    }
    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.tryParse(expiresAt) ?? DateTime.now(),
    );
  }

  Future<void> save(TokenPair pair) async {
    await _storage.write(key: 'access_token', value: pair.accessToken);
    await _storage.write(key: 'refresh_token', value: pair.refreshToken);
    await _storage.write(
        key: 'expires_at', value: pair.expiresAt.toIso8601String());
  }

  Future<void> delete() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'expires_at');
  }
}
