import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lockdin_app/core/theme/app_colors.dart';
import 'package:lockdin_app/features/analytics/data/analytics_provider.dart';
import 'package:lockdin_app/features/analytics/presentation/screens/analytics_summary_screen.dart';
import 'package:lockdin_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:lockdin_app/features/rules/data/rules_provider.dart';
import 'package:lockdin_app/features/rules/presentation/screens/lockdown_rules_screen.dart';
import 'package:lockdin_app/features/trends/presentation/screens/trends_screen.dart';
import 'package:lockdin_app/features/usage/data/usage_sync_provider.dart';
import 'package:lockdin_app/shared/models/models.dart';

class _TestDevicePermissionsController extends DevicePermissionsController {
  @override
  Future<DevicePermissions> build() async {
    return const DevicePermissions(
      isSupported: false,
      usageAccess: false,
      notifications: false,
      accessibility: false,
      notificationDiagnostics: NotificationDiagnostics(
        appEnabled: false,
        channelId: '',
        channelExists: false,
        channelEnabled: false,
        channelImportance: 0,
        channelImportanceLabel: 'unknown',
      ),
    );
  }
}

class _TestUsageSyncController extends UsageSyncController {
  @override
  Future<UsageSyncResult?> build() async => null;
}

class _TestLockdownRulesController extends LockdownRulesController {
  @override
  Future<List<LockdownRule>> build() async => const [];
}

const _dashboard = DashboardAnalyticsData(
  todayTotalMinutes: 1,
  categoryBreakdown: [
    UsageData(
      name: 'Web & Search',
      minutes: 0,
      durationMilliseconds: 19_933,
      color: AppColors.info,
    ),
  ],
  weeklyUsageHours: [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
  weeklyTotalMinutes: 30,
  deltaFromYesterdayPercent: 0,
);

const _summary = WeeklySummaryData(
  screenTimeReductionPercent: -60,
  totalWeekHours: 0.5,
  dailyAverageHours: 0.1,
  goalsMetDays: 4,
  longestStreakDays: 7,
);

void main() {
  test(
    'category parsing has stable colors and truthful sub-minute copy',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'todayTotalMinutes': 0,
                  'categoryBreakdown': [
                    {
                      'name': 'Video & Entertainment',
                      'minutes': 0,
                      'durationMilliseconds': 19_933,
                    },
                    {
                      'name': 'Learning',
                      'minutes': 2,
                      'durationMilliseconds': 120_000,
                    },
                    {
                      'name': 'System & Utilities',
                      'minutes': 3,
                      'durationMilliseconds': 180_000,
                    },
                    {
                      'name': 'Other',
                      'minutes': 4,
                      'durationMilliseconds': 240_000,
                    },
                  ],
                  'weeklyUsageHours': <double>[],
                  'weeklyTotalMinutes': 2,
                  'deltaFromYesterdayPercent': 0,
                },
              ),
            );
          },
        ),
      );

      final analytics = await AnalyticsRepository(dio).fetchDashboard();

      expect(analytics.categoryBreakdown[0].formattedTime, '<1m');
      expect(
        analytics.categoryBreakdown[0].color,
        AppColors.videoEntertainment,
      );
      expect(analytics.categoryBreakdown[1].formattedTime, '2m');
      expect(analytics.categoryBreakdown[1].color, AppColors.success);
      expect(analytics.categoryBreakdown[2].color, AppColors.systemUtilities);
      expect(analytics.categoryBreakdown[3].color, AppColors.otherCategory);
      expect(AppColors.socialMessaging, isNot(AppColors.videoEntertainment));
      expect(AppColors.systemUtilities, isNot(AppColors.otherCategory));
    },
  );

  testWidgets(
    'Dashboard exposes a visible Weekly Summary action and navigates',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, _) => const AnalyticsSummaryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardAnalyticsProvider.overrideWith((_) async => _dashboard),
            weeklySummaryProvider.overrideWith((_) async => _summary),
            devicePermissionsProvider.overrideWith(
              _TestDevicePermissionsController.new,
            ),
            usageSyncControllerProvider.overrideWith(
              _TestUsageSyncController.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('<1m'), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
      expect(find.textContaining('HLR'), findsNothing);
      await tester.scrollUntilVisible(find.text('View Weekly Summary'), 300);
      expect(find.text('30m total'), findsOneWidget);

      await tester.tap(find.text('View Weekly Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Summary'), findsOneWidget);
      expect(find.text('Total this week'), findsOneWidget);
      expect(find.text('Weekly Highlights'), findsOneWidget);
      expect(
        find.text('Your goal progress and best streak, updated weekly.'),
        findsOneWidget,
      );
      expect(find.text('Goal Progress'), findsOneWidget);
      expect(find.text('Best Streak'), findsOneWidget);
      expect(
        find.text('Best streak so far: 7 days under goal'),
        findsOneWidget,
      );
      expect(find.text('Achievements Unlocked'), findsNothing);
      expect(find.textContaining('HLR'), findsNothing);
      expect(find.text('Rate Your Experience'), findsNothing);
      expect(find.text('Submit Feedback'), findsNothing);
    },
  );

  testWidgets('Weekly Summary uses singular day copy for a one-day streak', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklySummaryProvider.overrideWith(
            (_) async => const WeeklySummaryData(
              screenTimeReductionPercent: 0,
              totalWeekHours: 1,
              dailyAverageHours: 0.1,
              goalsMetDays: 1,
              longestStreakDays: 1,
            ),
          ),
        ],
        child: const MaterialApp(home: AnalyticsSummaryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Best streak so far: 1 day under goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('day'), findsOneWidget);
    expect(find.text('Met goals 1 day this week'), findsOneWidget);
    expect(find.text('Best streak so far: 1 day under goal'), findsOneWidget);
    expect(find.textContaining('1 days'), findsNothing);
  });

  testWidgets('Dashboard Add Rule opens the creation form directly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
        GoRoute(
          path: '/rules',
          builder: (_, state) => LockdownRulesScreen(
            openCreateForm: state.uri.queryParameters['create'] == 'true',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardAnalyticsProvider.overrideWith((_) async => _dashboard),
          devicePermissionsProvider.overrideWith(
            _TestDevicePermissionsController.new,
          ),
          usageSyncControllerProvider.overrideWith(
            _TestUsageSyncController.new,
          ),
          lockdownRulesProvider.overrideWith(_TestLockdownRulesController.new),
          ruleStatusesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add Rule'), 300);
    await tester.tap(find.text('Add Rule'));
    await tester.pumpAndSettle();

    expect(find.text('Lockdown Rules'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Create Rule'), findsWidgets);
  });

  testWidgets('Rules route opens the overview without the creation form', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/rules',
      routes: [
        GoRoute(
          path: '/rules',
          builder: (_, state) => LockdownRulesScreen(
            openCreateForm: state.uri.queryParameters['create'] == 'true',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lockdownRulesProvider.overrideWith(_TestLockdownRulesController.new),
          ruleStatusesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lockdown Rules'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Active Rules'), findsOneWidget);
  });

  testWidgets('Trends has clear totals, labels, colors, and one peak insight', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trendsAnalyticsProvider.overrideWith(
            (_) async => const TrendsAnalyticsData(
              hourlyUsage: [],
              weeklyUsage: [
                DailyUsage(day: 'Mon', hours: 4.2),
                DailyUsage(day: 'Tue', hours: 0.1),
                DailyUsage(day: 'Wed', hours: 0.1),
                DailyUsage(day: 'Thu', hours: 0.1),
                DailyUsage(day: 'Fri', hours: 0.1),
                DailyUsage(day: 'Sat', hours: 0.1),
                DailyUsage(day: 'Sun', hours: 0.1),
              ],
              weeklyTotalMinutes: 30,
              topApps: [
                TopAppUsage(
                  appId: 'com.whatsapp',
                  appName: 'WhatsApp',
                  minutes: 20,
                ),
                TopAppUsage(
                  appId: 'com.sec.android.app.launcher',
                  appName: 'One UI Home',
                  minutes: 10,
                ),
              ],
              peakUsageWindow: '11 PM - 1 AM',
            ),
          ),
        ],
        child: const MaterialApp(home: TrendsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0.5h total'), findsOneWidget);
    expect(find.text('4.8h total'), findsNothing);
    expect(find.text('0h'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('4h'), findsOneWidget);
    expect(find.text('6h'), findsOneWidget);
    expect(find.textContaining('11 PM - 1 AM'), findsOneWidget);
    expect(find.textContaining('Your busiest window is'), findsNothing);
    final topAppIcons = tester.widgetList<Icon>(
      find.byIcon(Icons.apps_rounded),
    );
    expect(topAppIcons.map((icon) => icon.color), [
      AppColors.socialMessaging,
      AppColors.videoEntertainment,
    ]);
    expect(AppColors.socialMessaging, isNot(AppColors.videoEntertainment));
  });
}
