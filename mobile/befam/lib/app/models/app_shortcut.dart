import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_shortcut.freezed.dart';
part 'app_shortcut.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum AppShortcutStatus { live, bootstrap, planned }

@freezed
abstract class AppShortcut with _$AppShortcut {
  const factory AppShortcut({
    required String id,
    required String title,
    required String description,
    required String route,
    required String iconKey,
    @Default(AppShortcutStatus.planned) AppShortcutStatus status,
    @Default(false) bool isPrimary,
  }) = _AppShortcut;

  factory AppShortcut.fromJson(Map<String, dynamic> json) =>
      _$AppShortcutFromJson(json);
}
