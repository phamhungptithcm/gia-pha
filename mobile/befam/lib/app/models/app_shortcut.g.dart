// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_shortcut.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppShortcut _$AppShortcutFromJson(Map<String, dynamic> json) => _AppShortcut(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  route: json['route'] as String,
  iconKey: json['iconKey'] as String,
  status:
      $enumDecodeNullable(_$AppShortcutStatusEnumMap, json['status']) ??
      AppShortcutStatus.planned,
  isPrimary: json['isPrimary'] as bool? ?? false,
);

Map<String, dynamic> _$AppShortcutToJson(_AppShortcut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'route': instance.route,
      'iconKey': instance.iconKey,
      'status': _$AppShortcutStatusEnumMap[instance.status]!,
      'isPrimary': instance.isPrimary,
    };

const _$AppShortcutStatusEnumMap = {
  AppShortcutStatus.live: 'live',
  AppShortcutStatus.bootstrap: 'bootstrap',
  AppShortcutStatus.planned: 'planned',
};
