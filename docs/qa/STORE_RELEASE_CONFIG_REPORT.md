# Store Release Config Report

_Date: 2026-05-17_

## Scope

Production store console review for BeFam:

- App Store Connect: `BeFam: Gia phả & Họ tộc`, iOS version `1.0.0`
- Google Play Console: `BeFam: Gia phả & Họ tộc`, package `com.familyclanapp.befam`
- Firebase production console tab was available for visual access, but no production Firebase/Twilio mutation was performed.

## Generated Store Assets

Generated a refreshed Vietnamese screenshot package from the latest available app evidence with private phone/OTP values excluded or masked.

### App Store Connect

Target: iPhone 6.5" display.

Apple's current screenshot specification accepts `1242 x 2688` portrait screenshots for the 6.5" display class:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

Files:

- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/ios/vi/iphone-6.5/01-gia-pha-song.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/ios/vi/iphone-6.5/02-dang-nhap-an-toan.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/ios/vi/iphone-6.5/03-ho-so-nguoi-than.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/ios/vi/iphone-6.5/04-lich-gio-su-kien.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/ios/vi/iphone-6.5/05-tao-gia-pha.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/ios/vi/iphone-6.5/06-quan-tri-ho-toc.png`

Validation:

- All six files are `1242 x 2688`.
- Screenshot contact sheet: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/store-screenshot-contact-sheet.jpg`
- The profile screenshot masks private phone fields.

### Google Play Console

Target: phone screenshots and feature graphic.

Google Play preview asset requirements include JPEG or 24-bit PNG screenshots, minimum `320px`, maximum `3840px`, with the longest side no more than twice the shortest side. Google also recommends at least four app screenshots at minimum `1080px` resolution and a `1024 x 500` feature graphic:
https://support.google.com/googleplay/android-developer/answer/9866151

Files:

- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/phone/vi/01-gia-pha-song.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/phone/vi/02-dang-nhap-an-toan.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/phone/vi/03-ho-so-nguoi-than.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/phone/vi/04-lich-gio-su-kien.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/phone/vi/05-tao-gia-pha.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/phone/vi/06-quan-tri-ho-toc.png`
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play/feature-graphic.png`

Validation:

- All phone screenshots are `1080 x 1920`.
- Feature graphic is `1024 x 500`.
- Profile screenshot masks private phone fields.

## Console State Observed

### App Store Connect

Observed page:

- App: `BeFam: Gia phả & Họ tộc`
- iOS app version: `1.0.0`
- Status: `Prepare for Submission`
- Locale: Vietnamese
- In-app purchases/subscriptions visible:
  - `befam.base.yearly`
  - `befam.plus.yearly`
  - `befam.pro.yearly`

Upload result:

- Chrome extension could read and control the App Store Connect tab.
- The initial page showed `8 of 10 Screenshots`.
- During replacement, `Delete All` was confirmed before the extension upload failed.
- Current observed App Store Connect state after reload: `0 of 10 Screenshots`.
- Upload failed at file picker handoff with `fileChooser.setFiles failed: Not allowed`.
- Evidence screenshot:
  `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/app-store-connect-current.jpg`

Required restore action:

- Re-upload the six App Store screenshots above before any App Review submission.
- The current Chrome extension permission must allow file uploads, or a local App Store Connect API key must be available for CLI/API upload.

### Google Play Console

Observed page:

- App: `BeFam: Gia phả & Họ tộc`
- Package: `com.familyclanapp.befam`
- Status: Draft app
- Production: Inactive
- Temporary app name warning still present
- Closed testing setup: `3 of 5 complete`
- Production access requirement shown:
  - closed test must be published
  - at least 12 testers opted in
  - currently `0 testers opted-in`
  - run closed test for at least 14 days before applying for production
- Evidence screenshot:
  `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/artifacts/store-release/google-play-console-current.jpg`

No Google Play asset upload was attempted after the App Store upload permission failure, to avoid leaving another console in a partially mutated state.

## Release Readiness

Status: **Not Ready**

Blocking reasons:

- App Store Connect currently has `0 of 10` iPhone screenshots after the blocked upload attempt.
- Chrome extension file upload permission is blocking console upload automation.
- No local App Store Connect API key or Google Play service account file is available to perform direct CLI/API store asset upload.
- Google Play production cannot be published today from the observed state because closed testing has `0` opted-in testers and the required 14-day closed-test criteria are not met.
- The existing final release gate remains blocked by live Android staging auth failure caused by Firebase staging billing being disabled.
- Signed IPA/AAB production artifacts were not produced in this store-config pass.

## Safe Next Action

Enable the Chrome extension file upload permission and restore App Store screenshots immediately, or provide local API credentials outside the repo:

- App Store Connect API: issuer ID, key ID, `.p8` private key
- Google Play Developer API: service account JSON with Android Publisher access

Do not submit for App Review or Google Play production until the screenshots are restored and the release blockers in `FINAL_RELEASE_REPORT.md` are resolved.
