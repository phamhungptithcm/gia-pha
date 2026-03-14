import '../../member/models/member_profile.dart';
import 'genealogy_generation_label.dart';

class GenealogyGraph {
  const GenealogyGraph({
    required this.membersById,
    required this.parentMap,
    required this.childMap,
    required this.spouseMap,
    required this.siblingGroups,
    required this.generationLabels,
  });

  final Map<String, MemberProfile> membersById;
  final Map<String, List<String>> parentMap;
  final Map<String, List<String>> childMap;
  final Map<String, List<String>> spouseMap;
  final Map<String, List<String>> siblingGroups;
  final Map<String, GenealogyGenerationLabel> generationLabels;

  List<String> parentsOf(String memberId) => parentMap[memberId] ?? const [];

  List<String> childrenOf(String memberId) => childMap[memberId] ?? const [];

  List<String> spousesOf(String memberId) => spouseMap[memberId] ?? const [];

  List<String> siblingsOf(String memberId) =>
      siblingGroups[memberId] ?? const [];
}
