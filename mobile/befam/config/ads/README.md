# Ads Remote Config and Rollout Guide

This folder is the operational source of truth for the Flutter ads baseline.

- Runtime implementation lives in `lib/features/ads/services/`.
- Firebase Remote Config template lives in `remote_config_defaults.json`.
- The baseline currently activates `banner + interstitial + rewarded discovery`.
- `app_open` remains intentionally disabled by default.

## Current baseline

- Free users are ad-supported.
- Premium users are always ad-free.
- Banner is allowed only on low-risk shell screens: `home`, `tree`, `events`.
- Interstitial is considered only at natural breakpoints:
  `shell_tab_switch`, `route_return`, `task_complete`, `result_exit`, `content_unit_end`.
- Rewarded is enabled only for the `extra discovery attempt` flow on genealogy discovery.
- Rewarded discovery uses a strict cap: `3` free searches per session, then `1` rewarded unlock, `1` extra search per unlock.
- New users have a grace period.
- Premium-intent users and churn-risk users receive lower ad pressure.
- Post-crash reopen sessions are suppressed.
- Ad load failure never blocks the user flow.

## Firebase Remote Config defaults

Copy values from `remote_config_defaults.json` into Firebase Remote Config.

| Key | Type | Default | Description | Business / UX impact |
|---|---|---:|---|---|
| `ads_enabled` | bool | `true` | Global kill switch for ads. | Fast rollback for incidents. |
| `ads_policy_version` | string | `v1` | Logged into analytics for attribution. | Separates experiment variants cleanly. |
| `banner_enabled` | bool | `true` | Enables banner placements. | Low-risk monetization layer. |
| `banner_screen_allowlist` | string | `home,tree,events` | Screens allowed to render banner. | Prevents bad banner placements near critical UI. |
| `interstitial_enabled` | bool | `true` | Enables interstitial serving. | Main free-tier revenue lever. |
| `interstitial_breakpoint_allowlist` | string | `shell_tab_switch,route_return,task_complete,result_exit,content_unit_end` | Allowed natural breakpoints. | Protects UX by limiting full-screen ads to acceptable moments. |
| `ads_new_user_grace_sessions` | int | `2` | Session-based grace period. | Protects activation and D1 retention. |
| `ads_new_user_grace_days` | int | `1` | Day-based grace period. | Avoids early churn from ad pressure. |
| `interstitial_min_session_age_sec` | int | `75` | Minimum time since session start before fullscreen ads. | Prevents “ad right after open” frustration. |
| `interstitial_min_actions` | int | `3` | Meaningful actions required before fullscreen ads. | Makes ad exposure feel earned. |
| `interstitial_min_interval_sec` | int | `120` | Cooldown between fullscreen ads. | Prevents spam and protects retention. |
| `interstitial_min_screen_transitions` | int | `2` | Required transitions since prior fullscreen ad. | Prevents back-to-back interruptions. |
| `interstitial_max_per_session` | int | `1` | Session cap for fullscreen ads. | Safe starting point for production rollout. |
| `interstitial_max_per_day` | int | `3` | Daily cap for fullscreen ads. | Controls long-term ad pressure. |
| `interstitial_fail_backoff_sec` | int | `300` | Backoff after load/show failure. | Reduces no-fill churn and wasted requests. |
| `important_action_suppress_sec` | int | `45` | Suppress fullscreen ads after important actions. | Protects emotional and task-completion moments. |
| `post_crash_suppress_sessions` | int | `1` | Sessions to suppress after suspected crash/reopen. | Avoids compounding frustration after instability. |
| `rewarded_enabled` | bool | `true` | Rewarded ad master flag. | Enables the discovery reward surface while remaining user-initiated. |
| `rewarded_discovery_enabled` | bool | `true` | Enables rewarded extra discovery attempts. | Activates the only rewarded placement in the baseline. |
| `rewarded_discovery_free_searches_per_session` | int | `3` | Free manual discovery searches allowed per session before prompting reward. | Keeps the base flow usable before monetization begins. |
| `rewarded_discovery_max_unlocks_per_session` | int | `1` | Maximum rewarded unlocks per session. | Prevents turning rewarded into a spam loop. |
| `rewarded_discovery_extra_searches_per_reward` | int | `1` | Extra discovery searches granted after a completed reward. | Simple, predictable value exchange for users. |
| `app_open_enabled` | bool | `false` | App open ad master flag. | Keep off until reopen behavior is validated. |
| `premium_candidate_low_ad_pressure` | bool | `true` | Lowers pressure for likely premium converters. | Protects premium conversion. |
| `premium_candidate_cooldown_multiplier` | double | `2.0` | Multiplies cooldown for premium candidates. | Trades short-term ad revenue for subscription LTV. |
| `churn_risk_cooldown_multiplier` | double | `2.0` | Multiplies cooldown for churn-risk users. | Protects retention and reduces annoyance. |
| `low_engagement_daily_cap` | int | `1` | Daily cap for low-engagement users. | Reduces pressure on fragile cohorts. |
| `app_open_min_opens_before_eligible` | int | `5` | Opens before app-open eligibility. | Avoids aggressive early app-open rollout. |
| `app_open_min_foreground_gap_sec` | int | `14400` | Gap before app-open can be reconsidered. | Prevents repeated reopen monetization. |
| `session_exit_after_ad_window_sec` | int | `20` | Window for logging exit after ad dismissal. | Detects annoyance and churn proxies quickly. |

## Recommended rollout

### Phase 1: safe baseline

- Rollout target: `10%` of free users.
- Config posture:
  - Keep all defaults from `remote_config_defaults.json`.
  - Keep `app_open_enabled=false`.
- Hypothesis:
  - Natural-breakpoint interstitials, selected banners, and one user-initiated rewarded unlock improve free-user revenue without hurting early retention.
- Primary metrics:
  - `ad_impression` revenue
  - `ad_shown`
  - `ARPDAU`
  - `fill rate`
- Guardrails:
  - `D1 retention`
  - `median session length`
  - `session_exit_after_ad`
  - `premium_purchase_after_ad_exposure`
  - crash-free sessions/users
- Rollback if:
  - D1 drops by more than `2%`
  - `session_exit_after_ad` rises by more than `15%`
  - premium purchase rate softens materially
  - ad load failures spike after release

### Phase 2: moderate monetization increase

- Rollout target: `25-50%` of free users after 7-14 clean days.
- Candidate changes:
  - `interstitial_max_per_session=2` only if highly engaged cohorts remain healthy
  - `interstitial_min_interval_sec=105-120`
  - consider adding `result_exit` placements if not yet used
  - test `rewarded_discovery_free_searches_per_session=2` only if discovery engagement is strong and complaint rate stays clean
- Do not change more than `1-2` levers in one experiment.

### Phase 3: segment-aware optimization

- Rollout target: broad free-user rollout.
- Candidate changes:
  - leave low-engagement and churn-risk users on conservative caps
  - slightly relax pacing only for `highly_engaged`
  - tune discovery reward caps by segment if the baseline shows positive LTV
- Avoid enabling app open until reopen traffic and loading UX are understood.

## Suggested A/B tests

### Experiment A: baseline vs no-interstitial

- Variant A: baseline config
- Variant B: `interstitial_enabled=false`
- Purpose:
  - quantify the incremental revenue from interstitials
  - estimate retention or session-length tax

### Experiment B: 1 vs 2 interstitials per session for highly engaged users

- Variant A: `interstitial_max_per_session=1`
- Variant B: `interstitial_max_per_session=2`
- Guardrails:
  - `session_exit_after_ad`
  - `median session length`
  - `premium_purchase_after_ad_exposure`

### Experiment C: premium-candidate suppression on vs off

- Variant A: `premium_candidate_low_ad_pressure=true`
- Variant B: `premium_candidate_low_ad_pressure=false`
- Purpose:
  - measure whether reduced ad pressure improves premium conversion enough to offset lost ad revenue

### Experiment D: rewarded discovery pacing

- Variant A: `rewarded_discovery_free_searches_per_session=3`
- Variant B: `rewarded_discovery_free_searches_per_session=2`
- Guardrails:
  - `genealogy_discovery_reward_prompt_dismissed`
  - `genealogy_discovery_reward_unlocked`
  - discovery search completion rate
  - `session_exit_after_ad`

## Daily production checklist

- Check `ad_impression` revenue and `ARPDAU`.
- Check `ad_failed / ad_requested` ratio.
- Check `session_exit_after_ad`.
- Check premium purchase counts with recent ad exposure.
- Check rewarded discovery funnel:
  - `genealogy_discovery_attempt_limit_reached`
  - `genealogy_discovery_reward_prompt_opened`
  - `genealogy_discovery_reward_unlocked`
  - `ad_reward_earned`
- Check crash-free sessions and crash-free users.
- Check that free-user cohorts still pass retention and session-length guardrails.

## Rewarded discovery notes

Rewarded is now wired only for `extra discovery attempt`, which is the first natural reward surface in the app.

Operational constraints:

- Keep `rewarded_discovery_max_unlocks_per_session=1` for the initial rollout.
- Do not auto-open rewarded ads; always require an explicit user tap.
- Configure `BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID` and `BEFAM_ADMOB_IOS_REWARDED_UNIT_ID` before production rollout.
- Do not expand rewarded to other surfaces until the discovery funnel and retention impact are stable.
