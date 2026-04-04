import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/onboarding/models/onboarding_models.dart';
import 'package:befam/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:befam/features/onboarding/presentation/onboarding_scope.dart';
import 'package:befam/features/onboarding/services/onboarding_analytics_service.dart';
import 'package:befam/features/onboarding/services/onboarding_catalog_repository.dart';
import 'package:befam/features/onboarding/services/onboarding_remote_config_service.dart';
import 'package:befam/features/onboarding/services/onboarding_state_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'uid-onboarding-test',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901112222',
      displayName: 'Tester',
      memberId: 'member-1',
      clanId: 'clan-1',
      branchId: 'branch-1',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 2).toIso8601String(),
    );
  }

  const flow = OnboardingFlow(
    id: 'test-flow',
    triggerId: 'test-trigger',
    version: 1,
    steps: <OnboardingStep>[
      OnboardingStep(
        id: 'step-1',
        anchorId: 'anchor.one',
        title: OnboardingLocalizedText(vi: 'Bước đầu tiên', en: 'First step'),
        body: OnboardingLocalizedText(
          vi: 'Giải thích đầu tiên',
          en: 'First explanation',
        ),
      ),
      OnboardingStep(
        id: 'step-2',
        anchorId: 'anchor.two',
        title: OnboardingLocalizedText(vi: 'Bước thứ hai', en: 'Second step'),
        body: OnboardingLocalizedText(
          vi: 'Giải thích thứ hai',
          en: 'Second explanation',
        ),
      ),
    ],
  );

  const bottomAnchoredFlow = OnboardingFlow(
    id: 'bottom-flow',
    triggerId: 'bottom-trigger',
    version: 1,
    steps: <OnboardingStep>[
      OnboardingStep(
        id: 'bottom-step',
        anchorId: 'anchor.bottom',
        title: OnboardingLocalizedText(
          vi: 'Bước cuối ở đáy màn hình',
          en: 'Bottom edge step',
        ),
        body: OnboardingLocalizedText(
          vi: 'Tooltip phải tự đổi vị trí để nút Xong luôn bấm được.',
          en: 'The tooltip should reposition so Done always stays tappable.',
        ),
        placement: OnboardingTooltipPlacement.below,
      ),
    ],
  );

  Future<void> pumpHarness(
    WidgetTester tester, {
    required OnboardingCoordinator coordinator,
    Widget? body,
    Size surfaceSize = const Size(390, 844),
  }) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(
      surfaceSize.width * dpr,
      surfaceSize.height * dpr,
    );
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: OnboardingScope(
          controller: coordinator,
          child: Scaffold(
            body:
                body ??
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      OnboardingAnchor(
                        anchorId: 'anchor.one',
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Anchor one'),
                        ),
                      ),
                      const SizedBox(height: 220),
                      OnboardingAnchor(
                        anchorId: 'anchor.two',
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Anchor two'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders onboarding tooltip and completes the flow', (
    tester,
  ) async {
    final stateRepository = _MemoryOnboardingStateRepository();
    final analytics = _RecordingOnboardingAnalyticsService();
    final coordinator = OnboardingCoordinator(
      session: buildSession(),
      stateRepository: stateRepository,
      catalogRepository: _StaticCatalogRepository(
        flows: const <OnboardingFlow>[flow],
      ),
      analyticsService: analytics,
    );

    await pumpHarness(tester, coordinator: coordinator);

    await coordinator.handleTrigger(
      const OnboardingTrigger(id: 'test-trigger', routeId: 'test-route'),
    );
    await tester.pumpAndSettle();

    expect(find.text('First step'), findsOneWidget);
    expect(find.text('First explanation'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Second step'), findsOneWidget);
    expect(find.text('Second explanation'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Second step'), findsNothing);
    expect(
      stateRepository.state.progressFor('test-flow')?.status,
      OnboardingFlowStatus.completed,
    );
    expect(analytics.startedFlowIds, contains('test-flow'));
    expect(analytics.completedFlowIds, contains('test-flow'));
  });

  testWidgets('skip stores skipped progress and dismisses the overlay', (
    tester,
  ) async {
    final stateRepository = _MemoryOnboardingStateRepository();
    final coordinator = OnboardingCoordinator(
      session: buildSession(),
      stateRepository: stateRepository,
      catalogRepository: _StaticCatalogRepository(
        flows: const <OnboardingFlow>[flow],
      ),
      analyticsService: _RecordingOnboardingAnalyticsService(),
    );

    await pumpHarness(tester, coordinator: coordinator);

    await coordinator.handleTrigger(
      const OnboardingTrigger(id: 'test-trigger', routeId: 'test-route'),
    );
    await tester.pumpAndSettle();

    expect(find.text('First step'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('First step'), findsNothing);
    expect(
      stateRepository.state.progressFor('test-flow')?.status,
      OnboardingFlowStatus.skipped,
    );
  });

  testWidgets(
    'keeps the done button visible and tappable near the bottom edge',
    (tester) async {
      final stateRepository = _MemoryOnboardingStateRepository();
      final coordinator = OnboardingCoordinator(
        session: buildSession(),
        stateRepository: stateRepository,
        catalogRepository: _StaticCatalogRepository(
          flows: const <OnboardingFlow>[bottomAnchoredFlow],
        ),
        analyticsService: _RecordingOnboardingAnalyticsService(),
      );

      await pumpHarness(
        tester,
        coordinator: coordinator,
        surfaceSize: const Size(390, 640),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: <Widget>[
              OnboardingAnchor(
                anchorId: 'anchor.one',
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Anchor one'),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: OnboardingAnchor(
                  anchorId: 'anchor.bottom',
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Bottom anchor'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await coordinator.handleTrigger(
        const OnboardingTrigger(id: 'bottom-trigger', routeId: 'bottom-route'),
      );
      await tester.pumpAndSettle();

      final doneButton = find.widgetWithText(FilledButton, 'Done');
      expect(doneButton, findsOneWidget);

      final doneRect = tester.getRect(doneButton);
      expect(doneRect.bottom, lessThanOrEqualTo(640));

      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      expect(find.text('Bottom edge step'), findsNothing);
      expect(
        stateRepository.state.progressFor('bottom-flow')?.status,
        OnboardingFlowStatus.completed,
      );
    },
  );
}

class _StaticCatalogRepository implements OnboardingCatalogRepository {
  const _StaticCatalogRepository({required this.flows});

  final List<OnboardingFlow> flows;

  @override
  Future<OnboardingCatalogSnapshot> load({
    required AuthSession session,
    required OnboardingTrigger trigger,
  }) async {
    return OnboardingCatalogSnapshot(
      settings: const OnboardingRemoteSettings(
        enabled: true,
        firestoreCatalogEnabled: false,
        catalogCollection: 'onboardingFlows',
        rolloutPercent: 100,
        shellNavigationEnabled: true,
        memberWorkspaceEnabled: true,
        genealogyWorkspaceEnabled: true,
        genealogyDiscoveryEnabled: true,
        clanDetailEnabled: true,
      ),
      flows: flows.where((flow) => flow.triggerId == trigger.id).toList(),
    );
  }
}

class _MemoryOnboardingStateRepository implements OnboardingStateRepository {
  OnboardingUserState state = const OnboardingUserState();

  @override
  Future<OnboardingUserState> load({required AuthSession session}) async {
    return state;
  }

  @override
  Future<void> saveProgress({
    required AuthSession session,
    required OnboardingFlowProgress progress,
  }) async {
    state = state.copyWithFlow(progress);
  }
}

class _RecordingOnboardingAnalyticsService
    implements OnboardingAnalyticsService {
  final List<String> startedFlowIds = <String>[];
  final List<String> completedFlowIds = <String>[];

  @override
  Future<void> logAnchorMissing({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logCompleted({
    required OnboardingFlow flow,
    required String routeId,
  }) async {
    completedFlowIds.add(flow.id);
  }

  @override
  Future<void> logInterrupted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logSkipped({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logStarted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {
    startedFlowIds.add(flow.id);
  }

  @override
  Future<void> logStepViewed({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}
}
