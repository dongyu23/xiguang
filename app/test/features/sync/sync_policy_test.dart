import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiguang/features/shared/data/api_client.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';
import 'package:xiguang/features/sync/application/sync_providers.dart';
import 'package:xiguang/features/sync/data/sync_api.dart';
import 'package:xiguang/features/sync/domain/oplog.dart' as domain;
import 'package:xiguang/features/sync/domain/sync_config.dart';
import 'package:xiguang/features/sync/engine/sync_engine.dart';
import 'package:xiguang/features/sync/presentation/providers/sync_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatic timing options do not repeat the manual action', () {
    expect(
      SyncFrequency.automaticValues,
      isNot(contains(SyncFrequency.manual)),
    );
    expect(SyncFrequency.automaticValues, hasLength(4));
  });

  test('automatic network policy respects cloud and Wi-Fi switches', () {
    const enabled = SyncConfig(enabled: true);
    const wifiOnly = SyncConfig(enabled: true, wifiOnly: true);
    const disabled = SyncConfig(enabled: false);

    expect(
      automaticNetworkAllowed(enabled, [ConnectivityResult.mobile]),
      isTrue,
    );
    expect(
      automaticNetworkAllowed(wifiOnly, [ConnectivityResult.mobile]),
      isFalse,
    );
    expect(
      automaticNetworkAllowed(wifiOnly, [ConnectivityResult.wifi]),
      isTrue,
    );
    expect(
      automaticNetworkAllowed(enabled, [ConnectivityResult.none]),
      isFalse,
    );
    expect(
      automaticNetworkAllowed(disabled, [ConnectivityResult.wifi]),
      isFalse,
    );
  });

  test('legacy manual timing migrates to cloud sync off', () async {
    SharedPreferences.setMockInitialValues({
      'xiguang.sync.config.enabled': true,
      'xiguang.sync.config.frequency': SyncFrequency.manual.name,
    });
    final notifier = SyncConfigNotifier();
    addTearDown(notifier.dispose);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.enabled, isFalse);
    expect(notifier.state.frequency, SyncFrequency.onCapture);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('xiguang.sync.config.enabled'), isFalse);
    expect(
      prefs.getString('xiguang.sync.config.frequency'),
      SyncFrequency.onCapture.name,
    );
  });

  test('new local operation can sync immediately without persistence race',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://sync.test/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path.endsWith('/sync/push')) {
        final operations =
            (options.data as Map<String, dynamic>)['operations'] as List;
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'ok': true,
            'data': {
              'results': [
                {
                  'client_op_id': operations.first['client_op_id'],
                  'status': 'applied',
                }
              ],
              'new_server_rev': 1,
            },
          },
        ));
        return;
      }
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'ok': true,
          'data': {
            'operations': <dynamic>[],
            'next_since_rev': 1,
          },
        },
      ));
    }));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final engine = SyncEngine(
      api: SyncApi(ApiClient(dio: dio)),
      config: const SyncConfig(),
      db: db,
    );
    var enqueueEvents = 0;
    engine.onOperationEnqueued = () => enqueueEvents++;

    engine.enqueue(const domain.OpLog(
      clientOpId: 'capture-1',
      entityType: 'fragment',
      opType: 'INSERT',
      entityPublicId: 'fragment-1',
      payload: {'content_text': '一束光'},
    ));
    final status = await engine.syncNow();

    expect(enqueueEvents, 1);
    expect(status.error, isNull);
    expect(status.pendingCount, 0);
    expect(await db.getPendingOps(), isEmpty);
  });
}
