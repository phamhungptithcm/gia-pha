import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/events/presentation/event_workspace_page.dart';
import 'package:befam/features/events/services/debug_event_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    DebugEventRepository repository,
  ) async {
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
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void useLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders event list and opens event detail', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    expect(find.text('Không gian sự kiện'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Giỗ cụ tổ mùa xuân'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Giỗ cụ tổ mùa xuân'), findsOneWidget);

    await tester.tap(find.text('Giỗ cụ tổ mùa xuân').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Chi tiết sự kiện'), findsOneWidget);
    expect(find.text('Giỗ cụ tổ mùa xuân'), findsWidgets);
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Đã lưu sự kiện thành công.'), findsOneWidget);
    expect(find.text('Họp tổng kết'), findsWidgets);
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

  testWidgets('edits an existing event from detail screen', (tester) async {
    useLargeViewport(tester);
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );
    await pumpWorkspace(tester, repository);

    final eventRowFinder = find.byKey(
      const Key('event-row-event_demo_gathering_001'),
    );
    await tester.scrollUntilVisible(
      eventRowFinder,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(eventRowFinder);
    await tester.tap(eventRowFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('event-detail-edit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('event-title-field')),
      'Họp mặt đầu hè (cập nhật)',
    );

    final saveButton = find.byKey(const Key('event-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Đã lưu sự kiện thành công.'), findsOneWidget);
    expect(find.text('Họp mặt đầu hè (cập nhật)'), findsOneWidget);
  });
}
