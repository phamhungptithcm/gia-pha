# Billing, Store IAP, and Security Gate Resolution

_Date: 2026-05-17_

## Outcome

BeFam now separates product packages from clan funds again:

- `Gói` / `Billing` is the plan purchase and entitlement workspace.
- `Quỹ` / `Funds` remains the clan fund ledger and transaction workspace.
- Paid package purchase is exposed from the main app shell Billing tab and the
  Profile `Gói của bạn` hub.
- Web/non-store surfaces do not open a fake checkout. They tell the user to buy
  from the iOS or Android app through App Store / Google Play.

## Feedback Addressed

| Source | Feedback | Resolution |
| --- | --- | --- |
| Product Owner | Billing was hidden after Funds replaced the package tab. | Restored Billing as the fourth shell destination; Funds remains a workflow/module, not the package purchase tab. |
| Product Owner | Runtime Store IAP conflicted with VNPay-first docs. | Updated product, architecture, security, and release QA docs to describe Store IAP-first purchase. |
| Technical Lead | Billing scope could fall back to personal `ownerUid` for clan sessions. | Mobile billing repository now sends clan scope for claimed clan sessions and personal scope only for unlinked sessions. |
| Technical Lead | Billing mutation was not owner-only enough. | Backend `updateBillingPreferences` and `verifyInAppPurchase` now require owner mutation access. |
| Security Lead | Child sessions could inherit privileged role claims. | Firestore/Storage privileged helpers now require `memberAccessMode == claimed`; child auth context is forced to `MEMBER`. |
| Security Lead | Child lookup allowed raw member id fallback. | Removed raw `members.doc(childIdentifier)` fallback from child login lookup. |
| Security Lead | Direct relationship/member writes were too broad. | Direct relationship writes are server-only; member direct update allowlist excludes role/auth/relationship lineage fields. |
| Security Lead | QA self-test functions lacked production guard. | Self-test notification callables now require App Check plus `QA_SELF_TEST_ENABLED` and privileged claimed session. |
| Dev Lead | CI did not run Firebase rules tests. | Branch, staging, Firebase deploy, and main release workflows now run `npm run test:rules`. |
| UI/UX Manager | Store checkout should not appear on unsupported web path. | Web/non-store Billing shows clear mobile-store guidance instead of an actionable checkout button. |

## Verification

| Check | Result |
| --- | --- |
| `cd mobile/befam && flutter analyze` | PASS |
| `cd mobile/befam && flutter test` | PASS, 257 passed, 1 skipped |
| Billing/shell focused Flutter tests | PASS |
| `cd firebase/functions && npm test` | PASS, 31 passed |
| `cd firebase/functions && npm run test:rules` | PASS, 10 passed |

## Device Status

- Android device: blocked. `adb devices -l` returned no connected Android
  serial after restarting ADB.
- iOS real device `Andrew`: detected by Flutter as wireless iOS device, but
  `flutter test` integration runner cannot start on wireless iOS in this
  toolchain. A cabled Developer Mode connection is required for real-device
  integration tests.

## Release Readiness Note

Code, rules, docs, and CI gates are aligned for the package/security pass.
Production release should still require one final real-device smoke on Android
or cabled iOS before app-store submission because current device connectivity
blocked that evidence.
