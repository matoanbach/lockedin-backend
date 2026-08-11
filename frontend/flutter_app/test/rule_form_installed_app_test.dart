import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/rules/data/rules_provider.dart';
import 'package:lockdin_app/features/rules/presentation/screens/lockdown_rules_screen.dart';

void main() {
  testWidgets(
    'installed-app search selects an app and submits its identifier',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RuleFormValue? submitted;

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
                      installedAppsLoader: () async => const [
                        InstalledRuleApp(
                          displayName: 'Signal',
                          appId: 'org.thoughtcrime.securesms',
                        ),
                        InstalledRuleApp(
                          displayName: 'Spotify',
                          appId: 'com.spotify.music',
                        ),
                      ],
                      onSubmit: (value) async => submitted = value,
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
      await tester.ensureVisible(
        find.byKey(const ValueKey('installed-app-picker')),
      );
      await tester.tap(find.byKey(const ValueKey('installed-app-picker')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Signal');
      await tester.pumpAndSettle();
      expect(find.text('org.thoughtcrime.securesms'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Signal'));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );
      expect(fields.first.controller?.text, 'Signal');

      final createRule = find.text('Create Rule').last;
      await tester.ensureVisible(createRule);
      await tester.tap(createRule);
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.appId, 'org.thoughtcrime.securesms');
      expect(submitted!.appName, 'Signal');
      expect(submitted!.limitMinutes, 60);
      expect(submitted!.enabled, isTrue);
    },
  );
}
