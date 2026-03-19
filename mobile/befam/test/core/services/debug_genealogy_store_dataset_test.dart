import '../../support/core/services/debug_genealogy_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared production-like dataset has at least 50 members and 10 generations',
    () {
      final store = DebugGenealogyStore.sharedSeeded();

      expect(store.members.length, greaterThanOrEqualTo(50));

      final generations = store.members.values
          .map((member) => member.generation)
          .toSet();
      expect(generations.containsAll({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}), isTrue);
    },
  );

  test('reference user profile is mapped as child of reference parents', () {
    final store = DebugGenealogyStore.sharedSeeded();
    final member = store.members['member_prod_a_g8_a'];

    expect(member, isNotNull);
    expect(member!.generation, 8);
    expect(member.parentIds, contains('member_prod_a_g7_a'));
    expect(member.parentIds, contains('member_prod_a_g7_b'));
  });

  test(
    'dataset includes multiple independent lineage roots for stress testing',
    () {
      final store = DebugGenealogyStore.sharedSeeded();

      expect(store.members.containsKey('member_prod_a_g1_a'), isTrue);
      expect(store.members.containsKey('member_prod_b_g1_a'), isTrue);
      expect(store.members.containsKey('member_prod_c_g1_a'), isTrue);

      expect(store.branches.containsKey('branch_demo_003'), isTrue);
      expect(store.branches.containsKey('branch_demo_004'), isTrue);
      expect(store.branches.containsKey('branch_demo_005'), isTrue);
    },
  );
}
