import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/auth/domain/auth_session.dart';
import 'package:xiguang/features/auth/presentation/providers/auth_providers.dart';
import 'package:xiguang/features/membership/application/membership_controller.dart';
import 'package:xiguang/features/membership/domain/membership.dart';
import 'package:xiguang/features/profile/presentation/pages/mine_page.dart';

void main() {
  testWidgets('我的首页只保留商业应用式一级入口', (tester) async {
    tester.view.physicalSize = const Size(430, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const session = AuthSession(
      id: 1,
      publicId: 'user-public-id',
      username: 'xiguang_user',
      nickname: '一束光',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => session),
          membershipProvider.overrideWith(_MineMembershipController.new),
        ],
        child: MaterialApp(
          theme: xiguangTheme(),
          home: const MinePage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('一束光'), findsOneWidget);
    expect(find.text('微光会员'), findsOneWidget);
    expect(find.text('记录与体验'), findsOneWidget);
    expect(find.text('数据与同步'), findsOneWidget);
    expect(find.text('隐私与账号安全'), findsOneWidget);

    expect(find.text('白噪音'), findsNothing);
    expect(find.text('数据归档'), findsNothing);
    expect(find.text('潮汐提示'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _MineMembershipController extends MembershipController {
  @override
  Future<MembershipStatus> build() async => const MembershipStatus();
}
