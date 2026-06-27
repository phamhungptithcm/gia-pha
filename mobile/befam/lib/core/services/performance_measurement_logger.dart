import 'dart:async';

import 'app_logger.dart';
import 'performance_trace_reporter.dart';

typedef PerformanceLogWriter = void Function(String message);

class PerformanceMeasurementLogger {
  PerformanceMeasurementLogger({
    this.defaultSlowThreshold = const Duration(milliseconds: 120),
    PerformanceLogWriter? infoLogger,
    PerformanceLogWriter? warningLogger,
    PerformanceTraceReporter? traceReporter,
  }) : _infoLogger = infoLogger ?? AppLogger.info,
       _warningLogger = warningLogger ?? AppLogger.warning,
       _traceReporter =
           traceReporter ?? FirebasePerformanceTraceReporter.instance;

  final Duration defaultSlowThreshold;
  final PerformanceLogWriter _infoLogger;
  final PerformanceLogWriter _warningLogger;
  final PerformanceTraceReporter? _traceReporter;

  Future<T> measureAsync<T>({
    required String metric,
    required Future<T> Function() action,
    Duration? warnAfter,
    Map<String, Object?> dimensions = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      unawaited(
        recordDuration(
          metric: metric,
          elapsed: stopwatch.elapsed,
          warnAfter: warnAfter,
          dimensions: dimensions,
        ),
      );
    }
  }

  T measureSync<T>({
    required String metric,
    required T Function() action,
    Duration? warnAfter,
    Map<String, Object?> dimensions = const {},
  }) {
    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      unawaited(
        recordDuration(
          metric: metric,
          elapsed: stopwatch.elapsed,
          warnAfter: warnAfter,
          dimensions: dimensions,
        ),
      );
    }
  }

  void logDuration({
    required String metric,
    required Duration elapsed,
    Duration? warnAfter,
    Map<String, Object?> dimensions = const {},
  }) {
    final threshold = warnAfter ?? defaultSlowThreshold;
    final payload = <String, Object?>{'elapsed_ms': elapsed.inMilliseconds};
    payload.addAll(dimensions);

    final suffix = _formatDimensions(payload);
    final message = 'perf.$metric${suffix.isEmpty ? '' : ' $suffix'}';

    if (elapsed >= threshold) {
      _warningLogger('$message threshold_ms=${threshold.inMilliseconds}');
      return;
    }

    _infoLogger(message);
  }

  Future<void> recordDuration({
    required String metric,
    required Duration elapsed,
    Duration? warnAfter,
    Map<String, Object?> dimensions = const {},
  }) async {
    logDuration(
      metric: metric,
      elapsed: elapsed,
      warnAfter: warnAfter,
      dimensions: dimensions,
    );
    await _traceReporter?.recordDuration(
      metric: metric,
      elapsed: elapsed,
      dimensions: dimensions,
    );
  }

  String _formatDimensions(Map<String, Object?> dimensions) {
    final entries =
        dimensions.entries
            .where((entry) => entry.value != null)
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));

    if (entries.isEmpty) {
      return '';
    }

    return entries
        .map((entry) => '${entry.key}=${_normalizeValue(entry.value!)}')
        .join(' ');
  }

  Object _normalizeValue(Object value) {
    if (value is String) {
      return value.trim().replaceAll(RegExp(r'\s+'), '_');
    }
    return value;
  }
}
