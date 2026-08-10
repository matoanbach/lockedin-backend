import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/auth/data/auth_models.dart';
import 'package:lockdin_app/features/auth/data/auth_provider.dart';
import 'package:lockdin_app/features/auth/presentation/auth_screen.dart';

class _KnownAccountAuthController extends AuthController {
  int signInCalls = 0;

  @override
  Future<LockdInAuthState> build() async =>
      const LockdInAuthState.signedOut(hasKnownAccount: true);

  @override
  Future<void> signIn({bool createAccount = false}) async {
    signInCalls += 1;
  }
}

class _FirstAccountAuthController extends AuthController {
  int createAccountCalls = 0;

  @override
  Future<LockdInAuthState> build() async => const LockdInAuthState.signedOut();

  @override
  Future<void> signIn({bool createAccount = false}) async {
    if (createAccount) createAccountCalls += 1;
  }
}

void main() {
  testWidgets('returning device offers only its existing account sign-in', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              _KnownAccountAuthController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text('Sign in with the account already used on this device.'),
      findsOneWidget,
    );
    expect(find.text('Create account'), findsNothing);
    expect(find.text('Create another account'), findsNothing);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      (container.read(authControllerProvider.notifier)
              as _KnownAccountAuthController)
          .signInCalls,
      1,
    );
  });

  testWidgets('first-time device can create its account', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              _FirstAccountAuthController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(
      (container.read(authControllerProvider.notifier)
              as _FirstAccountAuthController)
          .createAccountCalls,
      1,
    );
  });
}
