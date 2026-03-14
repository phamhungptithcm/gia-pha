// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthSession {

 String get uid; AuthEntryMethod get loginMethod; String get phoneE164; String get displayName; String? get childIdentifier; String? get memberId; bool get isSandbox; String get signedInAtIso;
/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionCopyWith<AuthSession> get copyWith => _$AuthSessionCopyWithImpl<AuthSession>(this as AuthSession, _$identity);

  /// Serializes this AuthSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSession&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.loginMethod, loginMethod) || other.loginMethod == loginMethod)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.childIdentifier, childIdentifier) || other.childIdentifier == childIdentifier)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.isSandbox, isSandbox) || other.isSandbox == isSandbox)&&(identical(other.signedInAtIso, signedInAtIso) || other.signedInAtIso == signedInAtIso));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uid,loginMethod,phoneE164,displayName,childIdentifier,memberId,isSandbox,signedInAtIso);

@override
String toString() {
  return 'AuthSession(uid: $uid, loginMethod: $loginMethod, phoneE164: $phoneE164, displayName: $displayName, childIdentifier: $childIdentifier, memberId: $memberId, isSandbox: $isSandbox, signedInAtIso: $signedInAtIso)';
}


}

/// @nodoc
abstract mixin class $AuthSessionCopyWith<$Res>  {
  factory $AuthSessionCopyWith(AuthSession value, $Res Function(AuthSession) _then) = _$AuthSessionCopyWithImpl;
@useResult
$Res call({
 String uid, AuthEntryMethod loginMethod, String phoneE164, String displayName, String? childIdentifier, String? memberId, bool isSandbox, String signedInAtIso
});




}
/// @nodoc
class _$AuthSessionCopyWithImpl<$Res>
    implements $AuthSessionCopyWith<$Res> {
  _$AuthSessionCopyWithImpl(this._self, this._then);

  final AuthSession _self;
  final $Res Function(AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? loginMethod = null,Object? phoneE164 = null,Object? displayName = null,Object? childIdentifier = freezed,Object? memberId = freezed,Object? isSandbox = null,Object? signedInAtIso = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,loginMethod: null == loginMethod ? _self.loginMethod : loginMethod // ignore: cast_nullable_to_non_nullable
as AuthEntryMethod,phoneE164: null == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,childIdentifier: freezed == childIdentifier ? _self.childIdentifier : childIdentifier // ignore: cast_nullable_to_non_nullable
as String?,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,isSandbox: null == isSandbox ? _self.isSandbox : isSandbox // ignore: cast_nullable_to_non_nullable
as bool,signedInAtIso: null == signedInAtIso ? _self.signedInAtIso : signedInAtIso // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthSession].
extension AuthSessionPatterns on AuthSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthSession value)  $default,){
final _that = this;
switch (_that) {
case _AuthSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthSession value)?  $default,){
final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid,  AuthEntryMethod loginMethod,  String phoneE164,  String displayName,  String? childIdentifier,  String? memberId,  bool isSandbox,  String signedInAtIso)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that.uid,_that.loginMethod,_that.phoneE164,_that.displayName,_that.childIdentifier,_that.memberId,_that.isSandbox,_that.signedInAtIso);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid,  AuthEntryMethod loginMethod,  String phoneE164,  String displayName,  String? childIdentifier,  String? memberId,  bool isSandbox,  String signedInAtIso)  $default,) {final _that = this;
switch (_that) {
case _AuthSession():
return $default(_that.uid,_that.loginMethod,_that.phoneE164,_that.displayName,_that.childIdentifier,_that.memberId,_that.isSandbox,_that.signedInAtIso);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid,  AuthEntryMethod loginMethod,  String phoneE164,  String displayName,  String? childIdentifier,  String? memberId,  bool isSandbox,  String signedInAtIso)?  $default,) {final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that.uid,_that.loginMethod,_that.phoneE164,_that.displayName,_that.childIdentifier,_that.memberId,_that.isSandbox,_that.signedInAtIso);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthSession implements AuthSession {
  const _AuthSession({required this.uid, required this.loginMethod, required this.phoneE164, required this.displayName, this.childIdentifier, this.memberId, this.isSandbox = false, required this.signedInAtIso});
  factory _AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);

@override final  String uid;
@override final  AuthEntryMethod loginMethod;
@override final  String phoneE164;
@override final  String displayName;
@override final  String? childIdentifier;
@override final  String? memberId;
@override@JsonKey() final  bool isSandbox;
@override final  String signedInAtIso;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthSessionCopyWith<_AuthSession> get copyWith => __$AuthSessionCopyWithImpl<_AuthSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthSession&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.loginMethod, loginMethod) || other.loginMethod == loginMethod)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.childIdentifier, childIdentifier) || other.childIdentifier == childIdentifier)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.isSandbox, isSandbox) || other.isSandbox == isSandbox)&&(identical(other.signedInAtIso, signedInAtIso) || other.signedInAtIso == signedInAtIso));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uid,loginMethod,phoneE164,displayName,childIdentifier,memberId,isSandbox,signedInAtIso);

@override
String toString() {
  return 'AuthSession(uid: $uid, loginMethod: $loginMethod, phoneE164: $phoneE164, displayName: $displayName, childIdentifier: $childIdentifier, memberId: $memberId, isSandbox: $isSandbox, signedInAtIso: $signedInAtIso)';
}


}

/// @nodoc
abstract mixin class _$AuthSessionCopyWith<$Res> implements $AuthSessionCopyWith<$Res> {
  factory _$AuthSessionCopyWith(_AuthSession value, $Res Function(_AuthSession) _then) = __$AuthSessionCopyWithImpl;
@override @useResult
$Res call({
 String uid, AuthEntryMethod loginMethod, String phoneE164, String displayName, String? childIdentifier, String? memberId, bool isSandbox, String signedInAtIso
});




}
/// @nodoc
class __$AuthSessionCopyWithImpl<$Res>
    implements _$AuthSessionCopyWith<$Res> {
  __$AuthSessionCopyWithImpl(this._self, this._then);

  final _AuthSession _self;
  final $Res Function(_AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? loginMethod = null,Object? phoneE164 = null,Object? displayName = null,Object? childIdentifier = freezed,Object? memberId = freezed,Object? isSandbox = null,Object? signedInAtIso = null,}) {
  return _then(_AuthSession(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,loginMethod: null == loginMethod ? _self.loginMethod : loginMethod // ignore: cast_nullable_to_non_nullable
as AuthEntryMethod,phoneE164: null == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,childIdentifier: freezed == childIdentifier ? _self.childIdentifier : childIdentifier // ignore: cast_nullable_to_non_nullable
as String?,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,isSandbox: null == isSandbox ? _self.isSandbox : isSandbox // ignore: cast_nullable_to_non_nullable
as bool,signedInAtIso: null == signedInAtIso ? _self.signedInAtIso : signedInAtIso // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
