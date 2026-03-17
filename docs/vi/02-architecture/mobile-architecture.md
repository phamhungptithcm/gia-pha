# Kiến trúc mobile

_Cập nhật gần nhất: 17/03/2026_

## Cấu trúc ứng dụng

Ứng dụng mobile nằm tại `mobile/befam` và đi theo hướng feature-first:

```text
lib/
  app/            # shell, theme, bootstrap, dashboard
  core/           # runtime mode, firebase services, logging, crash reporting
  features/       # auth, clan, member, relationship, genealogy, calendar, funds, scholarship, notifications, profile
  l10n/           # file ARB vi/en và mã sinh tự động
```

## Quản lý trạng thái và luồng điều khiển

- `AuthController` điều phối các bước xác thực và lưu phiên
- controller theo feature (ví dụ `MemberController`) dùng `ChangeNotifier`
  cùng abstraction repository
- repository có thể đổi giữa debug và Firebase theo
  `RuntimeMode.shouldUseMockBackend`

## Chiến lược runtime mode

- debug mặc định đi theo Firebase thật (`BEFAM_USE_LIVE_AUTH=true`)
- mock vẫn dùng cho test hoặc khi bật override rõ ràng
- có chế độ bypass OTP local cho smoke test debug qua
  `BEFAM_LOCAL_AUTH_BYPASS`
- bootstrap trả metadata trạng thái Firebase để hiển thị UX phù hợp

## Shell điều hướng

- app bắt đầu ở màn hình auth
- sau đăng nhập thành công, người dùng vào `AppShellPage` với các tab:
  - Home
  - Tree
  - Events (dual calendar)
  - Profile
- handler deep-link từ push có thể đưa người dùng tới ngữ cảnh phù hợp

## Hướng chất lượng và khả năng tiếp cận

- ưu tiên copy tiếng Việt, dễ đọc với chữ lớn
- OTP 6 số có auto-submit khi nhập đủ
- form dài được chia section rõ ràng
- card/list tối ưu cho cả người lớn tuổi và người trẻ
- màn hình calendar/profile xử lý tốt khi tăng text scale

## Bổ sung đã triển khai

- workspace quản lý gói dịch vụ và thanh toán VNPay-first cho owner/admin
- quyền lợi theo gói được phản ánh rõ trong UI và trạng thái phiên
