# Epic cộng đồng thôn/làng và memorial

_Cập nhật gần nhất: 12/04/2026_

## 1. Mục tiêu

Mở rộng BeFam từ nền tảng gia phả + vận hành dòng họ sang một lớp cộng đồng địa
phương có tính kết nối cao hơn:

- trưởng thôn/làng tạo và quản lý cộng đồng thôn/làng
- hệ thống tự gom đúng thành viên theo nguyên quán
- trưởng thôn/làng tạo sự kiện và thông báo cho cộng đồng đó
- thành viên nhận thông báo về thời gian, địa điểm, nội dung
- mọi người có một không gian `memorial` để lưu lại sự kiện, hình ảnh, ghi chú,
  câu chuyện và xem lại về sau

## 2. Đánh giá nhanh trên codebase hiện tại

BeFam đã có nền tảng tốt để làm nhanh phần này:

- `members`, `clans`, `branches`, `genealogy` đã ổn định
- `events` đã có create/edit/reminder/notification
- `notifications` đã có inbox + push + deep-link
- `governance` đã có role-based access

Nhưng hiện tại còn 3 khoảng trống lớn:

1. `members` mới có `addressText`, chưa có cấu trúc riêng cho `nguyên quán`.
2. `events` và `notifications` mới scope theo `clan` hoặc `branch`, chưa có
   scope theo cộng đồng thôn/làng.
3. Chưa có mô hình feed/archive cho nội dung ký ức, ảnh, ghi chú, recap.

## 3. Quyết định sản phẩm quan trọng

### 3.1 Không dùng `branch` để biểu diễn thôn/làng

`branch` trong BeFam đang mang nghĩa `chi` trong gia phả. Nếu dùng lại cho
`thôn/làng`, mô hình sẽ bị lệch nghĩa và rất khó bảo trì.

Quyết định:

- tạo lớp domain mới: `community`
- `communityType`: `hamlet`, `village`, có thể mở rộng `association`,
  `alumni`, `hometown-group` về sau

### 3.2 Tách rõ `địa chỉ hiện tại` và `nguyên quán`

Không nên map `nguyên quán` vào `addressText`.

Quyết định:

- giữ `addressText` cho nơi ở hiện tại
- thêm `originProfile` cho nguyên quán
- `originProfile` nên có cấu trúc đủ để match tự động:
  - `provinceCode`
  - `districtCode`
  - `communeCode`
  - `villageName`
  - `hamletName`
  - `displayText`
  - `normalizedKey`

### 3.3 `Memorial` không chỉ là ngày giỗ

Hiện codebase đã có memorial theo nghĩa `giỗ kỵ` trong module events. Tính năng
mới nên mang nghĩa rộng hơn: không gian lưu ký ức cộng đồng và gia đình.

Quyết định:

- giữ `event memorial` hiện tại cho giỗ/lễ
- thêm `memorial space` như một timeline tri thức và kỷ niệm

## 4. Đề xuất mô hình dữ liệu

### 4.1 Mở rộng member

`members/{memberId}`

```json
{
  "addressText": "TP.HCM, Việt Nam",
  "originProfile": {
    "provinceCode": "31",
    "districtCode": "299",
    "communeCode": "10783",
    "villageName": "Làng Đông",
    "hamletName": "Thôn Đình",
    "displayText": "Thôn Đình, Làng Đông, xã X, huyện Y, tỉnh Z",
    "normalizedKey": "31|299|10783|lang-dong|thon-dinh"
  }
}
```

### 4.2 Community

`communities/{communityId}`

```json
{
  "id": "community_...",
  "clanId": "clan_...",
  "communityType": "hamlet",
  "name": "Thôn Đình",
  "parentCommunityId": "community_lang_dong",
  "originMatchKey": "31|299|10783|lang-dong|thon-dinh",
  "status": "active",
  "leaderMemberIds": ["member_a"],
  "memberCount": 120,
  "createdBy": "member_a"
}
```

### 4.3 Membership

`communityMemberships/{membershipId}`

```json
{
  "communityId": "community_...",
  "memberId": "member_...",
  "clanId": "clan_...",
  "membershipSource": "auto_origin_match",
  "status": "active",
  "joinedAt": "serverTimestamp"
}
```

### 4.4 Event và thông báo cộng đồng

Không cần tạo module event mới. Nên mở rộng `events` hiện tại:

- `audienceScopeType`: `clan`, `branch`, `community`
- `audienceScopeId`
- `announcementCategory`: `meeting`, `distribution`, `festival`, `notice`
- `requiresAck`: `true/false` cho thông báo quan trọng

### 4.5 Memorial space

Tối giản để ra được production sớm:

- `memorialEntries/{entryId}`
- `memorialComments/{commentId}`
- `memorialMedia/{mediaId}` hoặc lưu file trong Storage + metadata trong entry

`memorialEntries` nên hỗ trợ:

- `scopeType`: `clan`, `community`
- `scopeId`
- `entryType`: `story`, `photo_album`, `event_recap`, `tribute`, `note`
- `title`, `body`
- `eventId` nullable để gắn với một sự kiện
- `taggedMemberIds`
- `visibility`: `scope_members`, `public_link` về sau

## 5. Luồng nghiệp vụ đề xuất

### 5.1 Tạo cộng đồng thôn/làng

1. Trưởng thôn/làng hoặc admin tạo `community`.
2. Chọn loại cộng đồng: `thôn` hoặc `làng`.
3. Chọn địa danh chuẩn hoặc nhập tên chuẩn hóa.
4. Hệ thống tạo `originMatchKey`.
5. Hệ thống backfill toàn bộ member đang có `originProfile.normalizedKey` khớp.
6. Trigger tiếp tục tự sync cho member tạo mới hoặc member sửa nguyên quán.

### 5.2 Tạo event/thông báo

1. Trưởng thôn/làng vào workspace cộng đồng.
2. Chọn `Tạo sự kiện` hoặc `Đăng thông báo`.
3. Nếu là sự kiện:
   - dùng lại form event hiện tại
   - thêm audience `community`
4. Nếu là thông báo:
   - tạo bản ghi announcement nhẹ hơn event
   - có thể kèm thời gian/địa điểm hoặc chỉ là thông báo
5. Cloud Functions resolve audience qua `communityMemberships`.
6. Thành viên nhận inbox + push notification.

### 5.3 Memorial

1. Sau một buổi họp/gặp mặt/lễ chung, trưởng nhóm hoặc thành viên đăng recap.
2. Thêm ảnh, ghi chú, danh sách người tham dự, bài học/kỷ niệm.
3. Các thành viên khác vào xem, bình luận, bổ sung tư liệu.
4. Sau này có thể lọc theo năm, sự kiện, làng/thôn, người được nhắc đến.

## 6. Backlog stories đề xuất

## EPIC A - Cộng đồng thôn/làng

### COMM-001 Thêm cấu trúc `originProfile` vào member
- As a member, tôi cập nhật nguyên quán theo cấu trúc chuẩn để hệ thống hiểu
  đúng quê quán của tôi.

### COMM-002 Tạo community thôn/làng
- As a clan admin, tôi tạo được một cộng đồng thôn/làng với thông tin chuẩn hóa.

### COMM-003 Gán vai trò trưởng thôn/làng
- As a clan admin, tôi chỉ định trưởng thôn/làng để người đó quản lý đúng cộng
  đồng.

### COMM-004 Auto-match membership theo nguyên quán
- As the system, tôi tự thêm member vào community khi `originMatchKey` khớp.

### COMM-005 Sync membership khi member đổi nguyên quán
- As the system, tôi cập nhật membership khi hồ sơ thành viên thay đổi nguyên
  quán.

### COMM-006 Workspace cộng đồng
- As a village member, tôi mở được danh sách thành viên, sự kiện, thông báo của
  cộng đồng mình.

### COMM-007 Event cộng đồng
- As a village leader, tôi tạo event cho community và chỉ thành viên đúng nhóm
  nhận được.

### COMM-008 Announcement cộng đồng
- As a village leader, tôi đăng thông báo họp/phát quà/tổ chức lễ để mọi người
  nhận lịch và nội dung rõ ràng.

### COMM-009 Deep-link từ notification vào community target
- As a member, tôi chạm vào thông báo và mở đúng event/thông báo trong community.

## EPIC B - Memorial space

### MEM-001 Tạo memorial entry
- As a member, tôi đăng bài memorial để lưu lại ký ức hoặc recap một sự kiện.

### MEM-002 Đính kèm ảnh và ghi chú
- As a member, tôi thêm ảnh, mô tả và ghi chú để memorial có giá trị lưu trữ.

### MEM-003 Gắn với event đã diễn ra
- As a leader, tôi tạo memorial recap từ một event để không bị đứt ngữ cảnh.

### MEM-004 Bình luận và bổ sung tư liệu
- As a member, tôi bình luận và góp thêm thông tin cho memorial entry.

### MEM-005 Xem lại theo năm/chủ đề/cộng đồng
- As a member, tôi lọc memorial để xem lại lịch sử gặp mặt của thôn/làng hoặc
  gia đình.

### MEM-006 Quyền riêng tư memorial
- As a community member, tôi chỉ xem được memorial trong phạm vi được phép.

## EPIC C - Growth loop

### GROW-001 Mời thành viên chưa tham gia app từ event/thông báo
- As a leader, tôi chia sẻ link mời tham gia app trực tiếp từ community event.

### GROW-002 Mời xem memorial recap
- As a member, tôi chia sẻ memorial recap cho người thân chưa dùng app để họ có
  động lực vào xem và gia nhập.

### GROW-003 Đo chuyển đổi từ community activity sang join/claim
- As a product owner, tôi đo được event hoặc memorial nào kéo người dùng mới
  vào app.

## 7. Kế hoạch triển khai thực tế

### Giai đoạn 1 - Foundation data + quyền

Mục tiêu:

- thêm `originProfile` vào member model, rules, profile form
- thêm `community`, `communityMemberships`
- thêm role `COMMUNITY_LEADER` hoặc `VILLAGE_LEADER`

Phạm vi code chính:

- mobile:
  - `features/profile`
  - model member
- backend:
  - `members/callables.ts`
  - `governance/callables.ts`
  - trigger sync membership mới
- security:
  - `firebase/firestore.rules`

### Giai đoạn 2 - Community operations

Mục tiêu:

- community workspace
- create event cho audience `community`
- announcement + notification

Phạm vi code chính:

- mobile:
  - `features/community/**` mới
  - mở rộng `features/events/**`
  - mở rộng notification target/deep-link
- backend:
  - callable tạo/sửa community
  - callable tạo announcement
  - mở rộng `events/event-triggers.ts`
  - mở rộng `notifications/push-delivery.ts`

### Giai đoạn 3 - Memorial MVP

Mục tiêu:

- post recap
- ảnh + note
- liên kết event -> memorial
- danh sách memorial theo scope

Phạm vi code chính:

- mobile:
  - `features/memorial/**` mới
- backend:
  - Firestore schema + rules
  - upload Storage + metadata
  - notification nhẹ khi có memorial nổi bật

### Giai đoạn 4 - Growth và tối ưu

Mục tiêu:

- share link cho event/memorial
- invite flow từ community
- analytics funnel
- moderation/spam control

## 8. Rủi ro và cách giảm rủi ro

### 8.1 Sai dữ liệu nguyên quán

Rủi ro:

- thành viên nhập quê quán tự do, khó auto-match

Giải pháp:

- dùng selector địa danh chuẩn + normalize key
- membership auto-match nhưng cho phép leader review nếu confidence thấp

### 8.2 Spam thông báo

Rủi ro:

- trưởng nhóm gửi quá nhiều announcement

Giải pháp:

- rate limit theo ngày
- cho phép member mute community
- hỗ trợ `announcementPriority`

### 8.3 Memorial bị loãng

Rủi ro:

- memorial thành news feed hỗn tạp, mất giá trị lưu trữ

Giải pháp:

- giới hạn `entryType`
- ưu tiên recap, ký ức, tư liệu, ảnh có ngữ cảnh
- dùng bộ lọc năm/sự kiện/người được nhắc đến

## 9. Đánh giá viral và kéo user

### 9.1 Tác động mạnh nhất

Tính năng này có tiềm năng kéo user tốt hơn quỹ hoặc khuyến học, vì nó chạm vào
2 động lực dùng app mạnh:

- nhu cầu biết thông tin họp/lễ/gặp mặt đúng lúc
- nhu cầu xem lại ảnh, ký ức, lịch sử cộng đồng

### 9.2 Điều gì thực sự tạo growth

Không phải bản thân `community management`, mà là các vòng lặp sau:

1. `Event -> chia sẻ -> người thân cài app để xem chi tiết`
2. `Thông báo quan trọng -> bật notification -> quay lại app thường xuyên`
3. `Memorial recap -> tag người thân -> người chưa dùng app muốn vào xem`
4. `Origin auto-match -> vừa vào app đã thấy đúng cộng đồng của mình`

### 9.3 Điều gì không viral

- dashboard quản trị thuần admin
- form tạo community dài và khó
- memorial chỉ là một thư viện ảnh không có ngữ cảnh

### 9.4 KPI nên đo

- số community được tạo / tuần
- tỷ lệ member có `originProfile` hợp lệ
- số member được auto-match vào community
- open rate của community notification
- attendance proxy: số người mở event detail sau khi nhận push
- số memorial entries / event hoàn thành
- số invite/join/claim phát sinh từ link community hoặc memorial
- D30 retention của member có tham gia community so với member không tham gia

## 10. Khuyến nghị chốt để triển khai

Thứ tự nên làm:

1. `originProfile + community + auto-membership`
2. `community event + announcement + notification`
3. `memorial MVP dạng recap/story`
4. `share/invite/analytics growth`

Không nên làm ngay ở phase đầu:

- comment/reaction quá sâu
- public social feed rộng
- ranking/gamification
- moderation phức tạp nhiều tầng

## 11. Kết luận

Đây là hướng mở rộng rất hợp với BeFam vì nó tận dụng đúng 4 trục đã có:

- member identity
- governance role
- event workflow
- notification delivery

Nếu làm đúng thứ tự, đây không chỉ là feature mới mà còn là lớp tăng trưởng tự
nhiên cho sản phẩm: người dùng có lý do quay lại, có thứ để chia sẻ, và có động
lực mời thêm người trong họ/làng cùng tham gia.
