import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/api_transport.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'native_auth_bridge.dart';
import 'oidc_client.dart';
import 'secure_auth_storage.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => SecureAuthStorage());
final oidcClientProvider = Provider<OidcClient>(
  (ref) => const AppAuthOidcClient(),
);
final nativeAuthBridgeProvider = Provider<NativeAuthBridge>(
  (ref) => const MethodChannelNativeAuthBridge(),
);
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    publicDio: ref.watch(publicDioProvider),
    storage: ref.watch(authStorageProvider),
    oidcClient: ref.watch(oidcClientProvider),
    nativeBridge: ref.watch(nativeAuthBridgeProvider),
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, LockdInAuthState>(AuthController.new);

class AuthController extends AsyncNotifier<LockdInAuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<LockdInAuthState> build() => _repository.bootstrap();

  Future<void> signIn({bool createAccount = false}) async {
    final previousPhase = state.asData?.value.phase;
    state = const AsyncLoading();
    try {
      state = AsyncData(await _repository.signIn(createAccount: createAccount));
    } on AuthCancelled {
      state = const AsyncData(LockdInAuthState.signedOut());
    } on Object catch (error) {
      state = AsyncData(
        LockdInAuthState(
          phase: previousPhase == AuthPhase.reauthenticationRequired
              ? AuthPhase.reauthenticationRequired
              : AuthPhase.signedOut,
          message: error is DioException
              ? describeApiError(error)
              : 'Sign-in could not be completed. Check the authentication service and try again.',
        ),
      );
    }
  }

  Future<String> accessToken({bool forceRefresh = false}) async {
    try {
      return await _repository.accessToken(forceRefresh: forceRefresh);
    } catch (_) {
      requireReauthentication();
      rethrow;
    }
  }

  Future<void> resolveUnclaimedData(UnclaimedDataDecision decision) async {
    state = const AsyncLoading();
    state = AsyncData(await _repository.resolveUnclaimedData(decision));
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(LockdInAuthState.signedOut());
  }

  void requireReauthentication() {
    unawaited(_repository.stopAuthenticatedWork());
    state = const AsyncData(
      LockdInAuthState.reauthenticationRequired(
        message: 'Your session expired. Sign in again to continue.',
      ),
    );
  }
}
