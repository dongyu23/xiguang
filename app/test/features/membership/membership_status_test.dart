import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/membership/domain/membership.dart';

void main() {
  test('past due and grace memberships remain active until grace expires', () {
    final expiredPeriod = DateTime.now().subtract(const Duration(hours: 1));
    final futureGrace = DateTime.now().add(const Duration(hours: 71));

    for (final status in const ['past_due', 'grace']) {
      expect(
        MembershipStatus(
          tier: MembershipTier.starlight,
          status: status,
          expiresAt: expiredPeriod,
          graceUntil: futureGrace,
        ).isActive,
        isTrue,
      );
    }
  });

  test('revoked, expired and elapsed grace memberships are inactive', () {
    final past = DateTime.now().subtract(const Duration(hours: 1));
    for (final status in const ['revoked', 'expired', 'canceled']) {
      expect(
        MembershipStatus(
          tier: MembershipTier.starlight,
          status: status,
          expiresAt: past,
          graceUntil: past,
        ).isActive,
        isFalse,
      );
    }
    expect(
      MembershipStatus(
        tier: MembershipTier.starlight,
        status: 'grace',
        expiresAt: past,
        graceUntil: past,
      ).isActive,
      isFalse,
    );
  });
}
