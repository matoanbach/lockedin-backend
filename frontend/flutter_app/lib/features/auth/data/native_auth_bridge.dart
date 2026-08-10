import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_models.dart';

abstract interface class NativeAuthBridge {
  Future<void> configureAuthContext({
    required String accountGeneration,
    required String accessToken,
  });
  Future<void> clearAuthContext();
  Future<QueueOwnershipSummary> getQueueOwnershipSummary(
    String accountGeneration,
  );
  Future<void> resolveUnclaimedData(
    String accountGeneration,
    UnclaimedDataDecision decision,
  );
  Future<void> resetAccountScopedState();
  Future<void> deleteAccountData(String accountGeneration);
}

class MethodChannelNativeAuthBridge implements NativeAuthBridge {
  const MethodChannelNativeAuthBridge();

  static const MethodChannel _channel = MethodChannel('lockdin/usage');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> configureAuthContext({
    required String accountGeneration,
    required String accessToken,
  }) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('configureAuthContext', {
      'accountGeneration': accountGeneration,
      'accessToken': accessToken,
    });
  }

  @override
  Future<void> clearAuthContext() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('clearAuthContext');
  }

  @override
  Future<QueueOwnershipSummary> getQueueOwnershipSummary(
    String accountGeneration,
  ) async {
    if (!_isAndroid) return const QueueOwnershipSummary.empty();
    final json = await _channel.invokeMapMethod<String, dynamic>(
      'getQueueOwnershipSummary',
      {'accountGeneration': accountGeneration},
    );
    return QueueOwnershipSummary(
      activeCount: (json?['activeCount'] as num?)?.toInt() ?? 0,
      unclaimedCount: (json?['unclaimedCount'] as num?)?.toInt() ?? 0,
      quarantinedCount: (json?['quarantinedCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> resolveUnclaimedData(
    String accountGeneration,
    UnclaimedDataDecision decision,
  ) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('resolveUnclaimedData', {
      'accountGeneration': accountGeneration,
      'decision': decision.name,
    });
  }

  @override
  Future<void> resetAccountScopedState() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('resetAccountScopedState');
  }

  @override
  Future<void> deleteAccountData(String accountGeneration) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('deleteAccountData', {
      'accountGeneration': accountGeneration,
    });
  }
}
