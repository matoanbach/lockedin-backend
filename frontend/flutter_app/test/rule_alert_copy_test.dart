import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/enforcement/data/rule_alert_provider.dart';
import 'package:lockdin_app/features/rules/data/rules_provider.dart';
import 'package:lockdin_app/shared/models/models.dart';

void main() {
  test('approaching warning uses singular copy for every tone', () {
    final status = _status(
      status: 'approaching_limit',
      usedMinutes: 4,
      remainingMinutes: 1,
    );

    expect(
      ruleAlertMessageFor(status, NotificationTone.fun),
      "Heads up: only 1 minute left before Messages hits today's limit.",
    );
    expect(
      ruleAlertMessageFor(status, NotificationTone.edgy),
      '1 minute left. Messages is almost out of runway.',
    );
    expect(
      ruleAlertMessageFor(status, NotificationTone.professional),
      "1 minute remains before you hit today's 5-minute limit for Messages.",
    );
  });

  test('approaching warning retains plural agreement', () {
    final status = _status(
      status: 'approaching_limit',
      usedMinutes: 3,
      remainingMinutes: 2,
    );

    expect(
      ruleAlertMessageFor(status, NotificationTone.fun),
      "Heads up: only 2 minutes left before Messages hits today's limit.",
    );
    expect(
      ruleAlertMessageFor(status, NotificationTone.edgy),
      '2 minutes left. Messages is almost out of runway.',
    );
    expect(
      ruleAlertMessageFor(status, NotificationTone.professional),
      "2 minutes remain before you hit today's 5-minute limit for Messages.",
    );
  });

  test('approaching warning describes a positive sub-minute remainder', () {
    final status = _status(
      status: 'approaching_limit',
      usedMinutes: 4,
      remainingMinutes: 0,
      usedMilliseconds: 299900,
      remainingMilliseconds: 100,
    );

    expect(
      ruleAlertMessageFor(status, NotificationTone.professional),
      "less than 1 minute remains before you hit today's 5-minute limit for Messages.",
    );
  });

  test('limit and over-limit copy handles a one-minute count', () {
    final atLimit = _status(
      status: 'at_limit',
      usedMinutes: 1,
      remainingMinutes: 0,
      limitMinutes: 1,
    );
    final overLimit = _status(
      status: 'over_limit',
      usedMinutes: 1,
      remainingMinutes: 0,
      limitMinutes: 1,
    );

    for (final tone in NotificationTone.values) {
      expect(ruleAlertMessageFor(atLimit, tone), isNot(contains('1 minutes')));
      expect(
        ruleAlertMessageFor(overLimit, tone),
        isNot(contains('1 minutes')),
      );
      expect(ruleAlertMessageFor(overLimit, tone), contains('1-minute'));
    }
  });
}

RuleStatusData _status({
  required String status,
  required int usedMinutes,
  required int remainingMinutes,
  int limitMinutes = 5,
  int? usedMilliseconds,
  int? remainingMilliseconds,
}) {
  return RuleStatusData(
    ruleId: 'messages-rule',
    appId: 'com.google.android.apps.messaging',
    appName: 'Messages',
    usageDate: '2026-07-26',
    enabled: true,
    limitMinutes: limitMinutes,
    usedMinutes: usedMinutes,
    remainingMinutes: remainingMinutes,
    usedMilliseconds: usedMilliseconds ?? usedMinutes * 60000,
    remainingMilliseconds: remainingMilliseconds ?? remainingMinutes * 60000,
    progressPercent: 80,
    status: status,
    isBlockedNow: status == 'over_limit',
  );
}
