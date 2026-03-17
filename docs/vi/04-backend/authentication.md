# Xác thực

_Cập nhật gần nhất: 17/03/2026_

Hệ thống xác thực BeFam kết hợp OTP số điện thoại của Firebase với cơ chế phân
giải hồ sơ thành viên theo dòng họ và đồng bộ ngữ cảnh vai trò.

## Phương thức đăng nhập hỗ trợ

- đăng nhập OTP số điện thoại (`AuthEntryMethod.phone`)
- đăng nhập mã trẻ em thông qua OTP phụ huynh (`AuthEntryMethod.child`)

## Callable Functions liên quan

### `resolveChildLoginContext`

- input: `childIdentifier`
- trả về số phụ huynh + ngữ cảnh member/clan/branch
- ưu tiên bản ghi `invites` còn hiệu lực, fallback theo member id

### `claimMemberRecord`

- input gồm `loginMethod` và có thể có `childIdentifier`/`memberId`
- xác minh danh tính dựa trên OTP với member/invite records
- liên kết `members/{memberId}.authUid` khi hợp lệ
- cập nhật custom claims:
  - `clanIds`
  - `memberId`
  - `branchId`
  - `primaryRole`
  - `memberAccessMode`
- ghi audit log cho các hành động claim/session

### `registerDeviceToken`

- upsert token FCM vào `users/{uid}/deviceTokens/{token}`
- lưu metadata platform và session context để phục vụ push targeting

## Hành vi gateway trên mobile

- luồng chính dùng Firebase Auth + callable functions
- có fallback tạm thời khi callable không sẵn sàng:
  - fallback child mapping local cho mã demo đã biết
  - fallback claim/session sync qua Firestore
- `RuntimeMode` vẫn hỗ trợ mock mode cho test
- bypass OTP debug chỉ dùng cho phát triển, không dùng cho production

## Lưu phiên

- phiên được lưu local bằng `AuthSessionStore`
- restore app kiểm tra tính hợp lệ token qua Firebase Auth
- `FirebaseSessionAccessSync` giữ `users/{uid}` đồng bộ với phiên hiện tại

## Ghi chú bảo mật

- child login yêu cầu số phụ huynh đã xác minh phải khớp với ngữ cảnh resolve
- claim trùng số điện thoại bị từ chối với lỗi xung đột
- rules fallback dùng custom claims hoặc `users/{uid}` context
- hành động billing phải khóa theo role owner/admin cả ở callable và rules
