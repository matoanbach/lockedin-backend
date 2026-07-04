import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/core/theme/app_colors.dart';
import 'package:lockdin_app/core/theme/app_theme.dart';
import 'package:lockdin_app/features/analytics/data/analytics_provider.dart';
import 'package:lockdin_app/features/rules/data/rules_provider.dart';
import 'package:lockdin_app/features/rules/presentation/widgets/app_limit_warning.dart';

void main() {
  test(
    'usage dashboard top apps use weekly totals from analytics payload',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'hourlyUsage': <Map<String, Object?>>[],
                  'weeklyUsage': <Map<String, Object?>>[],
                  'topApps': [
                    {
                      'appId': 'com.instagram.android',
                      'appName': 'Instagram',
                      'minutes': 250,
                    },
                    {
                      'appId': 'com.google.android.youtube',
                      'appName': 'YouTube',
                      'minutes': 105,
                    },
                    {
                      'appId': 'com.spotify.music',
                      'appName': 'Spotify',
                      'minutes': 45,
                    },
                  ],
                  'peakUsageWindow': '8 PM - 10 PM',
                },
              ),
            );
          },
        ),
      );

      final analytics = await AnalyticsRepository(dio).fetchTrends();

      expect(analytics.topApps[0].formattedTime, '4h 10m');
      expect(analytics.topApps[1].formattedTime, '1h 45m');
      expect(analytics.topApps[2].formattedTime, '45m');
    },
  );

  testWidgets(
    'lockdown rules card displays daily used time, limit, and remaining time',
    (tester) async {
      final status = _status(
        appName: 'Instagram',
        usedMinutes: 60,
        limitMinutes: 90,
        remainingMinutes: 30,
      );

      await tester.pumpWidget(
        _TestHost(
          child: AppLimitUsageCard(
            appName: status.appName,
            icon: Icons.camera_alt,
            color: AppColors.instagram,
            enabled: true,
            limitMinutes: status.limitMinutes,
            status: status,
            reminderThresholdMinutes: 30,
            onToggle: () {},
            onEdit: () {},
          ),
        ),
      );

      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('1h used'), findsOneWidget);
      expect(find.text('Used: 1h'), findsOneWidget);
      expect(find.text('Limit: 1h 30m'), findsOneWidget);
      expect(find.text('Left: 30m'), findsOneWidget);
    },
  );

  testWidgets(
    'lockdown rules cards use daily limits separate from weekly totals',
    (tester) async {
      final statuses = [
        _status(
          appName: 'Instagram',
          usedMinutes: 60,
          limitMinutes: 90,
          remainingMinutes: 30,
        ),
        _status(
          appName: 'Spotify',
          appId: 'com.spotify.music',
          usedMinutes: 0,
          limitMinutes: 60,
          remainingMinutes: 60,
        ),
        _status(
          appName: 'YouTube',
          appId: 'com.google.android.youtube',
          usedMinutes: 15,
          limitMinutes: 45,
          remainingMinutes: 30,
        ),
      ];

      await tester.pumpWidget(
        _TestHost(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final status in statuses)
                  AppLimitUsageCard(
                    appName: status.appName,
                    icon: Icons.apps,
                    color: AppColors.instagram,
                    enabled: true,
                    limitMinutes: status.limitMinutes,
                    status: status,
                    reminderThresholdMinutes: 30,
                    onToggle: () {},
                    onEdit: () {},
                  ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1h used'), findsOneWidget);
      expect(find.text('Limit: 1h 30m'), findsOneWidget);
      expect(find.text('0m used'), findsOneWidget);
      expect(find.text('Limit: 1h'), findsOneWidget);
      expect(find.text('15m used'), findsOneWidget);
      expect(find.text('Limit: 45m'), findsOneWidget);
      expect(find.text('Left: 30m'), findsNWidgets(2));
      expect(find.text('Left: 1h'), findsOneWidget);
    },
  );

  testWidgets('warning label appears within reminder threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        child: AppLimitUsageCard(
          appName: 'Instagram',
          icon: Icons.camera_alt,
          color: AppColors.instagram,
          enabled: true,
          limitMinutes: 300,
          status: _status(
            usedMinutes: 270,
            limitMinutes: 300,
            remainingMinutes: 30,
          ),
          reminderThresholdMinutes: 30,
          onToggle: () {},
          onEdit: () {},
        ),
      ),
    );

    expect(find.text('30 minutes left'), findsOneWidget);
    expect(find.text('Approaching'), findsOneWidget);
  });

  testWidgets('warning label stays hidden when enough time remains', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        child: AppLimitUsageCard(
          appName: 'Instagram',
          icon: Icons.camera_alt,
          color: AppColors.instagram,
          enabled: true,
          limitMinutes: 300,
          status: _status(
            usedMinutes: 250,
            limitMinutes: 300,
            remainingMinutes: 50,
          ),
          reminderThresholdMinutes: 30,
          onToggle: () {},
          onEdit: () {},
        ),
      ),
    );

    expect(find.text('50 minutes left'), findsNothing);
    expect(find.text('Under Limit'), findsOneWidget);
  });

  test(
    'top reminder status is selected only for daily limits near threshold',
    () {
      final selected = firstReminderStatusFor([
        _status(
          appName: 'Spotify',
          appId: 'com.spotify.music',
          usedMinutes: 0,
          limitMinutes: 60,
          remainingMinutes: 60,
        ),
        _status(
          appName: 'Instagram',
          usedMinutes: 60,
          limitMinutes: 90,
          remainingMinutes: 30,
        ),
      ], 30);

      expect(selected?.appName, 'Instagram');
      expect(
        firstReminderStatusFor([
          _status(usedMinutes: 10, limitMinutes: 90, remainingMinutes: 80),
        ], 30),
        isNull,
      );
    },
  );

  testWidgets('top reminder banner displays app name and 30 minutes left', (
    tester,
  ) async {
    final status = _status(
      appName: 'Instagram',
      usedMinutes: 60,
      limitMinutes: 90,
      remainingMinutes: 30,
    );

    await tester.pumpWidget(
      _TestHost(
        child: ReminderBanner(status: status, onShowPopup: () {}),
      ),
    );

    expect(
      find.text('Reminder: You have 30 minutes left on Instagram.'),
      findsOneWidget,
    );
    expect(reminderPopupText(status), contains('Instagram'));
    expect(reminderPopupText(status), contains('30 minutes left'));
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }
}

RuleStatusData _status({
  String appName = 'Instagram',
  String appId = 'com.instagram.android',
  required int usedMinutes,
  required int limitMinutes,
  required int remainingMinutes,
}) {
  return RuleStatusData(
    ruleId: 'rule-$appId',
    appId: appId,
    appName: appName,
    usageDate: '2026-06-12',
    enabled: true,
    limitMinutes: limitMinutes,
    usedMinutes: usedMinutes,
    remainingMinutes: remainingMinutes,
    progressPercent: ((usedMinutes / limitMinutes) * 100).round(),
    status: remainingMinutes <= 30 ? 'approaching_limit' : 'under_limit',
    isBlockedNow: false,
  );
}
