# Thiết kế UI

_Cập nhật gần nhất: 17/03/2026_

## Định hướng thiết kế

BeFam dùng giao diện sáng, ấm, tương phản cao, bề mặt bo tròn lớn để thân thiện
với nhiều nhóm tuổi.

## Theme và ngôn ngữ thị giác

- Material 3 color scheme tùy chỉnh tại `app/theme/app_theme.dart`
- tông chính: xanh đậm, nền hỗ trợ sáng trung tính
- ưu tiên khoảng trắng và khả năng đọc hơn layout dày đặc

## Cải tiến UX đã phản ánh trong app

- mặc định tiếng Việt, có dự phòng tiếng Anh
- nhập OTP theo 6 ô ngang, tự submit khi đủ
- form dài tách thành các section rõ ràng
- màn hình member/genealogy ưu tiên câu chữ dễ hiểu
- dual calendar tối ưu cho chữ lớn và thiết bị cấu hình thấp

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

## Nguyên tắc copy

- ngắn, rõ, trực tiếp ở hành động quan trọng
- hiển thị trạng thái ngay tại nơi cần quyết định
- tránh đưa ngôn ngữ kỹ thuật vào màn hình người dùng cuối
