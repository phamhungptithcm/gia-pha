---
version: alpha
name: BeFam Light Lineage Workspace
description: A calm, commercial-grade design system for Vietnamese digital genealogy and clan operations.
colors:
  primary: "#3155FF"
  on-primary: "#FFFFFF"
  primary-container: "#E4EAFF"
  on-primary-container: "#071338"
  secondary: "#2FC37D"
  on-secondary: "#031C12"
  tertiary: "#8B5CF6"
  accent-violet: "#E34CFF"
  surface: "#F8FAFF"
  surface-raised: "#FFFFFF"
  surface-container: "#EAF0FA"
  outline: "#7E8AA3"
  outline-variant: "#DCE4F2"
  text-primary: "#0F172A"
  text-secondary: "#526076"
  text-muted: "#718096"
  trust-muted: "#8AA097"
  error: "#B3261E"
  on-error: "#FFFFFF"
  error-container: "#F9DEDC"
typography:
  display:
    fontFamily: system-ui
    fontSize: 44px
    fontWeight: 900
    lineHeight: 1.04
    letterSpacing: 0px
  headline-lg:
    fontFamily: system-ui
    fontSize: 28px
    fontWeight: 900
    lineHeight: 1.12
    letterSpacing: 0px
  headline-md:
    fontFamily: system-ui
    fontSize: 24px
    fontWeight: 800
    lineHeight: 1.16
    letterSpacing: 0px
  title-lg:
    fontFamily: system-ui
    fontSize: 20px
    fontWeight: 800
    lineHeight: 1.22
    letterSpacing: 0px
  body-md:
    fontFamily: system-ui
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.42
    letterSpacing: 0px
  body-sm:
    fontFamily: system-ui
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.35
    letterSpacing: 0px
  label-lg:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 800
    lineHeight: 1.15
    letterSpacing: 0px
  label-sm:
    fontFamily: system-ui
    fontSize: 12px
    fontWeight: 800
    lineHeight: 1
    letterSpacing: 0px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 22px
  xxl: 28px
  section: 40px
rounded:
  sm: 8px
  md: 12px
  lg: 18px
  full: 999px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.md}"
    height: 48px
    padding: 14px
  button-primary-pressed:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.md}"
    height: 48px
    padding: 14px
  button-trust:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.on-secondary}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.md}"
    height: 48px
    padding: 14px
  button-violet-signal:
    backgroundColor: "{colors.accent-violet}"
    textColor: "{colors.text-primary}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.sm}"
    size: 9px
  app-background:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-md}"
    padding: "{spacing.lg}"
  lineage-outline:
    backgroundColor: "{colors.outline-variant}"
    rounded: "{rounded.md}"
    width: 1px
  outline-focus-ring:
    backgroundColor: "{colors.outline}"
    width: 2px
  tertiary-focus-ring:
    backgroundColor: "{colors.tertiary}"
    width: 2px
  muted-meta:
    textColor: "{colors.text-muted}"
    typography: "{typography.body-sm}"
  trust-context-mark:
    backgroundColor: "{colors.trust-muted}"
    size: 8px
  input-field:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 14px
  input-error:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px
  card-workspace:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 16px
  chip-muted:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.text-secondary}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px
  navigation-selected:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px
  status-error:
    backgroundColor: "{colors.error}"
    textColor: "{colors.on-error}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.md}"
    padding: 8px
---

# BeFam Design Direction

_Last updated: May 16, 2026_

This file follows the Google Labs `design.md` format: machine-readable YAML
tokens first, then human-readable product guidance. Tokens are normative. Prose
explains how to apply them across web, iOS, Android, and release docs.

## Overview

BeFam should feel like a calm, premium, commercial-grade family operations
workspace for Vietnamese clans moving from paper records and chat threads into
digital genealogy. It is not a generic social feed.

The user should always understand:

- which clan they are viewing
- what needs attention next
- which action is safe to take
- whether a write action affects genealogy, governance, money, or privacy

Design principles:

- Trust first: keep clan context visible, make destructive and financial writes
  explicit, and prefer review states over hidden automation.
- Focus over decoration: show the primary task first, reduce stacked cards, and
  keep education text short.
- Mobile-first speed: show useful shell, skeleton, or stable placeholder in
  under one second whenever network data is still loading.
- Human warmth: copy should feel natural and respectful, but never verbose.

## Colors

The release direction is light lineage workspace: bright paper, a soft blue
lineage grid, strong black text, BeFam blue emphasis, and small green trust
signals.

- `primary` `#3155FF`: primary actions, selected states, focused fields, and
  commercial product emphasis.
- `secondary` `#2FC37D`: trust, positive state, verified clan context, and
  progress confirmation.
- `tertiary` `#8B5CF6` and `accent-violet` `#E34CFF`: tiny signal accents only.
  Do not let purple dominate the app.
- `surface` `#F8FAFF`: app background and web shell foundation.
- `surface-raised` `#FFFFFF`: cards, sheets, input fields, and primary surfaces.
- `outline-variant` `#DCE4F2`: quiet borders for tables, cards, maps, and form
  boundaries.
- `text-primary` `#0F172A`: headlines and core content.
- `text-secondary` `#526076`: metadata, secondary labels, and helper text.
- `error` `#B3261E`: inline field errors and blocking state.

Do not use beige wash, decorative orbs, heavy gradients, dark blue/slate
dominance, or one-note purple palettes.

## Typography

Use the system font stack so native text feels fast and familiar on iOS,
Android, and web. Typography must be compact, high-contrast, and scan-friendly.

- Display text is for first-viewport web positioning only, not app dashboards.
- App screen titles use `headline-lg` or smaller.
- Compact panels, cards, and sheets use `title-lg`, `body-md`, and `label-*`.
- Letter spacing stays `0px`; do not use negative tracking.
- Long explanations belong in About, Story, Privacy, Terms, and docs, not in
  task screens.

## Layout

BeFam uses mobile-first stacked workflows with full-width workspace bands and
bounded surface cards. The visual rhythm follows the token scale: 4, 8, 12, 16,
22, and 28px.

Primary tabs stay focused:

- Home: clan overview, urgent tasks, next event, quick actions
- Tree: genealogy browsing, search, relationship work
- Events: memorials, calendar, reminders, clan ceremonies
- Plan/Billing: entitlement, limits, upgrade, invoices
- Profile: identity, privacy, language, notifications, account deletion

Secondary workspaces open from contextual actions, not the bottom navigation:
funds, scholarship, discovery, notifications, branch detail, member detail,
event detail, and billing detail.

Digital genealogy migration flows should show one concrete next step at a time:
start clan, add branch, add member, verify relationship, invite relatives, and
review sensitive changes.

Public web shell:

- Top navigation and footer stay outside the main scroll container so page
  chrome remains fixed and predictable.
- Footer content must fit in a compact support/legal bar. Do not place large
  app-store cards, repeated support copy, or secondary marketing blocks there.
- Landing and info pages should use short, human copy with one clear CTA. Avoid
  duplicating FAQ, CTA, and explanation sections when the same point is already
  visible in the first view.

## Elevation & Depth

Depth is quiet. Use borders, tonal layers, and low shadows instead of floating
cards or decorative depth.

- App backgrounds use `surface`.
- Primary content uses `surface-raised`.
- Separators use `outline-variant`.
- Shadows are reserved for modal sheets, web hero surfaces, and active overlays.
- Avoid card-inside-card layouts.

## Shapes

Use small-to-medium radius for clarity and commercial polish.

- Web marketing cards: 8px.
- App buttons and inputs: 12px.
- App workspace cards and sheets: 18px where Material surfaces need softness.
- Pills: only for chips, status tags, and compact segmented controls.

Do not mix very sharp and very round shapes on the same surface.

## Components

Inputs:

- Required fields use `AppRequiredFieldLabel` through `appFieldDecoration`.
- Required state must be visible before submission.
- Inline validation blocks forward movement before any step transition or write.
- Error text says exactly what to fix.

Buttons:

- Async actions use `AppActionButton` or `AppAsyncAction`.
- Buttons show press feedback, loading progress, and repeat-tap protection.
- The primary button should be visually stronger than the secondary button.
- Destructive, billing, governance, and relationship writes need explicit copy.

Timers and loading:

- OTP resend and wait states show compact progress plus remaining time.
- Loading belongs inside the affected content region.
- Avoid whole-screen spinners after auth/bootstrap unless there is no stable
  fallback surface.

Motion:

- Button motion is a small press scale plus Material ink/color feedback.
- Route transitions use BeFam scale-only motion.
- Do not use slide or fade as the default tap response.
- Respect platform reduced-motion settings.

## Do's and Don'ts

Do:

- Keep clan context visible.
- Use one primary action per screen.
- Keep copy short and human.
- Show inline required-field errors before moving on.
- Preserve role, clan, and privacy boundaries in every workflow.
- Validate UI at mobile and desktop widths.

Don't:

- Do not turn BeFam into a social feed.
- Do not hide governance, billing, or relationship consequences.
- Do not animate financial, governance, or genealogy data after it becomes
  readable.
- Do not add ambient float, pulse, bokeh, blob, or decorative gradient motion.
- Do not over-explain task screens.

## Motion Contract

Motion should make the app feel responsive, not slower. Use motion only when it
gives feedback, preserves context, or confirms status. Otherwise keep the
interface stable.

BeFam should not use slide or fade as a default click response. Frequent
workspace clicks, tab changes, shortcut taps, and route navigation should swap
content immediately and rely on selected states, ripples, color, border, or
focus-ring feedback. This keeps readable clan, money, and governance data from
moving after a user has started reading it.

Context-specific rules:

- Navigation, bottom tabs, and workspace switches: no route slide, no route
  fade, no page-level entrance animation.
- Cards and buttons: Material ink plus 120-180ms color, border, or shadow
  feedback. Do not move card content.
- Workspace surfaces: allow decoration interpolation only when density, theme,
  or state changes. Do not animate text position.
- Loading states: use stable skeletons or shimmer inside the content region.
- Success and save states: prefer check/status color and label changes over
  moving the surrounding layout.
- Genealogy canvas: pan/zoom is allowed for search focus and relationship
  inspection because it preserves map orientation and explains spatial context.
- Web landing: no ambient float, pulse, or decorative movement. Hover and focus
  may change color, border, and shadow only.
- Public web nav/footer: no slide/fade movement on scroll. Keep the shell
  stable; only subtle color, border, or shadow changes are allowed.
- Onboarding spotlight: keep motion optional and short; the highlighted target
  should remain visually anchored.

## Form, Timer, and Action Contract

Forms are high-trust moments in BeFam because they can change identities,
relationships, clan operations, funds, or scholarship records. They should feel
calm, explicit, and hard to misuse.

Release-critical forms covered by automated tests:

- Auth: phone, child identifier, incomplete OTP, resend cooldown feedback
- Clan: clan profile and branch required identity fields
- Members: add/edit first-step required identity fields and parent filter flow
- Events: required title before moving deeper into the editor
- Funds: required fund name and transaction amount
- Scholarship: required program, award, and submission title fields

## Screen-Level Direction

### Auth

- Privacy consent should be part of the sign-in decision, not a detached legal
  card.
- Phone and child login should read as two clear entry modes.
- Error copy should be friendly but precise.

### Home

- First view should answer: "What clan am I in, and what should I handle next?"
- Promote one next action. Group everything else as scan-friendly rows.
- Nearby relatives, ads, AI, and discovery should hydrate after primary clan
  state and upcoming events.

### Genealogy

- Search and focus controls should be always reachable.
- Large trees need stable dimensions, visible node limits, and clear "show more"
  behavior.
- Relationship mutations need explicit review and audit-friendly confirmation.
- Import or migration flows must help families move from paper or spreadsheet
  records into verified digital relationships step by step.

### Events and Memorials

- Calendar should distinguish upcoming, memorial, and draft states visually.
- Lunar/solar recurrence should be explicit at creation and detail views.
- Reminders should feel like clan operations, not generic calendar alerts.

### Funds and Scholarship

- Money and award states need conservative UI.
- Primary numbers should be readable without opening detail pages.
- Write actions require role-aware disabled states and clear permission copy.

### Billing

- The plan screen should explain current entitlement first, then upgrade paths.
- Store/IAP actions need clear pending, success, and retry states.
- Never hide provider-managed payment boundaries.

### AI

- AI remains advisory and embedded in workflow context.
- Answers should be short, direct, and grounded in the provided clan/member
  context.
- AI should never invent family relationships, contact details, or private
  history.

## Performance Targets

The "<1s" target means first useful interaction or stable placeholder, not every
network-backed operation fully resolved.

- App shell first useful view: under 1000ms after Firebase/auth bootstrap.
- Tab switch to cached workspace: under 300ms.
- Network-backed workspace first skeleton: under 500ms.
- Network-backed workspace useful content: under 1000ms on warm cache or normal
  network.
- Genealogy graph layout for visible subset: under 1000ms for release test data.
- AI and billing provider calls may exceed one second, but must show immediate
  progress and allow safe retry/fallback.

## Measurement Contract

Release performance claims must come from artifacts, not estimates:

- Flutter profile mode: run `scripts/run_performance_benchmarks.sh` and inspect
  `mobile/befam/artifacts/performance/flutter-profile-build.log`. Use
  `flutter run --profile` for an interactive DevTools capture when a
  profile-capable device/browser session is available.
- Lighthouse web: use the JSON report generated at
  `mobile/befam/artifacts/performance/lighthouse-web-release.json`.
- Firebase Performance: verify custom traces after staging/profile runs for
  `befam_frames_batch_p95` plus workspace refresh traces for clan, events,
  funds, billing, profile, calendar, and scholarship.
- Genealogy render: use the synthetic 200/400/700 member benchmark in
  `test/features/genealogy/genealogy_workspace_benchmark_test.dart`.

If a local machine lacks an attached native device, the benchmark script still
builds the web profile target and the report calls out when interactive runtime
profiling must be captured separately.

## Release UI Checklist

- No RenderFlex overflow on supported mobile/web widths.
- No text clipped inside buttons, chips, navigation labels, or cards.
- No repeated title text that confuses widget tests or screen readers.
- All user-facing copy follows the localization pattern used by the screen.
- Required form fields are visibly marked and block forward movement with
  inline errors before any write or step transition.
- Async action buttons show immediate feedback, loading state, and repeat-tap
  protection.
- Timers and cooldowns use stable progress UI, not only text.
- Loading, empty, error, success, and permission-denied states exist for every
  release-critical workspace.
- Motion is short, purposeful, and does not obscure clan, money, or governance
  data.
