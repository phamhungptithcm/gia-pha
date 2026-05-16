# Thiết kế UI

_Cập nhật gần nhất: 16/05/2026_

## Định hướng thiết kế

BeFam dùng phong cách light lineage workspace: nền sáng, bề mặt rõ, viền mảnh,
chữ dễ đọc, xanh BeFam làm điểm nhấn và trạng thái tin cậy màu xanh lá. App cần
cảm giác như một công cụ vận hành họ tộc bình tĩnh, không giống social app.

## Theme và ngôn ngữ thị giác

- Material 3 color scheme tùy chỉnh tại `app/theme/app_theme.dart`
- tông chính: xanh BeFam, trạng thái tin cậy màu xanh lá, nền trắng, viền
  xanh xám nhẹ
- ưu tiên khoảng trắng và khả năng đọc hơn layout dày đặc
- tránh gradient trang trí, blob, hiệu ứng vào màn hình theo tầng và bố cục
  marketing nặng trong app shell

## Cải tiến UX đã phản ánh trong app

- mặc định tiếng Việt, có dự phòng tiếng Anh
- nhập OTP theo 6 ô ngang, tự submit khi đủ
- form dài tách thành các section rõ ràng
- màn hình member/genealogy ưu tiên câu chữ dễ hiểu
- dual calendar tối ưu cho chữ lớn và thiết bị cấu hình thấp
- field bắt buộc dùng chung pattern label/decoration
- button async có feedback khi nhấn, loading progress và chặn nhấn lặp

## Form, timer và action

- Field bắt buộc phải hiện dấu bắt buộc và lỗi inline trước khi người dùng đi
  tiếp.
- Editor nhiều bước phải validate bước hiện tại trước khi chuyển bước. Áp dụng
  cho auth, clan, branch, member, event, fund và scholarship.
- Error copy cần ngắn, rõ field nào phải sửa; không dùng lỗi chung chung cho
  required field.
- Timer như cooldown gửi lại OTP dùng progress indicator nhỏ kèm thời gian còn
  lại.
- Button async dùng `AppActionButton` hoặc `AppAsyncAction` để có feedback ngay,
  loading progress khi request đang chạy và chặn double submit.
- Chuyển màn hình dùng transition scale-only của BeFam. Không dùng slide/fade
  làm phản hồi mặc định khi tap.

## Accessibility và độ bền giao diện

- hardening cho text scale lớn và tránh overflow
- tap target rộng, thứ bậc heading rõ ràng
- giảm tải nhận thức ở các màn hình quan trọng
- hành động icon-only có tooltip/semantic label
- loading state có message dễ hiểu và semantic hỗ trợ

## Chuẩn cho empty/loading/error state

- workspace chính đều có loading state rõ nghĩa
- no-context/empty state hướng dẫn người dùng phải làm gì tiếp
- lỗi có đường hồi phục khi có thể (retry, back, action khác)
- crash runtime có fallback UI thay vì vỡ màn hình

## Test matrix cho form

Chạy các lệnh này khi chỉnh form, timer, action button hoặc motion chuyển màn:

```bash
cd mobile/befam
flutter analyze
flutter test test/core/widgets/app_form_controls_test.dart
flutter test test/widget_test.dart --name "auth phone form|auth child and OTP|clan editor shows|branch editor shows|member add form blocks|filters parent candidates"
flutter test test/features/events/event_widget_test.dart --name "edit form shows required title error before moving on"
flutter test test/features/funds/fund_form_validation_widget_test.dart
flutter test test/features/scholarship/scholarship_flow_widget_test.dart --name "create forms surface required errors before continuing"
```

## Nguyên tắc copy

- ngắn, rõ, trực tiếp ở hành động quan trọng
- hiển thị trạng thái ngay tại nơi cần quyết định
- tránh đưa ngôn ngữ kỹ thuật vào màn hình người dùng cuối
