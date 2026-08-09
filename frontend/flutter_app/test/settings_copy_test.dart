import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/settings/presentation/screens/device_permissions_screen.dart';
import 'package:lockdin_app/features/usage/data/usage_sync_provider.dart';

class _TestDevicePermissionsController extends DevicePermissionsController {
  @override
  Future<DevicePermissions> build() async {
    return const DevicePermissions(
      isSupported: false,
      usageAccess: false,
      notifications: false,
      accessibility: false,
      notificationDiagnostics: NotificationDiagnostics(
        appEnabled: false,
        channelId: '',
        channelExists: false,
        channelEnabled: false,
        channelImportance: 0,
        channelImportanceLabel: 'unknown',
      ),
    );
  }
}

void main() {
  testWidgets('settings offers sign out without implying account switching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devicePermissionsProvider.overrideWith(
            _TestDevicePermissionsController.new,
          ),
        ],
        child: const MaterialApp(home: DevicePermissionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out'), 300);

    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign out or switch account'), findsNothing);
  });
}
