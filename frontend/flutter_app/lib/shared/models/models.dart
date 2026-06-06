import 'package:flutter/material.dart';

/// Usage data model for app tracking.
class UsageData {
  final String name;
  final int minutes;
  final Color color;

  const UsageData({
    required this.name,
    required this.minutes,
    required this.color,
  });

  String get formattedTime {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins > 0 ? '${mins}m' : ''}';
    }
    return '${mins}m';
  }
}

/// Lockdown rule model.
class LockdownRule {
  final String id;
  final String appName;
  final IconData icon;
  final int limitMinutes;
  final bool enabled;
  final Color color;

  const LockdownRule({
    required this.id,
    required this.appName,
    required this.icon,
    required this.limitMinutes,
    required this.enabled,
    required this.color,
  });

  LockdownRule copyWith({
    String? id,
    String? appName,
    IconData? icon,
    int? limitMinutes,
    bool? enabled,
    Color? color,
  }) {
    return LockdownRule(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      icon: icon ?? this.icon,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      enabled: enabled ?? this.enabled,
      color: color ?? this.color,
    );
  }

  String get formattedLimit {
    final hours = limitMinutes ~/ 60;
    final mins = limitMinutes % 60;
    return '${hours}h ${mins > 0 ? '${mins}m' : ''}';
  }
}

/// Accountability partner model.
class AccountabilityPartner {
  final String id;
  final String name;
  final String email;

  const AccountabilityPartner({
    required this.id,
    required this.name,
    required this.email,
  });
}

/// Hourly usage data for charts.
class HourlyUsage {
  final String hour;
  final int minutes;

  const HourlyUsage({
    required this.hour,
    required this.minutes,
  });
}

/// Daily usage data for charts.
class DailyUsage {
  final String day;
  final double hours;

  const DailyUsage({
    required this.day,
    required this.hours,
  });
}

/// Notification tone options.
enum NotificationTone {
  fun,
  edgy,
  professional,
}

extension NotificationToneExtension on NotificationTone {
  String get displayName => switch (this) {
        NotificationTone.fun => 'Fun',
        NotificationTone.edgy => 'Edgy',
        NotificationTone.professional => 'Professional',
      };

  String get description => switch (this) {
        NotificationTone.fun => '🎉 Playful and encouraging messages',
        NotificationTone.edgy => '⚡ Direct and bold reminders',
        NotificationTone.professional => '💼 Polite and formal notifications',
      };

  String get example => switch (this) {
        NotificationTone.fun => '"Woah there! Time to take a break!"',
        NotificationTone.edgy => '"Stop scrolling. Seriously."',
        NotificationTone.professional => '"You\'ve reached your daily limit."',
      };
}
