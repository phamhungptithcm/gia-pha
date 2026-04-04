# Ads Launch Checklist

Use this checklist before enabling production traffic for AdMob in BeFam.

## 1. AdMob Console Setup

- [ ] App is added in `AdMob > Apps` and linked to the correct store listing.
- [ ] Android package name and iOS bundle ID match the production app.
- [ ] [`mobile/befam/web/app-ads.txt`](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/web/app-ads.txt) is filled with the real publisher ID.
- [ ] `./scripts/verify_app_ads_txt.sh mobile/befam/web/app-ads.txt` passes locally.
- [ ] `app-ads.txt` is published on the app website domain.
- [ ] AdMob shows the app as verified with `app-ads.txt`.
- [ ] `banner_home`, `banner_tree`, `banner_events` ad units are created.
- [ ] `interstitial_default` ad unit is created.
- [ ] `rewarded_discovery_extra_attempt` ad unit is created.

## 2. Privacy And Compliance

- [ ] `Privacy & messaging` has a published `European regulations` message.
- [ ] `Privacy & messaging` has a published `US state regulations` message.
- [ ] Ad partners in the consent message match the mediation partners actually used.
- [ ] The app has a visible `Privacy choices` or consent revocation entry point at `Hồ sơ > Mở cài đặt > Quyền riêng tư và dữ liệu`.
- [ ] Policy center has no blocking issue for the app.

## 3. App Configuration

- [ ] `BEFAM_ADMOB_ANDROID_APP_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_IOS_APP_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_ANDROID_BANNER_UNIT_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_IOS_BANNER_UNIT_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_IOS_INTERSTITIAL_UNIT_ID` is set for production builds.
- [ ] `BEFAM_ADMOB_IOS_REWARDED_UNIT_ID` is set for production builds.
- [ ] Native AdMob app IDs in Android/iOS configs are production IDs.
- [ ] Remote Config contains the latest keys from `remote_config_defaults.json`.

## 4. Remote Config Baseline

- [ ] `ads_enabled=true`
- [ ] `banner_enabled=true`
- [ ] `interstitial_enabled=true`
- [ ] `rewarded_enabled=true`
- [ ] `rewarded_discovery_enabled=true`
- [ ] `app_open_enabled=false`
- [ ] `interstitial_max_per_session=1`
- [ ] `interstitial_max_per_day=3`
- [ ] `rewarded_discovery_free_searches_per_session=3`
- [ ] `rewarded_discovery_max_unlocks_per_session=1`

## 5. QA On Real Devices

- [ ] Android build shows consent flow correctly on a clean install.
- [ ] iOS build shows consent flow correctly on a clean install.
- [ ] Banner renders as adaptive and is not cropped on home/tree/events.
- [ ] Interstitial does not show on onboarding, billing, profile, or payment flows.
- [ ] Rewarded discovery appears only after free search quota is exhausted.
- [ ] Completing rewarded unlock grants exactly one extra discovery search.
- [ ] Premium users do not see banner, interstitial, or rewarded prompts.
- [ ] App still behaves correctly when ads fail to load or no-fill occurs.
- [ ] Ad Inspector confirms real ad unit wiring and privacy state.

## 6. Rollout Plan

- [ ] Launch with `10%` of free-user traffic first.
- [ ] Keep the first rollout window at least `24-48h` before scaling.
- [ ] Do not change more than `1-2` monetization levers during the first rollout.
- [ ] Do not enable app open ads in the first rollout.
- [ ] Do not raise rewarded or interstitial caps before guardrails are clean.

## 7. Daily Checks After Launch

- [ ] `ad_impression` revenue is within expected range.
- [ ] `ARPDAU` is not regressing.
- [ ] `ad_failed / ad_requested` ratio is stable.
- [ ] `session_exit_after_ad` is not spiking.
- [ ] `genealogy_discovery_reward_unlocked` is firing correctly.
- [ ] `premium_purchase_after_ad_exposure` is not dropping materially.
- [ ] Crash-free users and sessions remain healthy.

## 8. Rollback Triggers

- [ ] Roll back if `D1 retention` drops by more than `2%`.
- [ ] Roll back if `session_exit_after_ad` rises by more than `15%`.
- [ ] Roll back if premium conversion softens materially.
- [ ] Roll back if load failures spike or ads stop serving unexpectedly.
- [ ] Use `ads_enabled=false` as the emergency kill switch first.

## 9. Owner Sign-Off

- [ ] Engineering sign-off
- [ ] Product sign-off
- [ ] QA sign-off
- [ ] Growth / monetization sign-off
