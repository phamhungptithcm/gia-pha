import 'clan_profile.dart';

class ClanDraft {
  const ClanDraft({
    required this.name,
    required this.slug,
    required this.description,
    required this.countryCode,
    required this.founderName,
    required this.logoUrl,
    this.status = 'active',
  });

  final String name;
  final String slug;
  final String description;
  final String countryCode;
  final String founderName;
  final String logoUrl;
  final String status;

  ClanDraft copyWith({
    String? name,
    String? slug,
    String? description,
    String? countryCode,
    String? founderName,
    String? logoUrl,
    String? status,
  }) {
    return ClanDraft(
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      countryCode: countryCode ?? this.countryCode,
      founderName: founderName ?? this.founderName,
      logoUrl: logoUrl ?? this.logoUrl,
      status: status ?? this.status,
    );
  }

  factory ClanDraft.empty() {
    return const ClanDraft(
      name: '',
      slug: '',
      description: '',
      countryCode: 'VN',
      founderName: '',
      logoUrl: '',
    );
  }

  factory ClanDraft.fromProfile(ClanProfile profile) {
    return ClanDraft(
      name: profile.name,
      slug: profile.slug,
      description: profile.description,
      countryCode: profile.countryCode,
      founderName: profile.founderName,
      logoUrl: profile.logoUrl,
      status: profile.status,
    );
  }
}
