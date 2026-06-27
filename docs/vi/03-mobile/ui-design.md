# Thiết kế UI

_Cập nhật gần nhất: 16/05/2026_

## Định hướng thiết kế

BeFam dùng phong cách light lineage workspace: nền sáng, bề mặt rõ, viền mảnh,
chữ dễ đọc, xanh BeFam làm điểm nhấn và trạng thái tin cậy màu xanh lá. App cần
cảm giác như một công cụ vận hành họ tộc bình tĩnh, không giống social app.

`DESIGN.md` là contract thiết kế chính của BeFam và hiện theo format Google
Labs `design.md`: design token bằng YAML ở đầu file, sau đó là hướng dẫn sản
phẩm. Khi chỉnh UI, motion, form, hoặc copy ảnh hưởng release, cập nhật file đó
trước và validate bằng:

```bash
./scripts/lint_design_md.sh
```

## Theme và ngôn ngữ thị giác

- Material 3 color scheme tùy chỉnh tại `app/theme/app_theme.dart`
- tông chính: xanh BeFam, trạng thái tin cậy màu xanh lá, nền trắng, viền
  xanh xám nhẹ
- ưu tiên khoảng trắng và khả năng đọc hơn layout dày đặc
- tránh gradient trang trí, blob, hiệu ứng vào màn hình theo tầng và bố cục
  marketing nặng trong app shell
- web, iOS và Android phải dùng chung contract `DESIGN.md` về màu, chữ,
  spacing, shape, component và motion

## Cải tiến UX đã phản ánh trong app

- mặc định tiếng Việt, có dự phòng tiếng Anh
- nhập OTP theo 6 ô ngang, tự submit khi đủ
- form dài tách thành các section rõ ràng
- màn hình member/genealogy ưu tiên câu chữ dễ hiểu
- dual calendar tối ưu cho chữ lớn và thiết bị cấu hình thấp
- field bắt buộc dùng chung pattern label/decoration
- button async có feedback khi nhấn, loading progress và chặn nhấn lặp
- web landing, static shell, iOS và Android dùng chung lineage grid nhẹ, copy
  ngắn, web marketing card 8px và surface app yên tĩnh hơn
- mobile route, detail page mở bằng push và secondary workspace dùng chung
  lineage backdrop qua app shell và route scaffold trong suốt
- tất cả route web public dùng chung logo BF, top navigation cố định trong suốt
  nhẹ, footer cố định dạng compact, artwork lineage theo home và shell
  responsive cho desktop/tablet/mobile

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
- Route scaffold trên iOS và Android dùng mobile theme trong suốt để màn hình
  mở sau vẫn giữ cùng nền app như home shell.
- Motion web landing chỉ dùng hover, focus, viền, màu và shadow nhẹ. Không thêm
  float, pulse hoặc chuyển động trang trí.
- Navigation và footer web public nằm ngoài vùng scroll chính. Nội dung có thể
  scroll, nhưng shell chrome phải ổn định và dễ theo dõi.
- Copy web public cần ngắn, tự nhiên và hướng vào quyết định chính. Tránh lặp
  FAQ/CTA trên landing flow nếu page không thật sự cần.
- Footer web public phải compact. Không đặt store-download card lớn hoặc block
  hỗ trợ lặp lại trong footer.

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
