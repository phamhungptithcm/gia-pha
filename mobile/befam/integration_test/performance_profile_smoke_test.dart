import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('[PERF-PROFILE][P1] boots auth surface in profile mode', (
    tester,
  ) async {
    final stopwatch = Stopwatch()..start();
    final context = await pumpE2EApp(tester, locale: const Locale('vi'));

    await waitForFinder(
      tester,
      find.byKey(const Key('auth-method-phone-button')),
      maxFrames: 240,
      reason: 'Không thấy auth surface trong profile smoke.',
    );
    stopwatch.stop();

    debugPrint(
      '[profile-smoke] authSurfaceReadyMs=${stopwatch.elapsedMilliseconds}',
    );
    assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
  });
}
