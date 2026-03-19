# Quản lý trạng thái

_Cập nhật gần nhất: 17/03/2026_

## Cách tiếp cận hiện tại

Ứng dụng dùng mô hình controller + `ChangeNotifier` kết hợp repository theo
feature.

## Mẫu triển khai

- controller giữ async action, cờ trạng thái và bề mặt lỗi
- repository interface tách lớp tích hợp Firebase cho runtime
- UI bind bằng `AnimatedBuilder`, không gọi backend trực tiếp

## Ví dụ

- `AuthController`: điều phối bước auth, OTP, restore/logout phiên
- `MemberController`: list/search/filter, save/edit, upload avatar
- `ClanController`: load và lưu dữ liệu clan/branch

## Search và derived state

- lọc thành viên qua `MemberSearchProvider`
- analytics search đi qua `MemberSearchAnalyticsService`
- controller có cơ chế chống kết quả async cũ ghi đè trạng thái mới

## Cache và lưu phiên

- phiên auth lưu qua `AuthSessionStore` (shared preferences)
- phân đoạn đọc genealogy có thể cache local qua
  `GenealogySegmentCache.shared()`
- ngữ cảnh phiên Firebase được sync vào `users/{uid}` để fallback rules

## Hành vi backend runtime

- luồng app runtime dùng Firebase mặc định
- fixture/mock chỉ giữ ở test layer
