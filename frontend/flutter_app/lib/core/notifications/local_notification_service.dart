import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

final localNotificationsProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService(ref),
);

class LocalNotificationService {
  LocalNotificationService(this._ref);

  final Ref _ref;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _warningChannel =
      AndroidNotificationChannel(
        'lockdin_warnings',
        'LockdIn warnings',
        description: 'Limit warnings and reminders from LockdIn.',
        importance: Importance.max,
      );

  bool _didInitialize = false;
  String? _pendingPayload;

  Future<void> initialize() async {
    if (!_isAndroid || _didInitialize) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_lockdin'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    await _androidPlugin?.createNotificationChannel(_warningChannel);
    _didInitialize = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _queuePayload(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_isAndroid) {
      return false;
    }

    await initialize();
    return await _androidPlugin?.areNotificationsEnabled() ?? false;
  }

  Future<bool> requestPermission() async {
    if (!_isAndroid) {
      return false;
    }

    await initialize();
    final granted = await _androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> showWarning({
    required int notificationId,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      if (!_isAndroid) {
        return false;
      }

      await initialize();
      if (!await areNotificationsEnabled()) {
        return false;
      }

      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'lockdin_warnings',
            'LockdIn warnings',
            channelDescription: 'Limit warnings and reminders from LockdIn.',
            icon: 'ic_stat_lockdin',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            styleInformation: BigTextStyleInformation(body),
            color: const Color(0xFF8B5CF6),
            ticker: 'LockdIn alert',
          ),
        ),
        payload: payload,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> consumePendingNavigation() async {
    final payload = _pendingPayload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final context = _ref.read(rootNavigatorKeyProvider).currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    _pendingPayload = null;
    GoRouter.of(context).go(_routeFromPayload(payload));
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _queuePayload(response.payload);
  }

  void _queuePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    _pendingPayload = payload;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(consumePendingNavigation());
    });
  }

  String _routeFromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final route = decoded['route'] as String?;
        if (route != null && route.startsWith('/')) {
          return route;
        }
      }
    } catch (_) {
      // Fall back to the rules screen for malformed payloads.
    }

    return AppRoutes.lockdownRules;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
