import 'package:befam/app/app.dart';
import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/features/auth/services/auth_analytics_service.dart';
import 'package:befam/features/auth/services/auth_session_store.dart';
import 'package:befam/features/auth/services/debug_auth_gateway.dart';
import 'package:befam/features/clan/services/clan_repository.dart';
import 'package:befam/features/clan/services/debug_clan_repository.dart';
import 'package:befam/features/member/services/debug_member_repository.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
  }

  Future<void> loginWithPhone(WidgetTester tester) async {
    await acceptPrivacyPolicy(tester);

    await tester.tap(find.text('Dùng số điện thoại'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '0901234567');
    await tester.pumpAndSettle();

    final sendOtpButton = find.widgetWithText(FilledButton, 'Gửi OTP');
    await tester.tap(sendOtpButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('otp-code-input')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> openMembersWorkspace(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('shortcut-members')));
    await tester.pumpAndSettle();
  }

  Future<void> loginWithChild(WidgetTester tester) async {
    await acceptPrivacyPolicy(tester);

    await tester.tap(find.text('Dùng mã trẻ em'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BEFAM-CHILD-001');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('otp-code-input')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Vietnamese when no locale override is provided', (
    tester,
  ) async {
    await pumpAuthApp(tester);

    expect(find.text('Tiếp tục bằng số điện thoại'), findsOneWidget);
    expect(find.text('Tiếp tục bằng mã trẻ em'), findsOneWidget);
    expect(
      find.text('Xác thực là cột mốc tiếp theo của BeFam.'),
      findsOneWidget,
    );
  });

  testWidgets('supports Vietnamese as the primary locale', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    expect(find.text('Tiếp tục bằng số điện thoại'), findsOneWidget);
    expect(find.text('Tiếp tục bằng mã trẻ em'), findsOneWidget);
    expect(
      find.text('Xác thực là cột mốc tiếp theo của BeFam.'),
      findsOneWidget,
    );
  });

  testWidgets('supports English as the secondary locale', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('en'));

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with child ID'), findsOneWidget);
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

    expect(find.textContaining('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Ngữ cảnh đã đăng nhập'), findsOneWidget);
    expect(find.text('Đăng nhập bằng điện thoại'), findsWidgets);
    expect(find.text('Phiên thành viên đã liên kết'), findsWidgets);
  });

  testWidgets('supports manual child identifier input', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));
    await acceptPrivacyPolicy(tester);

    await tester.tap(find.text('Dùng mã trẻ em'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BEFAM-CHILD-002');
    await tester.pumpAndSettle();

    final childField = tester.widget<TextField>(find.byType(TextField).first);
    expect(childField.controller?.text, 'BEFAM-CHILD-002');
  });

  testWidgets('completes child access with parent OTP context', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    await loginWithChild(tester);

    expect(find.text('Phiên truy cập trẻ em'), findsWidgets);
    expect(find.textContaining('BEFAM-CHILD-001'), findsWidgets);
    expect(find.textContaining('OTP phụ huynh'), findsWidgets);
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
    await tester.pumpAndSettle();

    expect(find.text('Quản lý họ tộc'), findsOneWidget);
    expect(find.text('Họ tộc BeFam'), findsWidgets);
    expect(find.text('Các chi'), findsOneWidget);
    expect(find.text('Chi Trưởng'), findsOneWidget);
    expect(find.text('Thêm chi'), findsOneWidget);

    await tester.tap(find.text('Mở danh sách chi'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm chi'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    expect(find.text('Chưa có hồ sơ họ tộc'), findsOneWidget);

    await tester.tap(find.text('Tạo hồ sơ').first);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    expect(find.text('Họ Nguyễn Văn'), findsWidgets);
    expect(find.text('Đã lưu hồ sơ họ tộc.'), findsOneWidget);
  });

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
    await tester.pumpAndSettle();

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
      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_elder_001')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('members-search-input')),
        'Ông Bảo',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('member-row-member_demo_elder_001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsNothing,
      );

      await tester.enterText(find.byKey(const Key('members-search-input')), '');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('members-generation-filter-4')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_parent_002')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_elder_001')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('members-branch-filter-branch_demo_002')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('member-row-member_demo_parent_002')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-row-member_demo_parent_001')),
        findsNothing,
      );

      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-phone-lookup-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin chính').first);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quan hệ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-parent-picker-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key('member-parent-picker-father-member_demo_parent_001'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-parent-picker-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin thêm').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-job-title-input')),
      'Điều phối viên thành viên',
    );

    await tester.tap(find.byKey(const Key('member-save-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đã lưu hồ sơ thành viên.'), findsOneWidget);
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
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-phone-lookup-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thông tin chính').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('member-birth-date-input')),
        '2000-01-01',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quan hệ').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('member-parent-picker-button')));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();
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
