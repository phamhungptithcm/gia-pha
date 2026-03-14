class ClanProfile {
  const ClanProfile({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.countryCode,
    required this.founderName,
    required this.logoUrl,
    required this.status,
    required this.memberCount,
    required this.branchCount,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String countryCode;
  final String founderName;
  final String logoUrl;
  final String status;
  final int memberCount;
  final int branchCount;

  ClanProfile copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? countryCode,
    String? founderName,
    String? logoUrl,
    String? status,
    int? memberCount,
    int? branchCount,
  }) {
    return ClanProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      countryCode: countryCode ?? this.countryCode,
      founderName: founderName ?? this.founderName,
      logoUrl: logoUrl ?? this.logoUrl,
      status: status ?? this.status,
      memberCount: memberCount ?? this.memberCount,
      branchCount: branchCount ?? this.branchCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'countryCode': countryCode,
      'founderName': founderName,
      'logoUrl': logoUrl,
      'status': status,
      'memberCount': memberCount,
      'branchCount': branchCount,
    };
  }

  factory ClanProfile.fromJson(Map<String, dynamic> json) {
    return ClanProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      founderName: json['founderName'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      memberCount: json['memberCount'] as int? ?? 0,
      branchCount: json['branchCount'] as int? ?? 0,
    );
  }
}
