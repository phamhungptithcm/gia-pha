import '../../support/core/services/debug_genealogy_store.dart';
import '../../support/features/genealogy/services/debug_genealogy_read_repository.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/models/branch_profile.dart';
import 'package:befam/features/genealogy/presentation/genealogy_workspace_page.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/relationship/models/relationship_record.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _runGenealogyBenchmarks = bool.fromEnvironment(
  'RUN_GENEALOGY_BENCHMARKS',
);

void main() {
  Future<void> scrollToTreeWorkspace(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('tree-zoom-in')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  AuthSession buildSession({required String memberId}) {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Benchmark Admin',
      memberId: memberId,
      clanId: 'clan_benchmark_001',
      branchId: 'branch_bench_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 20).toIso8601String(),
    );
  }

  int countTreeNodes(WidgetTester tester) {
    final finder = find.byWidgetPredicate((widget) {
      final key = widget.key;
      if (key is! ValueKey<String>) {
        return false;
      }
      final value = key.value;
      return value.startsWith('tree-node-') &&
          !value.startsWith('tree-node-info-');
    });
    return finder.evaluate().length;
  }

  testWidgets(
    'benchmark render for 200/400/700 members on low-ram profile',
    (tester) async {
      final scenarios = [200, 400, 700];
      final elapsedMsByScenario = <int, int>{};
      final visibleNodeCountByScenario = <int, int>{};

      for (final memberCount in scenarios) {
        final store = _buildSyntheticStore(memberCount: memberCount);
        final repository = DebugGenealogyReadRepository(store: store);
        final session = buildSession(memberId: 'member_bench_00001');
        final stopwatch = Stopwatch()..start();

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
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 740),
                devicePixelRatio: 2.0,
                textScaler: TextScaler.linear(1),
              ),
              child: Scaffold(
                body: GenealogyWorkspacePage(
                  session: session,
                  repository: repository,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        await scrollToTreeWorkspace(tester);
        stopwatch.stop();

        final visibleNodeCount = countTreeNodes(tester);
        elapsedMsByScenario[memberCount] = stopwatch.elapsedMilliseconds;
        visibleNodeCountByScenario[memberCount] = visibleNodeCount;
        debugPrint(
          '[genealogy-benchmark] members=$memberCount '
          'elapsedMs=${stopwatch.elapsedMilliseconds} '
          'visibleNodes=$visibleNodeCount',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }

      final benchmarkSummary = scenarios
          .map((scenario) {
            final elapsed = elapsedMsByScenario[scenario] ?? 0;
            final visibleNodes = visibleNodeCountByScenario[scenario] ?? 0;
            return '$scenario:$elapsed ms, visible=$visibleNodes';
          })
          .join(' | ');
      debugPrint('[genealogy-benchmark-summary] $benchmarkSummary');

      expect(elapsedMsByScenario[200] ?? 999999, lessThan(5500));
      expect(elapsedMsByScenario[400] ?? 999999, lessThan(8500));
      expect(elapsedMsByScenario[700] ?? 999999, lessThan(12000));
      expect(visibleNodeCountByScenario[700] ?? 0, lessThanOrEqualTo(220));
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !_runGenealogyBenchmarks,
  );
}

DebugGenealogyStore _buildSyntheticStore({required int memberCount}) {
  const clanId = 'clan_benchmark_001';
  final members = <String, MemberProfile>{};
  final relationships = <String, RelationshipRecord>{};
  var memberSeed = 0;

  String nextMemberId() {
    memberSeed += 1;
    return 'member_bench_${memberSeed.toString().padLeft(5, '0')}';
  }

  MemberProfile buildMember({
    required String id,
    required int generation,
    required bool isFemale,
    required String branchId,
  }) {
    final role = generation == 1 ? 'CLAN_ADMIN' : 'MEMBER';
    final indexLabel = id.substring(id.length - 3);
    final fullName = isFemale
        ? 'Nguyễn Thị Benchmark $indexLabel'
        : 'Nguyễn Văn Benchmark $indexLabel';
    return MemberProfile(
      id: id,
      clanId: clanId,
      branchId: branchId,
      fullName: fullName,
      normalizedFullName: fullName.toLowerCase(),
      nickName: 'Bench $indexLabel',
      gender: isFemale ? 'female' : 'male',
      birthDate: '${1900 + generation}-01-01',
      deathDate: generation < 4 ? '${1950 + generation}-01-01' : null,
      phoneE164: null,
      email: null,
      addressText: 'Đà Nẵng, Việt Nam',
      jobTitle: generation > 8 ? 'Học sinh' : 'Kỹ sư',
      avatarUrl: null,
      bio: 'Synthetic benchmark member',
      socialLinks: const MemberSocialLinks(),
      parentIds: const [],
      childrenIds: const [],
      spouseIds: const [],
      generation: generation,
      primaryRole: role,
      status: generation < 4 ? 'deceased' : 'active',
      isMinor: generation > 9,
      authUid: null,
    );
  }

  final branches = <String, BranchProfile>{
    'branch_bench_001': const BranchProfile(
      id: 'branch_bench_001',
      clanId: clanId,
      name: 'Chi Bắc',
      code: 'B01',
      leaderMemberId: null,
      viceLeaderMemberId: null,
      generationLevelHint: 1,
      status: 'active',
      memberCount: 0,
    ),
    'branch_bench_002': const BranchProfile(
      id: 'branch_bench_002',
      clanId: clanId,
      name: 'Chi Trung',
      code: 'B02',
      leaderMemberId: null,
      viceLeaderMemberId: null,
      generationLevelHint: 1,
      status: 'active',
      memberCount: 0,
    ),
    'branch_bench_003': const BranchProfile(
      id: 'branch_bench_003',
      clanId: clanId,
      name: 'Chi Nam',
      code: 'B03',
      leaderMemberId: null,
      viceLeaderMemberId: null,
      generationLevelHint: 1,
      status: 'active',
      memberCount: 0,
    ),
  };

  final activeCouples = <_SyntheticCouple>[];
  final rootMaleId = nextMemberId();
  final rootFemaleId = nextMemberId();
  members[rootMaleId] = buildMember(
    id: rootMaleId,
    generation: 1,
    isFemale: false,
    branchId: 'branch_bench_001',
  );
  members[rootFemaleId] = buildMember(
    id: rootFemaleId,
    generation: 1,
    isFemale: true,
    branchId: 'branch_bench_001',
  );
  relationships['rel_spouse_${rootMaleId}_$rootFemaleId'] = RelationshipRecord(
    id: 'rel_spouse_${rootMaleId}_$rootFemaleId',
    clanId: clanId,
    personAId: rootMaleId,
    personBId: rootFemaleId,
    type: RelationshipType.spouse,
    direction: RelationshipDirection.undirected,
    status: 'active',
    source: 'benchmark',
  );
  activeCouples.add(
    const _SyntheticCouple(
      maleId: 'member_bench_00001',
      femaleId: 'member_bench_00002',
      generation: 1,
    ),
  );

  while (members.length < memberCount && activeCouples.isNotEmpty) {
    final nextGenerationCouples = <_SyntheticCouple>[];
    for (final couple in activeCouples) {
      for (var childIndex = 0; childIndex < 2; childIndex++) {
        if (members.length >= memberCount) {
          break;
        }
        final generation = couple.generation + 1;
        final branchId = switch (generation % 3) {
          1 => 'branch_bench_001',
          2 => 'branch_bench_002',
          _ => 'branch_bench_003',
        };
        final childMaleId = nextMemberId();
        members[childMaleId] = buildMember(
          id: childMaleId,
          generation: generation,
          isFemale: false,
          branchId: branchId,
        );
        relationships['rel_parent_child_${couple.maleId}_$childMaleId'] =
            RelationshipRecord(
              id: 'rel_parent_child_${couple.maleId}_$childMaleId',
              clanId: clanId,
              personAId: couple.maleId,
              personBId: childMaleId,
              type: RelationshipType.parentChild,
              direction: RelationshipDirection.aToB,
              status: 'active',
              source: 'benchmark',
            );
        relationships['rel_parent_child_${couple.femaleId}_$childMaleId'] =
            RelationshipRecord(
              id: 'rel_parent_child_${couple.femaleId}_$childMaleId',
              clanId: clanId,
              personAId: couple.femaleId,
              personBId: childMaleId,
              type: RelationshipType.parentChild,
              direction: RelationshipDirection.aToB,
              status: 'active',
              source: 'benchmark',
            );

        if (members.length >= memberCount) {
          continue;
        }
        final spouseFemaleId = nextMemberId();
        members[spouseFemaleId] = buildMember(
          id: spouseFemaleId,
          generation: generation,
          isFemale: true,
          branchId: branchId,
        );
        relationships['rel_spouse_${childMaleId}_$spouseFemaleId'] =
            RelationshipRecord(
              id: 'rel_spouse_${childMaleId}_$spouseFemaleId',
              clanId: clanId,
              personAId: childMaleId,
              personBId: spouseFemaleId,
              type: RelationshipType.spouse,
              direction: RelationshipDirection.undirected,
              status: 'active',
              source: 'benchmark',
            );
        nextGenerationCouples.add(
          _SyntheticCouple(
            maleId: childMaleId,
            femaleId: spouseFemaleId,
            generation: generation,
          ),
        );
      }
      if (members.length >= memberCount) {
        break;
      }
    }
    activeCouples
      ..clear()
      ..addAll(nextGenerationCouples);
  }

  return DebugGenealogyStore(
    members: members,
    branches: branches,
    funds: const {},
    transactions: const {},
    relationships: relationships,
    events: const {},
  )..reconcileRelationshipFields(clanId);
}

class _SyntheticCouple {
  const _SyntheticCouple({
    required this.maleId,
    required this.femaleId,
    required this.generation,
  });

  final String maleId;
  final String femaleId;
  final int generation;
}
