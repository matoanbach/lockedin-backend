import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/core/router/app_router.dart';
import 'package:lockdin_app/features/auth/data/auth_models.dart';

void main() {
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
}
