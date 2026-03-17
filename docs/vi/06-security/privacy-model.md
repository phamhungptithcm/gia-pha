# Mô hình quyền riêng tư

_Cập nhật gần nhất: 17/03/2026_

## Nguyên tắc riêng tư

- ưu tiên cô lập dữ liệu theo clan
- ghi theo quyền tối thiểu cần thiết
- kiểm tra vai trò tường minh cho thao tác nhạy cảm
- mutation định danh/quan hệ phải có khả năng audit
- dữ liệu thanh toán tối giản và token hóa qua cổng thanh toán

## Ranh giới truy cập

- đọc theo phạm vi clan (`hasClanAccess`)
- ghi phụ thuộc vai trò và loại thao tác:
  - cài đặt clan: `SUPER_ADMIN` / `CLAN_ADMIN`
  - thao tác theo chi: `BRANCH_ADMIN` có ràng buộc chi
  - cập nhật hồ sơ cá nhân: kiểm tra diff trường nghiêm ngặt

## Định danh và truy cập trẻ em

- child login đi qua xác minh OTP phụ huynh
- member claim liên kết `authUid` và refresh role context claims
- `accessMode` (`unlinked`, `claimed`, `child`) được lưu và dùng bởi cả app
  và rules

## Tối thiểu hóa dữ liệu

- token push chỉ lưu metadata cần cho định tuyến
- notifications hướng theo member; người nhận được đổi trạng thái đã đọc
- upload storage bị giới hạn loại file và dung lượng
- billing chỉ lưu tham chiếu thanh toán và metadata đã che, không lưu PAN/CVV
- hóa đơn/giao dịch billing cô lập theo clan và chỉ owner/admin được đọc

## Bảo vệ dữ liệu thanh toán

- checkout tạo phía server với giá chuẩn theo `member_count`
- thông tin thẻ thu tại UI/SDK của nhà cung cấp; BeFam chỉ lưu token/reference
- callback VNPay/cổng thanh toán phải qua kiểm tra chữ ký trước khi đổi trạng thái
- webhook xử lý idempotent để tránh side effect trùng lặp
- billing audit logs ghi actor/action/transaction reference phục vụ điều tra
- metadata nhạy cảm được loại bỏ khỏi log phía client

## Lưu trữ và kiểm soát truy cập (billing)

- giữ transaction/invoice theo cửa sổ audit và hỗ trợ vận hành
- giới hạn quyền đọc billing ở role owner/admin
- cô lập dữ liệu billing theo `clanId`
- duy trì runbook ứng phó sự cố cho sự kiện liên quan thanh toán

## Kiểm soát vận hành

- nhánh bảo vệ + CI bắt buộc trước merge
- deploy production qua GitHub Environment vars/secrets
- automation sau release giúp truy vết đầy đủ story/epic đã phát hành
