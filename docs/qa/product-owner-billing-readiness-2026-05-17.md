# Product Owner Billing Readiness Review - BeFam

Ngày: 2026-05-17  
Vai trò reviewer: Product Owner  
Branch review: `hunpeolabs/ai-production-ux-pass`  
Phạm vi: luồng mua gói, Billing/Gói, package value, web purchase clarity,
Funds/Quỹ IA, và bằng chứng release cho billing/funds.  
Quyết định: **NO-GO cho production release.**

## Kết luận PO

BeFam **chưa sẵn sàng release billing/package purchase** ở trạng thái hiện tại.

Code đã có nền tảng billing workspace và luồng mua trên mobile, nhưng hành trình
người mua chưa đạt mức production-ready vì discovery, taxonomy gói, payment
model, web clarity và release evidence chưa khớp nhau.

Các điểm chính:

- App shell hiện đưa `Quỹ/Funds` lên tab đáy thứ 4, không còn `Gói/Billing`.
- Mua gói nằm ở Profile -> `Gói của bạn` -> `Đổi hoặc nâng cấp`; đây là entry
  hợp lệ nhưng chưa đủ rõ cho người dùng chủ động tìm chỗ mua gói.
- Runtime dùng plan code `FREE/BASE/PLUS/PRO`; UI fallback hiển thị
  `Miễn phí/Tiêu chuẩn/Nâng cao/Toàn diện`. Chưa có package tên `Premium` hoặc
  `Enterprise` trong luồng hiện tại.
- Product/release docs vẫn mô tả checkout VNPay 3 bước, trong khi code hiện
  nghiêng sang Store IAP trên iOS/Android; web checkout không khả dụng.
- Web marketing/legal có nhắc paid services nhưng chưa có pricing page, bảng so
  sánh gói, CTA mua gói, hoặc thông điệp rõ "mua trong mobile app".
- `Quỹ` là workflow clan-operations đúng và nên có chỗ nổi bật, nhưng việc đưa
  `Quỹ` thay slot `Gói` làm package purchase giảm discoverability.

## Bằng chứng đã review

- Graph context: `graphify-out/GRAPH_REPORT.md`.
- Product/release docs:
  - `docs/en/01-product/epic-tiered-subscription-payments.md`
  - `docs/vi/01-product/epic-tiered-subscription-payments.md`
  - `docs/vi/05-devops/release-test-plan.md`
  - `docs/en/05-devops/production-configuration.md`
  - `docs/vi/05-devops/service-inventory.md`
- QA/release reports hiện có:
  - `docs/qa/product-owner-review-2026-05-17.md`
  - `docs/qa/dev-lead-release-issue-triage-2026-05-17.md`
  - `docs/qa/dev-lead-post-fix-validation-2026-05-17.md`
- Source/test liên quan:
  - `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart`
  - `mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart`
  - `mobile/befam/lib/app/home/app_shell_page.dart`
  - `mobile/befam/lib/app/web/web_marketing_pages.dart`
  - `firebase/functions/src/billing/**`
  - `mobile/befam/test/features/billing/billing_workspace_page_test.dart`
  - `mobile/befam/test/app/home/app_shell_billing_tab_test.dart`
  - `mobile/befam/test/app/web/web_marketing_pages_test.dart`

Targeted verification đã chạy:

```bash
cd mobile/befam
flutter test test/features/billing/billing_workspace_page_test.dart test/app/home/app_shell_billing_tab_test.dart test/app/web/web_marketing_pages_test.dart
```

Kết quả: **pass, 14 tests**. Đây là bằng chứng widget/sandbox hữu ích, nhưng
không chứng minh provider payment thật, callback/webhook, cấu hình store product,
hoặc entitlement activation trên staging/production backend.

## Đánh giá readiness

### Mobile app - chỗ mua gói

Trạng thái: **có nhưng chưa đủ rõ để release.**

Điểm đang ổn:

- Billing workspace hiển thị plan hiện tại, trạng thái, giá năm, quảng cáo/
  không quảng cáo, ngày hết hạn, kỳ thanh toán tiếp theo, và danh sách plan có
  thể chọn.
- Profile có card `Gói của bạn`, hiển thị tóm tắt AI quota và CTA
  `Đổi hoặc nâng cấp`.
- Billing page có quick pricing view và CTA checkout khi store product IDs được
  cấu hình.
- Copy pending activation nói rõ gói chỉ kích hoạt sau khi BeFam xác nhận giao
  dịch thành công.

Khoảng trống:

- Người dùng tìm `Gói`, `Premium`, hoặc `Enterprise` sẽ không thấy các nhãn đó ở
  tab chính hoặc tên plan hiện tại.
- Tab đáy thứ 4 là `Quỹ/Funds`; đúng cho quỹ dòng họ, nhưng không còn là entry
  mua gói dễ thấy.
- Value proposition của gói còn mỏng: chủ yếu là member range, giá, ads/ad-free,
  AI quota. Chưa đủ rõ giá trị quản trị clan, audit/history, support, payment
  protection, hoặc lý do chọn gói cao hơn.
- Luồng mua hiện không giống acceptance docs `Chọn gói -> Xác nhận -> Thanh toán
  VNPay`. Code mobile hiện mở Store IAP trực tiếp khi khả dụng.

### Web - chỗ mua gói

Trạng thái: **chưa rõ.**

- Landing page giải thích BeFam cho gia phả, sự kiện, quỹ và việc chung; CTA
  chính mở app.
- Terms có nói một số tính năng phụ thuộc gói/thanh toán và quyền dùng chỉ mở
  sau khi hệ thống/store xác nhận.
- Không tìm thấy pricing page, bảng so sánh gói, nhãn
  `Tiêu chuẩn/Premium/Enterprise`, route checkout, hoặc copy nói rõ mua gói chỉ
  thực hiện trong mobile app.

Web chỉ chấp nhận được nếu Product xác nhận web là marketing/legal-only và mọi
purchase diễn ra trong app. Nếu vậy, web vẫn cần nói rõ điều này.

### Gói vs Quỹ/Funds IA

Trạng thái: **Quỹ rõ hơn, Gói kém discoverability hơn.**

- `Quỹ/Funds` xứng đáng là tab riêng vì đây là workflow clan operations lõi.
- Billing/Gói hiện sống trong Profile và assistant route; đây là entry phụ, không
  phải primary purchase surface.
- Release docs vẫn kỳ vọng tab thứ 4 là `Gói`, còn shell test hiện assert
  `Funds`. IA đã đổi nhưng acceptance language chưa đổi.
- Với user chưa có clan/unlinked, tab `Quỹ` có thể gây hiểu nhầm nếu empty/locked
  state không giải thích rõ cần clan context và không dẫn tới join/create clan
  hoặc personal billing phù hợp.

### Billing vs Funds trust boundary

Trạng thái: **tách khái niệm đúng, thiếu evidence.**

- Billing quản lý entitlement, store product IDs, payment transactions, invoices,
  audit logs và AI quota.
- Funds quản lý ledger tiền quỹ dòng họ và treasurer workflows.
- Không nên gộp ngôn ngữ Billing/Gói và Quỹ. Người dùng phải hiểu mua gói BeFam
  khác với đóng góp/thu chi quỹ dòng họ.
- Navigation hiện làm Quỹ nổi bật hơn, nhưng chưa bù lại độ rõ của Billing/Gói.

## Release blockers

| ID | Priority | Area | Blocker | Required resolution |
| --- | --- | --- | --- | --- |
| PO-BILL-P0-01 | P0 | Payment model | Docs/release tests yêu cầu VNPay 3 bước, nhưng code hiện remove card webhook và dùng Store IAP cho iOS/Android. | Product phải chốt payment model release: IAP-only, VNPay-only, hoặc phased. Sau đó update docs, test plan, support copy và UI copy. |
| PO-BILL-P0-02 | P0 | Purchase evidence | Chưa có evidence staging/provider cho success, pending, failed/cancel, entitlement activation, invoice/transaction write, và no-activation-before-confirmation. | Chạy BILL-001..BILL-012 trên đúng RC với backend/provider evidence. |
| PO-BILL-P0-03 | P0 | Catalog/config | Chưa có evidence `subscriptionPackages` staging/production có active `FREE/BASE/PLUS/PRO`, đúng giá, đúng localized names, đúng iOS/Android product IDs. | Đính kèm config audit output và store product mapping evidence. |
| PO-BILL-P0-04 | P0 | Package taxonomy | Request nhắc `Tiêu chuẩn/Premium/Enterprise`, nhưng current taxonomy là `Tiêu chuẩn/Nâng cao/Toàn diện` trên `BASE/PLUS/PRO`. | Chốt tên gói cuối cùng và align app copy, web copy, docs, store metadata, support scripts. |
| PO-BILL-P1-01 | P1 | Discoverability | Mua gói nằm dưới Profile; bottom nav hiện là `Quỹ/Funds`. | Chốt strategy entry Billing/Gói: profile-only với copy rõ, home card/shortcut, overflow route, hoặc dedicated route. |
| PO-BILL-P1-02 | P1 | Web clarity | Web chưa hiển thị package, giá, kênh mua, hoặc giới hạn app-only purchase. | Thêm pricing/package guidance hoặc copy rõ mua trong mobile app. |
| PO-BILL-P1-03 | P1 | Buyer value | Plan comparison chưa làm rõ giá trị Premium/Enterprise-level. | Bổ sung value ngoài price/member count: governance, ad-free, AI quota, audit/history, support, clan scale. |
| PO-FUND-P1-01 | P1 | Funds evidence | Funds list/validation có, nhưng ledger đầy đủ và treasurer workflow chưa có evidence release. | Chạy FUND-001..FUND-009 với Firestore/backend balance proof và role-denial evidence. |
| PO-FUND-P2-01 | P2 | IA consistency | Release docs vẫn kỳ vọng tab `Gói`, current shell kỳ vọng `Funds`. | Update release test plan sau khi Product sign off IA. |

## Acceptance criteria để chuyển GO

Billing/package release chỉ có thể chuyển từ **NO-GO** sang **GO** khi toàn bộ
điều kiện dưới đây đúng cho exact release candidate:

1. Taxonomy gói đã chốt và thống nhất:
   `Tiêu chuẩn/Premium/Enterprise` hoặc `Tiêu chuẩn/Nâng cao/Toàn diện`, không
   dùng lẫn.
2. App có entry mua gói rõ và đã test. Nếu Billing chỉ nằm trong Profile, Home/
   Profile copy phải hướng người dùng đủ rõ.
3. Mobile plan comparison hiển thị tên gói, giá năm, member range, ads state,
   AI quota, và giá trị clan-management bằng ngôn ngữ người trả tiền hiểu được.
4. Payment model thống nhất giữa code, docs, QA và support: Store IAP hoặc
   VNPay, không còn acceptance stale.
5. Success, pending, failed, canceled, expired và grace-period states được verify
   bằng provider/backend evidence.
6. Entitlement chỉ activate sau provider success đã verify. Pending/failed không
   bao giờ unlock upgraded access.
7. `subscriptionPackages` staging/production được verify active plans, prices,
   localized names và store product IDs.
8. Web có pricing/package page rõ hoặc nói rõ purchase được xử lý trong mobile
   app.
9. Funds/Quỹ tách rõ khỏi Billing/Gói; không có copy khiến user hiểu tiền quỹ
   dòng họ dùng để mua gói BeFam.
10. Funds ledger cases pass: tạo quỹ, thu, chi, balance recalculation, gán thủ
    quỹ, member denial, server-only write denial.
11. Evidence links screenshots/logs/provider traces tới BILL/FUND case IDs,
    expected result, actual result, owner và status.
12. Product, QA và Engineering sign off sau khi toàn bộ P0 pass và P1 pass rate
    đạt release policy.

## Missing evidence

- Real/staged IAP purchase proof trên iOS và Android, hoặc quyết định rõ release
  này không dùng IAP.
- VNPay proof nếu VNPay vẫn nằm trong release scope.
- Provider callback/webhook evidence cho success, renewal, cancel, refund và
  expired subscription paths.
- `subscriptionPackages` config audit cho staging và production.
- App Store Connect / Google Play subscription product status screenshots hoặc
  API output.
- Billing screen screenshots/videos đi từ home/profile tới chọn gói và mua gói.
- Web screenshots cho pricing/package guidance, nếu web nằm trong scope.
- Kết quả đầy đủ BILL-001..BILL-012.
- Kết quả đầy đủ FUND-001..FUND-009.
- Cross-clan/rules evidence chứng minh billing records và funds ledgers được
  scope đúng.
- Final release execution sheet có evidence URLs và sign-off.

## Recommended priority

### P0 - phải xử lý trước release

1. Chốt payment model release và gỡ mâu thuẫn IAP runtime vs VNPay-first docs/
   test plan.
2. Chốt taxonomy và user-facing package labels.
3. Produce BILL-001..BILL-012 evidence với real/staged provider traces và
   entitlement proof.
4. Verify `subscriptionPackages` và store product IDs cho staging/production.

### P1 - cần để billing launch đạt chất lượng

1. Làm Billing/Gói dễ tìm dù tab chính là Funds/Quỹ.
2. Thêm hoặc verify web pricing/app-only purchase guidance.
3. Tăng độ rõ của plan value copy để payer hiểu vì sao nên nâng gói.
4. Hoàn tất funds ledger evidence để `Quỹ` không ship như money workflow chỉ
   mới chứng minh một phần.

### P2 - nên sửa hoặc explicitly accept

1. Update release docs/test cases từ kỳ vọng tab `Gói` sang IA cuối cùng.
2. Thêm QA evidence index mapping screenshots/logs tới BILL/FUND case IDs.
3. Recapture final steady-state billing/funds screenshots, không còn loading,
   overlay hoặc debug-only ambiguity.

## Final recommendation

**NO-GO.**

Branch hiện có nền tảng billing và funds hữu ích; targeted sandbox widget tests
đã pass. Product readiness vẫn bị chặn bởi payment-model contradiction, taxonomy
gói chưa khớp kỳ vọng Premium/Enterprise, purchase discoverability yếu sau khi
đưa `Quỹ` lên tab chính, web chưa rõ chỗ mua gói, và thiếu high-trust evidence
cho money flows của billing/funds.
