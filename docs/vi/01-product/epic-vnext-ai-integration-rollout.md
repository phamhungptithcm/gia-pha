# [Epic] vNext AI Integration Rollout for BeFam

_Cập nhật gần nhất: 12/04/2026_

## Kết luận ngắn

AI **có thể là tính năng nổi bật** cho BeFam nếu được gắn vào đúng chỗ:

- giúp người dùng hoàn thiện hồ sơ để dễ được nhận ra trong họ hàng
- giúp ban vận hành soạn nội dung sự kiện/memorial nhanh hơn
- giúp admin tránh tạo trùng gia phả khi mở thêm nhánh hoặc gia phả riêng

AI **không nên** triển khai theo kiểu một tab chat chung, vì kiểu đó thường ít giữ chân
user trong app gia phả. Giá trị thật của BeFam đến từ **AI hỗ trợ tác vụ có cấu trúc**,
ngay trong flow đang làm.

## Đánh giá Firebase AI services

### 1. Firebase AI Logic

Phù hợp:

- gợi ý copy ngắn, low-risk, user-authored
- tính năng cần đo usage trực tiếp từ app client
- trải nghiệm AI đơn giản, độ trễ thấp

Chưa phải lựa chọn chính cho BeFam:

- dữ liệu gia phả có yếu tố nhạy cảm, cần role check và audit log ở server
- nhiều use case của BeFam là admin/governance, không nên để client tự gọi model

Kết luận:

- **nên dùng sau** cho các tính năng low-risk phía client
- **không nên là lớp AI chính** cho rollout đầu tiên

### 2. Genkit trên Firebase Functions

Phù hợp nhất cho BeFam:

- chạy server-side, đi cùng auth/session/clan scope hiện có
- dễ ép output có cấu trúc
- dễ audit, feature-flag, fallback an toàn
- cùng hệ Firebase hiện tại nên rollout ít phá kiến trúc

Kết luận:

- **đây là lựa chọn chính cho phase 1**

### 3. Firebase Machine Learning

Có ích nhưng chưa phải trọng tâm retention phase này:

- OCR ảnh chụp gia phả giấy
- nhận diện text tài liệu cũ
- xử lý ảnh/bản scan trước khi nhập dữ liệu

Kết luận:

- **nên để phase 2**
- giá trị lớn nhất là digitization, không phải assistant hằng ngày

## Sprint rollout

### Sprint A1 - AI foundation on Firebase Functions

Đã triển khai:

- thêm lớp AI callable backend trong `firebase/functions/src/ai/callables.ts`
- thêm runtime config `AI_ASSIST_ENABLED`, `AI_ASSIST_MODEL`
- mặc định phase 1 dùng `gemini-2.5-flash-lite` để kiểm soát chi phí
- thêm Genkit dependency để sẵn sàng bật model thật
- mọi flow đều có fallback heuristic an toàn khi AI chưa cấu hình

### Sprint A2 - AI profile quality reviewer

Đã triển khai:

- callable `reviewProfileDraftAi`
- UI review trong editor hồ sơ
- trả về tóm tắt, điểm mạnh, mục còn thiếu, rủi ro, bước tiếp theo

User value:

- hồ sơ đầy đủ hơn
- dễ được người thân nhận diện hơn
- giảm hồ sơ “trống”, khó xác minh

### Sprint A3 - AI event copy drafting

Đã triển khai:

- callable `draftEventCopyAi`
- gợi ý tiêu đề, mô tả, và mốc nhắc lịch
- gắn trực tiếp vào luồng chỉnh sửa sự kiện

User value:

- giảm thời gian soạn event/memorial
- nội dung nhất quán, dễ đọc
- admin ít bỏ sót mốc nhắc việc quan trọng

### Sprint A4 - AI duplicate genealogy explanation

Đã triển khai:

- callable `explainDuplicateGenealogyAi`
- giải thích vì sao hệ thống nghi ngờ bị trùng
- thêm checklist review trước khi cho override tạo gia phả mới

User value:

- giảm tạo trùng
- tăng niềm tin vào hệ thống duplicate check
- giảm quyết định override “mù”

## Vì sao đây có thể là feature nổi bật

Có, nhưng với điều kiện:

- AI phải nằm trong flow thật, không phải chat riêng lẻ
- AI chỉ đóng vai trò **advisory**, không auto-commit dữ liệu
- output phải ngắn, rõ, có thể hành động ngay

Nếu giữ đúng 3 điều trên, AI của BeFam có thể là điểm khác biệt vì:

- app gia phả hiện nay thường chỉ dừng ở CRUD
- BeFam có thể giúp người dùng **làm đúng việc nhanh hơn**
- admin/clan leader cảm nhận giá trị rõ hơn ở mỗi tác vụ

## Tác động tới retention

### Có tác động tích cực nếu tập trung vào:

- hồ sơ cá nhân
- sự kiện/memorial
- tạo hoặc mở rộng gia phả

Đây là các điểm chạm có tần suất và cảm xúc cao hơn một “AI chat” độc lập.

### Không nên kỳ vọng retention mạnh từ:

- câu trả lời chung chung
- AI mô tả kiến thức mà user đã biết
- tính năng AI quá xa khỏi task hiện tại

## Guardrails bắt buộc

- AI chỉ gợi ý, user vẫn phải xác nhận trước khi lưu
- action nhạy cảm vẫn giữ role check như hiện tại
- mọi AI callable đều ghi audit log tối thiểu
- phải có fallback khi model unavailable hoặc chưa cấu hình

## KPI nên theo dõi sau rollout

- tỷ lệ user bấm AI review trong editor hồ sơ
- tỷ lệ hồ sơ có thêm trường sau AI review
- tỷ lệ event được AI draft rồi lưu
- tỷ lệ duplicate override giảm sau khi có explanation
- retention của admin/clan leader theo cohort dùng AI vs không dùng AI

## Phase tiếp theo nên làm

### Ưu tiên cao

- natural-language family search bằng tiếng Việt
- OCR nhập liệu từ ảnh gia phả giấy bằng Firebase ML

### Ưu tiên vừa

- relationship suggestion assistant cho admin review
- recap/memorial drafting từ event history

### Chưa nên làm ngay

- chat bot chung cho toàn app
- auto-create relationship hoặc auto-merge người trùng mà không có confirm
