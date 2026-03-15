import 'fund_profile.dart';

class FundDraft {
  const FundDraft({
    this.clanId,
    required this.name,
    required this.description,
    required this.fundType,
    required this.currency,
    this.branchId,
    this.appliedMemberIds = const [],
  });

  final String? clanId;
  final String name;
  final String description;
  final String fundType;
  final String currency;
  final String? branchId;
  final List<String> appliedMemberIds;

  factory FundDraft.empty() {
    return const FundDraft(
      name: '',
      description: '',
      fundType: 'scholarship',
      currency: 'VND',
    );
  }

  factory FundDraft.fromProfile(FundProfile profile) {
    return FundDraft(
      clanId: profile.clanId,
      name: profile.name,
      description: profile.description,
      fundType: profile.fundType,
      currency: profile.currency,
      branchId: profile.branchId,
      appliedMemberIds: profile.appliedMemberIds,
    );
  }

  FundDraft copyWith({
    String? clanId,
    bool clearClanId = false,
    String? name,
    String? description,
    String? fundType,
    String? currency,
    String? branchId,
    bool clearBranchId = false,
    List<String>? appliedMemberIds,
  }) {
    return FundDraft(
      clanId: clearClanId ? null : (clanId ?? this.clanId),
      name: name ?? this.name,
      description: description ?? this.description,
      fundType: fundType ?? this.fundType,
      currency: currency ?? this.currency,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      appliedMemberIds:
          appliedMemberIds == null
              ? this.appliedMemberIds
              : List<String>.unmodifiable(appliedMemberIds),
    );
  }
}
