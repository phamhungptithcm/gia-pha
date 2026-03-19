import 'package:befam/app/app.dart';
import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/services/auth_analytics_service.dart';
import 'package:befam/features/auth/services/auth_session_store.dart';
import './support/features/auth/services/debug_auth_gateway.dart';
import 'package:befam/features/clan/services/clan_repository.dart';
import './support/features/clan/services/debug_clan_repository.dart';
import './support/features/member/services/debug_member_repository.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> safePumpAndSettle(
    WidgetTester tester, {
    Duration duration = const Duration(milliseconds: 16),
    int maxFrames = 120,
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
    int maxFrames = 240,
    Duration frameDuration = const Duration(milliseconds: 16),
  }) async {
    for (var frame = 0; frame < maxFrames; frame += 1) {
      if (condition()) {
        return;
      }
      await tester.pump(frameDuration);
    }
    expect(condition(), isTrue);
  }

  final status = FirebaseSetupStatus.ready(
    projectId: 'be-fam-3ab23',
    storageBucket: 'be-fam-3ab23.firebasestorage.app',
    enabledServices: const ['Auth', 'Firestore', 'Storage', 'Messaging'],
    isCrashReportingEnabled: false,
  );

  Future<void> pumpAuthApp(
    WidgetTester tester, {
    Locale? locale,
    ClanRepository? clanRepository,
    MemberRepository? memberRepository,
    Size viewportSize = const Size(1200, 2000),
    double textScaleFactor = 1.0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewportSize;
    tester.binding.platformDispatcher.textScaleFactorTestValue =
        textScaleFactor;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(
      BeFamApp(
        status: status,
        authGateway: DebugAuthGateway(),
        authAnalyticsService: const NoopAuthAnalyticsService(),
        sessionStore: InMemoryAuthSessionStore(),
        clanRepository: clanRepository,
        memberRepository: memberRepository ?? DebugMemberRepository.seeded(),
        locale: locale,
      ),
    );
    await safePumpAndSettle(tester);
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

  Future<void> loginWithPhone(WidgetTester tester) async {
    await acceptPrivacyPolicy(tester);

    await tester.tap(find.text('Dùng số điện thoại'));
    await safePumpAndSettle(tester);

    await tester.enterText(find.byType(TextField).first, '0901234567');
    await safePumpAndSettle(tester);

    final sendOtpButton = find.widgetWithText(FilledButton, 'Gửi OTP');
    await tester.tap(sendOtpButton);
    await waitFor(
      tester,
      condition: () =>
          find.byKey(const Key('otp-code-input')).evaluate().isNotEmpty ||
          find.byType(AppShellPage).evaluate().isNotEmpty,
    );

    final otpFinder = find.byKey(const Key('otp-code-input'));
    if (otpFinder.evaluate().isNotEmpty) {
      await tester.enterText(otpFinder, '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await safePumpAndSettle(tester);
    } else {
      await safePumpAndSettle(tester);
    }
  }

  Future<void> openMembersWorkspace(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('shortcut-members')));
    await safePumpAndSettle(tester);
  }

  Future<void> loginWithChild(WidgetTester tester) async {
    await acceptPrivacyPolicy(tester);

    await tester.tap(find.text('Dùng mã trẻ em'));
    await safePumpAndSettle(tester);

    await tester.enterText(find.byType(TextField).first, 'BEFAM-CHILD-001');
    await safePumpAndSettle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await waitFor(
      tester,
      condition: () =>
          find.byKey(const Key('otp-code-input')).evaluate().isNotEmpty ||
          find.byType(AppShellPage).evaluate().isNotEmpty,
    );

    final otpFinder = find.byKey(const Key('otp-code-input'));
    if (otpFinder.evaluate().isNotEmpty) {
      await tester.enterText(otpFinder, '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await safePumpAndSettle(tester);
    } else {
      await safePumpAndSettle(tester);
    }
  }

  testWidgets('defaults to Vietnamese when no locale override is provided', (
    tester,
  ) async {
    await pumpAuthApp(tester);

    expect(find.text('Dùng số điện thoại'), findsOneWidget);
    expect(find.text('Dùng mã trẻ em'), findsOneWidget);
    expect(
      find.text('Xác thực là cột mốc tiếp theo của BeFam.'),
      findsOneWidget,
    );
  });

  testWidgets('supports Vietnamese as the primary locale', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    expect(find.text('Dùng số điện thoại'), findsOneWidget);
    expect(find.text('Dùng mã trẻ em'), findsOneWidget);
    expect(
      find.text('Xác thực là cột mốc tiếp theo của BeFam.'),
      findsOneWidget,
    );
  });

  testWidgets('supports English as the secondary locale', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('en'));

    expect(find.text('Use phone number'), findsOneWidget);
    expect(find.text('Use child identifier'), findsOneWidget);
    expect(
      find.text('Authentication is the next BeFam milestone.'),
      findsOneWidget,
    );
  });

  testWidgets('completes debug phone login and opens dashboard', (
    tester,
  ) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    await loginWithPhone(tester);

    final shell = tester.widget<AppShellPage>(find.byType(AppShellPage));
    expect(shell.session.loginMethod, AuthEntryMethod.phone);
    expect(shell.session.accessMode, AuthMemberAccessMode.claimed);
    expect(find.text('Trang tổng quan'), findsOneWidget);
    expect(find.byKey(const Key('shortcut-members')), findsOneWidget);
  });

  testWidgets('supports manual child identifier input', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));
    await acceptPrivacyPolicy(tester);

    await tester.tap(find.text('Dùng mã trẻ em'));
    await safePumpAndSettle(tester);

    await tester.enterText(find.byType(TextField).first, 'BEFAM-CHILD-002');
    await safePumpAndSettle(tester);

    final childField = tester.widget<TextField>(find.byType(TextField).first);
    expect(childField.controller?.text, 'BEFAM-CHILD-002');
  });

  testWidgets('completes child access with parent OTP context', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    await loginWithChild(tester);

    final shell = tester.widget<AppShellPage>(find.byType(AppShellPage));
    expect(shell.session.loginMethod, AuthEntryMethod.child);
    expect(shell.session.accessMode, AuthMemberAccessMode.child);
    expect(shell.session.childIdentifier, 'BEFAM-CHILD-001');
    expect(find.text('Trang tổng quan'), findsOneWidget);
  });

  testWidgets('opens the clan workspace for a linked clan admin', (
    tester,
  ) async {
    await pumpAuthApp(
      tester,
      locale: const Locale('vi'),
      clanRepository: DebugClanRepository.seeded(),
    );

    await loginWithPhone(tester);

    await tester.tap(find.byKey(const Key('shortcut-clan')));
    await safePumpAndSettle(tester);

    expect(find.text('Quản lý họ tộc'), findsOneWidget);
    expect(find.text('Gia phả họ Nguyễn Văn Đà Nẵng'), findsWidgets);
    expect(find.text('Các chi'), findsOneWidget);
    expect(find.text('Chi Trưởng'), findsOneWidget);
    expect(find.text('Thêm chi'), findsOneWidget);

    await tester.tap(find.text('Mở danh sách chi'));
    await safePumpAndSettle(tester);

    expect(find.text('Danh sách chi'), findsOneWidget);
    expect(find.text('Chi Phụ'), findsOneWidget);
  });

  testWidgets('opens the branch editor for clan admins', (tester) async {
    await pumpAuthApp(
      tester,
      locale: const Locale('vi'),
      clanRepository: DebugClanRepository.seeded(),
    );

    await loginWithPhone(tester);

    await tester.tap(find.byKey(const Key('shortcut-clan')));
    await safePumpAndSettle(tester);

    await tester.tap(find.text('Thêm chi'));
    await safePumpAndSettle(tester);

    expect(find.text('Biên tập chi'), findsOneWidget);
    expect(find.byKey(const Key('branch-name-input')), findsOneWidget);
    expect(find.byKey(const Key('branch-code-input')), findsOneWidget);
    expect(find.byKey(const Key('branch-leader-input')), findsOneWidget);
    expect(find.byKey(const Key('branch-vice-input')), findsOneWidget);
  });

  testWidgets('supports creating the clan profile when it is missing', (
    tester,
  ) async {
    await pumpAuthApp(
      tester,
      locale: const Locale('vi'),
      clanRepository: DebugClanRepository.empty(),
    );

    await loginWithPhone(tester);

    await tester.tap(find.byKey(const Key('shortcut-clan')));
    await safePumpAndSettle(tester);

    expect(find.text('Chưa có hồ sơ họ tộc'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clan-edit-fab')));
    await safePumpAndSettle(tester);

    await tester.enterText(
      find.byKey(const Key('clan-name-input')),
      'Họ Nguyễn Văn',
    );
    await tester.enterText(
      find.byKey(const Key('clan-founder-input')),
      'Nguyễn Văn Thủy Tổ',
    );
    await tester.enterText(
      find.byKey(const Key('clan-description-input')),
      'Không gian họ tộc khởi tạo trong test.',
    );
    await tester.tap(find.byKey(const Key('clan-save-button')));
    await tester.pump();
    await safePumpAndSettle(tester);

    expect(find.text('Họ Nguyễn Văn'), findsWidgets);
    expect(find.text('Đã lưu hồ sơ họ tộc.'), findsOneWidget);
  });

  testWidgets(
    'renders the clan workspace without overflow on small viewport and large text',
    (tester) async {
      await pumpAuthApp(
        tester,
        locale: const Locale('vi'),
        clanRepository: DebugClanRepository.seeded(),
      );

      await loginWithPhone(tester);
      await tester.tap(find.byKey(const Key('shortcut-clan')));
      await safePumpAndSettle(tester);

      tester.view.physicalSize = const Size(320, 568);
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.35;
      await safePumpAndSettle(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Quản lý họ tộc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps the clan workspace read-only for child access', (
    tester,
  ) async {
    await pumpAuthApp(
      tester,
      locale: const Locale('vi'),
      clanRepository: DebugClanRepository.seeded(),
    );

    await loginWithChild(tester);

    await tester.tap(find.byKey(const Key('shortcut-clan')));
    await safePumpAndSettle(tester);

    expect(find.text('Bạn đang ở chế độ chỉ xem'), findsOneWidget);
    expect(find.text('Thêm chi'), findsNothing);
  });

  testWidgets(
    'opens the member workspace and supports search and filters for clan admins',
    (tester) async {
      await pumpAuthApp(
        tester,
        locale: const Locale('vi'),
        clanRepository: DebugClanRepository.seeded(),
        memberRepository: DebugMemberRepository.seeded(),
      );

      await loginWithPhone(tester);
      await openMembersWorkspace(tester);

      expect(find.text('Hồ sơ thành viên'), findsOneWidget);
      expect(find.byKey(const Key('member-add-fab')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('members-search-input')),
        'Nguyễn Minh',
      );
      await safePumpAndSettle(tester);
      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('members-search-input')),
        'Ông Bảo',
      );
      await safePumpAndSettle(tester);

      expect(
        find.byKey(const Key('member-row-member_demo_elder_001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsNothing,
      );

      await tester.enterText(find.byKey(const Key('members-search-input')), '');
      await safePumpAndSettle(tester);

      await tester.tap(
        find.byKey(const Key('members-generation-filter-dropdown')),
      );
      await safePumpAndSettle(tester);
      await tester.tap(find.text('Đời 8').last);
      await safePumpAndSettle(tester);
      await tester.enterText(
        find.byKey(const Key('members-search-input')),
        'Nguyễn Minh',
      );
      await safePumpAndSettle(tester);

      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_elder_001')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('members-search-input')),
        'Trần Văn Long',
      );
      await safePumpAndSettle(tester);
      expect(
        find.byKey(const Key('member-row-member_demo_parent_002')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('members-branch-filter-dropdown')));
      await safePumpAndSettle(tester);
      await tester.tap(find.text('Chi Phụ').last);
      await safePumpAndSettle(tester);

      expect(
        find.byKey(const Key('member-row-member_demo_parent_002')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('members-clear-filters')));
      await safePumpAndSettle(tester);
      await tester.enterText(
        find.byKey(const Key('members-search-input')),
        'Ông Bảo',
      );
      await safePumpAndSettle(tester);

      expect(
        find.byKey(const Key('member-row-member_demo_elder_001')),
        findsOneWidget,
      );
    },
  );

  testWidgets('creates a new member profile from the add form', (tester) async {
    await pumpAuthApp(
      tester,
      locale: const Locale('vi'),
      clanRepository: DebugClanRepository.seeded(),
      memberRepository: DebugMemberRepository.seeded(),
    );

    await loginWithPhone(tester);
    await openMembersWorkspace(tester);

    await tester.tap(find.byKey(const Key('member-add-fab')));
    await safePumpAndSettle(tester);
    await tester.tap(find.byKey(const Key('member-phone-lookup-skip')));
    await safePumpAndSettle(tester);
    await tester.tap(find.text('Thông tin chính').first);
    await safePumpAndSettle(tester);

    await tester.enterText(
      find.byKey(const Key('member-full-name-input')),
      'Phạm Hải An',
    );
    await tester.enterText(
      find.byKey(const Key('member-nickname-input')),
      'Hải An',
    );
    await tester.enterText(
      find.byKey(const Key('member-phone-input')),
      '+84905554444',
    );
    await safePumpAndSettle(tester);
    await tester.tap(find.text('Quan hệ').first);
    await safePumpAndSettle(tester);
    await tester.tap(find.byKey(const Key('member-parent-picker-button')));
    await safePumpAndSettle(tester);
    Finder buildParentOptionFinder(String prefix) {
      return find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith(prefix);
      });
    }

    final fatherOptions = buildParentOptionFinder(
      'member-parent-picker-father-',
    );
    final motherOptions = buildParentOptionFinder(
      'member-parent-picker-mother-',
    );
    final parentOptionToSelect = fatherOptions.evaluate().isNotEmpty
        ? fatherOptions.first
        : motherOptions.evaluate().isNotEmpty
        ? motherOptions.first
        : null;
    expect(parentOptionToSelect, isNotNull);
    await tester.ensureVisible(parentOptionToSelect!);
    await tester.tap(parentOptionToSelect);
    await safePumpAndSettle(tester);
    await tester.tap(find.byKey(const Key('member-parent-picker-done')));
    await safePumpAndSettle(tester);
    await tester.tap(find.text('Thông tin thêm').first);
    await safePumpAndSettle(tester);
    await tester.enterText(
      find.byKey(const Key('member-job-title-input')),
      'Điều phối viên thành viên',
    );

    await tester.tap(find.byKey(const Key('member-save-button')));
    await tester.pump();
    await safePumpAndSettle(tester);

    expect(find.text('Đã lưu hồ sơ thành viên.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('members-search-input')),
      'Phạm Hải An',
    );
    await safePumpAndSettle(tester);
    expect(find.text('Phạm Hải An'), findsWidgets);
  });

  testWidgets(
    'filters parent candidates to people at least 15 years older when birth date is set',
    (tester) async {
      await pumpAuthApp(
        tester,
        locale: const Locale('vi'),
        clanRepository: DebugClanRepository.seeded(),
        memberRepository: DebugMemberRepository.seeded(),
      );

      await loginWithPhone(tester);
      await openMembersWorkspace(tester);

      await tester.tap(find.byKey(const Key('member-add-fab')));
      await safePumpAndSettle(tester);
      await tester.tap(find.byKey(const Key('member-phone-lookup-skip')));
      await safePumpAndSettle(tester);
      await tester.tap(find.text('Thông tin chính').first);
      await safePumpAndSettle(tester);

      await tester.enterText(
        find.byKey(const Key('member-birth-date-input')),
        '2000-01-01',
      );
      await safePumpAndSettle(tester);

      await tester.tap(find.text('Quan hệ').first);
      await safePumpAndSettle(tester);

      await tester.tap(find.byKey(const Key('member-parent-picker-button')));
      await safePumpAndSettle(tester);

      expect(
        find.textContaining('chỉ hiển thị người lớn hơn tối thiểu 15 tuổi'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('member-parent-picker-father-member_demo_elder_001'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('member-parent-picker-father-member_demo_parent_001'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('member-parent-picker-father-member_demo_parent_002'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('member-parent-picker-mother-member_demo_child_002'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('member-parent-picker-cancel')));
      await safePumpAndSettle(tester);
    },
  );

  testWidgets('keeps the member workspace limited for child access', (
    tester,
  ) async {
    await pumpAuthApp(
      tester,
      locale: const Locale('vi'),
      clanRepository: DebugClanRepository.seeded(),
      memberRepository: DebugMemberRepository.seeded(),
    );

    await loginWithChild(tester);
    await openMembersWorkspace(tester);

    expect(find.text('Bạn đang ở chế độ chỉ xem'), findsOneWidget);
    expect(find.byKey(const Key('member-add-fab')), findsNothing);
    expect(
      find.byKey(const Key('member-row-member_demo_child_001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('member-row-member_demo_parent_001')),
      findsNothing,
    );
  });
}
