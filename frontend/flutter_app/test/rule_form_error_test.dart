import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/rules/presentation/screens/lockdown_rules_screen.dart';

class _DuplicateRuleResponse {
  static const duplicateDetail =
      "Rule already exists for app_id 'com.google.android.apps.messaging'";

  static Future<void> throwConflict() async {
    final requestOptions = RequestOptions(path: '/api/v1/rules');
    throw DioException(
      requestOptions: requestOptions,
      response: Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 409,
        data: const {'detail': duplicateDetail},
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

void main() {
  testWidgets('duplicate create error is visible inside the open rule sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => RuleFormSheet(
                    installedAppsLoader: () async => const [],
                    onSubmit: (_) => _DuplicateRuleResponse.throwConflict(),
                  ),
                );
              },
              child: const Text('Open rule form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open rule form'));
    await tester.pumpAndSettle();

    final messagesPreset = find.ancestor(
      of: find.text('Messages'),
      matching: find.byType(InkWell),
    );
    await tester.tap(messagesPreset);

    final limitField = find.byType(TextFormField).at(1);
    await tester.enterText(limitField, '10');

    final createRule = find.text('Create Rule').last;
    await tester.ensureVisible(createRule);
    await tester.tap(createRule);
    await tester.pumpAndSettle();

    expect(find.text(_DuplicateRuleResponse.duplicateDetail), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-form-error')), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
