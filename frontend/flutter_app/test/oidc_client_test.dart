import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/auth/data/auth_models.dart';
import 'package:lockdin_app/features/auth/data/oidc_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('crossingthestreams.io/flutter_appauth');
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
  final calls = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'authorizeAndExchangeCode') {
            return <String, Object>{
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'idToken': 'id-token',
              'accessTokenExpirationTime': DateTime.utc(
                2030,
              ).millisecondsSinceEpoch,
            };
          }
          return <String, Object>{};
        });
  });

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('normal sign-in forces an explicit provider login prompt', () async {
    await const AppAuthOidcClient().signIn(config);

    final arguments = Map<String, Object?>.from(calls.single.arguments as Map);
    expect(arguments['promptValues'], ['login']);
  });

  test('account creation retains the provider registration prompt', () async {
    await const AppAuthOidcClient().signIn(config, createAccount: true);

    final arguments = Map<String, Object?>.from(calls.single.arguments as Map);
    expect(arguments['promptValues'], ['create']);
  });

  test('end session uses the ID token and registered app redirect', () async {
    await const AppAuthOidcClient().endSession(
      config,
      AuthTokenSet(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        idToken: 'id-token',
        accessTokenExpiresAt: DateTime.utc(2030),
      ),
    );

    expect(calls.single.method, 'endSession');
    final arguments = Map<String, Object?>.from(calls.single.arguments as Map);
    expect(arguments['idTokenHint'], 'id-token');
    expect(arguments['postLogoutRedirectUrl'], config.redirectUri);
    expect(
      arguments['serviceConfiguration'],
      containsPair('endSessionEndpoint', config.endSessionEndpoint),
    );
  });
}
