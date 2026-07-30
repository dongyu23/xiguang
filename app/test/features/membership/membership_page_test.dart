import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/membership/application/membership_controller.dart';
import 'package:xiguang/features/membership/domain/membership.dart';
import 'package:xiguang/features/membership/presentation/pages/membership_page.dart';

const _products = <BillingProduct>[
  BillingProduct(
    code: 'starlight_month',
    tier: MembershipTier.starlight,
    period: 'month',
    priceCents: 1200,
    currency: 'CNY',
    trialDays: 0,
    storageQuotaBytes: 20 * 1024 * 1024 * 1024,
    aiQuota: 0,
    externalProductId: 'starlight.month',
    provider: 'alipay',
    providerEnabled: true,
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
    externalProductId: 'galaxy.year',
    provider: 'wechat',
    providerEnabled: true,
  ),
];

void main() {
  testWidgets('免费档显示永久空间和可用付费入口', (tester) async {
    await _pump(tester, const MembershipStatus(products: _products));

    expect(find.text('微光永久免费'), findsOneWidget);
    expect(find.text('0MB / 1GB'), findsOneWidget);
    expect(find.text('¥218'), findsOneWidget);
    expect(find.text('微信开通'), findsOneWidget);

    await tester.tap(find.text('月付'));
    await tester.pumpAndSettle();
    expect(find.text('¥12'), findsOneWidget);
    expect(find.text('支付宝开通'), findsOneWidget);
  });

  testWidgets('支付关闭时仍展示目录价格但不显示购买按钮', (tester) async {
    await _pump(
      tester,
      MembershipStatus(
        products: _products
            .map((product) => BillingProduct(
                  code: product.code,
                  tier: product.tier,
                  period: product.period,
                  priceCents: product.priceCents,
                  currency: product.currency,
                  trialDays: product.trialDays,
                  storageQuotaBytes: product.storageQuotaBytes,
                  aiQuota: product.aiQuota,
                  externalProductId: product.externalProductId,
                  provider: product.provider,
                  providerEnabled: false,
                ))
            .toList(),
      ),
    );

    expect(find.text('¥218'), findsOneWidget);
    expect(find.text('支付渠道暂未开放'), findsNWidgets(2));
    expect(find.text('微信开通'), findsNothing);

    await tester.tap(find.text('月付'));
    await tester.pumpAndSettle();
    expect(find.text('¥12'), findsOneWidget);
    expect(find.text('支付宝开通'), findsNothing);
  });

  testWidgets('订单处理中展示渠道确认提示', (tester) async {
    await _pump(
      tester,
      const MembershipStatus(
        pendingOrderStatus: 'pending',
        paymentMessage: '订单正在由支付渠道确认。',
      ),
    );

    expect(find.text('订单正在由支付渠道确认。'), findsOneWidget);
  });

  testWidgets('宽限期展示权益保持说明和截止日期', (tester) async {
    await _pump(
      tester,
      MembershipStatus(
        tier: MembershipTier.starlight,
        status: 'past_due',
        graceUntil: DateTime(2030, 8, 3),
      ),
    );

    expect(find.textContaining('宽限至 2030-08-03'), findsOneWidget);
    expect(find.textContaining('宽限期内权益保持不变'), findsOneWidget);
  });

  testWidgets('退款撤销展示回到微光说明', (tester) async {
    await _pump(
      tester,
      const MembershipStatus(
        tier: MembershipTier.glimmer,
        status: 'revoked',
      ),
    );

    expect(find.text('该订阅已退款或撤销，账号已回到微光。'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, MembershipStatus status) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membershipProvider.overrideWith(
          () => _FixedMembershipController(status),
        ),
      ],
      child: MaterialApp(
        theme: xiguangTheme(),
        home: const MembershipPage(),
      ),
    ),
  );
  await tester.pump();
}

class _FixedMembershipController extends MembershipController {
  _FixedMembershipController(this.value);

  final MembershipStatus value;

  @override
  Future<MembershipStatus> build() async => value;
}
