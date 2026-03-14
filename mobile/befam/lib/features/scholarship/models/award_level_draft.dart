class AwardLevelDraft {
  const AwardLevelDraft({
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.rewardType,
    required this.rewardAmountMinor,
    required this.criteriaText,
    required this.status,
  });

  const AwardLevelDraft.empty()
    : name = '',
      description = '',
      sortOrder = 10,
      rewardType = 'cash',
      rewardAmountMinor = 0,
      criteriaText = '',
      status = 'active';

  final String name;
  final String description;
  final int sortOrder;
  final String rewardType;
  final int rewardAmountMinor;
  final String criteriaText;
  final String status;

  AwardLevelDraft copyWith({
    String? name,
    String? description,
    int? sortOrder,
    String? rewardType,
    int? rewardAmountMinor,
    String? criteriaText,
    String? status,
  }) {
    return AwardLevelDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      rewardType: rewardType ?? this.rewardType,
      rewardAmountMinor: rewardAmountMinor ?? this.rewardAmountMinor,
      criteriaText: criteriaText ?? this.criteriaText,
      status: status ?? this.status,
    );
  }
}
