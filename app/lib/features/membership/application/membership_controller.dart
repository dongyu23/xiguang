import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/membership.dart';
import '../domain/membership_payment_gateway.dart';

final membershipProvider =
    AsyncNotifierProvider<MembershipController, MembershipStatus>(
  MembershipController.new,
);

class MembershipController extends AsyncNotifier<MembershipStatus> {
  StreamSubscription<ApplePurchaseEvent>? _appleSubscription;
  final _processingTransactions = <String>{};
  bool _disposeRegistered = false;

  @override
  Future<MembershipStatus> build() async {
    final gateway = ref.watch(membershipPaymentGatewayProvider);
    _appleSubscription ??= gateway.appleEvents.listen(
      (event) => unawaited(_handleAppleEvent(event)),
    );
    gateway.startAppleListener();
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        unawaited(_appleSubscription?.cancel());
      });
    }
    final session = ref.watch(authSessionProvider);
    if (session == null) {
      return const MembershipStatus();
    }
    return _withLocalizedApplePrices(
      await ref.watch(membershipRepositoryProvider).load(session.id),
    );
  }

  Future<void> refresh() async {
    final userId = _userId();
    state = const AsyncLoading<MembershipStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async => _withLocalizedApplePrices(
          await ref.read(membershipRepositoryProvider).load(userId),
        ));
  }

  Future<void> purchase(BillingProduct product) async {
    final previous = state.valueOrNull ?? const MembershipStatus();
    _validateSwitch(previous, product);
    if (product.provider == 'apple') {
      final account = ref.read(authSessionProvider)?.publicId;
      if (account == null || account.isEmpty) throw StateError('请先登录。');
      state = AsyncData(previous.copyWith(
        pendingOrderStatus: 'pending',
        paymentMessage: '等待 App Store 确认购买。',
      ));
      try {
        await ref.read(membershipPaymentGatewayProvider).startApplePurchase(
              product,
              appAccountToken: account,
            );
      } catch (error) {
        state = AsyncData(previous.copyWith(
          pendingOrderStatus: 'failed',
          paymentMessage: _message(error, '购买没有完成。'),
        ));
        rethrow;
      }
      return;
    }

    state = const AsyncLoading<MembershipStatus>().copyWithPrevious(state);
    try {
      final repository = ref.read(membershipRepositoryProvider);
      final response = await repository.createDirect(product);
      final payload = response['sdk_payload'];
      if (payload is! Map) throw StateError('支付渠道尚未准备好。');
      await ref
          .read(membershipPaymentGatewayProvider)
          .startDirect(Map<String, dynamic>.from(payload));
      final order = response['order'];
      final orderId = order is Map ? order['id'] as String? : null;
      if (orderId == null || orderId.isEmpty) {
        throw StateError('服务端没有返回订单编号。');
      }
      final activation = await repository.waitForDirectActivation(orderId);
      if (const {'failed', 'closed', 'refunded'}.contains(activation)) {
        throw StateError('这笔签约没有完成，请重新发起。');
      }
      final loaded = await repository.load(_userId());
      state = AsyncData(await _withLocalizedApplePrices(
        loaded.copyWith(
          pendingOrderStatus: activation == 'pending' ? 'pending' : '',
          paymentMessage: activation == 'pending' ? '订单正在由支付渠道确认。' : '',
        ),
      ));
    } catch (error) {
      state = AsyncData(previous.copyWith(
        pendingOrderStatus: 'failed',
        paymentMessage: _message(error, '签约没有完成。'),
      ));
      rethrow;
    }
  }

  Future<void> restoreApple() async {
    final previous = state.valueOrNull ?? const MembershipStatus();
    state = AsyncData(previous.copyWith(
      pendingOrderStatus: 'pending',
      paymentMessage: '正在从 App Store 恢复购买。',
    ));
    try {
      await ref.read(membershipPaymentGatewayProvider).restoreApple();
      if (state.valueOrNull?.pendingOrderStatus == 'pending') {
        await refresh();
      }
    } catch (error) {
      state = AsyncData(previous.copyWith(
        pendingOrderStatus: 'failed',
        paymentMessage: _message(error, '恢复购买没有完成。'),
      ));
      rethrow;
    }
  }

  Future<void> cancel() async {
    final current = state.valueOrNull;
    if (current == null || current.subscriptionId.isEmpty) return;
    state = const AsyncLoading<MembershipStatus>().copyWithPrevious(state);
    try {
      if (current.provider == 'apple') {
        await ref
            .read(membershipPaymentGatewayProvider)
            .manageAppleSubscription();
      } else {
        await ref
            .read(membershipRepositoryProvider)
            .cancel(current.subscriptionId);
      }
      state = AsyncData(await _withLocalizedApplePrices(
        await ref.read(membershipRepositoryProvider).load(_userId()),
      ));
    } catch (error) {
      state = AsyncData(current.copyWith(
        paymentMessage: _message(error, '停止续费没有完成。'),
      ));
      rethrow;
    }
  }

  Future<void> _handleAppleEvent(ApplePurchaseEvent event) async {
    final current = state.valueOrNull ?? const MembershipStatus();
    switch (event.status) {
      case ApplePurchaseEventStatus.pending:
        state = AsyncData(current.copyWith(
          pendingOrderStatus: 'pending',
          paymentMessage: '订单正在等待 App Store 确认。',
        ));
        return;
      case ApplePurchaseEventStatus.canceled:
        state = AsyncData(current.copyWith(
          pendingOrderStatus: 'canceled',
          paymentMessage: event.message.isEmpty ? '你取消了这次购买。' : event.message,
        ));
        return;
      case ApplePurchaseEventStatus.failed:
        state = AsyncData(current.copyWith(
          pendingOrderStatus: 'failed',
          paymentMessage: event.message.isEmpty ? '购买没有完成。' : event.message,
        ));
        return;
      case ApplePurchaseEventStatus.purchased:
      case ApplePurchaseEventStatus.restored:
        break;
    }

    final signed = event.signedTransaction;
    if (signed.isEmpty || !_processingTransactions.add(signed)) return;
    if (ref.read(authSessionProvider) == null) {
      _processingTransactions.remove(signed);
      return;
    }
    state = AsyncData(current.copyWith(
      pendingOrderStatus: 'pending',
      paymentMessage: 'App Store 已确认，正在核验会员权益。',
    ));
    try {
      await ref.read(membershipRepositoryProvider).verifyApple(signed);
      await ref
          .read(membershipPaymentGatewayProvider)
          .completeApplePurchase(event);
      state = AsyncData(await _withLocalizedApplePrices(
        await ref.read(membershipRepositoryProvider).load(_userId()),
      ));
    } catch (error) {
      state = AsyncData(current.copyWith(
        pendingOrderStatus: 'failed',
        paymentMessage: _message(error, '交易核验失败，App Store 会保留交易供稍后重试。'),
      ));
    } finally {
      _processingTransactions.remove(signed);
    }
  }

  void _validateSwitch(MembershipStatus current, BillingProduct product) {
    if (!current.isActive) return;
    if (current.provider == 'apple' && product.provider == 'apple') return;
    if (current.provider != product.provider) {
      throw StateError(
          '当前账号已有 ${current.providerLabel} 订阅，请先在原渠道停止续费并等待当前周期结束。');
    }
    throw StateError('微信和支付宝暂不支持周期内切换套餐，请先停止续费并等待当前周期结束。');
  }

  Future<MembershipStatus> _withLocalizedApplePrices(
    MembershipStatus status,
  ) async {
    final prices = await ref
        .read(membershipPaymentGatewayProvider)
        .appleLocalizedPrices(
            status.products.where((item) => item.provider == 'apple'));
    if (prices.isEmpty) return status;
    return status.copyWith(
      products: status.products
          .map((product) => product.copyWith(
                localizedPrice: prices[product.externalProductId],
              ))
          .toList(growable: false),
    );
  }

  String _message(Object error, String fallback) {
    if (error is StateError) return error.message.toString();
    final text = '$error'.trim();
    return text.isEmpty ? fallback : text;
  }

  int _userId() {
    final userId = ref.read(authSessionProvider)?.id;
    if (userId == null || userId <= 0) throw StateError('请先登录。');
    return userId;
  }
}
