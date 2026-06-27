import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';

import 'app_logger.dart';

abstract class PerformanceTraceReporter {
  Future<void> recordDuration({
    required String metric,
    required Duration elapsed,
    Map<String, Object?> dimensions,
  });
}

class FirebasePerformanceTraceReporter implements PerformanceTraceReporter {
  const FirebasePerformanceTraceReporter();

  static const instance = FirebasePerformanceTraceReporter();

  @override
  Future<void> recordDuration({
    required String metric,
    required Duration elapsed,
    Map<String, Object?> dimensions = const {},
  }) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    try {
      final trace = FirebasePerformance.instance.newTrace(
        _traceNameFor(metric),
      );
      await trace.start();
      trace.setMetric('elapsed_ms', elapsed.inMilliseconds);
      for (final entry in _safeAttributes(dimensions).entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      await trace.stop();
    } catch (error) {
      final message = error.toString();
      if (message.contains('Unable to establish connection on channel')) {
        return;
      }
      AppLogger.warning('Firebase performance trace failed.', error);
    }
  }

  String _traceNameFor(String metric) {
    final normalized = metric
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final name = 'befam_${normalized.isEmpty ? 'metric' : normalized}';
    return name.length <= 100 ? name : name.substring(0, 100);
  }

  Map<String, String> _safeAttributes(Map<String, Object?> dimensions) {
    final attributes = <String, String>{};
    for (final entry in dimensions.entries) {
      if (entry.value == null) {
        continue;
      }
      if (attributes.length >= 5) {
        break;
      }
      final key = entry.key
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value.toString().trim();
      if (value.isEmpty) {
        continue;
      }
      attributes[key.length <= 40 ? key : key.substring(0, 40)] =
          value.length <= 100 ? value : value.substring(0, 100);
    }
    return attributes;
  }
}
