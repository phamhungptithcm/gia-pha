import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_logger.dart';
import '../../auth/models/auth_session.dart';
import '../models/onboarding_models.dart';
import '../services/onboarding_analytics_service.dart';
import '../services/onboarding_catalog_repository.dart';
import '../services/onboarding_state_repository.dart';

class OnboardingCoordinator extends ChangeNotifier {
  OnboardingCoordinator({
    required AuthSession session,
    required OnboardingStateRepository stateRepository,
    required OnboardingCatalogRepository catalogRepository,
    required OnboardingAnalyticsService analyticsService,
  }) : _session = session,
       _stateRepository = stateRepository,
       _catalogRepository = catalogRepository,
       _analyticsService = analyticsService;

  final OnboardingStateRepository _stateRepository;
  final OnboardingCatalogRepository _catalogRepository;
  final OnboardingAnalyticsService _analyticsService;
  final Map<String, GlobalKey> _anchorKeys = <String, GlobalKey>{};

  AuthSession _session;
  Timer? _scheduledTrigger;
  bool _isResolving = false;
  bool _disposed = false;
  bool _isActionInFlight = false;
  OnboardingFlow? _activeFlow;
  OnboardingFlowProgress? _activeProgress;
  String? _activeRouteId;
  int _currentStepIndex = 0;

  AuthSession get session => _session;
  OnboardingFlow? get activeFlow => _activeFlow;
  OnboardingFlowProgress? get activeProgress => _activeProgress;
  int get currentStepIndex => _currentStepIndex;
  int get stepCount => _activeFlow?.steps.length ?? 0;
  bool get isVisible => _activeFlow != null && currentStep != null;
  bool get isActionInFlight => _isActionInFlight;

  OnboardingStep? get currentStep {
    final flow = _activeFlow;
    if (flow == null || flow.steps.isEmpty) {
      return null;
    }
    if (_currentStepIndex < 0 || _currentStepIndex >= flow.steps.length) {
      return null;
    }
    return flow.steps[_currentStepIndex];
  }

  void updateSession(AuthSession session) {
    _session = session;
  }

  void registerAnchor(String anchorId, GlobalKey key) {
    _anchorKeys[anchorId] = key;
  }

  void unregisterAnchor(String anchorId, GlobalKey key) {
    final current = _anchorKeys[anchorId];
    if (current == key) {
      _anchorKeys.remove(anchorId);
    }
  }

  Rect? rectForAnchor(String anchorId) {
    final key = _anchorKeys[anchorId];
    final context = key?.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & size;
  }

  Future<void> scheduleTrigger(
    OnboardingTrigger trigger, {
    Duration delay = const Duration(milliseconds: 1600),
  }) async {
    _scheduledTrigger?.cancel();
    _scheduledTrigger = Timer(delay, () {
      unawaited(handleTrigger(trigger));
    });
  }

  Future<void> handleTrigger(OnboardingTrigger trigger) async {
    if (_disposed || _isResolving || _activeFlow != null) {
      return;
    }

    _isResolving = true;
    try {
      final catalog = await _catalogRepository.load(
        session: _session,
        trigger: trigger,
      );
      if (catalog.flows.isEmpty) {
        return;
      }
      final state = await _stateRepository.load(session: _session);
      final flow = _selectFlow(catalog.flows, state);
      if (flow == null) {
        return;
      }

      final progress = _baselineProgress(flow, state.progressFor(flow.id));
      final startStepIndex = _resolveStartStepIndex(flow, progress);
      final anchorReady = await _waitForAnchor(
        flow.steps[startStepIndex].anchorId,
      );
      if (!anchorReady) {
        await _analyticsService.logAnchorMissing(
          flow: flow,
          step: flow.steps[startStepIndex],
          stepIndex: startStepIndex,
          routeId: trigger.routeId,
        );
        return;
      }

      final now = DateTime.now();
      final nextProgress = progress.copyWith(
        version: flow.version,
        status: OnboardingFlowStatus.inProgress,
        currentStepIndex: startStepIndex,
        displayCount: progress.displayCount + 1,
        lastStartedAt: now,
        updatedAt: now,
        clearCooldownUntil: true,
        resumeExpiresAt: now.add(flow.resumeTtl),
      );
      _activeFlow = flow;
      _activeProgress = nextProgress;
      _activeRouteId = trigger.routeId;
      _currentStepIndex = startStepIndex;
      notifyListeners();
      await _stateRepository.saveProgress(
        session: _session,
        progress: nextProgress,
      );
      await _analyticsService.logStarted(
        flow: flow,
        step: flow.steps[startStepIndex],
        stepIndex: startStepIndex,
        routeId: trigger.routeId,
      );
      await _analyticsService.logStepViewed(
        flow: flow,
        step: flow.steps[startStepIndex],
        stepIndex: startStepIndex,
        routeId: trigger.routeId,
      );
    } finally {
      _isResolving = false;
    }
  }

  Future<void> next() async {
    await _runAction(() async {
      final flow = _activeFlow;
      final progress = _activeProgress;
      final routeId = _activeRouteId;
      if (flow == null || progress == null || routeId == null) {
        return;
      }
      final nextIndex = _currentStepIndex + 1;
      if (nextIndex >= flow.steps.length) {
        await _completeActiveFlow(
          flow: flow,
          progress: progress,
          routeId: routeId,
        );
        return;
      }

      final anchorReady = await _waitForAnchor(flow.steps[nextIndex].anchorId);
      if (!anchorReady) {
        await _analyticsService.logAnchorMissing(
          flow: flow,
          step: flow.steps[nextIndex],
          stepIndex: nextIndex,
          routeId: routeId,
        );
        return;
      }

      final now = DateTime.now();
      final nextProgress = progress.copyWith(
        status: OnboardingFlowStatus.inProgress,
        currentStepIndex: nextIndex,
        resumeExpiresAt: now.add(flow.resumeTtl),
        updatedAt: now,
      );
      _activeProgress = nextProgress;
      _currentStepIndex = nextIndex;
      notifyListeners();
      await _stateRepository.saveProgress(
        session: _session,
        progress: nextProgress,
      );
      await _analyticsService.logStepViewed(
        flow: flow,
        step: flow.steps[nextIndex],
        stepIndex: nextIndex,
        routeId: routeId,
      );
    });
  }

  Future<void> back() async {
    await _runAction(() async {
      final flow = _activeFlow;
      final progress = _activeProgress;
      final routeId = _activeRouteId;
      if (flow == null ||
          progress == null ||
          routeId == null ||
          _currentStepIndex <= 0) {
        return;
      }
      final previousIndex = _currentStepIndex - 1;
      final anchorReady = await _waitForAnchor(
        flow.steps[previousIndex].anchorId,
      );
      if (!anchorReady) {
        return;
      }
      final now = DateTime.now();
      final nextProgress = progress.copyWith(
        status: OnboardingFlowStatus.inProgress,
        currentStepIndex: previousIndex,
        resumeExpiresAt: now.add(flow.resumeTtl),
        updatedAt: now,
      );
      _activeProgress = nextProgress;
      _currentStepIndex = previousIndex;
      notifyListeners();
      await _stateRepository.saveProgress(
        session: _session,
        progress: nextProgress,
      );
      await _analyticsService.logStepViewed(
        flow: flow,
        step: flow.steps[previousIndex],
        stepIndex: previousIndex,
        routeId: routeId,
      );
    });
  }

  Future<void> skip() async {
    await _runAction(() async {
      final flow = _activeFlow;
      final progress = _activeProgress;
      final step = currentStep;
      final routeId = _activeRouteId;
      if (flow == null || progress == null || step == null || routeId == null) {
        return;
      }
      final now = DateTime.now();
      final nextProgress = progress.copyWith(
        status: OnboardingFlowStatus.skipped,
        currentStepIndex: _currentStepIndex,
        lastSkippedAt: now,
        cooldownUntil: now.add(flow.cooldown),
        updatedAt: now,
        clearResumeExpiresAt: true,
      );
      _clearPresentation();
      await _stateRepository.saveProgress(
        session: _session,
        progress: nextProgress,
      );
      await _analyticsService.logSkipped(
        flow: flow,
        step: step,
        stepIndex: _currentStepIndex,
        routeId: routeId,
      );
    });
  }

  Future<void> complete() async {
    await _runAction(() async {
      final flow = _activeFlow;
      final progress = _activeProgress;
      final routeId = _activeRouteId;
      if (flow == null || progress == null || routeId == null) {
        return;
      }
      await _completeActiveFlow(
        flow: flow,
        progress: progress,
        routeId: routeId,
      );
    });
  }

  Future<void> interrupt() async {
    _scheduledTrigger?.cancel();
    final flow = _activeFlow;
    final progress = _activeProgress;
    final step = currentStep;
    final routeId = _activeRouteId;
    if (flow == null || progress == null || step == null || routeId == null) {
      return;
    }
    final now = DateTime.now();
    final nextProgress = progress.copyWith(
      status: OnboardingFlowStatus.interrupted,
      currentStepIndex: _currentStepIndex,
      resumeExpiresAt: now.add(flow.resumeTtl),
      updatedAt: now,
    );
    await _stateRepository.saveProgress(
      session: _session,
      progress: nextProgress,
    );
    await _analyticsService.logInterrupted(
      flow: flow,
      step: step,
      stepIndex: _currentStepIndex,
      routeId: routeId,
    );
    _clearPresentation(notify: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _scheduledTrigger?.cancel();
    super.dispose();
  }

  OnboardingFlow? _selectFlow(
    List<OnboardingFlow> candidates,
    OnboardingUserState state,
  ) {
    for (final flow in candidates) {
      final progress = state.progressFor(flow.id);
      if (_isFlowEligible(flow, progress)) {
        return flow;
      }
    }
    return null;
  }

  bool _isFlowEligible(OnboardingFlow flow, OnboardingFlowProgress? progress) {
    if (!flow.enabled || flow.steps.isEmpty) {
      return false;
    }
    if (progress == null || progress.version != flow.version) {
      return true;
    }
    if (progress.status == OnboardingFlowStatus.skipped) {
      return false;
    }
    if (progress.canResume) {
      return true;
    }
    if (progress.status == OnboardingFlowStatus.completed) {
      return false;
    }
    if (progress.hasActiveCooldown) {
      return false;
    }
    if (flow.maxDisplays > 0 && progress.displayCount >= flow.maxDisplays) {
      return false;
    }
    return true;
  }

  OnboardingFlowProgress _baselineProgress(
    OnboardingFlow flow,
    OnboardingFlowProgress? progress,
  ) {
    if (progress == null || progress.version != flow.version) {
      return OnboardingFlowProgress(flowId: flow.id, version: flow.version);
    }
    return progress;
  }

  int _resolveStartStepIndex(
    OnboardingFlow flow,
    OnboardingFlowProgress progress,
  ) {
    if (!progress.canResume) {
      return 0;
    }
    return progress.currentStepIndex.clamp(0, flow.steps.length - 1).toInt();
  }

  Future<bool> _waitForAnchor(String anchorId) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 1500));
    while (DateTime.now().isBefore(deadline)) {
      final rect = rectForAnchor(anchorId);
      if (rect != null && rect.width > 0 && rect.height > 0) {
        return true;
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    final rect = rectForAnchor(anchorId);
    return rect != null && rect.width > 0 && rect.height > 0;
  }

  Future<void> _completeActiveFlow({
    required OnboardingFlow flow,
    required OnboardingFlowProgress progress,
    required String routeId,
  }) async {
    final now = DateTime.now();
    final nextProgress = progress.copyWith(
      status: OnboardingFlowStatus.completed,
      currentStepIndex: flow.steps.length - 1,
      lastCompletedAt: now,
      updatedAt: now,
      clearCooldownUntil: true,
      clearResumeExpiresAt: true,
    );
    _clearPresentation();
    await _stateRepository.saveProgress(
      session: _session,
      progress: nextProgress,
    );
    await _analyticsService.logCompleted(flow: flow, routeId: routeId);
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isActionInFlight || _disposed) {
      return;
    }
    _isActionInFlight = true;
    if (!_disposed) {
      notifyListeners();
    }
    try {
      await action();
    } finally {
      _isActionInFlight = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _clearPresentation({bool notify = true}) {
    _activeFlow = null;
    _activeProgress = null;
    _activeRouteId = null;
    _currentStepIndex = 0;
    if (notify && !_disposed) {
      notifyListeners();
    }
  }
}

bool _hasLoggedDisabledDefaultOnboarding = false;

bool _canUseFirebaseBackedOnboarding() {
  try {
    Firebase.app();
    return true;
  } catch (_) {
    return false;
  }
}

OnboardingCoordinator createDefaultOnboardingCoordinator({
  required AuthSession session,
}) {
  final useFirebaseBackedServices = _canUseFirebaseBackedOnboarding();
  if (!useFirebaseBackedServices && !_hasLoggedDisabledDefaultOnboarding) {
    _hasLoggedDisabledDefaultOnboarding = true;
    AppLogger.warning(
      'Onboarding default services are disabled because Firebase has not been bootstrapped yet.',
    );
  }

  return OnboardingCoordinator(
    session: session,
    stateRepository: useFirebaseBackedServices
        ? createDefaultOnboardingStateRepository()
        : InMemoryOnboardingStateRepository(),
    catalogRepository: useFirebaseBackedServices
        ? createDefaultOnboardingCatalogRepository()
        : const DisabledOnboardingCatalogRepository(),
    analyticsService: useFirebaseBackedServices
        ? createDefaultOnboardingAnalyticsService()
        : const NoopOnboardingAnalyticsService(),
  );
}

OnboardingCoordinator createDisabledOnboardingCoordinator({
  required AuthSession session,
}) {
  return OnboardingCoordinator(
    session: session,
    stateRepository: InMemoryOnboardingStateRepository(),
    catalogRepository: const DisabledOnboardingCatalogRepository(),
    analyticsService: const NoopOnboardingAnalyticsService(),
  );
}
