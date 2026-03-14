import 'package:cloud_firestore/cloud_firestore.dart';

enum RelationshipType {
  parentChild('parent_child'),
  spouse('spouse');

  const RelationshipType(this.wireName);

  final String wireName;

  static RelationshipType? fromWireName(String? value) {
    return switch (value) {
      'parent_child' => RelationshipType.parentChild,
      'spouse' => RelationshipType.spouse,
      _ => null,
    };
  }
}

enum RelationshipDirection {
  aToB('A_TO_B'),
  undirected('UNDIRECTED');

  const RelationshipDirection(this.wireName);

  final String wireName;

  static RelationshipDirection fromWireName(String? value) {
    return switch (value) {
      'A_TO_B' => RelationshipDirection.aToB,
      _ => RelationshipDirection.undirected,
    };
  }
}

class RelationshipRecord {
  const RelationshipRecord({
    required this.id,
    required this.clanId,
    required this.personAId,
    required this.personBId,
    required this.type,
    required this.direction,
    required this.status,
    required this.source,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clanId;
  final String personAId;
  final String personBId;
  final RelationshipType type;
  final RelationshipDirection direction;
  final String status;
  final String source;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status.trim().toLowerCase() == 'active';

  bool involves(String memberId) {
    return personAId == memberId || personBId == memberId;
  }

  String? relatedMemberIdFor(String memberId) {
    if (personAId == memberId) {
      return personBId;
    }
    if (personBId == memberId) {
      return personAId;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'personA': personAId,
      'personB': personBId,
      'type': type.wireName,
      'direction': direction.wireName,
      'status': status,
      'source': source,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory RelationshipRecord.fromJson(Map<String, dynamic> json) {
    return RelationshipRecord(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      personAId: json['personA'] as String? ?? '',
      personBId: json['personB'] as String? ?? '',
      type:
          RelationshipType.fromWireName(json['type'] as String?) ??
          RelationshipType.parentChild,
      direction: RelationshipDirection.fromWireName(
        json['direction'] as String?,
      ),
      status: json['status'] as String? ?? 'active',
      source: json['source'] as String? ?? 'manual',
      createdBy: json['createdBy'] as String?,
      createdAt: _dateTimeOrNull(json['createdAt']),
      updatedAt: _dateTimeOrNull(json['updatedAt']),
    );
  }
}

DateTime? _dateTimeOrNull(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
