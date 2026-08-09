import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockdin_app/features/auth/data/auth_models.dart';
import 'package:lockdin_app/features/auth/data/auth_repository.dart';
import 'package:lockdin_app/features/auth/data/auth_provider.dart';
import 'package:lockdin_app/features/auth/data/native_auth_bridge.dart';
import 'package:lockdin_app/features/auth/data/oidc_client.dart';
import 'package:lockdin_app/features/auth/data/secure_auth_storage.dart';

void main() {
  const config = AuthConfig(
    issuer: 'https://issuer.example/realms/lockdin',
    authorizationEndpoint: 'https://issuer.example/auth',
    tokenEndpoint: 'https://issuer.example/token',
    endSessionEndpoint: 'https://issuer.example/logout',
    clientId: 'lockdin-mobile',
    redirectUri: 'com.lockdin.lockdinapp:/oauth2redirect',
    scopes: ['openid', 'profile', 'email'],
    codeChallengeMethod: 'S256',
  );

  AuthTokenSet tokens(String accessToken) => AuthTokenSet(
    accessToken: accessToken,
    refreshToken: 'refresh-$accessToken',
    idToken: 'id-$accessToken',
    accessTokenExpiresAt: DateTime.utc(2030),
  );

  test(
    'bootstrap without credentials clears native auth and signs out',
    () async {
      final native = FakeNativeAuthBridge();
      final repository = buildRepository(
        storage: FakeAuthStorage(),
        oidc: FakeOidcClient(tokens('login')),
        native: native,
      );

      final state = await repository.bootstrap();

      expect(state.phase, AuthPhase.signedOut);
      expect(native.events, ['clear']);
    },
  );

  test(
    'AppAuth cancellation returns to signed out without an error state',
    () async {
      final repository = buildRepository(
        storage: FakeAuthStorage(),
        oidc: FakeOidcClient(tokens('unused'), cancelSignIn: true),
        native: FakeNativeAuthBridge(),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).signIn();

      final state = container.read(authControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.asData?.value.phase, AuthPhase.signedOut);
    },
  );

  test('create account requests the provider registration prompt', () async {
    final oidc = FakeOidcClient(tokens('login'));
    final repository = buildRepository(
      storage: FakeAuthStorage(),
      oidc: oidc,
      native: FakeNativeAuthBridge(),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .signIn(createAccount: true);

    expect(oidc.createAccountRequests, 1);
    expect(
      container.read(authControllerProvider).asData?.value.phase,
      AuthPhase.authenticated,
    );
  });

  test('configuration connection failure shows the backend address', () async {
    final repository = buildRepository(
      storage: FakeAuthStorage(),
      oidc: FakeOidcClient(tokens('login')),
      native: FakeNativeAuthBridge(),
      failConfigConnection: true,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).signIn();

    final message = container
        .read(authControllerProvider)
        .asData
        ?.value
        .message;
    expect(message, startsWith('Could not connect to the backend at '));
  });

  test('configuration TLS failure does not expose Dio internals', () async {
    final repository = buildRepository(
      storage: FakeAuthStorage(),
      oidc: FakeOidcClient(tokens('login')),
      native: FakeNativeAuthBridge(),
      failConfigTls: true,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).signIn();

    final message = container
        .read(authControllerProvider)
        .asData
        ?.value
        .message;
    expect(
      message,
      startsWith('Could not establish a trusted HTTPS connection to '),
    );
    expect(message, isNot(contains('DioException')));
    expect(message, isNot(contains('CERTIFICATE_VERIFY_FAILED')));
  });

  test('unclaimed rows block uploads until an explicit import', () async {
    final storage = FakeAuthStorage();
    final native = FakeNativeAuthBridge(
      summary: const QueueOwnershipSummary(
        activeCount: 0,
        unclaimedCount: 2,
        quarantinedCount: 1,
      ),
    );
    final repository = buildRepository(
      storage: storage,
      oidc: FakeOidcClient(tokens('login')),
      native: native,
    );

    final transition = await repository.signIn();
    expect(transition.phase, AuthPhase.accountTransition);
    expect(native.events.last, 'clear');
    expect(
      native.events.where((event) => event.startsWith('configure:')),
      isEmpty,
    );

    native.summary = const QueueOwnershipSummary.empty();
    final authenticated = await repository.resolveUnclaimedData(
      UnclaimedDataDecision.import,
    );
    expect(authenticated.phase, AuthPhase.authenticated);
    expect(native.events, contains(startsWith('resolve:import:')));
    expect(native.events, contains(startsWith('configure:')));
  });

  test('account generation is stable per issuer and subject', () async {
    final storage = FakeAuthStorage();
    final repository = buildRepository(
      storage: storage,
      oidc: FakeOidcClient(tokens('login')),
      native: FakeNativeAuthBridge(),
    );

    final first = await repository.accountGenerationFor('issuer', 'subject-a');
    final repeated = await repository.accountGenerationFor(
      'issuer',
      'subject-a',
    );
    final other = await repository.accountGenerationFor('issuer', 'subject-b');

    expect(repeated, first);
    expect(other, isNot(first));
  });

  test('concurrent refresh callers share one rotated token request', () async {
    final oidc = FakeOidcClient(tokens('login'));
    final repository = buildRepository(
      storage: FakeAuthStorage(
        session: StoredAuthSession(config: config, tokens: tokens('initial')),
      ),
      oidc: oidc,
      native: FakeNativeAuthBridge(),
    );
    expect((await repository.bootstrap()).phase, AuthPhase.authenticated);
    final refresh = Completer<AuthTokenSet>();
    oidc.refreshCompleter = refresh;

    final callers = List.generate(
      4,
      (_) => repository.accessToken(forceRefresh: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(oidc.refreshCalls, 1);

    refresh.complete(tokens('rotated'));
    expect(await Future.wait(callers), everyElement('rotated'));
  });

  test('logout clears native auth before deleting secure session', () async {
    final events = <String>[];
    final storage = FakeAuthStorage(
      session: StoredAuthSession(config: config, tokens: tokens('initial')),
      events: events,
    );
    final native = FakeNativeAuthBridge(events: events);
    final oidc = FakeOidcClient(tokens('login'), events: events);
    final repository = buildRepository(
      storage: storage,
      oidc: oidc,
      native: native,
      requestEvents: events,
    );
    await repository.bootstrap();
    events.clear();

    await repository.logout();

    expect(events.first, 'clear');
    expect(
      events,
      containsAllInOrder([
        'backend:logout',
        'provider:end-session',
        'delete',
        'reset',
      ]),
    );
    expect(oidc.endSessionCalls, 1);
    expect(storage.session, isNull);
  });

  test(
    'provider logout failure cannot prevent authoritative local logout',
    () async {
      final events = <String>[];
      final storage = FakeAuthStorage(
        session: StoredAuthSession(config: config, tokens: tokens('initial')),
        events: events,
      );
      final oidc = FakeOidcClient(
        tokens('login'),
        events: events,
        failEndSession: true,
      );
      final repository = buildRepository(
        storage: storage,
        oidc: oidc,
        native: FakeNativeAuthBridge(events: events),
        requestEvents: events,
      );
      await repository.bootstrap();
      events.clear();

      await repository.logout();

      expect(oidc.endSessionCalls, 1);
      expect(events, containsAllInOrder(['delete', 'reset']));
      expect(storage.session, isNull);
    },
  );

  test('terminal reauthentication clears the native auth context', () async {
    final native = FakeNativeAuthBridge();
    final repository = buildRepository(
      storage: FakeAuthStorage(
        session: StoredAuthSession(config: config, tokens: tokens('initial')),
      ),
      oidc: FakeOidcClient(tokens('login')),
      native: native,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(authControllerProvider.future)).phase,
      AuthPhase.authenticated,
    );
    native.events.clear();

    container.read(authControllerProvider.notifier).requireReauthentication();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authControllerProvider).asData?.value.phase,
      AuthPhase.reauthenticationRequired,
    );
    expect(native.events, ['clear']);
  });
}

AuthRepository buildRepository({
  required FakeAuthStorage storage,
  required FakeOidcClient oidc,
  required FakeNativeAuthBridge native,
  List<String>? requestEvents,
  bool failConfigConnection = false,
  bool failConfigTls = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith('/auth/config')) {
          if (failConfigConnection) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          if (failConfigTls) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: Exception(
                  'HandshakeException: CERTIFICATE_VERIFY_FAILED',
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: const {
                'issuer': 'https://issuer.example/realms/lockdin',
                'authorizationEndpoint': 'https://issuer.example/auth',
                'tokenEndpoint': 'https://issuer.example/token',
                'endSessionEndpoint': 'https://issuer.example/logout',
                'clientId': 'lockdin-mobile',
                'redirectUri': 'com.lockdin.lockdinapp:/oauth2redirect',
                'scopes': ['openid', 'profile', 'email'],
                'codeChallengeMethod': 'S256',
              },
            ),
          );
          return;
        }
        if (options.path.endsWith('/auth/session')) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: const {
                'accountId': 'account-1',
                'profileId': 'profile-1',
                'issuer': 'https://issuer.example/realms/lockdin',
                'subject': 'subject-1',
                'sid': 'sid-1',
              },
            ),
          );
          return;
        }
        if (options.path.endsWith('/auth/logout')) {
          requestEvents?.add('backend:logout');
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 204),
          );
          return;
        }
        handler.reject(DioException(requestOptions: options));
      },
    ),
  );
  return AuthRepository(
    publicDio: dio,
    storage: storage,
    oidcClient: oidc,
    nativeBridge: native,
    now: () => DateTime.utc(2026),
    secureRandom: Random(42),
  );
}

class FakeAuthStorage implements AuthStorage {
  FakeAuthStorage({this.session, this.events});

  StoredAuthSession? session;
  Map<String, String> bindings = {};
  final List<String>? events;

  @override
  Future<void> deleteSession() async {
    events?.add('delete');
    session = null;
  }

  @override
  Future<Map<String, String>> readAccountBindings() async => {...bindings};

  @override
  Future<StoredAuthSession?> readSession() async => session;

  @override
  Future<void> writeAccountBindings(Map<String, String> replacement) async {
    bindings = {...replacement};
  }

  @override
  Future<void> writeSession(StoredAuthSession replacement) async {
    session = replacement;
  }
}

class FakeOidcClient implements OidcClient {
  FakeOidcClient(
    this.signInTokens, {
    this.cancelSignIn = false,
    this.events,
    this.failEndSession = false,
  });

  final AuthTokenSet signInTokens;
  final bool cancelSignIn;
  final List<String>? events;
  final bool failEndSession;
  Completer<AuthTokenSet>? refreshCompleter;
  int refreshCalls = 0;
  int createAccountRequests = 0;
  int endSessionCalls = 0;

  @override
  Future<void> endSession(AuthConfig config, AuthTokenSet current) async {
    endSessionCalls += 1;
    events?.add('provider:end-session');
    if (failEndSession) throw Exception('provider logout failed');
  }

  @override
  Future<AuthTokenSet> refresh(AuthConfig config, AuthTokenSet current) {
    refreshCalls += 1;
    return refreshCompleter?.future ?? Future.value(signInTokens);
  }

  @override
  Future<AuthTokenSet> signIn(
    AuthConfig config, {
    bool createAccount = false,
  }) async {
    if (cancelSignIn) throw const AuthCancelled();
    if (createAccount) createAccountRequests += 1;
    return signInTokens;
  }
}

class FakeNativeAuthBridge implements NativeAuthBridge {
  FakeNativeAuthBridge({
    this.summary = const QueueOwnershipSummary.empty(),
    List<String>? events,
  }) : events = events ?? <String>[];

  QueueOwnershipSummary summary;
  final List<String> events;

  @override
  Future<void> clearAuthContext() async => events.add('clear');

  @override
  Future<void> configureAuthContext({
    required String accountGeneration,
    required String accessToken,
  }) async => events.add('configure:$accountGeneration');

  @override
  Future<QueueOwnershipSummary> getQueueOwnershipSummary(
    String accountGeneration,
  ) async => summary;

  @override
  Future<void> resetAccountScopedState() async => events.add('reset');

  @override
  Future<void> resolveUnclaimedData(
    String accountGeneration,
    UnclaimedDataDecision decision,
  ) async => events.add('resolve:${decision.name}:$accountGeneration');
}
