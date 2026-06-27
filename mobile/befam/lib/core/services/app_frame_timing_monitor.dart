import 'dart:async';

import 'package:flutter/scheduler.dart';

import 'performance_measurement_logger.dart';

class AppFrameTimingMonitor {
  AppFrameTimingMonitor({
    PerformanceMeasurementLogger? performanceLogger,
    this.batchSize = 90,
    this.jankThreshold = const Duration(milliseconds: 16),
  }) : _performanceLogger =
           performanceLogger ??
           PerformanceMeasurementLogger(
             defaultSlowThreshold: const Duration(milliseconds: 16),
           );

  final PerformanceMeasurementLogger _performanceLogger;
  final int batchSize;
  final Duration jankThreshold;
  final List<Duration> _frameTotals = <Duration>[];
  final List<Duration> _buildDurations = <Duration>[];
  final List<Duration> _rasterDurations = <Duration>[];
  bool _isStarted = false;

  void start() {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    SchedulerBinding.instance.addTimingsCallback(_handleTimings);
  }

  void stop() {
    if (!_isStarted) {
      return;
    }
    SchedulerBinding.instance.removeTimingsCallback(_handleTimings);
    _isStarted = false;
    _flush();
  }

  void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameTotals.add(timing.totalSpan);
      _buildDurations.add(timing.buildDuration);
      _rasterDurations.add(timing.rasterDuration);
    }

    if (_frameTotals.length >= batchSize) {
      _flush();
    }
  }

  void _flush() {
    if (_frameTotals.isEmpty) {
      return;
    }

    final p95Frame = _percentile(_frameTotals, 0.95);
    final p95Build = _percentile(_buildDurations, 0.95);
    final p95Raster = _percentile(_rasterDurations, 0.95);
    final jankyFrames = _frameTotals
        .where((duration) => duration > jankThreshold)
        .length;

    unawaited(
      _performanceLogger.recordDuration(
        metric: 'frames.batch_p95',
        elapsed: p95Frame,
        warnAfter: jankThreshold,
        dimensions: {
          'frames': _frameTotals.length,
          'janky_frames': jankyFrames,
          'p95_build_ms': p95Build.inMilliseconds,
          'p95_raster_ms': p95Raster.inMilliseconds,
        },
      ),
    );

    _frameTotals.clear();
    _buildDurations.clear();
    _rasterDurations.clear();
  }

  Duration _percentile(List<Duration> values, double percentile) {
    if (values.isEmpty) {
      return Duration.zero;
    }
    final sorted = values.map((value) => value.inMicroseconds).toList()..sort();
    final index = ((sorted.length - 1) * percentile).ceil();
    final clampedIndex = index.clamp(0, sorted.length - 1).toInt();
    return Duration(microseconds: sorted[clampedIndex]);
  }
}
