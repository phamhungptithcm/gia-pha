# Production Readiness Checklist

_Last reviewed: April 4, 2026_

This checklist is the source of truth for BeFam production readiness across code, CI/CD, Firebase, Google Cloud, and store release operations.

Primary operator runbook:

- [docs/vi/05-devops/production-release-runbook.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/vi/05-devops/production-release-runbook.md)

## Target Operating Model

- `staging`:
  - Auto deploys Firebase + web sandbox only.
  - Mobile iOS/Android builds are for local QA or manual staging artifact generation only.
  - Local staging release is allowed to use bundled staging Firebase and Google test AdMob IDs.
- `main`:
  - Must always stay release-ready.
  - Produces signed Android/iOS/Web release assets and a GitHub Release tag.
  - Does **not** auto deploy production Firebase or production Hosting.
  - Production promotion happens manually by selecting a tested `release_tag`.
- `production`:
  - Firebase + web are promoted manually from a tested `release_tag`.
  - Mobile binaries are tested in store test channels first, then submitted to Google Play / App Store release.

## Status Legend

- `Done`: locked in code or repo config.
- `Partial`: groundwork exists, but there is still operational follow-up.
- `Verify`: expected to be done outside the repo and must be checked in console.
- `Blocker`: must be completed before real production rollout.

## Current Decisions Locked In Repo

- Production deploy from `main` is now decoupled from release creation.
- Production Firebase deploy requires manual `workflow_dispatch` with `release_tag`.
- Production Hosting deploy requires manual `workflow_dispatch` with `release_tag`.
- Local staging release keeps bundled staging Firebase support.
- Public legal pages now exist for:
  - `/privacy`
  - `/terms`
  - `/account-deletion`
- The mobile app now exposes:
  - an in-app account deletion request entry point
  - a visible privacy choices entry point for ads consent
- iOS source now declares:
  - push entitlements wiring
  - background remote notification mode
- Production release build now blocks:
  - Google test AdMob app IDs
  - Google test AdMob unit IDs
- Secret templates in repo no longer contain the previously committed signing values.
- `app-ads.txt` now exists at `mobile/befam/web/app-ads.txt` with an explicit placeholder line that must be replaced before production.
- GitHub environment audit script now exists at `scripts/audit_github_environment.sh`.

## Final Checklist

| Area | Item | Owner | Status | Notes |
|---|---|---|---|---|
| Release model | `main` only creates release-ready artifacts and GitHub Release tags | Platform | `Done` | Enforced by [`.github/workflows/release-main.yml`](.github/workflows/release-main.yml) |
| Release model | Production Firebase deploy is manual from a chosen `release_tag` | Platform | `Done` | Enforced by [`.github/workflows/deploy-firebase.yml`](.github/workflows/deploy-firebase.yml) |
| Release model | Production Hosting deploy is manual from a chosen `release_tag` | Platform | `Done` | Enforced by [`.github/workflows/deploy-web-hosting.yml`](.github/workflows/deploy-web-hosting.yml) |
| Release model | Release manager playbook exists for `release -> test -> promote -> store submit` | Platform + PM | `Partial` | This file is the baseline; keep runbook steps in sync with workflows |
| Secret hygiene | Repo templates scrubbed of signing material | Platform | `Done` | Example files now use placeholders only |
| Secret hygiene | Rotate Android signing keystore, passwords, and any exposed derivatives outside repo | Security + Mobile | `Blocker` | This cannot be completed by code alone; rotate in keystore storage, Play/App Store, and GitHub secrets |
| Secret hygiene | Audit git history and invalidate any previously leaked credentials still trusted by CI/store tooling | Security + Platform | `Blocker` | Use secret scanning + rotation log; treat past committed signing values as compromised |
| GitHub production env | Required iOS signing secrets exist in the `production` environment | Platform + Mobile | `Blocker` | Current audit found `IOS_P12_BASE64`, `IOS_P12_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, and `IOS_TEAM_ID` missing from GitHub `production` secrets |
| GitHub production env | Required runtime/store vars exist in the `production` environment | Platform | `Blocker` | Current audit found `BEFAM_OTP_PROVIDER`, `BEFAM_WEB_BASE_URL`, `BEFAM_IOS_APP_STORE_URL`, and `BEFAM_ANDROID_PLAY_STORE_URL` missing from GitHub `production` vars |
| GitHub production env | Required production AdMob vars exist in the `production` environment | Growth + Platform | `Blocker` | Current audit found production AdMob app IDs and unit IDs missing from GitHub `production` vars |
| GitHub production env | Production environment requires reviewer approval without self-approval | Platform | `Blocker` | `scripts/audit_github_environment.sh --env production --strict` now fails until `prevent_self_review` is enabled |
| Firebase projects | Separate staging and production Firebase projects exist | Backend/Firebase | `Verify` | User confirmed production project exists; verify it is not reusing staging resources accidentally |
| Firebase projects | Production GitHub vars point to the production Firebase project only | Platform | `Verify` | Check `production` environment vars/secrets in GitHub |
| Firebase projects | `.firebaserc` aliases and local docs clearly distinguish staging vs production | Platform | `Partial` | Repo still defaults to staging locally; acceptable, but team must avoid ad-hoc prod CLI deploys |
| Mobile environment | Local staging release may use bundled staging Firebase | Mobile | `Done` | Kept intentionally in [`scripts/build_mobile_release_local.sh`](scripts/build_mobile_release_local.sh) |
| Mobile environment | Production release build must inject explicit production Firebase values | Mobile + Platform | `Done` | Guarded in [`.github/workflows/release-main.yml`](.github/workflows/release-main.yml) |
| Mobile environment | One package name / bundle ID shared across staging local QA and production release is documented and accepted | Product + Mobile | `Done` | Matches current release strategy |
| Web legal pages | Privacy policy page is public and linked from footer | Web + Legal | `Done` | [`/privacy`](mobile/befam/lib/app/web/web_marketing_pages.dart) |
| Web legal pages | Terms page is public and linked from footer | Web + Legal | `Done` | [`/terms`](mobile/befam/lib/app/web/web_marketing_pages.dart) |
| Web legal pages | Account deletion page is public and linked from footer | Web + Legal | `Done` | [`/account-deletion`](mobile/befam/lib/app/web/web_marketing_pages.dart) |
| Account deletion | In-app account deletion flow exists for app-store compliance | Product + Mobile + Backend | `Partial` | App now supports an in-app deletion request flow; production runbook still needs ownership, SLA, and final deletion handling policy |
| Auth | Phone Auth is enabled in Firebase staging and production | Backend/Firebase | `Verify` | Also verify authorized domains for staging web and production web |
| Auth | OTP provider policy is correct per environment | Backend/Firebase | `Verify` | Staging should stay Firebase test/QA-safe; production should stay Twilio if that is the chosen provider |
| App Check | Production Android app is registered with Play Integrity | Backend/Firebase + Mobile | `Verify` | Enable in Firebase App Check for the production app |
| App Check | Production iOS app is registered with App Attest or DeviceCheck | Backend/Firebase + Mobile | `Verify` | Match what the release build expects |
| App Check | Production web has a valid reCAPTCHA site key configured | Backend/Firebase + Web | `Verify` | Must match `BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY` |
| App Check | Enforcement is turned on only after production smoke tests pass | Backend/Firebase | `Partial` | Code supports it; rollout order must be controlled in console/runtime config |
| Push notifications | Android FCM works in production with real sender/app IDs | Mobile + Backend/Firebase | `Verify` | Verify install, token registration, background delivery, tap deep-link |
| Push notifications | iOS APNs key is uploaded to Firebase and mapped to production app | Mobile + Backend/Firebase | `Verify` | Required for iOS push in TestFlight/App Store builds |
| Push notifications | Web push/VAPID settings are configured if web push is part of scope | Web + Backend/Firebase | `Verify` | Optional if web push is not launched yet |
| Firestore | Production Firestore database, rules, indexes, and storage rules are deployed | Backend/Firebase | `Partial` | Deploy workflows exist; must be promoted intentionally per `release_tag` |
| Firestore | Scheduled backups are enabled for production | Backend/Firebase | `Verify` | Use Firestore backups in Google Cloud |
| Firestore | Point-in-time recovery is enabled for production | Backend/Firebase | `Verify` | Recommended for startup-grade recovery posture |
| Cloud Functions | Cloud Scheduler API is enabled in production project | Backend/Firebase | `Verify` | Required for reminder and billing scheduled jobs |
| Billing/IAP | Production subscription catalog matches code IDs exactly | Backend + Mobile | `Verify` | Must include `befam.base.yearly`, `befam.plus.yearly`, `befam.pro.yearly` |
| Billing/IAP | Google Play RTDN Pub/Sub is configured to production webhook audience | Backend/Firebase | `Verify` | Required for reliable subscription status updates |
| Billing/IAP | App Store server notifications / receipt validation secrets are configured | Backend/Firebase | `Verify` | Match production bundle/app |
| Ads | Production AdMob app IDs are stored in GitHub production vars | Growth + Platform | `Partial` | Required by `release-main` preflight |
| Ads | Production AdMob ad unit IDs are stored in GitHub production vars | Growth + Platform | `Partial` | Required by `release-main` preflight |
| Ads | Android native AdMob app ID is injected only from production vars on real production builds | Mobile + Platform | `Done` | Guarded in [`build.gradle.kts`](mobile/befam/android/app/build.gradle.kts) |
| Ads | iOS native AdMob app ID is injected only from production vars on real production builds | Mobile + Platform | `Done` | Guarded in [`project.pbxproj`](mobile/befam/ios/Runner.xcodeproj/project.pbxproj) |
| Ads | `app-ads.txt` is published on the production web domain | Web + Growth | `Blocker` | Required before real AdMob traffic |
| Ads | Consent flow and privacy choices are validated on real production candidates | QA + Growth + Mobile | `Partial` | In-app privacy choices entry now exists; validate it on clean Android and iOS installs before launch |
| Web hosting | Production custom domain is attached and SSL is healthy | Web + Platform | `Verify` | Also verify redirects/canonical base URL |
| Web hosting | Sitemap includes legal URLs and production base URL is correct | Web | `Done` | Updated in [`sitemap.template.xml`](mobile/befam/web/sitemap.template.xml) |
| Observability | Firebase Crashlytics is verified in production Android/iOS release candidates | Mobile | `Verify` | Send a controlled test event before submission |
| Observability | Cloud Logging alerts exist for Functions failures and Scheduler failures | Platform + Backend/Firebase | `Verify` | Configure log-based alerts in Google Cloud |
| Observability | Cloud Billing budget alerts exist for production project | Platform | `Verify` | Required to avoid surprise startup spend |
| Observability | On-call destination for release failures exists | Platform + PM | `Partial` | Slack webhook exists in workflows; decide escalation owner and response window |
| QA gate | Release smoke suite exists for every `release_tag` before any production promote | QA + Mobile + Backend | `Blocker` | Must include OTP, push, genealogy create flows, fund, scholarship, billing, web legal pages |
| QA gate | Real-device push notification smoke test is included in RC checklist | QA + Mobile | `Partial` | Debug helpers now exist; formalize test steps in QA runbook |
| Store release | Google Play App Signing is configured and production SHA fingerprints are registered in Firebase | Mobile + Platform | `Verify` | Needed for Auth/App Check/Maps/sign-in edge cases |
| Store release | Google Play internal/closed testing track is used before production rollout | Product + Mobile | `Verify` | `main` release artifact should go here first |
| Store release | Play Data safety form, privacy policy URL, account deletion URL, and ads declaration are complete | Product + Legal | `Blocker` | Needed before launch on Google Play |
| Store release | App Store Connect app metadata, privacy policy URL, support URL, and review notes are complete | Product + Legal | `Blocker` | Needed before iOS submission |
| Store release | TestFlight build is used before App Store release | Product + Mobile | `Verify` | Required release rehearsal step |
| Store release | Apple Push Notifications capability, Background Modes, and In-App Purchase capability are enabled | Mobile | `Partial` | Source now wires push entitlements and background remote notifications; still verify Apple Developer portal, provisioning, and signing capabilities |
| Docs | CI/CD docs match the new promote model | Platform | `Done` | Updated in [`docs/en/05-devops/ci-cd.md`](docs/en/05-devops/ci-cd.md) and [`docs/vi/05-devops/ci-cd.md`](docs/vi/05-devops/ci-cd.md) |
| Docs | Production hardening docs explain manual promote and rollback | Platform | `Done` | Updated in both English and Vietnamese docs |

## Release Sequence

1. Merge tested code into `main`.
2. Let `CD - Release Main` finish and publish the immutable `release_tag`.
3. Install the Android/iOS release artifacts from that tag into test channels or local real-device QA.
4. Run the release smoke suite and record sign-off.
5. Manually run `CD - Deploy Firebase (Production)` with the approved `release_tag`.
6. Verify production Firebase health, scheduler jobs, runtime config, and monitoring.
7. Manually run `CD - Deploy Web Hosting (Production)` with the same `release_tag`.
8. Verify web production routes, legal pages, and healthcheck.
9. Submit the already-tested Android/iOS binaries to Google Play / App Store test tracks.
10. After store test sign-off, promote the same tested binaries to public release.

## Minimum Go/No-Go Gates

- No unresolved `Blocker` rows above.
- Real production AdMob IDs are configured.
- Rotated signing credentials are active in CI and store backends.
- Firebase production project is confirmed distinct from staging.
- App Check, Auth, Push, Billing, and Scheduler are verified in production.
- Privacy, terms, and account deletion URLs are public and correct.
- Release smoke test is signed off by Engineering, QA, Product, and the release owner.

## Official References

- Firebase multiple projects: [firebase.google.com/docs/projects/multiprojects](https://firebase.google.com/docs/projects/multiprojects)
- Firebase App Check for Flutter: [firebase.google.com/docs/app-check/flutter/default-providers](https://firebase.google.com/docs/app-check/flutter/default-providers)
- Firebase Cloud Messaging for Flutter: [firebase.google.com/docs/cloud-messaging/flutter/get-started](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- Firebase scheduled functions / Cloud Scheduler: [firebase.google.com/docs/functions/schedule-functions](https://firebase.google.com/docs/functions/schedule-functions)
- Google Cloud budgets and alerts: [cloud.google.com/billing/docs/how-to/budgets](https://cloud.google.com/billing/docs/how-to/budgets)
- Firestore backups: [docs.cloud.google.com/firestore/native/docs/backups](https://docs.cloud.google.com/firestore/native/docs/backups)
- Firestore point-in-time recovery: [cloud.google.com/firestore/native/docs/use-pitr](https://cloud.google.com/firestore/native/docs/use-pitr)
- Firebase Hosting custom domain: [firebase.google.com/docs/hosting/custom-domain](https://firebase.google.com/docs/hosting/custom-domain)
- Google Play Data safety: [support.google.com/googleplay/android-developer/answer/10787469](https://support.google.com/googleplay/android-developer/answer/10787469)
- Google Play internal / closed testing: [support.google.com/googleplay/android-developer/answer/9845334](https://support.google.com/googleplay/android-developer/answer/9845334)
- Google Play App Signing: [support.google.com/googleplay/android-developer/answer/9842756](https://support.google.com/googleplay/android-developer/answer/9842756)
- Apple account deletion in apps: [developer.apple.com/support/offering-account-deletion-in-your-app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- Apple App Review Guidelines: [developer.apple.com/app-store/review/guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Apple app privacy setup: [developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
