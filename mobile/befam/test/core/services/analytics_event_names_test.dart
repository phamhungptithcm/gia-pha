import 'package:befam/core/services/analytics_event_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics event names stay unique and snake_case', () {
    final values = AnalyticsEventNames.values;
    final unique = values.toSet();

    expect(unique.length, values.length);

    const snakeCasePattern = r'^[a-z]+[a-z0-9_]*$';
    final regex = RegExp(snakeCasePattern);
    for (final value in values) {
      expect(regex.hasMatch(value), isTrue);
    }
  });

  test('analytics user property names stay unique and snake_case', () {
    final values = AnalyticsUserPropertyNames.values;
    final unique = values.toSet();

    expect(unique.length, values.length);

    const snakeCasePattern = r'^[a-z]+[a-z0-9_]*$';
    final regex = RegExp(snakeCasePattern);
    for (final value in values) {
      expect(regex.hasMatch(value), isTrue);
    }
  });
}
