import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/calendar/models/calendar_region.dart';
import 'package:befam/features/calendar/models/lunar_date.dart';
import 'package:befam/features/calendar/services/lunar_conversion_engine.dart';
import 'package:befam/features/events/models/event_type.dart';
import 'package:befam/features/events/presentation/event_workspace_page.dart';
import '../../support/features/events/services/debug_event_repository.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLunarConversionEngine implements LunarConversionEngine {
  const _FakeLunarConversionEngine();

  @override
  Future<DateTime?> lunarToSolar(
    LunarDate lunarDate, {
    required CalendarRegion region,
  }) async {
    if (lunarDate.month == 1 && lunarDate.day == 4) {
      return DateTime(lunarDate.year, 2, 20);
    }
    return DateTime(lunarDate.year, lunarDate.month, lunarDate.day);
  }

  @override
  Future<Map<int, LunarDate>> monthSolarToLunar({
    required int year,
    required int month,
    required CalendarRegion region,
  }) async {
    return <int, LunarDate>{};
  }

  @override
  Future<LunarDate> solarToLunar(
    DateTime solarDate, {
    required CalendarRegion region,
  }) async {
    return LunarDate(
      year: solarDate.year,
      month: solarDate.month,
      day: solarDate.day,
    );
  }
}

void main() {
  Finder workspaceScroll() => find.byType(Scrollable).first;

  Finder memorialEntryQuickSetupButtons() => find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('event-memorial-entry-quick-setup-');
  });

  AuthSession buildClanAdminSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  Future<void> pumpWorkspace(
    WidgetTester tester,
    DebugEventRepository repository, {
    DateTime Function()? nowProvider,
    LunarConversionEngine? lunarConversionEngine,
  }) async {
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
        home: Scaffold(
          body: EventWorkspacePage(
            session: buildClanAdminSession(),
            repository: repository,
            nowProvider: nowProvider,
            lunarConversionEngine: lunarConversionEngine,
          ),
        ),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 30; attempt++) {
      if (find.byType(Scrollable).evaluate().isNotEmpty &&
          find
              .byKey(const Key('event-workspace-scroll'))
              .evaluate()
              .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(Scrollable), findsWidgets);
  }

  Future<void> createEvent(
    WidgetTester tester, {
    required String title,
    required String startAt,
    required String endAt,
  }) async {
    await tester.tap(find.byKey(const Key('event-create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(const Key('event-title-field')), title);
    await tester.tap(find.byKey(const Key('event-save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('event-start-field')), startAt);
    await tester.enterText(find.byKey(const Key('event-end-field')), endAt);

    final saveButton = find.byKey(const Key('event-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void useLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders event workspace shell', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    expect(find.text('Không gian sự kiện'), findsOneWidget);
    expect(find.byKey(const Key('event-workspace-scroll')), findsOneWidget);
    expect(find.byKey(const Key('event-create-button')), findsOneWidget);
  });

  testWidgets('shows memorial checklist and opens quick setup form', (
    tester,
  ) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    final memorialChecklistTitle = find.text('Truy cập nhanh');
    await tester.scrollUntilVisible(
      memorialChecklistTitle,
      320,
      scrollable: workspaceScroll(),
    );
    expect(memorialChecklistTitle, findsOneWidget);
    await tester.tap(
      find.byKey(const Key('event-memorial-access-anniversary')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Giỗ Kỵ (từ 3 năm trở đi)'), findsWidgets);

    final quickSetupButton = memorialEntryQuickSetupButtons().first;
    await tester.ensureVisible(quickSetupButton);
    await tester.tap(quickSetupButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final titleField = find.byKey(const Key('calendar-event-title-field'));
    expect(titleField, findsOneWidget);
    final titleWidget = tester.widget<TextField>(titleField);
    expect(titleWidget.controller?.text.trim().isNotEmpty, isTrue);
    expect(
      find.byKey(const Key('calendar-event-continue-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows ritual checklist and supports quick setup', (
    tester,
  ) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    final ritualChecklistTitle = find.text('Truy cập nhanh');
    await tester.scrollUntilVisible(
      ritualChecklistTitle,
      320,
      scrollable: workspaceScroll(),
    );
    expect(ritualChecklistTitle, findsOneWidget);
    await tester.tap(find.byKey(const Key('event-memorial-access-prayer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lễ tiết cầu siêu (49/100 ngày)'), findsWidgets);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(memorialEntryQuickSetupButtons(), findsWidgets);
  });

  testWidgets('uses next yearly occurrence for recurring memorial events', (
    tester,
  ) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(
      tester,
      repository,
      nowProvider: () => DateTime(2027, 1, 10, 9),
    );

    await tester.scrollUntilVisible(
      find.text('Sự kiện sắp tới gần nhất'),
      260,
      scrollable: workspaceScroll(),
    );

    expect(find.text('Giỗ cụ tổ mùa xuân'), findsOneWidget);
    expect(find.textContaining('2027-04-04'), findsWidgets);
    expect(find.text('Họp mặt đầu hè'), findsNothing);
  });

  testWidgets('creates a new event from the create form', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    await tester.tap(find.byKey(const Key('event-create-button')));
    await tester.pump();
    for (var attempt = 0; attempt < 40; attempt++) {
      if (find
          .byKey(const Key('calendar-event-title-field'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 120));
    }

    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      'Họp tổng kết',
    );
    final eventTypeDropdown = find.byKey(
      const Key('calendar-event-type-dropdown-death_anniversary'),
    );
    final dropdownWidget = tester.widget<DropdownButtonFormField<EventType>>(
      eventTypeDropdown,
    );
    dropdownWidget.onChanged?.call(EventType.clanGathering);
    await tester.pump();
    expect(
      find.byKey(const Key('calendar-event-type-dropdown-clan_gathering')),
      findsOneWidget,
    );

    final continueButton = find.byKey(
      const Key('calendar-event-continue-button'),
    );
    final continueWidget = tester.widget<FilledButton>(continueButton);
    continueWidget.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    for (var attempt = 0; attempt < 20; attempt++) {
      if (find
          .byKey(const Key('calendar-event-save-button'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.byKey(const Key('calendar-event-save-button')), findsOneWidget);
  });

  testWidgets('validates required title in unified create form', (
    tester,
  ) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    await tester.tap(find.byKey(const Key('event-create-button')));
    await tester.pump();
    for (var attempt = 0; attempt < 40; attempt++) {
      if (find
          .byKey(const Key('calendar-event-title-field'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 120));
    }

    final continueButton = find.byKey(
      const Key('calendar-event-continue-button'),
    );
    final continueWidget = tester.widget<FilledButton>(continueButton);
    continueWidget.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('calendar-event-title-field')), findsOneWidget);
    expect(find.byKey(const Key('calendar-event-save-button')), findsNothing);
  });

  testWidgets(
    'shows upcoming longevity link and opens member detail for 70+ milestone',
    (tester) async {
      useLargeViewport(tester);
      final store = DebugGenealogyStore.seeded();
      store.members['member_demo_longevity_001'] = const MemberProfile(
        id: 'member_demo_longevity_001',
        clanId: 'clan_demo_001',
        branchId: 'branch_demo_001',
        fullName: 'Cụ Nguyễn Văn Thọ',
        normalizedFullName: 'cụ nguyễn văn thọ',
        nickName: 'Cụ Thọ',
        gender: 'male',
        birthDate: '1970-02-20',
        deathDate: null,
        phoneE164: null,
        email: null,
        addressText: 'Quảng Nam, Việt Nam',
        jobTitle: 'Nông dân',
        avatarUrl: null,
        bio: 'Hồ sơ mừng thọ dùng cho kiểm thử.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 7,
        primaryRole: 'MEMBER',
        status: 'active',
        isMinor: false,
        authUid: null,
      );
      final repository = DebugEventRepository(store: store);

      await pumpWorkspace(
        tester,
        repository,
        nowProvider: () => DateTime(2040, 1, 25, 9),
        lunarConversionEngine: const _FakeLunarConversionEngine(),
      );

      expect(
        find.byKey(const Key('event-longevity-reminder-link-card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('event-longevity-link-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(
          const Key('event-longevity-member-row-member_demo_longevity_001'),
        ),
        findsOneWidget,
      );
      expect(find.text('70 tuổi'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const Key('event-longevity-member-row-member_demo_longevity_001'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cụ Nguyễn Văn Thọ'), findsWidgets);
      expect(find.text('Chi tiết thành viên'), findsOneWidget);
    },
  );

  testWidgets('edits an existing event from detail screen', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    await createEvent(
      tester,
      title: 'Sự kiện cần chỉnh sửa',
      startAt: '2026-09-12 18:00',
      endAt: '2026-09-12 20:00',
    );

    await tester.tap(find.text('Sự kiện cần chỉnh sửa').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('event-detail-edit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('event-title-field')),
      'Giỗ cụ tổ mùa xuân (cập nhật)',
    );

    final saveButton = find.byKey(const Key('event-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Đã lưu sự kiện thành công.'), findsOneWidget);
    expect(find.text('Giỗ cụ tổ mùa xuân (cập nhật)'), findsOneWidget);
  }, skip: true);
}
