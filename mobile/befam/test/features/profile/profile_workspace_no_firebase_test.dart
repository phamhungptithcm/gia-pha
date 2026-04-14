import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/ai/services/ai_assist_service.dart';
import 'package:befam/features/profile/presentation/profile_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/features/member/services/debug_member_repository.dart';
import '../../support/features/ai/services/fake_ai_assist_service.dart';
import '../../support/features/billing/services/debug_billing_repository.dart';
import '../../support/features/profile/services/debug_profile_notification_preferences_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';

void main() {
  void configureMobileViewport(WidgetTester tester) {
    const logicalSize = Size(430, 932);
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(
      logicalSize.width * dpr,
      logicalSize.height * dpr,
    );
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pumpUi(WidgetTester tester, {int frames = 24}) async {
    for (var index = 0; index < frames; index += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  AuthSession buildSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 4).toIso8601String(),
    );
  }

  testWidgets('renders profile settings with sandbox fallback services', (
    tester,
  ) async {
    configureMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProfileWorkspacePage(
          session: buildSession(),
          memberRepository: DebugMemberRepository.seeded(),
          billingRepository: DebugBillingRepository.shared(),
          notificationPreferencesRepository:
              DebugProfileNotificationPreferencesRepository.shared(),
          showAppBar: true,
        ),
      ),
    );
    await pumpUi(tester, frames: 120);

    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open settings'));
    await pumpUi(tester, frames: 36);

    expect(find.text('Memorials and events'), findsOneWidget);
    expect(find.text('Scholarships'), findsOneWidget);
    expect(find.text('Family updates'), findsOneWidget);
    expect(find.text('Quiet hours'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('AI help this month'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AI help this month'), findsOneWidget);
    expect(find.text('Change or upgrade plan'), findsOneWidget);
    expect(find.text('Test on this device'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows AI disclosure and loading copy in the profile quick check', (
    tester,
  ) async {
    configureMobileViewport(tester);
    final aiAssistService = FakeAiAssistService(
      onReviewProfileDraft:
          ({required session, required locale, required draft}) async {
            await Future<void>.delayed(const Duration(milliseconds: 220));
            return const ProfileAiReview(
              summary: 'Hồ sơ đã có nền khá tốt.',
              strengths: ['Tên đầy đủ rõ ràng.'],
              missingImportant: ['Nên thêm vài dòng giới thiệu ngắn.'],
              risks: [],
              nextActions: ['Bổ sung 1-2 câu về nơi ở hiện tại.'],
              usedFallback: false,
              model: null,
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProfileWorkspacePage(
          session: buildSession(),
          memberRepository: DebugMemberRepository.seeded(),
          notificationPreferencesRepository:
              DebugProfileNotificationPreferencesRepository.shared(),
          aiAssistService: aiAssistService,
          showAppBar: true,
        ),
      ),
    );
    await pumpUi(tester, frames: 120);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await pumpUi(tester, frames: 40);

    expect(find.text('Kiểm tra nhanh hồ sơ'), findsOneWidget);
    expect(
      find.text(
        'AI chỉ dùng các tín hiệu cần thiết của hồ sơ nháp để kiểm tra, không dùng toàn bộ dữ liệu liên hệ thô.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('profile-quality-check-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Đang phân tích...'), findsOneWidget);
    expect(find.text('Đang tạo gợi ý, thường mất vài giây.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Hồ sơ đã có nền khá tốt.'), findsOneWidget);
  });
}
