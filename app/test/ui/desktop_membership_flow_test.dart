import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/design/tokens/colors.dart';
import 'package:xiguang/features/membership/application/membership_controller.dart';
import 'package:xiguang/features/membership/domain/membership.dart';
import 'package:xiguang/features/membership/presentation/pages/membership_page.dart';

const _disabledCatalog = <BillingProduct>[
  BillingProduct(
    code: 'starlight_month',
    tier: MembershipTier.starlight,
    period: 'month',
    priceCents: 1200,
    currency: 'CNY',
    trialDays: 0,
    storageQuotaBytes: 20 * 1024 * 1024 * 1024,
    aiQuota: 0,
    externalProductId: 'com.xiguang.membership.starlight.month',
    provider: 'apple',
    providerEnabled: false,
  ),
  BillingProduct(
    code: 'starlight_year',
    tier: MembershipTier.starlight,
    period: 'year',
    priceCents: 9800,
    currency: 'CNY',
    trialDays: 7,
    storageQuotaBytes: 20 * 1024 * 1024 * 1024,
    aiQuota: 0,
    externalProductId: 'com.xiguang.membership.starlight.year',
    provider: 'apple',
    providerEnabled: false,
  ),
  BillingProduct(
    code: 'galaxy_month',
    tier: MembershipTier.galaxy,
    period: 'month',
    priceCents: 2800,
    currency: 'CNY',
    trialDays: 0,
    storageQuotaBytes: 100 * 1024 * 1024 * 1024,
    aiQuota: 300,
    externalProductId: 'com.xiguang.membership.galaxy.month',
    provider: 'apple',
    providerEnabled: false,
  ),
  BillingProduct(
    code: 'galaxy_year',
    tier: MembershipTier.galaxy,
    period: 'year',
    priceCents: 21800,
    currency: 'CNY',
    trialDays: 7,
    storageQuotaBytes: 100 * 1024 * 1024 * 1024,
    aiQuota: 300,
    externalProductId: 'com.xiguang.membership.galaxy.year',
    provider: 'apple',
    providerEnabled: false,
  ),
];

void main() {
  testWidgets('desktop membership flow remains readable with payment disabled',
      (tester) async {
    tester.view.physicalSize = const Size(430, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWith(
            () => _DesktopMembershipController(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: xiguangTheme(),
          home: const MembershipPage(),
        ),
      ),
    );
    await tester.pump();

    final currentTier = tester.widget<Text>(find.text('微光会员'));
    expect(currentTier.style?.color, AppColors.ink);
    expect(find.text('0MB / 1GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/membership_desktop_top.png'),
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
    await tester.pumpAndSettle();

    expect(find.text('¥98'), findsOneWidget);
    expect(find.text('¥218'), findsOneWidget);
    expect(find.text('支付渠道暂未开放'), findsNWidgets(2));
    expect(find.textContaining('新用户可试用 7 天'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/membership_desktop_catalog.png'),
    );
  });
}

class _DesktopMembershipController extends MembershipController {
  @override
  Future<MembershipStatus> build() async => const MembershipStatus(
        products: _disabledCatalog,
      );
}
