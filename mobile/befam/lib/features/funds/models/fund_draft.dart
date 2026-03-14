import 'fund_profile.dart';

class FundDraft {
  const FundDraft({
    required this.name,
    required this.description,
    required this.fundType,
    required this.currency,
    this.branchId,
  });

  final String name;
  final String description;
  final String fundType;
  final String currency;
  final String? branchId;

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
      name: profile.name,
      description: profile.description,
      fundType: profile.fundType,
      currency: profile.currency,
      branchId: profile.branchId,
    );
  }

  FundDraft copyWith({
    String? name,
    String? description,
    String? fundType,
    String? currency,
    String? branchId,
    bool clearBranchId = false,
  }) {
    return FundDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      fundType: fundType ?? this.fundType,
      currency: currency ?? this.currency,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
    );
  }
}
