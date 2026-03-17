# Cấu trúc Flutter

_Cập nhật gần nhất: 17/03/2026_

## Vị trí source

```text
mobile/befam
```

## Thư mục chính

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

## Quy ước cấu trúc

- mỗi feature tự quản lý model, service và presentation
- interface repository đặt trong feature và có thể đổi backend Firebase/debug
- shell và bootstrap cấp ứng dụng nằm trong `app/`
- wrapper Firebase services và runtime toggle nằm trong `core/services`

## File sinh tự động và tooling

- localization output: `lib/l10n/generated/*`
- Freezed/JSON output: `*.freezed.dart`, `*.g.dart`
- lệnh sinh mã:
  - `flutter gen-l10n`
  - `dart run build_runner build --delete-conflicting-outputs`
