// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_shortcut.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppShortcut {

 String get id; String get title; String get description; String get route; String get iconKey; AppShortcutStatus get status; bool get isPrimary;
/// Create a copy of AppShortcut
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppShortcutCopyWith<AppShortcut> get copyWith => _$AppShortcutCopyWithImpl<AppShortcut>(this as AppShortcut, _$identity);

  /// Serializes this AppShortcut to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppShortcut&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.route, route) || other.route == route)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,route,iconKey,status,isPrimary);

@override
String toString() {
  return 'AppShortcut(id: $id, title: $title, description: $description, route: $route, iconKey: $iconKey, status: $status, isPrimary: $isPrimary)';
}


}

/// @nodoc
abstract mixin class $AppShortcutCopyWith<$Res>  {
  factory $AppShortcutCopyWith(AppShortcut value, $Res Function(AppShortcut) _then) = _$AppShortcutCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, String route, String iconKey, AppShortcutStatus status, bool isPrimary
});




}
/// @nodoc
class _$AppShortcutCopyWithImpl<$Res>
    implements $AppShortcutCopyWith<$Res> {
  _$AppShortcutCopyWithImpl(this._self, this._then);

  final AppShortcut _self;
  final $Res Function(AppShortcut) _then;

/// Create a copy of AppShortcut
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? route = null,Object? iconKey = null,Object? status = null,Object? isPrimary = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AppShortcutStatus,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppShortcut].
extension AppShortcutPatterns on AppShortcut {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppShortcut value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppShortcut() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppShortcut value)  $default,){
final _that = this;
switch (_that) {
case _AppShortcut():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppShortcut value)?  $default,){
final _that = this;
switch (_that) {
case _AppShortcut() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String route,  String iconKey,  AppShortcutStatus status,  bool isPrimary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppShortcut() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.route,_that.iconKey,_that.status,_that.isPrimary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String route,  String iconKey,  AppShortcutStatus status,  bool isPrimary)  $default,) {final _that = this;
switch (_that) {
case _AppShortcut():
return $default(_that.id,_that.title,_that.description,_that.route,_that.iconKey,_that.status,_that.isPrimary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  String route,  String iconKey,  AppShortcutStatus status,  bool isPrimary)?  $default,) {final _that = this;
switch (_that) {
case _AppShortcut() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.route,_that.iconKey,_that.status,_that.isPrimary);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppShortcut implements AppShortcut {
  const _AppShortcut({required this.id, required this.title, required this.description, required this.route, required this.iconKey, this.status = AppShortcutStatus.planned, this.isPrimary = false});
  factory _AppShortcut.fromJson(Map<String, dynamic> json) => _$AppShortcutFromJson(json);

@override final  String id;
@override final  String title;
@override final  String description;
@override final  String route;
@override final  String iconKey;
@override@JsonKey() final  AppShortcutStatus status;
@override@JsonKey() final  bool isPrimary;

/// Create a copy of AppShortcut
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppShortcutCopyWith<_AppShortcut> get copyWith => __$AppShortcutCopyWithImpl<_AppShortcut>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppShortcutToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppShortcut&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.route, route) || other.route == route)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,route,iconKey,status,isPrimary);

@override
String toString() {
  return 'AppShortcut(id: $id, title: $title, description: $description, route: $route, iconKey: $iconKey, status: $status, isPrimary: $isPrimary)';
}


}

/// @nodoc
abstract mixin class _$AppShortcutCopyWith<$Res> implements $AppShortcutCopyWith<$Res> {
  factory _$AppShortcutCopyWith(_AppShortcut value, $Res Function(_AppShortcut) _then) = __$AppShortcutCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, String route, String iconKey, AppShortcutStatus status, bool isPrimary
});




}
/// @nodoc
class __$AppShortcutCopyWithImpl<$Res>
    implements _$AppShortcutCopyWith<$Res> {
  __$AppShortcutCopyWithImpl(this._self, this._then);

  final _AppShortcut _self;
  final $Res Function(_AppShortcut) _then;

/// Create a copy of AppShortcut
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? route = null,Object? iconKey = null,Object? status = null,Object? isPrimary = null,}) {
  return _then(_AppShortcut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AppShortcutStatus,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
