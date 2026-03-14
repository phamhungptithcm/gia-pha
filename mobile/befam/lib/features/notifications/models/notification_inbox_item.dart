import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationInboxTarget { event, scholarship, generic, unknown }

class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.memberId,
    required this.clanId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.target,
    required this.data,
    this.targetId,
  });

  final String id;
  final String memberId;
  final String clanId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final NotificationInboxTarget target;
  final String? targetId;
  final Map<String, String> data;

  bool get isUnread => !isRead;

  factory NotificationInboxItem.fromFirestore({
    required String documentId,
    required Map<String, dynamic> json,
  }) {
    final dataPayload = _readStringMap(json['data']);
    final type = _readString(json['type']);
    final target = _resolveTarget(type: type, data: dataPayload);

    return NotificationInboxItem(
      id: _readString(json['id'], fallback: documentId),
      memberId: _readString(json['memberId']),
      clanId: _readString(json['clanId']),
      type: type,
      title: _readString(json['title']),
      body: _readString(json['body']),
      isRead: json['isRead'] == true,
      createdAt: _readDateTime(json['createdAt']) ?? DateTime.now(),
      target: target,
      targetId: _firstNonEmpty([
        dataPayload['id'],
        dataPayload['eventId'],
        dataPayload['submissionId'],
        dataPayload['scholarshipSubmissionId'],
      ]),
      data: dataPayload,
    );
  }

  static NotificationInboxTarget _resolveTarget({
    required String type,
    required Map<String, String> data,
  }) {
    final targetRaw = data['target']?.trim().toLowerCase() ?? '';
    switch (targetRaw) {
      case 'event':
        return NotificationInboxTarget.event;
      case 'scholarship':
        return NotificationInboxTarget.scholarship;
      case 'generic':
        return NotificationInboxTarget.generic;
    }

    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.contains('event')) {
      return NotificationInboxTarget.event;
    }
    if (normalizedType.contains('scholarship')) {
      return NotificationInboxTarget.scholarship;
    }
    if (normalizedType.isNotEmpty) {
      return NotificationInboxTarget.generic;
    }
    return NotificationInboxTarget.unknown;
  }
}

String _readString(Object? value, {String fallback = ''}) {
  return switch (value) {
    String v when v.trim().isNotEmpty => v.trim(),
    String _ => fallback,
    _ => fallback,
  };
}

Map<String, String> _readStringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }

  final mapped = <String, String>{};
  value.forEach((key, rawValue) {
    final normalizedKey = _readString(key);
    final normalizedValue = _readString(rawValue);
    if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
      return;
    }
    mapped[normalizedKey] = normalizedValue;
  });
  return mapped;
}

DateTime? _readDateTime(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
    String raw => DateTime.tryParse(raw),
    _ => null,
  };
}

String? _firstNonEmpty(List<String?> values) {
  for (final candidate in values) {
    final normalized = candidate?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}
