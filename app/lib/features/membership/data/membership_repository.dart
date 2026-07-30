import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../design/tokens/motion.dart';
import '../../shared/data/api_client.dart';
import '../domain/membership.dart';
import '../domain/membership_repository.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl(this._api);

  final ApiClient _api;

  static const _legacyKeys = <String>[
    'xiguang.membership.tier',
    'xiguang.membership.expires_at',
    'xiguang.membership.is_trial',
  ];
  static const _snapshotPrefix = 'xiguang.membership.offline_snapshot';
  static const _snapshotPublicKeyPrefix =
      'xiguang.membership.offline_public_key';

  @override
  Future<MembershipStatus> load(int userId) async {
    await _clearLegacyTrial();
    final providers = Platform.isIOS
        ? const ['apple']
        : Platform.isAndroid
            ? const ['wechat', 'alipay']
            : const ['apple'];
    try {
      final responses = await Future.wait([
        _api.get('/billing/me'),
        ...providers.map(
          (provider) =>
              _api.get('/billing/catalog', query: {'provider': provider}),
        ),
      ]);
      final products = <BillingProduct>[];
      for (final response in responses.skip(1)) {
        final raw = response['items'];
        if (raw is List) {
          products.addAll(raw.whereType<Map>().map((item) =>
              BillingProduct.fromJson(Map<String, dynamic>.from(item))));
        }
      }
      await _cacheOfflineSnapshot(userId, responses.first);
      return MembershipStatus.fromJson(responses.first, products: products);
    } catch (_) {
      final cached = await _loadOfflineSnapshot(userId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createDirect(BillingProduct product) {
    return _api.post('/billing/subscriptions', {
      'provider': product.provider,
      'product_code': product.code,
      'client_request_id':
          '${DateTime.now().microsecondsSinceEpoch}-${product.code}',
    });
  }

  @override
  Future<String> waitForDirectActivation(String orderId) async {
    for (var attempt = 0; attempt < 15; attempt++) {
      final responses = await Future.wait([
        _api.get('/billing/orders/$orderId'),
        _api.get('/billing/me'),
      ]);
      final orderStatus = responses.first['status'] as String? ?? 'pending';
      final tier = responses.last['tier'] as String? ?? 'glimmer';
      if (tier != 'glimmer' || orderStatus == 'paid') return 'active';
      if (const {'failed', 'closed', 'refunded'}.contains(orderStatus)) {
        return orderStatus;
      }
      await Future<void>.delayed(AppTiming.paymentStatusPoll);
    }
    return 'pending';
  }

  @override
  Future<void> verifyApple(String signedTransaction) async {
    await _api.post('/billing/apple/verify', {
      'signed_transaction': signedTransaction,
    });
  }

  @override
  Future<void> restoreApple(List<String> signedTransactions) async {
    await _api.post('/billing/apple/restore', {
      'signed_transactions': signedTransactions,
    });
  }

  @override
  Future<void> cancel(String subscriptionId) async {
    await _api.post('/billing/subscriptions/$subscriptionId/cancel', const {});
  }

  Future<void> _clearLegacyTrial() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
  }

  Future<void> _cacheOfflineSnapshot(
    int userId,
    Map<String, dynamic> entitlement,
  ) async {
    final snapshot = entitlement['offline_snapshot'] as String? ?? '';
    final publicKey = entitlement['offline_public_key'] as String? ?? '';
    if (snapshot.isEmpty || publicKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final snapshotKey = '$_snapshotPrefix.$userId';
    final publicKeyKey = '$_snapshotPublicKeyPrefix.$userId';
    final pinnedKey = prefs.getString(publicKeyKey);
    if (pinnedKey != null && pinnedKey != publicKey) {
      await prefs.remove(snapshotKey);
      throw StateError('离线权益签名密钥发生变化。');
    }
    await prefs.setString(publicKeyKey, publicKey);
    await prefs.setString(snapshotKey, snapshot);
  }

  Future<MembershipStatus?> _loadOfflineSnapshot(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshotKey = '$_snapshotPrefix.$userId';
    final token = prefs.getString(snapshotKey);
    final encodedPublicKey =
        prefs.getString('$_snapshotPublicKeyPrefix.$userId');
    if (token == null || encodedPublicKey == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final publicKey = SimplePublicKey(
        base64Url.decode(base64Url.normalize(encodedPublicKey)),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        base64Url.decode(base64Url.normalize(parts[2])),
        publicKey: publicKey,
      );
      final valid = await Ed25519().verify(
        utf8.encode('${parts[0]}.${parts[1]}'),
        signature: signature,
      );
      if (!valid) return null;
      final claims = Map<String, dynamic>.from(jsonDecode(utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      )) as Map);
      if ((claims['sub'] as num?)?.toInt() != userId) return null;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        ((claims['exp'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      );
      if (!expiresAt.isAfter(DateTime.now().toUtc())) {
        await prefs.remove(snapshotKey);
        return null;
      }
      return MembershipStatus.fromJson(claims, products: const []);
    } catch (_) {
      return null;
    }
  }
}
