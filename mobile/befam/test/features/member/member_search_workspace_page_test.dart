import 'dart:async';
import 'dart:typed_data';

import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/models/branch_profile.dart';
import 'package:befam/features/member/models/member_draft.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/member/models/member_workspace_snapshot.dart';
import 'package:befam/features/member/presentation/member_workspace_page.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:befam/features/member/services/member_search_analytics_service.dart';
import 'package:befam/features/member/services/member_search_provider.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'uid-1',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901111111',
      displayName: 'Người kiểm thử',
      memberId: 'm1',
      clanId: 'c1',
      branchId: 'b1',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  MemberProfile buildMember({
    required String id,
    required String fullName,
    required String branchId,
    required int generation,
    String nickName = '',
    String? phone,
  }) {
    return MemberProfile(
      id: id,
      clanId: 'c1',
      branchId: branchId,
      fullName: fullName,
      normalizedFullName: fullName.toLowerCase(),
      nickName: nickName,
      gender: null,
      birthDate: null,
      deathDate: null,
      phoneE164: phone,
      email: null,
      addressText: null,
      jobTitle: null,
      avatarUrl: null,
      bio: null,
      socialLinks: const MemberSocialLinks(),
      parentIds: const [],
      childrenIds: const [],
      spouseIds: const [],
      generation: generation,
      primaryRole: 'MEMBER',
      status: 'active',
      isMinor: false,
      authUid: null,
    );
  }

  Future<void> pumpWorkspace(
    WidgetTester tester, {
    required MemberRepository repository,
    MemberSearchProvider? searchProvider,
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
        home: MemberWorkspacePage(
          session: buildSession(),
          repository: repository,
          searchProvider: searchProvider,
          searchAnalyticsService: const NoopMemberSearchAnalyticsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToSearchSection(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  final repository = _FakeMemberRepository(
    members: [
      buildMember(
        id: 'm1',
        fullName: 'Nguyen An',
        nickName: 'An',
        branchId: 'b1',
        generation: 4,
        phone: '+84901111111',
      ),
      buildMember(
        id: 'm2',
        fullName: 'Tran Binh',
        nickName: 'Binh',
        branchId: 'b2',
        generation: 5,
        phone: '+84902222222',
      ),
    ],
  );

  testWidgets('renders branch chips, generation controls, and result rows', (
    tester,
  ) async {
    await pumpWorkspace(
      tester,
      repository: repository,
      searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
    );
    await scrollToSearchSection(
      tester,
      find.byKey(const Key('members-branch-filter-dropdown')),
    );

    expect(
      find.byKey(const Key('members-branch-filter-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('members-generation-filter-dropdown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('member-search-result-m1')), findsOneWidget);
    expect(find.byKey(const Key('member-search-result-m2')), findsOneWidget);
  });

  testWidgets('shows loading state while a search request is in-flight', (
    tester,
  ) async {
    final provider = _ControlledSearchProvider();
    await pumpWorkspace(
      tester,
      repository: repository,
      searchProvider: provider,
    );
    await scrollToSearchSection(
      tester,
      find.byKey(const Key('members-search-input')),
    );

    provider.holdNextSearch = true;
    await tester.enterText(find.byKey(const Key('members-search-input')), 'An');
    await tester.pump();

    expect(
      find.byKey(const Key('member-search-loading-state')),
      findsOneWidget,
    );

    provider.releasePendingSearch();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-search-loading-state')), findsNothing);
  });

  testWidgets('shows retry state when search fails', (tester) async {
    final provider = _AlwaysFailSearchProvider();
    await pumpWorkspace(
      tester,
      repository: repository,
      searchProvider: provider,
    );
    await scrollToSearchSection(
      tester,
      find.byKey(const Key('member-search-error-state')),
    );

    expect(find.byKey(const Key('member-search-error-state')), findsOneWidget);
    expect(provider.calls, greaterThan(0));

    await tester.tap(find.byKey(const Key('member-search-retry-action')));
    await tester.pumpAndSettle();

    expect(provider.calls, greaterThan(1));
    expect(find.byKey(const Key('member-search-error-state')), findsOneWidget);
  });

  testWidgets('shows empty state and supports clearing active filters', (
    tester,
  ) async {
    await pumpWorkspace(
      tester,
      repository: repository,
      searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
    );
    await scrollToSearchSection(
      tester,
      find.byKey(const Key('members-search-input')),
    );

    await tester.enterText(
      find.byKey(const Key('members-search-input')),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-search-empty-state')), findsOneWidget);
    expect(find.byKey(const Key('members-clear-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('members-clear-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-search-empty-state')), findsNothing);
    expect(find.byKey(const Key('member-search-result-m1')), findsOneWidget);
  });
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({required this.members});

  final List<MemberProfile> members;

  @override
  bool get isSandbox => true;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    return MemberWorkspaceSnapshot(
      members: members,
      branches: const [
        BranchProfile(
          id: 'b1',
          clanId: 'c1',
          name: 'Branch 1',
          code: 'B1',
          leaderMemberId: null,
          viceLeaderMemberId: null,
          generationLevelHint: 1,
          status: 'active',
          memberCount: 1,
        ),
        BranchProfile(
          id: 'b2',
          clanId: 'c1',
          name: 'Branch 2',
          code: 'B2',
          leaderMemberId: null,
          viceLeaderMemberId: null,
          generationLevelHint: 1,
          status: 'active',
          memberCount: 1,
        ),
      ],
    );
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateMemberLiveLocation({
    required AuthSession session,
    required String memberId,
    required bool sharingEnabled,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {}

  @override
  Future<void> notifyNearbyRelativesDetected({
    required AuthSession session,
    required String clanId,
    required String memberId,
    required List<String> relativeMemberIds,
    double? closestDistanceKm,
  }) async {}
}

class _ControlledSearchProvider implements MemberSearchProvider {
  bool holdNextSearch = false;
  Completer<List<MemberProfile>>? _pendingCompleter;

  @override
  Future<List<MemberProfile>> search({
    required List<MemberProfile> members,
    required MemberSearchQuery query,
  }) {
    if (holdNextSearch) {
      _pendingCompleter ??= Completer<List<MemberProfile>>();
      return _pendingCompleter!.future;
    }

    return Future<List<MemberProfile>>.value(members);
  }

  void releasePendingSearch() {
    holdNextSearch = false;
    if (_pendingCompleter == null || _pendingCompleter!.isCompleted) {
      return;
    }
    _pendingCompleter!.complete(<MemberProfile>[]);
    _pendingCompleter = null;
  }
}

class _AlwaysFailSearchProvider implements MemberSearchProvider {
  int calls = 0;

  @override
  Future<List<MemberProfile>> search({
    required List<MemberProfile> members,
    required MemberSearchQuery query,
  }) async {
    calls += 1;
    throw Exception('search failed');
  }
}
