# Test Plan và Test Cases trước Release Production

_Cập nhật gần nhất: 19/03/2026_

## 1) Mục tiêu

Tài liệu này là bộ kiểm thử đầy đủ để xác minh BeFam sẵn sàng phát hành production, bao phủ:

- code và logic nghiệp vụ
- UI/UX và luồng người dùng thực tế
- yêu cầu sản phẩm và user stories
- Firebase rules (Firestore + Storage)
- tích hợp backend (Cloud Functions, FCM, billing, dữ liệu clan)

## 2) Phạm vi và nguồn đối chiếu

## 2.1) Nguồn đối chiếu đã rà soát

- Product: `docs/vi/01-product/feature-spec.md`, `docs/vi/01-product/user-stories.md`
- Backend/Auth/Notification: `docs/vi/04-backend/authentication.md`, `docs/vi/04-backend/notifications.md`
- Security: `docs/vi/06-security/firebase-rules.md`, `firebase/firestore.rules`, `firebase/storage.rules`
- CI gate: `.github/workflows/branch-ci.yml`
- Mobile code: `mobile/befam/lib/features/*`, `mobile/befam/lib/app/home/app_shell_page.dart`
- Functions code: `firebase/functions/src/*`
- Test hiện có: `mobile/befam/test/**/*`, `firebase/functions/src/contract-tests/*.test.ts`

## 2.2) In-scope

- Auth OTP + child login + claim member + trusted device
- Multi-clan context switching và data scoping theo clan đang chọn
- Clan/Branch/Member/Relationship/Genealogy
- Event + dual calendar + reminders
- Notifications inbox, mark-read, deep-link
- Funds + transactions + treasurer/dashboard
- Scholarship programs, awards, submissions, approvals
- Billing plan entitlement + 3-step VNPay flow
- Profile, localization EN/VI, location sharing, nearby relatives
- Firestore/Storage rules cho cả allow và deny case

## 2.3) Out-of-scope (cho đợt release này)

- stress test quy mô cực lớn > 10k concurrent users
- penetration test chuyên sâu bên thứ ba
- web admin portal ngoài mobile scope hiện tại

## 3) Entry/Exit Criteria

## 3.1) Entry criteria (điều kiện bắt đầu kiểm thử RC)

- RC branch đã freeze scope
- dữ liệu test đã seed sạch và nhất quán
- Firebase project staging/prod-like sẵn sàng
- secrets và env vars đã được kiểm tra

## 3.2) Exit criteria (điều kiện cho phép release)

- 100% testcase P0 pass
- testcase P1 pass >= 95%, không còn bug Sev-1/Sev-2 mở
- toàn bộ CI required checks xanh
- không có vi phạm rule/permission nghiêm trọng
- Product + QA + Engineering sign-off

## 4) Runbook kiểm thử step-by-step trước release

1. Freeze RC commit và gắn tag nội bộ.
2. Đồng bộ env/secrets production theo `docs/vi/05-devops/production-configuration.md`.
3. Chạy gate tự động:
   - `python3 scripts/validate_rules_documentation.py`
   - `cd firebase/functions && npm ci && npm test`
   - `cd mobile/befam && flutter pub get && flutter gen-l10n && flutter analyze && flutter test --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true`
4. Build artifact kiểm tra:
   - web release build
   - Android release AAB
   - iOS release build (local CI/runner nội bộ)
5. Chạy manual P0 suite (Auth -> Multi-clan -> Core operations -> Billing -> Notifications).
6. Chạy manual P1 suite (UX edge cases, localization, permission denial, long list/lazy loading).
7. Chạy Security/Rules suite (allow + deny + cross-clan isolation).
8. Chạy NFR suite (performance, startup, offline handling, crash recovery).
9. Tổng hợp test evidence (ảnh, video, logs, query snapshots).
10. Go/No-Go meeting và ký duyệt release.

## 5) Ma trận môi trường kiểm thử

| Hạng mục | Bắt buộc |
| --- | --- |
| iOS | iOS 17+ (1 máy nhỏ màn hình, 1 máy màn hình lớn) |
| Android | Android 13/14 (ít nhất 2 OEM khác nhau) |
| Network | Wi-Fi tốt, 4G/5G, mạng chập chờn, offline -> online |
| Language | Vietnamese + English |
| Permission | Notification ON/OFF, Location ON/OFF, Photo access ON/OFF |
| Session | Tài khoản đơn clan + đa clan + unlinked user |

## 6) Ma trận vai trò test data

| Role | Mục đích kiểm thử |
| --- | --- |
| `CLAN_OWNER` | full flow + billing + governance |
| `CLAN_ADMIN` | quản trị clan/branch/member/events/scholarship |
| `BRANCH_ADMIN` | kiểm tra branch-scoped write restrictions |
| `TREASURER` | quỹ và giao dịch |
| `SCHOLARSHIP_COUNCIL_HEAD` | duyệt hồ sơ khuyến học |
| `ADMIN_SUPPORT` | governance/join review + limited admin actions |
| `MEMBER` | self profile, read-only phần quản trị |
| Unlinked user | discover/join/create clan entry points |

## 7) Bộ test case chi tiết

Ghi chú mức ưu tiên:

- `P0`: bắt buộc pass trước release
- `P1`: nên pass trong release, có thể rollback nếu bug nghiêm trọng

### 7.1) Auth, Session, Identity

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| AUTH-001 | P0 | user có member đã claim | 1) Mở app -> login phone OTP.<br>2) Nhập OTP đúng.<br>3) Quan sát landing shell. | Login thành công, vào đúng member + clan context. |
| AUTH-002 | P0 | user có OTP nhưng nhập sai | 1) Nhập OTP sai 3 lần.<br>2) Theo dõi thông báo lỗi. | Báo lỗi rõ ràng, không tạo session rác. |
| AUTH-003 | P0 | child identifier hợp lệ | 1) Chọn child login.<br>2) Nhập mã trẻ em + OTP phụ huynh.<br>3) Hoàn tất flow. | Resolve đúng parent phone + member context, không lệch clan. |
| AUTH-004 | P0 | số điện thoại tồn tại profile chưa claim | 1) Login phone.<br>2) Thực hiện claim flow.<br>3) Reload app. | `members/{id}.authUid` được gán đúng, session restore ổn định. |
| AUTH-005 | P0 | user đa clan | 1) Login thành công.<br>2) Mở menu ba chấm -> Switch clan.<br>3) Chọn clan khác. | Claims/session đổi đúng clan, data toàn app đổi theo clan mới. |
| AUTH-006 | P1 | trusted device bật | 1) Login trên thiết bị A.<br>2) Logout/login lại trên A.<br>3) Thử trên thiết bị B. | Device trust hoạt động đúng, không bypass OTP trái phép. |
| AUTH-007 | P0 | số phone format khác nhau | 1) Thử login với biến thể `+84`, `0`, có khoảng trắng.<br>2) So khớp profile. | Normalize nhất quán về E.164, mapping đúng một profile. |
| AUTH-008 | P1 | token hết hạn | 1) Để phiên cũ hết hạn/thu hồi.<br>2) Mở lại app. | App yêu cầu xác thực lại, không treo UI. |
| AUTH-009 | P0 | user chưa có clan/member | 1) Login user mới.<br>2) Vào Home/Tree/Profile. | Không crash, hiển thị empty-state có CTA rõ ràng để tạo/join clan. |
| AUTH-010 | P1 | app kill/reopen | 1) Login thành công.<br>2) Đóng hẳn app rồi mở lại. | Session restore đúng; không nhảy sai màn hình. |

### 7.2) Clan Context và Navigation toàn app

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| CTX-001 | P0 | user có >=2 clan | 1) Ở mọi tab chính, quan sát header context clan.<br>2) Switch clan từ menu. | Header luôn hiển thị **tên clan** (không phải ID), cập nhật realtime sau switch. |
| CTX-002 | P0 | user có >=2 clan | 1) Ở tab Events/Funds/Scholarship, switch clan.<br>2) Pull to refresh từng tab. | Dữ liệu chỉ thuộc clan đang active, không lẫn clan khác. |
| CTX-003 | P0 | unlinked user | 1) Mở tab Gia phả/discovery.<br>2) Nhấn nút `+`. | Mở form tạo gia phả/join flow phù hợp, không điều hướng gây confuse. |
| CTX-004 | P1 | app đang ở tab con | 1) Switch clan khi đang ở deep page (event detail/fund detail).<br>2) Back về root. | Context giữ nhất quán, không còn dữ liệu stale của clan cũ. |
| CTX-005 | P0 | user có quyền hạn khác nhau theo clan | 1) Clan A (admin), clan B (member).<br>2) Switch qua lại và thử action write. | Permission thay đổi đúng theo clan hiện tại. |
| CTX-006 | P1 | logout từ menu | 1) Mở menu ba chấm.<br>2) Chọn logout.<br>3) Mở lại app. | Logout sạch session + token context local. |
| CTX-007 | P1 | localization EN/VI | 1) Đổi language trong profile.<br>2) Kiểm tra labels header/menu/action. | Chuỗi UI đổi đúng theo ngôn ngữ, không hardcode còn sót. |
| CTX-008 | P0 | app startup | 1) Cold start app.<br>2) Quan sát tab đáy. | Tab label đúng UX thống nhất (`Nhà`, `Gia phả`, `Sự kiện`, `Gói`, `Hồ sơ`). |

### 7.3) Member, Relationship, Genealogy

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| MEM-001 | P0 | admin role | 1) Mở Member workspace.<br>2) Tạo thành viên bằng stepper 3 bước.<br>3) Lưu. | Stepper cân đối, lưu thành công, record xuất hiện trong list. |
| MEM-002 | P0 | admin role | 1) Tạo member có phone.<br>2) Kiểm tra format phone và icon phone trên card list. | Phone hiển thị đúng chuẩn, icon thẳng hàng, không lệch layout. |
| MEM-003 | P0 | dataset >50 members | 1) Scroll list thành viên đến cuối.<br>2) Theo dõi tải thêm dữ liệu. | Lazy loading hoạt động, không load toàn bộ một lần, không giật lag mạnh. |
| MEM-004 | P1 | admin role | 1) Sửa hồ sơ member.<br>2) Đổi avatar.<br>3) Reload app. | Dữ liệu persist đúng, avatar cập nhật đúng Storage path/rules. |
| MEM-005 | P0 | branch admin | 1) Thử sửa member cùng branch.<br>2) Thử sửa member khác branch. | Chỉ được sửa trong phạm vi branch được cấp. |
| REL-001 | P0 | có 3 member test | 1) Tạo quan hệ cha mẹ-con cái hợp lệ.<br>2) Lưu. | Quan hệ tạo thành công, graph cập nhật đúng chiều. |
| REL-002 | P0 | có quan hệ sẵn | 1) Tạo quan hệ gây vòng lặp/cạnh không hợp lệ.<br>2) Lưu. | Validation chặn với lỗi rõ ràng, không ghi dữ liệu sai. |
| REL-003 | P1 | spouse relation | 1) Tạo quan hệ vợ/chồng trùng cặp.<br>2) Lưu. | Chặn trùng quan hệ theo ràng buộc nghiệp vụ. |
| TREE-001 | P0 | có cây gia phả đủ sâu | 1) Mở màn hình cây.<br>2) Dùng bộ lọc hiển thị.<br>3) Expand/collapse cha mẹ/con cái. | UI không vỡ dòng, nút icon cân đối, thao tác mượt. |
| TREE-002 | P0 | có data nhiều nhánh | 1) Dùng nút `+` trên tree.<br>2) Chọn từng action: thêm gia phả/nhánh/thành viên. | Menu + hiển thị đúng option theo quyền và context. |
| TREE-003 | P1 | ở tree workspace | 1) Nhấn icon refresh trong title khu vực tree.<br>2) Quan sát dữ liệu. | Refresh đúng scope, không reset filter ngoài ý muốn. |
| TREE-004 | P1 | mobile nhỏ màn hình | 1) Test portrait/landscape (nếu hỗ trợ).<br>2) Quan sát card/button text. | Không break line khó đọc; tap target đủ lớn. |

### 7.4) Events và Dual Calendar

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| EVT-001 | P0 | admin role | 1) Tạo event dương lịch.<br>2) Lưu và mở lại detail. | Event lưu đúng timezone/startsAt/endsAt. |
| EVT-002 | P0 | admin role | 1) Tạo event âm lịch lặp hằng năm.<br>2) Kiểm tra occurrence kế tiếp. | Resolver âm lịch đúng ngày; không lệch múi giờ. |
| EVT-003 | P1 | admin role | 1) Sửa event đã có.<br>2) Đổi audience/visibility.<br>3) Lưu. | Quyền chỉnh sửa đúng role; data cập nhật chính xác. |
| EVT-004 | P1 | member role | 1) Vào event workspace.<br>2) Thử tạo/sửa/xóa event. | Member thường bị chặn write; chỉ đọc dữ liệu được phép. |
| EVT-005 | P0 | home card upcoming event | 1) Mở Home card "Sự kiện gần tới".<br>2) Kiểm tra tiêu đề và dòng metadata. | Không break line xấu; nội dung địa điểm/clan name đúng context. |
| EVT-006 | P1 | event có địa chỉ map | 1) Nhấn icon điều hướng địa chỉ.<br>2) Kiểm tra deep-link map app. | Mở app bản đồ thành công hoặc fallback hợp lệ. |
| EVT-007 | P0 | switch clan | 1) Chuyển clan.<br>2) Vào event list/home card. | Chỉ hiện event của clan active. |
| EVT-008 | P1 | notification trigger path | 1) Tạo event mới.<br>2) Kiểm tra notifications collection + push. | Trigger gửi notification đúng audience. |

### 7.5) Notifications (Inbox, push, deep-link)

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| NOTIF-001 | P0 | đã bật quyền notification | 1) Login app trên thiết bị thật.<br>2) Kiểm tra token đăng ký thành công. | Có `users/{uid}/deviceTokens/{token}` với context đúng. |
| NOTIF-002 | P0 | có bản tin notification | 1) Mở inbox.<br>2) Scroll cuối danh sách. | Pagination hoạt động, load thêm ổn định. |
| NOTIF-003 | P0 | notification chưa đọc | 1) Nhấn vào item trong inbox.<br>2) Quay lại list. | `isRead` cập nhật đúng, badge/trạng thái đổi ngay. |
| NOTIF-004 | P0 | push event | 1) Trigger push event từ backend.<br>2) Tap notification system tray. | App deep-link đến target event page chính xác. |
| NOTIF-005 | P0 | push scholarship | 1) Trigger push scholarship.<br>2) Tap notification. | App deep-link đến scholarship target page chính xác. |
| NOTIF-006 | P1 | foreground push | 1) Giữ app foreground.<br>2) Trigger push. | Hiện in-app feedback/snackbar đúng nội dung. |
| NOTIF-007 | P1 | invalid token scenario | 1) Gỡ app/tạo token cũ invalid.<br>2) Trigger push. | Token invalid bị cleanup khỏi Firestore. |
| NOTIF-008 | P1 | member thường | 1) Thử cập nhật notification của member khác (tools/emulator). | Rules chặn, chỉ self mark-read được phép. |

### 7.6) Funds

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| FUND-001 | P0 | treasurer/admin | 1) Tạo quỹ mới.<br>2) Kiểm tra list và detail. | Quỹ tạo thành công, hiển thị đúng loại/quy mô áp dụng. |
| FUND-002 | P0 | có quỹ tồn tại | 1) Tạo giao dịch thu/chi hợp lệ.<br>2) Kiểm tra số dư sau mỗi giao dịch. | Số dư tính đúng và nhất quán với ledger. |
| FUND-003 | P0 | role member | 1) Đăng nhập member thường.<br>2) Thử tạo/sửa quỹ hoặc giao dịch. | Bị chặn write theo quyền. |
| FUND-004 | P1 | fund card UI | 1) Mở danh sách quỹ nhiều item.<br>2) Kiểm tra spacing/card hierarchy. | Không lồng container rối; thông tin quan trọng dễ đọc trên mobile. |
| FUND-005 | P1 | có thủ quỹ được gán | 1) Mở fund detail/workspace.<br>2) Kiểm tra thông tin người thủ quỹ. | Chỉ hiển thị thủ quỹ thuộc quỹ hiện tại + clan hiện tại. |
| FUND-006 | P1 | dataset lớn | 1) Scroll danh sách quỹ dài.<br>2) Quan sát tải thêm. | Lazy loading hoạt động, không tải tất cả một lần. |
| FUND-007 | P1 | switch clan | 1) Đổi clan active.<br>2) Vào fund workspace. | Dữ liệu quỹ và dashboard đổi theo clan active. |
| FUND-008 | P0 | server-only transaction writes | 1) Thử client write trực tiếp `transactions`.<br>2) Quan sát kết quả. | Bị deny bởi rules. |
| FUND-009 | P1 | dashboard tổng hợp | 1) Kiểm tra cards số quỹ/giao dịch/quyền truy cập.<br>2) So với dữ liệu thực. | Các số liệu đúng, không mismatch context. |

### 7.7) Scholarship

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| SCH-001 | P0 | admin role | 1) Tạo chương trình khuyến học.<br>2) Điền tiêu đề, năm, trạng thái.<br>3) Lưu. | Program tạo thành công, xuất hiện trong danh sách. |
| SCH-002 | P0 | có program | 1) Tạo mức thưởng trong program.<br>2) Lưu và reload. | Award level lưu đúng thứ tự hiển thị và loại thưởng. |
| SCH-003 | P0 | member role | 1) Tạo hồ sơ đề cử.<br>2) Upload minh chứng.<br>3) Gửi hồ sơ. | Submission tạo thành công, file upload đúng path/rules. |
| SCH-004 | P0 | reviewer role | 1) Mở submission pending.<br>2) Approve hoặc reject.<br>3) Lưu quyết định. | Trạng thái cập nhật đúng, audit/log ghi nhận đầy đủ. |
| SCH-005 | P1 | user không phải reviewer | 1) Mở hàng đợi xét duyệt.<br>2) Thử action duyệt. | UI hiển thị đúng "không có quyền", không cho thao tác. |
| SCH-006 | P1 | danh sách dài | 1) Scroll list programs/submissions.<br>2) Theo dõi tải thêm. | Lazy loading hoạt động, UX mượt. |
| SCH-007 | P1 | nhiều action tạo mới | 1) Nhấn FAB `+`.<br>2) Chọn từng action (chương trình/mức thưởng/hồ sơ). | Menu hành động thống nhất, không trùng CTA gây rối. |
| SCH-008 | P0 | notification trigger | 1) Duyệt submission.<br>2) Kiểm tra push + inbox người nộp. | Notification gửi đúng người, deep-link mở đúng chi tiết. |
| SCH-009 | P1 | switch clan | 1) Chuyển clan active.<br>2) Vào scholarship workspace. | Program/award/submission chỉ thuộc clan active. |
| SCH-010 | P1 | localization | 1) Chuyển EN/VI.<br>2) Kiểm tra label/trạng thái trong scholarship. | Không còn text hardcode sai ngôn ngữ. |

### 7.8) Billing và VNPay

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| BILL-001 | P0 | owner/admin clan | 1) Mở trang Gói.<br>2) Kiểm tra plan hiện tại + member count. | Entitlement phản ánh đúng plan thực tế đang hiệu lực. |
| BILL-002 | P0 | clan có 0-10 member | 1) Resolve entitlement.<br>2) Kiểm tra plan tối thiểu. | Mặc định `FREE`. |
| BILL-003 | P0 | clan có 11-200 member | 1) Resolve entitlement.<br>2) Kiểm tra minimum tier. | Clan phải ở mức tối thiểu `BASE`. |
| BILL-004 | P0 | đang ở plan cao | 1) Chọn hạ gói dưới mức tối thiểu theo member count.<br>2) Continue checkout. | Hệ thống chặn downgrade không hợp lệ, báo lỗi rõ ràng. |
| BILL-005 | P1 | đang còn hạn gói hiện tại | 1) Chọn gia hạn cùng gói khi chưa gần hạn.<br>2) Continue. | Chặn renew sớm theo rule hiện tại. |
| BILL-006 | P0 | upgrade hợp lệ | 1) Chọn gói cao hơn ở step 1.<br>2) Sang step 2 xác nhận.<br>3) Qua step 3 VNPay. | Stepper cân đối, CTA không xuống dòng, flow rõ ràng. |
| BILL-007 | P0 | VNPay success path | 1) Thanh toán thành công.<br>2) Quay lại app.<br>3) Refresh billing. | Transaction/invoice/subscription cập nhật, plan kích hoạt đúng. |
| BILL-008 | P0 | VNPay pending path | 1) Tạo giao dịch pending.<br>2) Kiểm tra UI trạng thái. | Không kích hoạt plan mới cho đến khi confirmed. |
| BILL-009 | P0 | VNPay failed/cancel | 1) Hủy/failed tại cổng thanh toán.<br>2) Quay lại app. | Giữ plan cũ, hiển thị trạng thái thất bại rõ ràng. |
| BILL-010 | P1 | non-billing role | 1) Đăng nhập member thường.<br>2) Mở billing data nhạy cảm. | Bị chặn đọc document billing nhạy cảm theo rules. |
| BILL-011 | P1 | checkout form | 1) Nhập số điện thoại liên hệ.<br>2) Kiểm tra normalize lưu payload. | Phone được normalize nhất quán. |
| BILL-012 | P1 | pending transactions | 1) Mở detail giao dịch chờ.<br>2) Copy checkout URL (nếu có). | Detail đầy đủ, copy URL hoạt động. |

### 7.9) Profile, Localization, Nearby Relatives

| ID | Mức | Tiền điều kiện | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- | --- |
| PRO-001 | P0 | member linked | 1) Mở profile.<br>2) Sửa thông tin được phép.<br>3) Lưu. | Chỉ field cho phép được update, lưu thành công. |
| PRO-002 | P0 | unlinked user | 1) Login user chưa có member/clan.<br>2) Mở profile screen. | Empty-state thân thiện, có CTA cập nhật thông tin/gia nhập/tạo clan. |
| PRO-003 | P1 | language switch | 1) Đổi ngôn ngữ VI/EN.<br>2) Kiểm tra toàn app. | Chuỗi UI đổi đồng bộ, không còn text sai ngữ cảnh. |
| PRO-004 | P1 | location permission OFF | 1) Vào "Người thân ở gần bạn".<br>2) Quan sát guidance box.<br>3) Bấm link cấp quyền. | Có link mở đúng OS settings (`App Settings`/`Location Settings`). |
| PRO-005 | P0 | location permission ON trên >=2 user | 1) Bật share vị trí cho nhiều member gần nhau.<br>2) Mở nearby list + radar rescan. | Danh sách gần đây dựa trên vị trí thật, cập nhật sau rescan. |
| PRO-006 | P1 | location sharing OFF | 1) Tắt chia sẻ vị trí.<br>2) Reload nearby module. | User không bị lộ vị trí; UI hiển thị trạng thái phù hợp. |
| PRO-007 | P1 | profile avatar | 1) Đổi avatar bằng ảnh >10MB và ảnh hợp lệ.<br>2) So sánh kết quả. | File quá giới hạn bị chặn; file hợp lệ upload thành công. |
| PRO-008 | P1 | header clan context | 1) Đi qua tất cả tabs.<br>2) Xác minh header luôn hiện tên clan. | Không còn hiển thị clan ID/hardcode. |
| PRO-009 | P1 | accessibility basic | 1) Tăng font hệ thống.<br>2) Duyệt màn profile/home/cards chính. | Text vẫn đọc được, CTA chính không vỡ layout nghiêm trọng. |

## 8) Security/Rules Test Suite (Firestore + Storage)

| ID | Mức | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- |
| RULE-001 | P0 | Dùng client account A đọc `members` clan B. | Deny (cross-clan isolation). |
| RULE-002 | P0 | Member tự update profile với field ngoài whitelist (`primaryRole`, `clanId`). | Deny bởi `safeProfileUpdate()`. |
| RULE-003 | P0 | Member update field hợp lệ (`nickName`, `bio`, `location*`). | Allow. |
| RULE-004 | P0 | Branch admin sửa member ngoài branch claim. | Deny. |
| RULE-005 | P0 | Client ghi trực tiếp `transactions`. | Deny (server-only write). |
| RULE-006 | P0 | Client tạo notification doc trực tiếp. | Deny (server-only write). |
| RULE-007 | P0 | Member đánh dấu read notification của member khác. | Deny. |
| RULE-008 | P0 | Member mark-read notification của chính mình (`isRead` only). | Allow. |
| RULE-009 | P0 | Non-billing role đọc `subscriptions/paymentTransactions`. | Deny. |
| RULE-010 | P0 | Billing admin đọc billing docs đúng clan. | Allow. |
| RULE-011 | P1 | Upload avatar sai content-type hoặc >10MB. | Deny tại Storage rules. |
| RULE-012 | P1 | Upload scholarship evidence >20MB hoặc sai path owner. | Deny; owner đúng path + size hợp lệ thì allow. |

## 9) Non-functional và Reliability Suite

| ID | Mức | Bước test (step-by-step) | Kỳ vọng |
| --- | --- | --- | --- |
| NFR-001 | P0 | Cold start app trên iOS/Android 3 lần, đo thời gian đến home. | Không crash; thời gian ổn định trong ngưỡng team chấp nhận. |
| NFR-002 | P1 | Scroll list member/fund/scholarship dài liên tục 2-3 phút. | Không leak nghiêm trọng, không jank kéo dài. |
| NFR-003 | P0 | Chuyển mạng online -> offline -> online trong khi load dữ liệu. | Hiện lỗi thân thiện, có thể retry, app không treo. |
| NFR-004 | P1 | Nhận push khi app foreground/background/terminated. | Hành vi nhất quán, không duplicate mở trang đích. |
| NFR-005 | P1 | Kill app giữa lúc đang checkout/bottom sheet form. | Mở lại app không hỏng session, không mất ổn định state. |
| NFR-006 | P1 | Bật chế độ pin thấp và mạng yếu, test flow chính. | CTA vẫn phản hồi, timeout/error message rõ ràng. |
| NFR-007 | P1 | Đổi ngôn ngữ liên tục ở runtime rồi điều hướng qua các tab. | Không crash, không string null/hardcode lẫn ngôn ngữ. |
| NFR-008 | P1 | Test với timezone khác `Asia/Ho_Chi_Minh` trên thiết bị. | Event time hiển thị nhất quán theo logic app/timezone setting. |

## 10) Traceability Matrix (Requirement -> Test coverage)

| Nhóm yêu cầu | Nguồn | Testcase chính |
| --- | --- | --- |
| Xác thực OTP/child/claim | Product spec + Auth docs | AUTH-001..AUTH-010, RULE-002..RULE-004 |
| Multi-clan context và data scoping | App shell + auth callables | CTX-001..CTX-008, RULE-001 |
| Thành viên, quan hệ, gia phả | User stories + features code | MEM-001..TREE-004, RULE-004 |
| Sự kiện và lịch kép | User stories + events/calendar code | EVT-001..EVT-008 |
| Notification inbox + deep-link | Notifications docs + code | NOTIF-001..NOTIF-008, RULE-006..RULE-007 |
| Quỹ và giao dịch | Funds features + functions triggers | FUND-001..FUND-009, RULE-005 |
| Khuyến học | Scholarship features + triggers | SCH-001..SCH-010, RULE-012 |
| Billing + VNPay + entitlement | Pricing/callables/rules | BILL-001..BILL-012, RULE-009..RULE-010 |
| Hồ sơ, localization, nearby | Profile/member/home code | PRO-001..PRO-009, NFR-007 |
| Reliability trước release | CI + runtime | NFR-001..NFR-008 |

## 11) Mẫu ghi nhận bằng chứng kiểm thử

Sử dụng template sau cho mỗi test run:

- Build/Commit: `<sha>`
- Môi trường: `staging/prod-like`
- Thiết bị: `iOS/Android model`
- Testcase ID: `AUTH-001 ...`
- Kết quả: `PASS/FAIL/BLOCKED`
- Bằng chứng: screenshot/video/log/query link
- Ghi chú lỗi: steps tái hiện + severity + owner

## 12) Release Go/No-Go Checklist

- [ ] Toàn bộ P0 PASS
- [ ] Không còn bug Sev-1/Sev-2 mở
- [ ] CI required checks xanh hoàn toàn
- [ ] Firestore/Storage rules deny/allow suite PASS
- [ ] Billing success/pending/failed path PASS
- [ ] Notification push + deep-link PASS trên thiết bị thật
- [ ] Multi-clan switch không rò dữ liệu cross-clan
- [ ] Localization EN/VI không còn chuỗi hardcode sai
- [ ] Product sign-off
- [ ] Engineering sign-off
- [ ] QA sign-off
