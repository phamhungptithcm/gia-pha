# Flutter Structure

_Last reviewed: March 14, 2026_

## Repository location

```text
mobile/befam
```

## Main folders

```text
lib/
  app/
    bootstrap/
    home/
    models/
    theme/
  core/
    services/
  features/
    auth/
    clan/
    genealogy/
    member/
    notifications/
    relationship/
  l10n/
    generated/
test/
```

## Structure conventions

- feature modules own their models, services, and presentation files
- repository interfaces live with features and can swap Firebase/debug backends
- app-level shell and bootstrap logic stay in `app/`
- Firebase service wrappers and runtime toggles stay in `core/services`

## Generated and tooling files

- localization output: `lib/l10n/generated/*`
- freezed/json output: `*.freezed.dart` and `*.g.dart`
- generation commands:
  - `flutter gen-l10n`
  - `dart run build_runner build --delete-conflicting-outputs`
