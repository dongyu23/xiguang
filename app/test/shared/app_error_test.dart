import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/domain/app_exception.dart';
import 'package:xiguang/features/shared/presentation/app_error.dart';

void main() {
  testWidgets('showAppError displays a SnackBar with the exception message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () =>
                showAppError(context, const NetworkException('网络不太通')),
            child: const Text('trigger'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    expect(find.text('网络不太通'), findsOneWidget);
  });
}
