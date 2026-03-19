# Checklist QA trước release

_Cập nhật gần nhất: 19/03/2026_

Tài liệu test đầy đủ (test plan + test cases + step-by-step):

- [Test Plan và Test Cases trước Release Production](release-test-plan.md)
- [Hướng dẫn dùng Test Execution Sheet](release-test-execution-guide.md)
- [CSV Template để import Google Sheets](release-test-execution-template.csv)
- [Excel Template (.xlsx) đã setup sẵn dropdown/màu/formula](release-test-execution-template.xlsx)
- [CSV Dashboard Formula Template](release-test-dashboard-template.csv)

## Build và môi trường

- [ ] nhánh release candidate đã cập nhật mới nhất
- [ ] vars/secrets production đã kiểm tra đầy đủ
- [ ] `flutter analyze` pass
- [ ] `flutter test` pass
- [ ] Functions build/test pass
- [ ] các check CI bắt buộc đều xanh

## Luồng người dùng cốt lõi

- [ ] đăng nhập OTP số điện thoại chạy end-to-end
- [ ] clan/member/relationship/genealogy hoạt động ổn định
- [ ] sự kiện âm/dương lịch tạo-sửa-xóa đúng
- [ ] quỹ và giao dịch cho ra số dư đúng
- [ ] khuyến học nộp/duyệt đúng quyền
- [ ] hồ sơ cá nhân và avatar hoạt động đúng

## Kiểm tra gói dịch vụ và thanh toán

- [ ] thẻ gói hiện tại chỉ hiển thị gói đang hiệu lực thực tế
- [ ] điều kiện nâng cấp/gia hạn hoạt động đúng
- [ ] luồng VNPay 3 bước dễ hiểu
- [ ] trạng thái thanh toán rõ ràng
- [ ] thanh toán chờ/thất bại không kích hoạt gói mới

## Ký duyệt release

- [ ] QA sign-off
- [ ] Engineering sign-off
- [ ] Product sign-off
