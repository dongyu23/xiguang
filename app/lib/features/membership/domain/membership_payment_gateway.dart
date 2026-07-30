import 'membership.dart';

enum ApplePurchaseEventStatus { pending, purchased, restored, canceled, failed }

class ApplePurchaseEvent {
  const ApplePurchaseEvent({
    required this.productId,
    required this.status,
    this.signedTransaction = '',
    this.message = '',
    this.completionToken,
  });

  final String productId;
  final ApplePurchaseEventStatus status;
  final String signedTransaction;
  final String message;
  final Object? completionToken;
}

abstract interface class MembershipPaymentGatewayPort {
  Stream<ApplePurchaseEvent> get appleEvents;

  void startAppleListener();
  Future<Map<String, String>> appleLocalizedPrices(
    Iterable<BillingProduct> products,
  );
  Future<void> startApplePurchase(
    BillingProduct product, {
    required String appAccountToken,
  });
  Future<void> completeApplePurchase(ApplePurchaseEvent event);
  Future<void> restoreApple();
  Future<Map<String, String>> startDirect(Map<String, dynamic> sdkPayload);
  Future<void> manageAppleSubscription();
}
