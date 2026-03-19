import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/calendar/models/calendar_region.dart';
import 'package:befam/features/calendar/models/lunar_date.dart';
import 'package:befam/features/calendar/services/lunar_conversion_engine.dart';
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

  Finder memorialQuickSetupButtons() => find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('event-memorial-quick-setup-');
  });

  Finder ritualQuickSetupButtons() => find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('event-ritual-quick-setup-');
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

  testWidgets('shows memorial checklist and supports quick setup', (
    tester,
  ) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    final memorialChecklistTitle = find.text('Danh sách giỗ kỵ');
    await tester.scrollUntilVisible(
      memorialChecklistTitle,
      320,
      scrollable: workspaceScroll(),
    );
    expect(memorialChecklistTitle, findsOneWidget);
    expect(find.text('Chưa thiết lập'), findsWidgets);

    final quickSetupButton = memorialQuickSetupButtons().first;
    await tester.ensureVisible(quickSetupButton);
    await tester.tap(quickSetupButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saveButton = find.byKey(const Key('event-save-button'));
    expect(saveButton, findsOneWidget);
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
  });

  testWidgets('shows ritual checklist and supports quick setup', (
    tester,
  ) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    final ritualChecklistTitle = find.text('Danh sách dỗ trạp');
    await tester.scrollUntilVisible(
      ritualChecklistTitle,
      320,
      scrollable: workspaceScroll(),
    );
    expect(ritualChecklistTitle, findsOneWidget);
    expect(
      find.byKey(const Key('event-ritual-checklist-panel')),
      findsOneWidget,
    );
    expect(ritualQuickSetupButtons(), findsWidgets);
  });

  testWidgets('creates a new event from the create form', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    await tester.tap(find.byKey(const Key('event-create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('event-title-field')),
      'Họp tổng kết',
    );
    await tester.tap(find.byKey(const Key('event-save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const Key('event-start-field')),
      '2026-07-01 19:00',
    );
    await tester.enterText(
      find.byKey(const Key('event-end-field')),
      '2026-07-01 21:00',
    );

    final saveButton = find.byKey(const Key('event-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Đã lưu sự kiện thành công.'), findsOneWidget);
  });

  testWidgets('validates start and end time ordering in form', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    await tester.tap(find.byKey(const Key('event-create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('event-title-field')),
      'Sự kiện lỗi thời gian',
    );
    await tester.tap(find.byKey(const Key('event-save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const Key('event-start-field')),
      '2026-06-10 18:00',
    );
    await tester.enterText(
      find.byKey(const Key('event-end-field')),
      '2026-06-10 17:00',
    );

    final saveButton = find.byKey(const Key('event-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(
        'Thời gian bắt đầu/kết thúc không hợp lệ. Thời gian kết thúc phải sau thời gian bắt đầu.',
      ),
      findsOneWidget,
    );
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
