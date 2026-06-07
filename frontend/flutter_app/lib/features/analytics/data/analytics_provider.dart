import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(dioProvider));
});

final dashboardAnalyticsProvider = FutureProvider<DashboardAnalyticsData>((ref) {
  return ref.watch(analyticsRepositoryProvider).fetchDashboard();
});

final trendsAnalyticsProvider = FutureProvider<TrendsAnalyticsData>((ref) {
  return ref.watch(analyticsRepositoryProvider).fetchTrends();
});

final weeklySummaryProvider = FutureProvider<WeeklySummaryData>((ref) {
  return ref.watch(analyticsRepositoryProvider).fetchWeeklySummary();
});

class AnalyticsRepository {
  AnalyticsRepository(this._dio);

  final Dio _dio;

  Future<DashboardAnalyticsData> fetchDashboard() async {
    final response = await _dio.get('/api/v1/analytics/dashboard');
    final json = Map<String, dynamic>.from(response.data as Map);
    final categoryBreakdown = _listFromJson(json['categoryBreakdown']);

    return DashboardAnalyticsData(
      todayTotalMinutes: (json['todayTotalMinutes'] as num?)?.toInt() ?? 0,
      categoryBreakdown: [
        for (var index = 0; index < categoryBreakdown.length; index++)
          UsageData(
            name: categoryBreakdown[index]['name'] as String? ?? 'Other',
            minutes:
                (categoryBreakdown[index]['minutes'] as num?)?.toInt() ?? 0,
            color: _colorForCategory(
              categoryBreakdown[index]['name'] as String? ?? 'Other',
              index,
            ),
          ),
      ],
      weeklyUsageHours: _listFromJson(json['weeklyUsageHours'])
          .map((item) => (item['value'] as num).toDouble())
          .toList(),
      deltaFromYesterdayPercent:
          (json['deltaFromYesterdayPercent'] as num?)?.toInt() ?? 0,
    );
  }

  Future<TrendsAnalyticsData> fetchTrends() async {
    final response = await _dio.get('/api/v1/analytics/trends');
    final json = Map<String, dynamic>.from(response.data as Map);

    return TrendsAnalyticsData(
      hourlyUsage: _listFromJson(json['hourlyUsage'])
          .map(
            (item) => HourlyUsage(
              hour: item['hour'] as String? ?? '',
              minutes: (item['minutes'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      weeklyUsage: _listFromJson(json['weeklyUsage'])
          .map(
            (item) => DailyUsage(
              day: item['day'] as String? ?? '',
              hours: (item['hours'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      topApps: _listFromJson(json['topApps'])
          .map(
            (item) => TopAppUsage(
              appId: item['appId'] as String? ?? '',
              appName: item['appName'] as String? ?? 'Unknown App',
              minutes: (item['minutes'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      peakUsageWindow: json['peakUsageWindow'] as String? ?? '',
    );
  }

  Future<WeeklySummaryData> fetchWeeklySummary() async {
    final response = await _dio.get('/api/v1/analytics/weekly-summary');
    final json = Map<String, dynamic>.from(response.data as Map);

    return WeeklySummaryData(
      screenTimeReductionPercent:
          (json['screenTimeReductionPercent'] as num?)?.toInt() ?? 0,
      totalWeekHours: (json['totalWeekHours'] as num?)?.toDouble() ?? 0,
      dailyAverageHours: (json['dailyAverageHours'] as num?)?.toDouble() ?? 0,
      goalsMetDays: (json['goalsMetDays'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longestStreakDays'] as num?)?.toInt() ?? 0,
    );
  }
}

List<Map<String, dynamic>> _listFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{'value': item};
      })
      .toList();
}

const _categoryPalette = <Color>[
  AppColors.chart1,
  AppColors.chart2,
  AppColors.chart3,
  AppColors.chart4,
];

Color _colorForCategory(String category, int index) {
  switch (category.toLowerCase()) {
    case 'social':
      return AppColors.instagram;
    case 'entertainment':
      return AppColors.youtube;
    case 'productivity':
      return AppColors.info;
    case 'other':
      return AppColors.chart4;
    default:
      return _categoryPalette[index % _categoryPalette.length];
  }
}
