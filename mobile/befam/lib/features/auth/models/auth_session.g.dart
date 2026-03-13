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
      'isSandbox': instance.isSandbox,
      'signedInAtIso': instance.signedInAtIso,
    };

const _$AuthEntryMethodEnumMap = {
  AuthEntryMethod.phone: 'phone',
  AuthEntryMethod.child: 'child',
};
