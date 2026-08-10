import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/core/router/app_router.dart';
import 'package:lockdin_app/features/auth/data/auth_models.dart';
import 'package:lockdin_app/features/auth/data/auth_provider.dart';

const _authenticated = LockdInAuthState(
  phase: AuthPhase.authenticated,
  session: MobileSession(
    accountId: 'account',
    profileId: 'profile',
    issuer: 'issuer',
    subject: 'subject',
    sid: 'sid',
    accountGeneration: 'generation',
  ),
);

class _ControllableAuthController extends AuthController {
  @override
  Future<LockdInAuthState> build() async => _authenticated;

  void completeDeletion() {
    state = const AsyncData(LockdInAuthState.signedOut());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signed-out users can only reach login', () {
    expect(
      authRedirectFor(
        auth: const LockdInAuthState.signedOut(),
        location: AppRoutes.dashboard,
      ),
      AppRoutes.authLogin,
    );
    expect(
      authRedirectFor(
        auth: const LockdInAuthState.signedOut(),
        location: AppRoutes.authLogin,
      ),
      isNull,
    );
  });

  test('authenticated users stay inside onboarding and product routes', () {
    const session = MobileSession(
      accountId: 'account',
      profileId: 'profile',
      issuer: 'issuer',
      subject: 'subject',
      sid: 'sid',
      accountGeneration: 'generation',
    );
    const auth = LockdInAuthState(
      phase: AuthPhase.authenticated,
      session: session,
    );
    expect(
      authRedirectFor(auth: auth, location: AppRoutes.onboardingWelcome),
      isNull,
    );
    expect(
      authRedirectFor(auth: auth, location: AppRoutes.authLogin),
      AppRoutes.bootstrap,
    );
  });

  test('account transition is restricted to the data choice route', () {
    const auth = LockdInAuthState(phase: AuthPhase.accountTransition);
    expect(
      authRedirectFor(auth: auth, location: AppRoutes.dashboard),
      AppRoutes.authDataChoice,
    );
    expect(
      authRedirectFor(auth: auth, location: AppRoutes.authDataChoice),
      isNull,
    );
  });

  test('auth changes refresh one stable router instance', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_ControllableAuthController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final router = container.read(routerProvider);

    final controller =
        container.read(authControllerProvider.notifier)
            as _ControllableAuthController;
    controller.completeDeletion();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(routerProvider), same(router));
  });
}
