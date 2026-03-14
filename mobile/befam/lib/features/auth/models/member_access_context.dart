import 'auth_member_access_mode.dart';

class MemberAccessContext {
  const MemberAccessContext({
    this.memberId,
    this.displayName,
    this.clanId,
    this.branchId,
    this.primaryRole,
    required this.accessMode,
    required this.linkedAuthUid,
  });

  const MemberAccessContext.unlinked({this.displayName})
    : memberId = null,
      clanId = null,
      branchId = null,
      primaryRole = null,
      accessMode = AuthMemberAccessMode.unlinked,
      linkedAuthUid = false;

  final String? memberId;
  final String? displayName;
  final String? clanId;
  final String? branchId;
  final String? primaryRole;
  final AuthMemberAccessMode accessMode;
  final bool linkedAuthUid;

  factory MemberAccessContext.fromFunctionsData(dynamic data) {
    final payload = data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};

    return MemberAccessContext(
      memberId: _stringOrNull(payload['memberId']),
      displayName: _stringOrNull(payload['displayName']),
      clanId: _stringOrNull(payload['clanId']),
      branchId: _stringOrNull(payload['branchId']),
      primaryRole: _stringOrNull(payload['primaryRole']),
      accessMode: _accessModeFrom(payload['accessMode']),
      linkedAuthUid: payload['linkedAuthUid'] == true,
    );
  }
}

String? _stringOrNull(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return value;
}

AuthMemberAccessMode _accessModeFrom(dynamic value) {
  if (value is String) {
    return switch (value) {
      'claimed' => AuthMemberAccessMode.claimed,
      'child' => AuthMemberAccessMode.child,
      _ => AuthMemberAccessMode.unlinked,
    };
  }

  return AuthMemberAccessMode.unlinked;
}
