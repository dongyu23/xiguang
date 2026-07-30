import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiguang/features/membership/data/membership_repository.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

void main() {
  test('clears legacy trial keys before loading server membership', () async {
    SharedPreferences.setMockInitialValues({
      'xiguang.membership.tier': 'galaxy',
      'xiguang.membership.expires_at': '2099-01-01T00:00:00Z',
      'xiguang.membership.is_trial': true,
      'unrelated': 'keep',
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/billing/me') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'code': 'success',
            'data': {'tier': 'glimmer', 'status': 'active'},
          },
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'code': 'success',
          'data': {'items': []},
        },
      ));
    }));

    final status = await MembershipRepositoryImpl(ApiClient(dio: dio)).load(7);
    final prefs = await SharedPreferences.getInstance();

    expect(status.tier.code, 'glimmer');
    expect(prefs.containsKey('xiguang.membership.tier'), isFalse);
    expect(prefs.containsKey('xiguang.membership.expires_at'), isFalse);
    expect(prefs.containsKey('xiguang.membership.is_trial'), isFalse);
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('uses a valid signed entitlement snapshot for offline display',
      () async {
    SharedPreferences.setMockInitialValues({});
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final header =
        base64Url.encode(utf8.encode('{"alg":"EdDSA"}')).replaceAll('=', '');
    final claims = base64Url
        .encode(utf8.encode(jsonEncode({
          'sub': 42,
          'tier': 'starlight',
          'status': 'active',
          'storage_quota_bytes': 20 * 1024 * 1024 * 1024,
          'version': 3,
          'exp': DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 72))
                  .millisecondsSinceEpoch ~/
              1000,
        })))
        .replaceAll('=', '');
    final signature = await algorithm.sign(
      utf8.encode('$header.$claims'),
      keyPair: keyPair,
    );
    final token =
        '$header.$claims.${base64Url.encode(signature.bytes).replaceAll('=', '')}';
    final encodedPublicKey =
        base64Url.encode(publicKey.bytes).replaceAll('=', '');

    final onlineDio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    onlineDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'code': 'success',
          'data': options.path == '/billing/me'
              ? {
                  'tier': 'starlight',
                  'status': 'active',
                  'offline_snapshot': token,
                  'offline_public_key': encodedPublicKey,
                }
              : {'items': <dynamic>[]},
        },
      )),
    ));
    await MembershipRepositoryImpl(ApiClient(dio: onlineDio)).load(42);

    final offlineDio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    offlineDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      )),
    ));
    final offline =
        await MembershipRepositoryImpl(ApiClient(dio: offlineDio)).load(42);

    expect(offline.tier.code, 'starlight');
    expect(offline.version, 3);
    expect(offline.products, isEmpty);

    await expectLater(
      MembershipRepositoryImpl(ApiClient(dio: offlineDio)).load(43),
      throwsA(isA<DioException>()),
    );
  });
}
