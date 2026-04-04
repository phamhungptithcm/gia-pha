# Mẫu form xóa tài khoản cho Google Play Console

_Cập nhật gần nhất: 27/03/2026_

Tài liệu này giúp BeFam đáp ứng mục **Data safety > Account deletion** trên
Google Play Console bằng:

- 1 trang URL công khai để người dùng gửi yêu cầu xóa tài khoản
- 1 mẫu Google Form để tiếp nhận yêu cầu
- 1 bộ nội dung copy-paste để điền Play Console

## 1) URL xóa tài khoản (dùng cho Play Console)

Tạo một trang public (không cần đăng nhập), ví dụ:

- `https://<domain-cua-ban>/delete-account`
- hoặc trang docs public của dự án

Trang này nên có nội dung tối thiểu (có thể copy nguyên mẫu dưới):

### Mẫu nội dung trang (VI)

```text
Yêu cầu xóa tài khoản BeFam

Để yêu cầu xóa tài khoản và dữ liệu liên quan, vui lòng điền form:
<FORM_URL>

Thông tin cần cung cấp:
- Số điện thoại đã đăng ký (định dạng quốc tế, ví dụ: +84901234567)
- Họ tên hiển thị (nếu có)
- Email liên hệ (nếu có)

Quy trình xử lý:
1) Chúng tôi xác minh chủ tài khoản.
2) Gửi xác nhận tiếp nhận yêu cầu.
3) Thực hiện xóa theo phạm vi đã chọn.

Dữ liệu xóa khi xóa toàn bộ tài khoản:
- Hồ sơ đăng nhập và liên kết phiên
- Token thiết bị thông báo
- Thông tin hồ sơ cá nhân do người dùng cung cấp

Dữ liệu có thể được lưu theo nghĩa vụ pháp lý/vận hành trong thời gian giới hạn:
- Nhật ký giao dịch thanh toán và audit logs (nếu phát sinh)
- Bản ghi cần thiết cho an ninh/chống gian lận

Thời gian xử lý:
- Xác nhận tiếp nhận: trong 3 ngày làm việc
- Hoàn tất xóa: trong vòng 30 ngày (trừ dữ liệu phải lưu theo luật)

Liên hệ hỗ trợ:
- Email: <SUPPORT_EMAIL>
```

## 2) Mẫu Google Form tiếp nhận yêu cầu

Tạo Google Form tên:

`BeFam - Yêu cầu xóa tài khoản`

Mô tả form (copy-paste):

```text
Form này dùng để yêu cầu xóa tài khoản BeFam và dữ liệu liên quan.
Vui lòng cung cấp đúng số điện thoại đã dùng đăng nhập để chúng tôi xác minh.
Thời gian xử lý tối đa 30 ngày.
```

Các câu hỏi đề xuất:

1. **Họ và tên** (Short answer, Required)
2. **Số điện thoại tài khoản BeFam (E.164)** (Short answer, Required)
   - Gợi ý: `+84901234567`
3. **Email liên hệ** (Short answer, Optional)
4. **Mã thành viên hoặc UID (nếu biết)** (Short answer, Optional)
5. **Loại yêu cầu** (Multiple choice, Required)
   - Xóa toàn bộ tài khoản và dữ liệu liên quan
   - Yêu cầu xóa một phần dữ liệu
6. **Mô tả thêm (tuỳ chọn)** (Paragraph, Optional)
7. **Xác nhận** (Checkbox, Required)
   - Tôi xác nhận mình là chủ tài khoản hoặc người được ủy quyền hợp lệ.
   - Tôi hiểu một số dữ liệu có thể được lưu theo yêu cầu pháp lý.

Settings khuyến nghị:

- Collect email addresses: `On`
- Send responders a copy of responses: `On`
- Limit to 1 response: `Off` (để không chặn người dùng ngoài Google login)

## 3) Nội dung điền Play Console (copy-paste)

Trong `Data safety`:

- **Delete account URL**: dán URL trang public ở mục (1)
- **Do you provide a way for users to request that some or all of their data is deleted...?**
  - Nếu hiện chỉ hỗ trợ xóa toàn bộ tài khoản: chọn `No`
  - Nếu có hỗ trợ xóa một phần dữ liệu thật sự: chọn `Yes`

## 4) Mẫu phản hồi email sau khi nhận yêu cầu

```text
Tiêu đề: [BeFam] Đã tiếp nhận yêu cầu xóa tài khoản

Xin chào {{name}},

BeFam đã nhận yêu cầu xóa tài khoản của bạn với số điện thoại {{phone}}.
Mã yêu cầu: {{ticket_id}}.

Chúng tôi sẽ xác minh và xử lý trong tối đa 30 ngày.
Nếu cần bổ sung thông tin, đội ngũ hỗ trợ sẽ liên hệ qua email này.

Trân trọng,
BeFam Support
```

## 5) Checklist trước khi submit Google Play

- [ ] URL xóa tài khoản truy cập public không cần đăng nhập
- [ ] Trang URL có nêu rõ dữ liệu xóa / dữ liệu giữ lại / thời gian xử lý
- [ ] Google Form hoạt động và nhận response bình thường
- [ ] Support email trên trang và trên Play Console là hợp lệ

