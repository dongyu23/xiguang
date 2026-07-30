import 'membership.dart';

abstract interface class MembershipRepository {
  Future<MembershipStatus> load(int userId);
  Future<Map<String, dynamic>> createDirect(BillingProduct product);
  Future<String> waitForDirectActivation(String orderId);
  Future<void> verifyApple(String signedTransaction);
  Future<void> restoreApple(List<String> signedTransactions);
  Future<void> cancel(String subscriptionId);
}
