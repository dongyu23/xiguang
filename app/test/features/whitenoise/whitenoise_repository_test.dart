import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/data/api_client.dart';
import 'package:xiguang/features/whitenoise/data/whitenoise_api.dart';
import 'package:xiguang/features/whitenoise/data/whitenoise_repository_impl.dart';

void main() {
  test('keeps server entitlement lock on paid sounds', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'ok': true,
          'data': [
            {
              'id': 'wind',
              'name': '风声',
              'category': 'nature',
              'required_tier': 'starlight',
              'locked': true,
            }
          ]
        },
      ));
    }));

    final items = await WhiteNoiseRepositoryImpl(
      WhiteNoiseApi(ApiClient(dio: dio)),
    ).list();

    expect(items.single.id, 'wind');
    expect(items.single.requiredTier, 'starlight');
    expect(items.single.locked, isTrue);
  });
}
