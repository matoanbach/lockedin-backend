import 'package:flutter_appauth/flutter_appauth.dart';

import 'auth_models.dart';

abstract interface class OidcClient {
  Future<AuthTokenSet> signIn(AuthConfig config, {bool createAccount = false});
  Future<AuthTokenSet> refresh(AuthConfig config, AuthTokenSet current);
}

class AppAuthOidcClient implements OidcClient {
  const AppAuthOidcClient({this.appAuth = const FlutterAppAuth()});

  final FlutterAppAuth appAuth;

  AuthorizationServiceConfiguration _serviceConfiguration(AuthConfig config) {
    return AuthorizationServiceConfiguration(
      authorizationEndpoint: config.authorizationEndpoint,
      tokenEndpoint: config.tokenEndpoint,
      endSessionEndpoint: config.endSessionEndpoint,
    );
  }

  @override
  Future<AuthTokenSet> signIn(
    AuthConfig config, {
    bool createAccount = false,
  }) async {
    if (config.codeChallengeMethod != 'S256' ||
        config.scopes.contains('offline_access')) {
      throw const FormatException('Unsupported authentication configuration.');
    }

    try {
      final response = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUri,
          scopes: config.scopes,
          serviceConfiguration: _serviceConfiguration(config),
          promptValues: createAccount ? const ['create'] : null,
        ),
      );
      return _tokensFromResponse(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        idToken: response.idToken,
        expiresAt: response.accessTokenExpirationDateTime,
      );
    } on FlutterAppAuthUserCancelledException {
      throw const AuthCancelled();
    }
  }

  @override
  Future<AuthTokenSet> refresh(AuthConfig config, AuthTokenSet current) async {
    final response = await appAuth.token(
      TokenRequest(
        config.clientId,
        config.redirectUri,
        refreshToken: current.refreshToken,
        scopes: config.scopes,
        serviceConfiguration: _serviceConfiguration(config),
      ),
    );
    return _tokensFromResponse(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken ?? current.refreshToken,
      idToken: response.idToken ?? current.idToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
  }

  AuthTokenSet _tokensFromResponse({
    required String? accessToken,
    required String? refreshToken,
    required String? idToken,
    required DateTime? expiresAt,
  }) {
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        expiresAt == null) {
      throw const ReauthenticationRequired();
    }
    return AuthTokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      accessTokenExpiresAt: expiresAt.toUtc(),
    );
  }
}
