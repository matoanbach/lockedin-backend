import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/usage/data/usage_sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lockdin/usage');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('uploads bounded native pages and advances the cursor', () async {
    final nativeCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'getPermissionStatus') {
            return permissionStatus(accessibility: false);
          }
          if (call.method == 'collectUsageEventBatch') {
            final arguments = Map<String, dynamic>.from(call.arguments as Map);
            if (arguments['afterEndedAtMillis'] == null) {
              return {
                'events': [usageEvent('first')],
                'hasMore': true,
                'nextEndedAtMillis': 2000,
                'nextSourceEventId': 'first',
              };
            }
            expect(arguments['afterEndedAtMillis'], 2000);
            expect(arguments['afterSourceEventId'], 'first');
            return {
              'events': [usageEvent('second')],
              'hasMore': false,
            };
          }
          fail('Unexpected native method ${call.method}');
        });

    final dio = Dio();
    var requestCount = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount += 1;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {
                'receivedCount': 1,
                'createdCount': 1,
                'duplicateCount': 0,
              },
            ),
          );
        },
      ),
    );

    final result = await UsageSyncRepository(dio).syncRecentUsage(days: 14);

    expect(result.collectedCount, 2);
    expect(result.createdCount, 2);
    expect(requestCount, 2);
    expect(
      nativeCalls.where((call) => call.method == 'collectUsageEventBatch'),
      hasLength(2),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('usage_sync.last_successful_at'), isNotNull);
  });

  test('uses only the live queue while accessibility is enabled', () async {
    final calledMethods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calledMethods.add(call.method);
          if (call.method == 'getPermissionStatus') {
            return permissionStatus(accessibility: true);
          }
          if (call.method == 'flushPendingUsageUploads') {
            return {'uploadedCount': 2, 'failedCount': 0, 'pendingCount': 0};
          }
          fail('Unexpected native method ${call.method}');
        });

    final result = await UsageSyncRepository(Dio()).syncRecentUsage();

    expect(result.createdCount, 2);
    expect(calledMethods, isNot(contains('collectUsageEventBatch')));
  });

  test('does not advance watermark when an upload fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getPermissionStatus') {
            return permissionStatus(accessibility: false);
          }
          if (call.method == 'collectUsageEventBatch') {
            return {
              'events': [usageEvent('offline')],
              'hasMore': false,
            };
          }
          fail('Unexpected native method ${call.method}');
        });

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'backend offline',
          ),
        ),
      ),
    );

    await expectLater(
      UsageSyncRepository(dio).syncRecentUsage(),
      throwsA(isA<DioException>()),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('usage_sync.last_successful_at'), isNull);
  });
}

Map<String, dynamic> permissionStatus({required bool accessibility}) => {
  'usageAccess': true,
  'notifications': false,
  'accessibility': accessibility,
  'notificationDiagnostics': <String, dynamic>{},
};

Map<String, dynamic> usageEvent(String sourceEventId) => {
  'sourceEventId': sourceEventId,
  'appId': 'com.google.android.youtube',
  'appName': 'YouTube',
  'category': 'Entertainment',
  'startedAt': '2026-07-16T12:00:00Z',
  'endedAt': '2026-07-16T12:01:00Z',
  'timezone': 'UTC',
};
