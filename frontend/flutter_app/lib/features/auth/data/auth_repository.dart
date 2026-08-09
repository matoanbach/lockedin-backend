import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'auth_models.dart';
import 'native_auth_bridge.dart';
import 'oidc_client.dart';
import 'secure_auth_storage.dart';

class AuthRepository {
  AuthRepository({
    required this.publicDio,
    required this.storage,
    required this.oidcClient,
    required this.nativeBridge,
    DateTime Function()? now,
    Random? secureRandom,
  }) : _now = now ?? DateTime.now,
       _secureRandom = secureRandom ?? Random.secure();

  final Dio publicDio;
  final AuthStorage storage;
  final OidcClient oidcClient;
  final NativeAuthBridge nativeBridge;
  final DateTime Function() _now;
  final Random _secureRandom;

  StoredAuthSession? _storedSession;
  MobileSession? _mobileSession;
  Future<AuthTokenSet>? _refreshInFlight;

  MobileSession? get currentSession => _mobileSession;

  Future<LockdInAuthState> bootstrap() async {
    final stored = await storage.readSession();
    if (stored == null) {
      await nativeBridge.clearAuthContext();
      return const LockdInAuthState.signedOut();
    }
    _storedSession = stored;
    try {
      if (stored.tokens.shouldRefresh(_now())) {
        await refreshTokens();
      }
      return _validateAndPrepareSession();
    } on Object {
      await nativeBridge.clearAuthContext();
      return const LockdInAuthState.reauthenticationRequired(
        message: 'Your session needs to be renewed.',
      );
    }
  }

  Future<LockdInAuthState> signIn({bool createAccount = false}) async {
    final config = await _fetchConfig();
    final tokens = await oidcClient.signIn(
      config,
      createAccount: createAccount,
    );
    final stored = StoredAuthSession(config: config, tokens: tokens);
    await storage.writeSession(stored);
    _storedSession = stored;
    return _validateAndPrepareSession(transitioningAccount: true);
  }

  Future<LockdInAuthState> _validateAndPrepareSession({
    bool transitioningAccount = false,
  }) async {
    final stored = _storedSession;
    if (stored == null) throw const ReauthenticationRequired();
    final response = await _authorizedRequest(
      'GET',
      '/api/v1/auth/session',
      stored.tokens.accessToken,
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    final issuer = _requiredString(json, 'issuer');
    final subject = _requiredString(json, 'subject');
    if (issuer != stored.config.issuer) {
      throw const ReauthenticationRequired();
    }
    final generation = await accountGenerationFor(issuer, subject);
    final session = MobileSession(
      accountId: _requiredString(json, 'accountId'),
      profileId: _requiredString(json, 'profileId'),
      issuer: issuer,
      subject: subject,
      sid: _requiredString(json, 'sid'),
      accountGeneration: generation,
    );
    _mobileSession = session;
    if (transitioningAccount) {
      await nativeBridge.clearAuthContext();
      await nativeBridge.resetAccountScopedState();
    }
    final summary = await nativeBridge.getQueueOwnershipSummary(generation);
    if (summary.unclaimedCount > 0) {
      await nativeBridge.clearAuthContext();
      return LockdInAuthState(
        phase: AuthPhase.accountTransition,
        session: session,
        queueSummary: summary,
      );
    }
    await nativeBridge.configureAuthContext(
      accountGeneration: generation,
      accessToken: stored.tokens.accessToken,
    );
    return LockdInAuthState(
      phase: AuthPhase.authenticated,
      session: session,
      queueSummary: summary,
    );
  }

  Future<String> accessToken({bool forceRefresh = false}) async {
    final stored = _storedSession;
    if (stored == null) throw const ReauthenticationRequired();
    if (forceRefresh || stored.tokens.shouldRefresh(_now())) {
      return (await refreshTokens()).accessToken;
    }
    return stored.tokens.accessToken;
  }

  Future<AuthTokenSet> refreshTokens() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<AuthTokenSet> _performRefresh() async {
    final current = _storedSession;
    if (current == null) throw const ReauthenticationRequired();
    try {
      final tokens = await oidcClient.refresh(current.config, current.tokens);
      final replacement = current.withTokens(tokens);
      await storage.writeSession(replacement);
      _storedSession = replacement;
      final session = _mobileSession;
      if (session != null) {
        await nativeBridge.configureAuthContext(
          accountGeneration: session.accountGeneration,
          accessToken: tokens.accessToken,
        );
      }
      return tokens;
    } on Object {
      await nativeBridge.clearAuthContext();
      rethrow;
    }
  }

  Future<LockdInAuthState> resolveUnclaimedData(
    UnclaimedDataDecision decision,
  ) async {
    final session = _mobileSession;
    final stored = _storedSession;
    if (session == null || stored == null) {
      throw const ReauthenticationRequired();
    }
    await nativeBridge.resolveUnclaimedData(
      session.accountGeneration,
      decision,
    );
    await nativeBridge.configureAuthContext(
      accountGeneration: session.accountGeneration,
      accessToken: stored.tokens.accessToken,
    );
    final summary = await nativeBridge.getQueueOwnershipSummary(
      session.accountGeneration,
    );
    return LockdInAuthState(
      phase: AuthPhase.authenticated,
      session: session,
      queueSummary: summary,
    );
  }

  Future<void> logout() async {
    final current = _storedSession;
    await nativeBridge.clearAuthContext();
    if (current != null) {
      try {
        await _authorizedRequest(
          'POST',
          '/api/v1/auth/logout',
          current.tokens.accessToken,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode != 401) {
          // Local logout is authoritative even when revocation is unavailable.
        }
      }
      try {
        await oidcClient.endSession(current.config, current.tokens);
      } on Object {
        // Local logout remains authoritative when provider logout is unavailable.
      }
    }
    await storage.deleteSession();
    await nativeBridge.resetAccountScopedState();
    _storedSession = null;
    _mobileSession = null;
  }

  Future<void> stopAuthenticatedWork() => nativeBridge.clearAuthContext();

  Future<String> accountGenerationFor(String issuer, String subject) async {
    final bindings = await storage.readAccountBindings();
    final key = base64Url.encode(utf8.encode('$issuer\u0000$subject'));
    final existing = bindings[key];
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    final generation = base64Url.encode(bytes).replaceAll('=', '');
    await storage.writeAccountBindings({...bindings, key: generation});
    return generation;
  }

  Future<AuthConfig> _fetchConfig() async {
    final response = await publicDio.get<Object>('/api/v1/auth/config');
    return AuthConfig.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Response<Object?>> _authorizedRequest(
    String method,
    String path,
    String accessToken,
  ) {
    return publicDio.request<Object?>(
      path,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid authentication session response.');
    }
    return value;
  }
}
