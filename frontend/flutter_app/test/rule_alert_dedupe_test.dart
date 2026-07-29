import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/features/enforcement/data/rule_alert_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reload observes warning markers written after Dart cached preferences',
    () async {
      const dedupeKey =
          'rule_alert.messages-rule.2026-07-28.warning_limit_reached';
      SharedPreferences.setMockInitialValues({});
      final cachedPreferences = await SharedPreferences.getInstance();
      final dedupePreferences = RuleAlertDedupePreferences(cachedPreferences);

      expect(dedupePreferences.wasIssued(dedupeKey), isFalse);

      SharedPreferences.setMockInitialValues({dedupeKey: true});
      expect(dedupePreferences.wasIssued(dedupeKey), isFalse);

      await dedupePreferences.reload();

      expect(dedupePreferences.wasIssued(dedupeKey), isTrue);
    },
  );
}
