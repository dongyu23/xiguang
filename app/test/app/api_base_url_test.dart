import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/app/providers.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

void main() {
  group('API base URL', () {
    test('uses the production HTTPS domain by default', () {
      expect(ApiClient.defaultBaseUrl, 'https://api.frozenfish.cn/api/v1');
      expect(resolveInitialApiBaseUrl(null), ApiClient.defaultBaseUrl);
    });

    test('migrates legacy IP and local defaults', () {
      for (final legacy in <String>[
        'http://101.35.113.175:8088/api/v1',
        'http://192.168.5.200:8088/api/v1',
        'http://127.0.0.1:8088/api/v1',
      ]) {
        expect(resolveInitialApiBaseUrl(legacy), ApiClient.defaultBaseUrl);
      }
    });

    test('only accepts HTTPS domain API addresses', () {
      expect(validateApiBaseUrl('https://api.frozenfish.cn/api/v1'), isNull);
      expect(validateApiBaseUrl('http://api.frozenfish.cn/api/v1'), isNotNull);
      expect(validateApiBaseUrl('https://101.35.113.175/api/v1'), isNotNull);
      expect(validateApiBaseUrl('https://api.frozenfish.cn'), isNotNull);
      expect(
        validateApiBaseUrl('https://api.frozenfish.cn/other/api/v1'),
        isNotNull,
      );
      expect(
        validateApiBaseUrl('https://api.frozenfish.cn/api/v1?debug=1'),
        isNotNull,
      );
    });
  });
}
