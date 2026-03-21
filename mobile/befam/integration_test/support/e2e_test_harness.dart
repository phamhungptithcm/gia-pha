import 'package:befam/app/app.dart';
import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/auth/services/auth_analytics_service.dart';
import 'package:befam/features/auth/services/auth_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/features/auth/services/debug_auth_gateway.dart';
import '../../test/support/features/billing/services/debug_billing_repository.dart';
import '../../test/support/features/clan/services/debug_clan_repository.dart';
import '../../test/support/features/discovery/services/debug_genealogy_discovery_repository.dart';
import '../../test/support/features/events/services/debug_event_repository.dart';
import '../../test/support/features/funds/services/debug_fund_repository.dart';
import '../../test/support/features/genealogy/services/debug_genealogy_read_repository.dart';
import '../../test/support/features/member/services/debug_member_repository.dart';
import '../../test/support/features/profile/services/debug_profile_notification_preferences_repository.dart';
import '../../test/support/features/auth/services/debug_clan_context_service.dart';
import 'e2e_scenarios.dart';
import 'fakes/fake_push_notification_service.dart';

final FirebaseSetupStatus e2eReadyStatus = FirebaseSetupStatus.ready(
  projectId: 'e2e-debug-sandbox',
  storageBucket: 'e2e-debug-sandbox.appspot.com',
  enabledServices: const ['Auth', 'Firestore', 'Storage', 'Messaging'],
  isCrashReportingEnabled: false,
);

class E2ECrashGuard {
  E2ECrashGuard._(
    this._capturedErrors,
    this._previousFlutterOnError,
    this._previousPlatformOnError,
    this._binding,
  );

  final List<Object> _capturedErrors;
  final void Function(FlutterErrorDetails)? _previousFlutterOnError;
  final bool Function(Object, StackTrace)? _previousPlatformOnError;
  final TestWidgetsFlutterBinding _binding;

  List<Object> get capturedErrors => List.unmodifiable(_capturedErrors);

  static E2ECrashGuard install(TestWidgetsFlutterBinding binding) {
    final capturedErrors = <Object>[];
    final previousFlutterOnError = FlutterError.onError;
    final previousPlatformOnError = binding.platformDispatcher.onError;

    FlutterError.onError = (details) {
      capturedErrors.add(details.exception);
      previousFlutterOnError?.call(details);
    };
    binding.platformDispatcher.onError = (error, stack) {
      capturedErrors.add(error);
      return true;
    };

    return E2ECrashGuard._(
      capturedErrors,
      previousFlutterOnError,
      previousPlatformOnError,
      binding,
    );
  }

  void dispose() {
    FlutterError.onError = _previousFlutterOnError;
    _binding.platformDispatcher.onError = _previousPlatformOnError;
  }
}

class E2EAppContext {
  const E2EAppContext({
    required this.binding,
    required this.pushNotificationService,
    required this.crashGuard,
  });

  final IntegrationTestWidgetsFlutterBinding binding;
  final FakePushNotificationService pushNotificationService;
  final E2ECrashGuard crashGuard;
}

Future<void> safePumpAndSettle(
  WidgetTester tester, {
  Duration duration = const Duration(milliseconds: 16),
  int maxFrames = 300,
}) async {
  try {
    await tester.pumpAndSettle(duration);
    return;
  } catch (error) {
    if (!error.toString().contains('pumpAndSettle timed out')) {
      rethrow;
    }
  }

  for (var frame = 0; frame < maxFrames; frame += 1) {
    await tester.pump(duration);
  }
}

Future<void> waitFor(
  WidgetTester tester, {
  required bool Function() condition,
  int maxFrames = 420,
  Duration frameDuration = const Duration(milliseconds: 16),
  String? reason,
}) async {
  for (var frame = 0; frame < maxFrames; frame += 1) {
    if (condition()) {
      return;
    }
    await tester.pump(frameDuration);
  }
  expect(condition(), isTrue, reason: reason);
}

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 420,
  Duration frameDuration = const Duration(milliseconds: 16),
  String? reason,
}) async {
  await waitFor(
    tester,
    maxFrames: maxFrames,
    frameDuration: frameDuration,
    reason: reason,
    condition: () => finder.evaluate().isNotEmpty,
  );
}

Future<E2EAppContext> pumpE2EApp(
  WidgetTester tester, {
  Locale locale = const Locale('vi'),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.binding.platformDispatcher.clearTextScaleFactorTestValue);

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final crashGuard = E2ECrashGuard.install(tester.binding);
  addTearDown(crashGuard.dispose);

  final fakePush = FakePushNotificationService();

  await tester.pumpWidget(
    BeFamApp(
      status: e2eReadyStatus,
      authGateway: DebugAuthGateway(),
      authAnalyticsService: const NoopAuthAnalyticsService(),
      sessionStore: InMemoryAuthSessionStore(),
      clanContextService: const DebugClanContextService(),
      clanRepository: DebugClanRepository.seeded(),
      memberRepository: DebugMemberRepository.seeded(),
      eventRepository: DebugEventRepository.shared(),
      fundRepository: DebugFundRepository.seeded(),
      genealogyRepository: DebugGenealogyReadRepository.seeded(),
      genealogyDiscoveryRepository: DebugGenealogyDiscoveryRepository.seeded(),
      billingRepository: DebugBillingRepository.shared(),
      pushNotificationService: fakePush,
      profileNotificationPreferencesRepository:
          DebugProfileNotificationPreferencesRepository.shared(),
      locale: locale,
    ),
  );
  await safePumpAndSettle(tester);

  return E2EAppContext(
    binding: binding,
    pushNotificationService: fakePush,
    crashGuard: crashGuard,
  );
}

Future<void> acceptPrivacyPolicy(WidgetTester tester) async {
  final checkboxFinder = find.byType(Checkbox);
  if (checkboxFinder.evaluate().isEmpty) {
    return;
  }

  final checkbox = tester.widget<Checkbox>(checkboxFinder.first);
  if (checkbox.value == true) {
    return;
  }

  await tester.tap(checkboxFinder.first);
  await safePumpAndSettle(tester);
}

Future<void> loginWithPhone(
  WidgetTester tester, {
  required String phoneInput,
  String otpCode = '123456',
}) async {
  await acceptPrivacyPolicy(tester);
  await tapText(tester, 'Dùng số điện thoại');

  await tester.enterText(find.byType(TextField).first, phoneInput);
  await safePumpAndSettle(tester);

  final sendOtpButton = find.widgetWithText(FilledButton, 'Gửi OTP');
  await waitForFinder(
    tester,
    sendOtpButton,
    reason: 'Không tìm thấy nút gửi OTP.',
  );
  await tester.tap(sendOtpButton);

  await waitFor(
    tester,
    reason: 'Không chuyển tới màn OTP hoặc AppShell sau khi gửi OTP.',
    condition: () =>
        find.byKey(const Key('otp-code-input')).evaluate().isNotEmpty ||
        find.byType(AppShellPage).evaluate().isNotEmpty,
  );

  final otpField = find.byKey(const Key('otp-code-input'));
  if (otpField.evaluate().isNotEmpty) {
    await tester.enterText(otpField, otpCode);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await safePumpAndSettle(tester);
  }

  await waitFor(
    tester,
    reason: 'Không vào được AppShell sau khi verify OTP.',
    condition: () => find.byType(AppShellPage).evaluate().isNotEmpty,
  );
}

Future<void> loginWithChildCode(
  WidgetTester tester, {
  required String childCode,
  String otpCode = '123456',
}) async {
  await acceptPrivacyPolicy(tester);
  await tapText(tester, 'Dùng mã trẻ em');

  await tester.enterText(find.byType(TextField).first, childCode);
  await safePumpAndSettle(tester);

  final continueButton = find.widgetWithText(FilledButton, 'Tiếp tục');
  await waitForFinder(
    tester,
    continueButton,
    reason: 'Không tìm thấy nút Tiếp tục ở luồng mã trẻ em.',
  );
  await tester.tap(continueButton);

  await waitForFinder(
    tester,
    find.byKey(const Key('otp-code-input')),
    reason: 'Luồng mã trẻ em không tới màn OTP.',
  );

  await tester.enterText(find.byKey(const Key('otp-code-input')), otpCode);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await safePumpAndSettle(tester);

  await waitFor(
    tester,
    reason: 'Luồng mã trẻ em verify OTP xong nhưng không vào AppShell.',
    condition: () => find.byType(AppShellPage).evaluate().isNotEmpty,
  );
}

Future<void> openShortcut(WidgetTester tester, String shortcutId) async {
  final finder = find.byKey(Key(shortcutId));
  await waitForFinder(
    tester,
    finder,
    reason: 'Không tìm thấy shortcut "$shortcutId".',
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await safePumpAndSettle(tester);
}

Future<void> tapBottomNavigationLabel(WidgetTester tester, String label) async {
  final finder = find.text(label);
  if (finder.evaluate().isNotEmpty) {
    await tester.tap(finder.last);
    await safePumpAndSettle(tester);
    return;
  }

  final fallbackIconFinder = _navigationIconFallbackFinder(label);
  if (fallbackIconFinder != null) {
    await waitForFinder(
      tester,
      fallbackIconFinder,
      reason: 'Không tìm thấy icon tab "$label".',
    );
    await tester.tap(fallbackIconFinder.last);
    await safePumpAndSettle(tester);
    return;
  }

  await waitForFinder(
    tester,
    finder,
    reason: 'Không tìm thấy tab đáy "$label".',
  );
  await tester.tap(finder.last);
  await safePumpAndSettle(tester);
}

Finder? _navigationIconFallbackFinder(String label) {
  final normalized = label.trim().toLowerCase();
  return switch (normalized) {
    'trang chủ' || 'home' =>
      _navigationScopedIconFinder(Icons.space_dashboard_outlined),
    'gia phả' || 'tree' || 'genealogy' =>
      _navigationScopedIconFinder(Icons.account_tree_outlined).evaluate().isNotEmpty
          ? _navigationScopedIconFinder(Icons.account_tree_outlined)
          : _navigationScopedIconFinder(Icons.travel_explore_outlined),
    'sự kiện' || 'events' => _navigationScopedIconFinder(Icons.event_outlined),
    'gói' || 'billing' =>
      _navigationScopedIconFinder(Icons.workspace_premium_outlined),
    'hồ sơ' || 'profile' => _navigationScopedIconFinder(Icons.person_outline),
    _ => null,
  };
}

Future<void> tapBottomNavigationByIcons(
  WidgetTester tester, {
  required List<IconData> icons,
  String? fallbackLabel,
}) async {
  for (final icon in icons) {
    final finder = _navigationScopedIconFinder(icon);
    if (finder.evaluate().isEmpty) {
      continue;
    }
    final target = finder.last;
    await tester.ensureVisible(target);
    await tester.tap(target, warnIfMissed: false);
    await safePumpAndSettle(tester);
    return;
  }

  if (fallbackLabel != null && fallbackLabel.trim().isNotEmpty) {
    await tapBottomNavigationLabel(tester, fallbackLabel);
    return;
  }

  fail('Không tìm thấy tab đáy theo icon candidates: $icons');
}

Finder _navigationScopedIconFinder(IconData icon) {
  final navScopedCandidates = <Finder>[
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.byIcon(icon),
    ),
    find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.byIcon(icon),
    ),
    find.byIcon(icon),
  ];

  for (final candidate in navScopedCandidates) {
    if (candidate.evaluate().isNotEmpty) {
      return candidate;
    }
  }
  return find.byIcon(icon);
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool useLast = true,
}) async {
  final finder = find.text(text);
  await waitForFinder(tester, finder, reason: 'Không tìm thấy text "$text".');
  await tester.tap(useLast ? finder.last : finder.first);
  await safePumpAndSettle(tester);
}

Future<void> captureScreenshotSafe(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    await binding
        .takeScreenshot(name)
        .timeout(const Duration(seconds: 8));
  } catch (_) {}
}

AuthSession extractShellSession(WidgetTester tester) {
  final shellFinder = find.byType(AppShellPage);
  expect(shellFinder, findsOneWidget);
  final shell = tester.widget<AppShellPage>(shellFinder);
  return shell.session;
}

void expectShellAccessMode(
  Finder shellFinder,
  AuthMemberAccessMode expectedMode,
  WidgetTester tester,
) {
  final shell = tester.widget<AppShellPage>(shellFinder);
  expect(shell.session.accessMode, expectedMode);
}

void expectShellRole(
  Finder shellFinder,
  String expectedRole,
  WidgetTester tester,
) {
  final shell = tester.widget<AppShellPage>(shellFinder);
  expect(shell.session.primaryRole?.toUpperCase() ?? '', expectedRole);
}

void expectScenarioContext(WidgetTester tester, E2ELoginScenario scenario) {
  final shellFinder = find.byType(AppShellPage);
  expect(shellFinder, findsOneWidget);
  final shell = tester.widget<AppShellPage>(shellFinder);
  expect(shell.session.accessMode, scenario.expectedAccessMode);
  expect(shell.session.primaryRole?.toUpperCase() ?? '', scenario.expectedRole);
  if (scenario.expectedClanId != null) {
    expect(shell.session.clanId, scenario.expectedClanId);
  }
  if (scenario.expectedBranchId != null) {
    expect(shell.session.branchId, scenario.expectedBranchId);
  }
}

void assertNoUnhandledFailures(
  WidgetTester tester, {
  required E2ECrashGuard crashGuard,
}) {
  final flutterException = tester.takeException();
  expect(
    flutterException,
    isNull,
    reason: 'Phát hiện exception chưa xử lý: $flutterException',
  );
  expect(
    crashGuard.capturedErrors,
    isEmpty,
    reason:
        'Phát hiện lỗi Flutter/Platform không được xử lý: ${crashGuard.capturedErrors}',
  );
}
