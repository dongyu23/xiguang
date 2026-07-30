import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design/tokens/motion.dart';
import '../domain/membership.dart';
import '../domain/membership_payment_gateway.dart';

class MembershipPaymentGateway implements MembershipPaymentGatewayPort {
  static const _androidChannel = MethodChannel('com.xiguang.xiguang/payments');

  final _appleEvents = StreamController<ApplePurchaseEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _appleSubscription;

  @override
  Stream<ApplePurchaseEvent> get appleEvents => _appleEvents.stream;

  @override
  void startAppleListener() {
    if (!Platform.isIOS || _appleSubscription != null) return;
    _appleSubscription = InAppPurchasePlatform.instance.purchaseStream.listen(
      _handleApplePurchases,
      onError: (Object error) {
        _appleEvents.add(ApplePurchaseEvent(
          productId: '',
          status: ApplePurchaseEventStatus.failed,
          message: '$error',
        ));
      },
    );
  }

  Future<void> dispose() async {
    await _appleSubscription?.cancel();
    await _appleEvents.close();
  }

  @override
  Future<Map<String, String>> appleLocalizedPrices(
    Iterable<BillingProduct> products,
  ) async {
    if (!Platform.isIOS) return const {};
    final ids = products
        .map((product) => product.externalProductId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty || !await InAppPurchasePlatform.instance.isAvailable()) {
      return const {};
    }
    final response =
        await InAppPurchasePlatform.instance.queryProductDetails(ids);
    return {
      for (final item in response.productDetails) item.id: item.price,
    };
  }

  @override
  Future<void> startApplePurchase(
    BillingProduct product, {
    required String appAccountToken,
  }) async {
    if (!Platform.isIOS) throw StateError('当前设备不是 iOS。');
    startAppleListener();
    final store = InAppPurchasePlatform.instance;
    if (!await store.isAvailable()) throw StateError('App Store 暂时不可用。');
    final response =
        await store.queryProductDetails({product.externalProductId});
    if (response.error != null || response.productDetails.isEmpty) {
      throw StateError('App Store 中尚未配置这个订阅商品。');
    }
    final started = await store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.single,
        applicationUserName: appAccountToken,
      ),
    );
    if (!started) throw StateError('未能发起购买。');
  }

  @override
  Future<void> completeApplePurchase(ApplePurchaseEvent event) async {
    final details = event.completionToken as PurchaseDetails?;
    if (details != null && details.pendingCompletePurchase) {
      await InAppPurchasePlatform.instance.completePurchase(details);
    }
  }

  @override
  Future<void> restoreApple() async {
    if (!Platform.isIOS) return;
    startAppleListener();
    await InAppPurchasePlatform.instance.restorePurchases();
    await Future<void>.delayed(AppTiming.appleRestoreCollection);
  }

  void _handleApplePurchases(List<PurchaseDetails> items) {
    for (final item in items) {
      switch (item.status) {
        case PurchaseStatus.pending:
          _appleEvents.add(ApplePurchaseEvent(
            productId: item.productID,
            status: ApplePurchaseEventStatus.pending,
            completionToken: item,
          ));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final signed = item.verificationData.serverVerificationData;
          if (signed.isEmpty) {
            _appleEvents.add(ApplePurchaseEvent(
              productId: item.productID,
              status: ApplePurchaseEventStatus.failed,
              message: 'App Store 没有返回可验证的交易。',
              completionToken: item,
            ));
            continue;
          }
          _appleEvents.add(ApplePurchaseEvent(
            productId: item.productID,
            status: item.status == PurchaseStatus.restored
                ? ApplePurchaseEventStatus.restored
                : ApplePurchaseEventStatus.purchased,
            signedTransaction: signed,
            completionToken: item,
          ));
          break;
        case PurchaseStatus.error:
          final error = item.error;
          final canceled = error?.code.toLowerCase().contains('cancel') == true;
          _appleEvents.add(ApplePurchaseEvent(
            productId: item.productID,
            status: canceled
                ? ApplePurchaseEventStatus.canceled
                : ApplePurchaseEventStatus.failed,
            message: error?.message ?? '购买没有完成。',
            completionToken: item,
          ));
          break;
        case PurchaseStatus.canceled:
          _appleEvents.add(ApplePurchaseEvent(
            productId: item.productID,
            status: ApplePurchaseEventStatus.canceled,
            message: '你取消了这次购买。',
            completionToken: item,
          ));
          break;
      }
    }
  }

  @override
  Future<Map<String, String>> startDirect(
    Map<String, dynamic> sdkPayload,
  ) async {
    if (!Platform.isAndroid) throw StateError('当前设备不是 Android。');
    final result = await _androidChannel.invokeMapMethod<String, String>(
      'startSubscription',
      sdkPayload,
    );
    if (sdkPayload['provider'] == 'alipay') {
      final status = result?['resultStatus'];
      if (status == '6001') throw StateError('你取消了这次签约。');
      if (status != '9000' && status != '8000') {
        throw StateError(result?['memo'] ?? '支付宝签约没有完成。');
      }
    }
    if (sdkPayload['provider'] == 'wechat' &&
        result?['resultStatus'] != '8000') {
      throw StateError('微信签约没有正常发起。');
    }
    return result ?? const {};
  }

  @override
  Future<void> manageAppleSubscription() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('无法打开 App Store 订阅管理。');
    }
  }
}
