import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/auth/data/auth_repository.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

void main() {
  test('current session is named, marked, and sorted before historical devices',
      () async {
    final api = _DeviceApiClient()..accessToken = 'valid-token';
    final repository = AuthRepository(api);

    final devices = await repository.listDevices();

    expect(devices, hasLength(3));
    expect(devices.first.isCurrent, isTrue);
    expect(devices.first.deviceName, isNot('未命名设备'));
    expect(devices.skip(1).every((device) => !device.isCurrent), isTrue);
    expect(
      devices.skip(1).map((device) => device.deviceName).toSet(),
      hasLength(2),
    );
    expect(devices.any((device) => device.deviceName == '未命名设备'), isFalse);
  });
}

class _DeviceApiClient extends ApiClient {
  _DeviceApiClient() : super(baseUrl: 'http://test.invalid/api/v1');

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    expect(path, '/users/devices');
    return {
      'value': [
        {
          'id': 11,
          'device_info': '',
          'is_current': false,
          'created_at': '2026-07-13T08:00:00Z',
          'expires_at': '2026-08-13T08:00:00Z',
        },
        {
          'id': 10,
          'device_info': '',
          'is_current': true,
          'created_at': '2026-07-12T08:00:00Z',
          'expires_at': '2026-08-12T08:00:00Z',
        },
        {
          'id': 9,
          'device_info': '',
          'is_current': false,
          'created_at': '2026-07-11T08:00:00Z',
          'expires_at': '2026-08-11T08:00:00Z',
        },
      ],
    };
  }
}
