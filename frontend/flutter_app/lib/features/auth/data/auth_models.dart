enum AuthPhase {
  initializing,
  signedOut,
  verificationRequired,
  authenticated,
  reauthenticationRequired,
  accountTransition,
}

class AuthConfig {
  const AuthConfig({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.endSessionEndpoint,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    required this.codeChallengeMethod,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    String requiredString(String camelCase, String snakeCase) {
      final value = json[camelCase] ?? json[snakeCase];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid authentication configuration.');
      }
      return value;
    }

    final rawScopes = json['scopes'];
    if (rawScopes is! List || rawScopes.any((scope) => scope is! String)) {
      throw const FormatException('Invalid authentication configuration.');
    }

    return AuthConfig(
      issuer: requiredString('issuer', 'issuer'),
      authorizationEndpoint: requiredString(
        'authorizationEndpoint',
        'authorization_endpoint',
      ),
      tokenEndpoint: requiredString('tokenEndpoint', 'token_endpoint'),
      endSessionEndpoint: requiredString(
        'endSessionEndpoint',
        'end_session_endpoint',
      ),
      clientId: requiredString('clientId', 'client_id'),
      redirectUri: requiredString('redirectUri', 'redirect_uri'),
      scopes: List<String>.unmodifiable(rawScopes.cast<String>()),
      codeChallengeMethod: requiredString(
        'codeChallengeMethod',
        'code_challenge_method',
      ),
    );
  }

  factory AuthConfig.fromStoredJson(Map<String, dynamic> json) =>
      AuthConfig.fromJson(json);

  final String issuer;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String endSessionEndpoint;
  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String codeChallengeMethod;

  Map<String, dynamic> toJson() => {
    'issuer': issuer,
    'authorizationEndpoint': authorizationEndpoint,
    'tokenEndpoint': tokenEndpoint,
    'endSessionEndpoint': endSessionEndpoint,
    'clientId': clientId,
    'redirectUri': redirectUri,
    'scopes': scopes,
    'codeChallengeMethod': codeChallengeMethod,
  };
}

class AuthTokenSet {
  const AuthTokenSet({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiresAt,
  });

  factory AuthTokenSet.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAt = json['accessTokenExpiresAt'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        expiresAt is! String) {
      throw const FormatException('Invalid stored authentication session.');
    }

    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (parsedExpiry == null) {
      throw const FormatException('Invalid stored authentication session.');
    }

    return AuthTokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: json['idToken'] as String?,
      accessTokenExpiresAt: parsedExpiry.toUtc(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String? idToken;
  final DateTime accessTokenExpiresAt;

  bool shouldRefresh(
    DateTime now, {
    Duration minimumValidity = const Duration(seconds: 30),
  }) => !accessTokenExpiresAt.isAfter(now.toUtc().add(minimumValidity));

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
  };
}

class StoredAuthSession {
  const StoredAuthSession({required this.config, required this.tokens});

  factory StoredAuthSession.fromJson(Map<String, dynamic> json) {
    return StoredAuthSession(
      config: AuthConfig.fromStoredJson(
        Map<String, dynamic>.from(json['config'] as Map),
      ),
      tokens: AuthTokenSet.fromJson(
        Map<String, dynamic>.from(json['tokens'] as Map),
      ),
    );
  }

  final AuthConfig config;
  final AuthTokenSet tokens;

  StoredAuthSession withTokens(AuthTokenSet replacement) =>
      StoredAuthSession(config: config, tokens: replacement);

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'tokens': tokens.toJson(),
  };
}

class MobileSession {
  const MobileSession({
    required this.accountId,
    required this.profileId,
    required this.issuer,
    required this.subject,
    required this.sid,
    required this.accountGeneration,
  });

  final String accountId;
  final String profileId;
  final String issuer;
  final String subject;
  final String sid;
  final String accountGeneration;
}

class QueueOwnershipSummary {
  const QueueOwnershipSummary({
    required this.activeCount,
    required this.unclaimedCount,
    required this.quarantinedCount,
  });

  const QueueOwnershipSummary.empty()
    : activeCount = 0,
      unclaimedCount = 0,
      quarantinedCount = 0;

  final int activeCount;
  final int unclaimedCount;
  final int quarantinedCount;
}

class LockdInAuthState {
  const LockdInAuthState({
    required this.phase,
    this.session,
    this.queueSummary = const QueueOwnershipSummary.empty(),
    this.message,
  });

  const LockdInAuthState.initializing() : this(phase: AuthPhase.initializing);

  const LockdInAuthState.signedOut() : this(phase: AuthPhase.signedOut);

  const LockdInAuthState.reauthenticationRequired({String? message})
    : this(phase: AuthPhase.reauthenticationRequired, message: message);

  final AuthPhase phase;
  final MobileSession? session;
  final QueueOwnershipSummary queueSummary;
  final String? message;

  bool get canUseProtectedRoutes => phase == AuthPhase.authenticated;
  bool get hasPendingUnclaimedData => queueSummary.unclaimedCount > 0;
}

enum UnclaimedDataDecision { import, discard }

class AuthCancelled implements Exception {
  const AuthCancelled();
}

class ReauthenticationRequired implements Exception {
  const ReauthenticationRequired();
}
