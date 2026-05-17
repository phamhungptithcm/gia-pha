import 'package:befam/core/services/performance_measurement_logger.dart';
import 'package:befam/core/services/performance_trace_reporter.dart';
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
      traceReporter: const _NoopTraceReporter(),
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

  test('recordDuration forwards safe metrics to trace reporter', () async {
    final reporter = _FakeTraceReporter();
    final logger = PerformanceMeasurementLogger(
      defaultSlowThreshold: const Duration(seconds: 1),
      infoLogger: (_) {},
      warningLogger: (_) {},
      traceReporter: reporter,
    );

    await logger.recordDuration(
      metric: 'workspace.refresh',
      elapsed: const Duration(milliseconds: 88),
      dimensions: const {'surface': 'genealogy', 'members': 42},
    );

    expect(reporter.records, hasLength(1));
    expect(reporter.records.single.metric, 'workspace.refresh');
    expect(reporter.records.single.elapsed.inMilliseconds, 88);
    expect(reporter.records.single.dimensions['surface'], 'genealogy');
  });
}

class _NoopTraceReporter implements PerformanceTraceReporter {
  const _NoopTraceReporter();

  @override
  Future<void> recordDuration({
    required String metric,
    required Duration elapsed,
    Map<String, Object?> dimensions = const {},
  }) async {}
}

class _FakeTraceReporter implements PerformanceTraceReporter {
  final records = <_TraceRecord>[];

  @override
  Future<void> recordDuration({
    required String metric,
    required Duration elapsed,
    Map<String, Object?> dimensions = const {},
  }) async {
    records.add(
      _TraceRecord(metric: metric, elapsed: elapsed, dimensions: dimensions),
    );
  }
}

class _TraceRecord {
  const _TraceRecord({
    required this.metric,
    required this.elapsed,
    required this.dimensions,
  });

  final String metric;
  final Duration elapsed;
  final Map<String, Object?> dimensions;
}
