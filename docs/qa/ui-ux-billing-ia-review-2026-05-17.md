# BeFam UI/UX Billing IA Review

Date: 2026-05-17
Reviewer role: UI/UX Manager
Scope: Read-only IA/UI review of the current web/mobile billing, funds, navigation, purchase CTA, plan cards, loading/button states, forms, and motion. No production code was changed.

## Executive Summary

The product direction is close, but the current IA still lets "Gói/Billing" and "Quỹ/Funds" blur in several high-trust places. Funds is a clan treasury workflow, while Billing is a BeFam subscription workflow; the UI should keep those two mental models separate at every nav label, card title, CTA, and payment state.

Top blockers:

- The purchase CTA can look actionable on web/non-store sessions, then only returns "checkout is not available" after tap.
- Web and mobile copy mix clan funds, product billing, "quyền dùng", AI usage, and payment history in ways that weaken user confidence.
- Plan cards do not expose member limits, current clan size, or eligibility reason even though the code enforces those rules.

## Severity Legend

- P0: Blocks release or causes serious trust/compliance failure.
- P1: High-impact UX issue likely to block purchase, finance workflow, or user trust.
- P2: Important clarity/ergonomics issue; should fix before broad rollout.
- P3: Polish or consistency improvement.

## P0 Findings

No P0 blockers found in this read-only pass.

## P1 Findings

### P1-1: Purchase CTA is enabled even when checkout is unavailable on web/non-store sessions

Screen/path:

- Mobile/Profile entry: `/profile/settings` -> `Gói của bạn`
- Billing workspace: `BillingWorkspacePage`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:500`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:704`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:726`

Expected:

- If the current platform cannot complete checkout, the primary CTA should not present as a purchase action.
- Users should know whether they can buy now, must open the iOS/Android app, or must contact admin/support.

Actual:

- `_shouldUseStoreCheckout` returns false for web/sandbox, but `canCheckoutSelectedPlan` can still become true.
- The FilledButton copy says `Nâng cấp lên ...` / `Upgrade to ...` with a price.
- On tap, the app shows `Thanh toán chưa sẵn sàng trên phiên này.` / `Checkout is not available in this session.`

Recommended copy/layout:

- Disable the CTA when checkout is unavailable and replace with a clear state card:
  - VI: `Mua gói trên ứng dụng iOS/Android`
  - EN: `Buy this plan in the iOS or Android app`
  - Secondary text: `Phiên web hiện chỉ cho xem gói và giá. Hãy mở app trên điện thoại để thanh toán qua cửa hàng ứng dụng.`
- If manual payment is planned, use a separate secondary action:
  - VI: `Liên hệ hỗ trợ thanh toán`
  - EN: `Contact billing support`
- Do not show a purchase-looking FilledButton unless tapping can start a real checkout.

### P1-2: Billing and Funds IA are still mixed on web and mobile

Screen/path:

- App bottom nav: `Funds`
- Profile settings billing card: `Gói của bạn`
- Web info page feature card
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/l10n/l10n.dart:91`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart:1235`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/app/web/web_marketing_pages.dart:381`

Expected:

- `Quỹ họ/Funds` = clan treasury: donations, expenses, balances, transfer details, treasurer workflows.
- `Gói dịch vụ/Plans` = BeFam subscription: plan, renewal, AI quota, invoices, app-store purchase.
- A user should never wonder whether a "payment" screen is asking them to donate to a clan fund or buy BeFam.

Actual:

- Web feature card uses VI `Quỹ và quyền dùng` while EN says `Plans and billing`.
- Top web nav has `Quỹ họ/Funds` but no distinct `Gói dịch vụ/Plans`.
- Mobile billing lives under Profile and AI assistant deep-links, while the visible tab is `Quỹ/Funds`.
- Profile exposes two billing-related CTAs: `Đổi hoặc nâng cấp` and `AI và thanh toán`, which splits the billing concept across plan management and AI usage.

Recommended copy/layout:

- Standardize labels:
  - Clan treasury: `Quỹ họ` / `Clan funds`
  - Product subscription: `Gói dịch vụ` / `Plans`
  - Payment history for subscription: `Thanh toán gói` / `Plan payments`
- Web feature card should become:
  - Title VI: `Gói dịch vụ BeFam`
  - Title EN: `BeFam plans`
  - Description VI: `Xem quyền lợi, hạn dùng, lượt AI và trạng thái thanh toán của gói BeFam.`
- Keep `Quỹ họ` web/mobile content focused on `thu`, `chi`, `số dư`, `thủ quỹ`, and `chuyển khoản quỹ`.

### P1-3: Plan cards do not explain eligibility, member limits, or why a plan is blocked

Screen/path:

- Billing workspace: `Chọn gói tiếp theo`
- Quick pricing sheet: `Các gói hiện có`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:611`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:1047`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:699`

Expected:

- Purchase plan cards should show the concrete rule that matters: member range, current member count, current plan, minimum required plan, ads/no-ads, annual price.
- If a plan is unavailable, the card should explain the rule inline before the CTA area.

Actual:

- `_planSupportLabel` uses broad marketing copy such as `Gọn nhẹ cho nhu cầu hằng ngày` / `A lighter fit for everyday use`.
- The app computes `minimumTier` and blocks downgrade by member count, but plan cards do not show `minMembers`, `maxMembers`, or `workspace.memberCount`.
- The blocked copy says `Gói này không phù hợp với dữ liệu hiện tại của tài khoản`, which is too vague for a purchase decision.

Recommended copy/layout:

- Add a compact comparison row per card:
  - `Tối đa 50 thành viên`
  - `Gia phả hiện có: 64 thành viên`
  - `Cần tối thiểu: Plus`
  - `Không quảng cáo`
- Replace vague blocked copy with:
  - VI: `Gia phả hiện có 64 thành viên, vượt giới hạn 50 thành viên của gói này.`
  - EN: `This clan has 64 members, above this plan's 50-member limit.`
- Add badges:
  - `Đang dùng` / `Current`
  - `Phù hợp hiện tại` / `Fits current clan`
  - `Không đủ giới hạn` / `Below required limit`

### P1-4: Store purchase error copy exposes test/build details to production users

Screen/path:

- Billing purchase failure snackbar
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:2878`

Expected:

- End users should receive short, safe, actionable purchase errors.
- Build/test/product-ID diagnostics should be logged for QA/devs, not shown in a snackbar.

Actual:

- Missing product errors can show copy about `adb`, `Google Play internal testing`, `License Testing`, and product IDs such as `befam.base.yearly`.
- This looks like an internal test failure and reduces purchase trust.

Recommended copy/layout:

- User snackbar:
  - VI: `Cửa hàng ứng dụng chưa mở được gói này. Vui lòng cập nhật app hoặc thử lại sau.`
  - EN: `The app store cannot open this plan yet. Please update the app or try again later.`
- Optional details sheet for support:
  - `Mã lỗi: STORE_PRODUCT_UNAVAILABLE`
- Keep product IDs and license-testing guidance in structured logs or QA-only diagnostics.

## P2 Findings

### P2-1: Billing labels are inconsistent across profile, billing workspace, and plan names

Screen/path:

- Profile settings billing card
- Billing workspace hero/card
- Billing details page
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart:1475`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:2771`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:1329`

Expected:

- The same plan code should have one user-facing name in each language.
- Billing details should sound like subscription management first, AI usage second.

Actual:

- BASE appears as `Gói Cơ bản` in Profile, but `Tiêu chuẩn` in Billing.
- PLUS appears as `Gói Plus` in Profile, but `Nâng cao` in Billing.
- Billing details title is `Lượt AI và thanh toán`, which makes AI feel like the primary billing object.

Recommended copy/layout:

- Use one vocabulary:
  - `Miễn phí`, `Cơ bản`, `Plus`, `Pro`
  - EN: `Free`, `Base`, `Plus`, `Pro`
- Rename `Lượt AI và thanh toán` to:
  - VI: `Thanh toán gói và lượt AI`
  - EN: `Plan payments and AI usage`
- Profile CTAs:
  - Primary: `Xem và đổi gói`
  - Secondary: `Lịch sử thanh toán`

### P2-2: Billing detail IA puts AI usage before payment history

Screen/path:

- Billing details page
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:1419`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:1682`

Expected:

- A user entering from `Gói/Thanh toán` should see subscription status, pending transaction, and invoice/payment history before AI quota.

Actual:

- The first card is `_AiUsageSummaryCard`.
- Payment history and invoices appear after renewal reminders and pending transactions.
- This reinforces the confusing idea that billing is mostly about AI usage.

Recommended copy/layout:

- Reorder Billing Details:
  1. `Trạng thái gói`
  2. `Giao dịch đang chờ`
  3. `Lịch sử thanh toán`
  4. `Hóa đơn`
  5. `Lượt AI theo gói`
  6. `Nhắc gia hạn`
- Keep AI quota visually attached to plan benefits, not as the billing page lead.

### P2-3: Fund transaction form relies on free-text member ID

Screen/path:

- Fund detail -> `Thêm đóng góp` / `Thêm chi tiêu`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:2915`

Expected:

- Finance entries should minimize ambiguous free text for member identity.
- The operator should be able to pick an existing member and still optionally enter external reference text.

Actual:

- `Thành viên liên quan` is a plain `TextFormField` with hints like `nguyen-minh`.
- This can create inconsistent ledger attribution and support burden.

Recommended copy/layout:

- Replace free-text member ID with a member picker like the fund editor member selector.
- Field copy:
  - VI: `Thành viên liên quan`
  - EN: `Linked member`
  - Empty state: `Không gắn với thành viên`
- Keep `Mã tham chiếu` for receipt/bank-transfer IDs.

### P2-4: Fund history section only offers a Donation shortcut

Screen/path:

- Fund detail -> `Lịch sử giao dịch`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:1687`

Expected:

- In a ledger history section, income and expense actions should be equally reachable.

Actual:

- The section action is only `Đóng góp` / `Donation`.
- Expense is available in the hero area, but disappears once the user scrolls to history.

Recommended copy/layout:

- Replace single text action with a compact two-action row:
  - `Ghi thu` / `Record income`
  - `Ghi chi` / `Record expense`
- Keep the hero buttons, but make history actions balanced for repeated treasurer work.

### P2-5: Loading states are calm but still too blocking for billing/funds trust flows

Screen/path:

- Billing workspace loading
- Fund workspace loading
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:415`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:389`

Expected:

- Billing and finance screens should have a recovery path if loading is slow.
- If cached data exists, show stale content with a small sync banner instead of blocking the screen.

Actual:

- Both screens use full-screen `AppLoadingState` during initial load.
- There is no visible retry action or "last updated" context in the loading state.

Recommended copy/layout:

- After 2 seconds:
  - VI: `Đang đồng bộ dữ liệu.`
  - EN: `Syncing data.`
- After 8-10 seconds, show inline recovery:
  - `Thử lại`
  - `Kiểm tra kết nối`
- If cached snapshot exists:
  - Banner VI: `Đang cập nhật dữ liệu mới nhất...`
  - Banner EN: `Updating the latest data...`

## P3 Findings

### P3-1: Motion is safe overall, but large list surfaces animate too broadly

Screen/path:

- Shared workspace surfaces used by Billing and Funds
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_workspace_chrome.dart:101`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_workspace_chrome.dart:173`

Expected:

- Motion should help transitions without making finance screens feel unstable.

Actual:

- `AppWorkspaceSurface` wraps every surface in `AnimatedContainer` unless reduced motion is enabled.
- On list-heavy screens, many cards can animate decoration changes during refresh/state updates.

Recommended copy/layout:

- Keep page entrance motion and focused button loading motion.
- Avoid animating every card background/shadow on finance screens.
- Use static surfaces for ledger rows, invoices, and transaction history.

### P3-2: Web top nav items route to the same page without anchors

Screen/path:

- Web top navigation
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/app/web/web_marketing_pages.dart:1133`

Expected:

- Nav labels should either route to distinct pages or scroll to visible sections.

Actual:

- `Gia phả`, `Giỗ lễ`, and `Quỹ họ` all point to `/befam-info`.
- This is acceptable for a lightweight site, but it feels imprecise for a product that emphasizes operational clarity.

Recommended copy/layout:

- Use anchors:
  - `/befam-info#lineage`
  - `/befam-info#memorials`
  - `/befam-info#funds`
  - `/befam-info#plans`
- Add a distinct `Gói dịch vụ` / `Plans` nav item if billing is part of the web IA.

### P3-3: Some finance labels could be more operator-oriented

Screen/path:

- Funds dashboard and detail
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:468`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:1572`

Expected:

- Treasurer workflows should use ledger language: `thu`, `chi`, `số dư`, `ghi nhận`.

Actual:

- Most copy is clear, but mixed labels like `Thêm đóng góp`, `Đóng góp`, `Add donation` are less ledger-oriented when recording entries.

Recommended copy/layout:

- Dashboard stats can stay `Thu tháng này` / `Chi tháng này`.
- Buttons:
  - `Ghi thu` / `Record income`
  - `Ghi chi` / `Record expense`
  - Keep `Đóng góp` as transaction type after entry is created.

## Recommended IA Model

Mobile:

- Bottom nav: `Trang chủ`, `Gia phả`, `Lịch`, `Quỹ họ`, `Hồ sơ`
- Profile -> account section: `Gói dịch vụ BeFam`
- Billing workspace app bar: `Gói dịch vụ`
- Billing details app bar: `Thanh toán gói và lượt AI`

Web:

- Top nav: `Gia phả`, `Giỗ lễ`, `Quỹ họ`, `Gói dịch vụ`, `Bảo mật`
- Landing feature cards should keep `Quỹ họ` and `Gói dịch vụ` as separate cards.

Purchase card layout:

1. Plan name and `Đang dùng`/`Phù hợp` badge.
2. Annual price.
3. Member limit and current member count.
4. Key benefit chips: ads, AI quota, support tier.
5. Eligibility note.
6. One primary CTA that only appears when checkout is actually available.

## Verification Notes

- Reviewed source and existing QA documentation only.
- Did not run a device/browser screenshot pass in this task.
- Did not edit app code, localization files, generated files, or tests.
