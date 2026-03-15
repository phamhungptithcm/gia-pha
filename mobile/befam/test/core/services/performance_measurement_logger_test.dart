import 'package:befam/core/services/performance_measurement_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logDuration emits info when below threshold', () {
    final infoLogs = <String>[];
    final warningLogs = <String>[];

    final logger = PerformanceMeasurementLogger(
      defaultSlowThreshold: const Duration(milliseconds: 100),
      infoLogger: infoLogs.add,
      warningLogger: warningLogs.add,
    );

    logger.logDuration(
      metric: 'member_search.query',
      elapsed: const Duration(milliseconds: 40),
      dimensions: const {'status': 'success', 'query_length': 3},
    );

    expect(infoLogs, hasLength(1));
    expect(infoLogs.single, contains('perf.member_search.query'));
    expect(infoLogs.single, contains('elapsed_ms=40'));
    expect(warningLogs, isEmpty);
  });

  test('logDuration emits warning when threshold is met', () {
    final infoLogs = <String>[];
    final warningLogs = <String>[];

    final logger = PerformanceMeasurementLogger(
      defaultSlowThreshold: const Duration(milliseconds: 100),
      infoLogger: infoLogs.add,
      warningLogger: warningLogs.add,
    );

    logger.logDuration(
      metric: 'genealogy.tree_scene_build',
      elapsed: const Duration(milliseconds: 120),
      dimensions: const {'nodes': 120},
    );

    expect(infoLogs, isEmpty);
    expect(warningLogs, hasLength(1));
    expect(warningLogs.single, contains('perf.genealogy.tree_scene_build'));
    expect(warningLogs.single, contains('threshold_ms=100'));
  });

  test('measureAsync returns action result and logs timing', () async {
    final infoLogs = <String>[];

    final logger = PerformanceMeasurementLogger(
      defaultSlowThreshold: const Duration(seconds: 1),
      infoLogger: infoLogs.add,
      warningLogger: (_) {},
    );

    final value = await logger.measureAsync<int>(
      metric: 'bootstrap.firebase_initialize',
      action: () async => 7,
      dimensions: const {'release_mode': 0},
    );

    expect(value, 7);
    expect(infoLogs, hasLength(1));
    expect(infoLogs.single, contains('perf.bootstrap.firebase_initialize'));
    expect(infoLogs.single, contains('release_mode=0'));
  });
}
