import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/app/providers.dart';
import 'package:xiguang/features/membership/application/membership_controller.dart';
import 'package:xiguang/features/membership/domain/membership.dart';
import 'package:xiguang/features/membership/domain/membership_payment_gateway.dart';
import 'package:xiguang/features/membership/domain/membership_repository.dart';

import '../../test_auth_repository.dart';

const _appleProduct = BillingProduct(
  code: 'starlight_month',
  tier: MembershipTier.starlight,
  period: 'month',
  priceCents: 1200,
  currency: 'CNY',
  trialDays: 0,
  storageQuotaBytes: 20 * 1024 * 1024 * 1024,
  aiQuota: 0,
  externalProductId: 'com.xiguang.starlight.month',
  provider: 'apple',
  providerEnabled: true,
);

const _alipayProduct = BillingProduct(
  code: 'starlight_year',
  tier: MembershipTier.starlight,
  period: 'year',
  priceCents: 9800,
  currency: 'CNY',
  trialDays: 7,
  storageQuotaBytes: 20 * 1024 * 1024 * 1024,
  aiQuota: 0,
  externalProductId: 'com.xiguang.membership.starlight.year',
  provider: 'alipay',
  providerEnabled: true,
);

void main() {
  test('loads server entitlement and applies Apple localized price', () async {
    final repository = _FakeMembershipRepository();
    final gateway = _FakePaymentGateway(
      localizedPrices: const {'com.xiguang.starlight.month': '¥12.00'},
    );
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });

    final status = await container.read(membershipProvider.future);

    expect(status.tier, MembershipTier.glimmer);
    expect(status.products.single.priceLabel, '¥12.00');
    expect(repository.loadCalls, 1);
    expect(gateway.listenerStarts, 1);
  });

  test('pending Apple purchase does not verify or complete transaction',
      () async {
    final repository = _FakeMembershipRepository();
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await container.read(membershipProvider.notifier).purchase(_appleProduct);
    gateway.emit(const ApplePurchaseEvent(
      productId: 'com.xiguang.starlight.month',
      status: ApplePurchaseEventStatus.pending,
    ));
    await _flush();

    expect(repository.verifiedTransactions, isEmpty);
    expect(gateway.completedTransactions, isEmpty);
    expect(container.read(membershipProvider).value?.pendingOrderStatus,
        'pending');
  });

  test('Apple transaction completes only after server verification', () async {
    final repository = _FakeMembershipRepository();
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);
    await container.read(membershipProvider.notifier).purchase(_appleProduct);

    const event = ApplePurchaseEvent(
      productId: 'com.xiguang.starlight.month',
      status: ApplePurchaseEventStatus.purchased,
      signedTransaction: 'signed-transaction',
      completionToken: 'transaction-token',
    );
    repository.verifyGate = Completer<void>();
    gateway.emit(event);
    await _flush();
    expect(gateway.completedTransactions, isEmpty);

    repository.verifyGate!.complete();
    await _flush();
    expect(repository.verifiedTransactions, ['signed-transaction']);
    expect(gateway.completedTransactions, ['signed-transaction']);
    expect(repository.loadCalls, 2);
  });

  test('failed Apple purchase start never verifies entitlement', () async {
    final repository = _FakeMembershipRepository();
    final gateway = _FakePaymentGateway(startError: StateError('canceled'));
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await expectLater(
      container.read(membershipProvider.notifier).purchase(_appleProduct),
      throwsStateError,
    );

    expect(repository.verifiedTransactions, isEmpty);
    expect(
        container.read(membershipProvider).value?.pendingOrderStatus, 'failed');
  });

  test('restored Apple transaction is verified and then completed', () async {
    final repository = _FakeMembershipRepository();
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await container.read(membershipProvider.notifier).restoreApple();
    gateway.emit(const ApplePurchaseEvent(
      productId: 'com.xiguang.starlight.month',
      status: ApplePurchaseEventStatus.restored,
      signedTransaction: 'restored-one',
      completionToken: 'restore-token',
    ));
    await _flush();

    expect(gateway.restoreCalls, 1);
    expect(repository.verifiedTransactions, ['restored-one']);
    expect(gateway.completedTransactions, ['restored-one']);
  });

  test('direct payment keeps a clear pending state until server confirmation',
      () async {
    final repository = _FakeMembershipRepository(waitResult: 'pending');
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await container.read(membershipProvider.notifier).purchase(_alipayProduct);

    expect(container.read(membershipProvider).value?.pendingOrderStatus,
        'pending');
    expect(gateway.directStarts, 1);
  });

  test('Apple cancellation opens the App Store subscription manager', () async {
    final repository = _FakeMembershipRepository(
      status: _activeMembership(provider: 'apple'),
    );
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await container.read(membershipProvider.notifier).cancel();

    expect(gateway.manageAppleCalls, 1);
    expect(repository.canceledSubscriptions, isEmpty);
  });

  test('direct channel cancellation is requested from the server', () async {
    final repository = _FakeMembershipRepository(
      status: _activeMembership(provider: 'alipay'),
    );
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await container.read(membershipProvider.notifier).cancel();

    expect(repository.canceledSubscriptions, ['subscription-1']);
    expect(gateway.manageAppleCalls, 0);
  });

  test('cross-channel purchase returns an explicit original-channel message',
      () async {
    final repository = _FakeMembershipRepository(
      status: _activeMembership(provider: 'apple'),
    );
    final gateway = _FakePaymentGateway();
    final container = await _container(repository, gateway);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });
    await container.read(membershipProvider.future);

    await expectLater(
      container.read(membershipProvider.notifier).purchase(_alipayProduct),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('App Store'),
      )),
    );

    expect(gateway.directStarts, 0);
  });
}

MembershipStatus _activeMembership({required String provider}) {
  return MembershipStatus(
    tier: MembershipTier.starlight,
    status: 'active',
    provider: provider,
    subscriptionId: 'subscription-1',
    productCode: 'starlight_month',
    expiresAt: DateTime.now().add(const Duration(days: 20)),
    products: const [_appleProduct, _alipayProduct],
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

Future<ProviderContainer> _container(
  _FakeMembershipRepository repository,
  _FakePaymentGateway gateway,
) async {
  final auth = FakeAuthRepository();
  await auth.login(username: 'member', password: 'password');
  return ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    membershipRepositoryProvider.overrideWithValue(repository),
    membershipPaymentGatewayProvider.overrideWithValue(gateway),
  ]);
}

class _FakeMembershipRepository implements MembershipRepository {
  _FakeMembershipRepository({
    this.waitResult = 'active',
    this.status = const MembershipStatus(products: [_appleProduct]),
  });

  int loadCalls = 0;
  final String waitResult;
  final MembershipStatus status;
  final verifiedTransactions = <String>[];
  final canceledSubscriptions = <String>[];
  Completer<void>? verifyGate;

  @override
  Future<MembershipStatus> load(int userId) async {
    loadCalls++;
    return status;
  }

  @override
  Future<Map<String, dynamic>> createDirect(BillingProduct product) async =>
      const {
        'order': {'id': 'order-1'},
        'sdk_payload': {
          'provider': 'alipay',
          'order_string': 'signed-order',
        },
      };

  @override
  Future<String> waitForDirectActivation(String orderId) async => waitResult;

  @override
  Future<void> verifyApple(String signedTransaction) async {
    verifiedTransactions.add(signedTransaction);
    await verifyGate?.future;
  }

  @override
  Future<void> restoreApple(List<String> signedTransactions) async {}

  @override
  Future<void> cancel(String subscriptionId) async {
    canceledSubscriptions.add(subscriptionId);
  }
}

class _FakePaymentGateway implements MembershipPaymentGatewayPort {
  _FakePaymentGateway({
    this.localizedPrices = const {},
    this.startError,
  });

  final Map<String, String> localizedPrices;
  final Object? startError;
  final _events = StreamController<ApplePurchaseEvent>.broadcast();
  final completedTransactions = <String>[];
  int directStarts = 0;
  int restoreCalls = 0;
  int listenerStarts = 0;
  int manageAppleCalls = 0;

  void emit(ApplePurchaseEvent event) => _events.add(event);
  Future<void> close() => _events.close();

  @override
  Stream<ApplePurchaseEvent> get appleEvents => _events.stream;

  @override
  void startAppleListener() => listenerStarts++;

  @override
  Future<Map<String, String>> appleLocalizedPrices(
    Iterable<BillingProduct> products,
  ) async =>
      localizedPrices;

  @override
  Future<void> startApplePurchase(
    BillingProduct product, {
    required String appAccountToken,
  }) async {
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Future<void> completeApplePurchase(ApplePurchaseEvent event) async {
    completedTransactions.add(event.signedTransaction);
  }

  @override
  Future<void> restoreApple() async {
    restoreCalls++;
  }

  @override
  Future<Map<String, String>> startDirect(
    Map<String, dynamic> sdkPayload,
  ) async {
    directStarts++;
    return const {'resultStatus': '9000'};
  }

  @override
  Future<void> manageAppleSubscription() async {
    manageAppleCalls++;
  }
}
