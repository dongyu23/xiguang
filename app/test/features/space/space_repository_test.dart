import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/data/api_client.dart';
import 'package:xiguang/features/membership/domain/membership.dart';
import 'package:xiguang/features/space/application/space_providers.dart';
import 'package:xiguang/features/space/data/space_api.dart';
import 'package:xiguang/features/space/data/space_repository_impl.dart';

void main() {
  test('reads locked themes and preserves config while selecting', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (options.path == '/space/themes') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'code': 'success',
            'data': {
              'items': [
                {
                  'id': 'ocean',
                  'name': '潮声',
                  'primary_color': '#7096A6',
                  'description': '低缓的海面。',
                  'required_tier': 'starlight',
                  'locked': true,
                  'selected': false,
                }
              ]
            }
          },
        ));
        return;
      }
      if (options.method == 'GET') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'code': 'success',
            'data': {
              'theme': 'morning_mist',
              'breathing_motion': true,
              'white_noise_enabled': true,
            }
          },
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {'code': 'success', 'data': <String, dynamic>{}},
      ));
    }));
    final repository = SpaceRepositoryImpl(SpaceApi(ApiClient(dio: dio)));

    final themes = await repository.themes();
    await repository.selectTheme('ocean');

    expect(themes.single.locked, isTrue);
    final update = requests.last;
    expect(update.method, 'PUT');
    expect(update.data, containsPair('breathing_motion', true));
    expect(update.data, containsPair('white_noise_enabled', true));
  });

  test('falls back to local catalog and applies offline entitlement tier',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://offline.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ));
    }));
    final repository = SpaceRepositoryImpl(SpaceApi(ApiClient(dio: dio)));

    final fallback = await repository.themes();
    final starlight = applySpaceThemeEntitlements(
      fallback,
      MembershipTier.starlight,
    );

    expect(fallback.map((item) => item.id),
        containsAll(<String>['morning_mist', 'starry', 'ocean', 'island']));
    expect(starlight.firstWhere((item) => item.id == 'ocean').locked, isFalse);
    expect(starlight.firstWhere((item) => item.id == 'island').locked, isFalse);
  });

  test('offline catalog still requires network when selecting a theme',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://offline.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ));
    }));
    final repository = SpaceRepositoryImpl(SpaceApi(ApiClient(dio: dio)));

    await expectLater(
        repository.selectTheme('ocean'), throwsA(isA<DioException>()));
  });
}
