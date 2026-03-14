// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => _AuthSession(
  uid: json['uid'] as String,
  loginMethod: $enumDecode(_$AuthEntryMethodEnumMap, json['loginMethod']),
  phoneE164: json['phoneE164'] as String,
  displayName: json['displayName'] as String,
  childIdentifier: json['childIdentifier'] as String?,
  memberId: json['memberId'] as String?,
  clanId: json['clanId'] as String?,
  branchId: json['branchId'] as String?,
  primaryRole: json['primaryRole'] as String?,
  accessMode:
      $enumDecodeNullable(_$AuthMemberAccessModeEnumMap, json['accessMode']) ??
      AuthMemberAccessMode.unlinked,
  linkedAuthUid: json['linkedAuthUid'] as bool? ?? false,
  isSandbox: json['isSandbox'] as bool? ?? false,
  signedInAtIso: json['signedInAtIso'] as String,
);

Map<String, dynamic> _$AuthSessionToJson(_AuthSession instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'loginMethod': _$AuthEntryMethodEnumMap[instance.loginMethod]!,
      'phoneE164': instance.phoneE164,
      'displayName': instance.displayName,
      'childIdentifier': instance.childIdentifier,
      'memberId': instance.memberId,
      'clanId': instance.clanId,
      'branchId': instance.branchId,
      'primaryRole': instance.primaryRole,
      'accessMode': _$AuthMemberAccessModeEnumMap[instance.accessMode]!,
      'linkedAuthUid': instance.linkedAuthUid,
      'isSandbox': instance.isSandbox,
      'signedInAtIso': instance.signedInAtIso,
    };

const _$AuthEntryMethodEnumMap = {
  AuthEntryMethod.phone: 'phone',
  AuthEntryMethod.child: 'child',
};

const _$AuthMemberAccessModeEnumMap = {
  AuthMemberAccessMode.unlinked: 'unlinked',
  AuthMemberAccessMode.claimed: 'claimed',
  AuthMemberAccessMode.child: 'child',
};
