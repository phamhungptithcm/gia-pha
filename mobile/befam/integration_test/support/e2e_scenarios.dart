import 'package:befam/features/auth/models/auth_member_access_mode.dart';

class E2ELoginScenario {
  const E2ELoginScenario({
    required this.code,
    required this.phoneInput,
    required this.description,
    required this.expectedAccessMode,
    required this.expectedRole,
    this.expectedClanId,
    this.expectedBranchId,
  });

  final String code;
  final String phoneInput;
  final String description;
  final AuthMemberAccessMode expectedAccessMode;
  final String expectedRole;
  final String? expectedClanId;
  final String? expectedBranchId;
}

const E2ELoginScenario clanLeaderExistingGenealogy = E2ELoginScenario(
  code: 'SCENARIO_01',
  phoneInput: '0901234567',
  description: 'Clan leader with existing genealogy',
  expectedAccessMode: AuthMemberAccessMode.claimed,
  expectedRole: 'CLAN_ADMIN',
  expectedClanId: 'clan_demo_001',
  expectedBranchId: 'branch_demo_001',
);

const E2ELoginScenario branchLeaderExistingGenealogy = E2ELoginScenario(
  code: 'SCENARIO_02',
  phoneInput: '0908886655',
  description: 'Branch leader with existing genealogy',
  expectedAccessMode: AuthMemberAccessMode.claimed,
  expectedRole: 'BRANCH_ADMIN',
  expectedClanId: 'clan_demo_001',
  expectedBranchId: 'branch_demo_002',
);

const E2ELoginScenario linkedNormalMember = E2ELoginScenario(
  code: 'SCENARIO_03',
  phoneInput: '0907770011',
  description: 'Normal member already linked',
  expectedAccessMode: AuthMemberAccessMode.claimed,
  expectedRole: 'MEMBER',
  expectedClanId: 'clan_demo_001',
  expectedBranchId: 'branch_demo_002',
);

const E2ELoginScenario unlinkedUser = E2ELoginScenario(
  code: 'SCENARIO_04',
  phoneInput: '0906660022',
  description: 'User not linked to any genealogy',
  expectedAccessMode: AuthMemberAccessMode.unlinked,
  expectedRole: 'GUEST',
);

const E2ELoginScenario branchLeaderNoGenealogy = E2ELoginScenario(
  code: 'SCENARIO_05',
  phoneInput: '0905550033',
  description: 'Branch leader role but no genealogy linked',
  expectedAccessMode: AuthMemberAccessMode.unlinked,
  expectedRole: 'BRANCH_ADMIN',
);

const E2ELoginScenario clanLeaderNoGenealogy = E2ELoginScenario(
  code: 'SCENARIO_06',
  phoneInput: '0909990001',
  description: 'Clan leader role but no genealogy created',
  expectedAccessMode: AuthMemberAccessMode.claimed,
  expectedRole: 'CLAN_ADMIN',
  expectedClanId: 'clan_onboarding_001',
);

const List<E2ELoginScenario> allDebugLoginScenarios = [
  clanLeaderExistingGenealogy,
  branchLeaderExistingGenealogy,
  linkedNormalMember,
  unlinkedUser,
  branchLeaderNoGenealogy,
  clanLeaderNoGenealogy,
];
