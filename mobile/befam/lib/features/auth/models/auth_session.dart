import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_entry_method.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String uid,
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    required String displayName,
    String? childIdentifier,
    String? memberId,
    @Default(false) bool isSandbox,
    required String signedInAtIso,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}
