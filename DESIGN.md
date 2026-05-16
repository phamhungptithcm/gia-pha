# BeFam Design Direction

_Last updated: May 16, 2026_

This file is the working design contract for the BeFam release-readiness pass.
It keeps the app focused on real Vietnamese clan workflows while modernizing the
mobile experience.

## Product Goal

BeFam should feel like a calm family operations workspace, not a generic social
feed. The user should always understand:

- which clan they are viewing
- what needs attention next
- which action is safe to take
- whether a write action affects genealogy, governance, money, or privacy

## Design Principles

1. Trust first
   - Keep clan context visible on every workspace.
   - Make destructive, billing, governance, and relationship writes explicit.
   - Prefer clear review states over hidden automation.

2. Focus over decoration
   - Put the primary task first on each screen.
   - Reduce stacked cards and nested surfaces.
   - Keep secondary education text short and contextual.

3. Mobile-first speed
   - Use cached shell data and progressive hydration.
   - Show skeletons or stable placeholders in under one second.
   - Avoid blocking the first useful view on location, AI, ads, or large graph
     work.

4. Human warmth
   - Use softer copy for helper states and AI fallback.
   - Add small motion moments to confirm progress, success, and context change.
   - Keep motion respectful and fast; genealogy and financial data should not
     feel playful at the expense of clarity.

## Visual Language

The new release direction is **light lineage workspace**: bright paper, soft
blue grid, strong black text, BeFam blue emphasis, and small green trust
signals. It is inspired by technical product landing pages, but translated for
Vietnamese family-clan workflows.

- Background: `#F8FAFF` with a very light lineage grid. No beige wash, gradient
  blobs, decorative orbs, or heavy illustrated backgrounds.
- Accent: `#3155FF` for primary focus, `#2FC37D` for positive/trust states, and
  violet only as a tiny emphasis.
- Surfaces: white, thin `#DCE4F2` borders, low shadows, 8px radius for web
  marketing cards, 12-18px for native Material workspace surfaces where the
  app system already expects it.
- Type: short headings, strong weight, normal letter spacing, tighter line
  heights. Dense app screens do not use hero-scale text.
- Copy: short, human, and task-first. Avoid explaining every feature on screen.
  Longer writing belongs in About, Story, Terms, Privacy, and docs.
- Icons: Material icons for app surfaces, simple logo/mark treatment for web.
- Empty states: one short sentence, one primary action, one optional secondary
  action.

## Navigation Model

Primary tabs stay focused:

- Home: clan overview, urgent tasks, next event, quick actions
- Tree: genealogy browsing, search, relationship work
- Events: memorials, calendar, reminders, clan ceremonies
- Plan/Billing: entitlement, limits, upgrade, invoices
- Profile: identity, privacy, language, notifications, account deletion

Secondary workspaces should open from contextual actions, not compete with the
bottom navigation: funds, scholarship, discovery, notifications, branch detail,
member detail, event detail, and billing detail.

## Motion Contract

Motion should make the app feel responsive, not slower. The working rule follows
[Apple HIG Motion](https://developer.apple.com/design/Human-Interface-Guidelines/motion)
and [Material motion](https://m1.material.io/motion/material-motion.html)
guidance: use motion only when it gives feedback, preserves context, or confirms
status; otherwise keep the interface stable.

BeFam should not use slide or fade as a default click response. Frequent
workspace clicks, tab changes, shortcut taps, and route navigation should swap
content immediately and rely on selected states, ripples, color, border, or
focus-ring feedback. This keeps readable clan, money, and governance data from
moving after a user has started reading it.

Context-specific rules:

- Navigation, bottom tabs, and workspace switches: no route slide, no route
  fade, no page-level entrance animation.
- Cards and buttons: Material ink plus 120-180ms color, border, or shadow
  feedback. Do not move the card content.
- Workspace surfaces: allow decoration interpolation only when density,
  theme, or state changes. Do not animate text position.
- Loading states: use stable skeletons or shimmer inside the content region.
  Avoid whole-screen spinners after initial auth/bootstrap.
- Success and save states: use a short icon/state change. Prefer check/status
  color and label changes over moving the surrounding layout.
- Genealogy canvas: pan/zoom is allowed for search focus and relationship
  inspection because it preserves map orientation and explains spatial context.
- Web landing: no ambient float, pulse, or decorative movement. Hover and focus
  may change color, border, and shadow only.
- Onboarding spotlight: keep motion optional and short; the highlighted target
  should remain visually anchored.
- Reduced-motion settings: every custom motion helper must return a stable
  non-animated state when platform settings request reduced motion.

Avoid decorative background blobs, long bounce effects, generic staged entrances,
animation that moves financial or governance content after it becomes readable,
and motion that makes a user wait before acting again.

## Form, Timer, and Action Contract

Forms are high-trust moments in BeFam because they can change identities,
relationships, clan operations, funds, or scholarship records. They should feel
calm, explicit, and hard to misuse.

- Required fields use `AppRequiredFieldLabel` through `appFieldDecoration`.
  Required state must be visible before submission and must not rely on helper
  copy hidden lower in the sheet.
- Validation errors appear inline on the field or immediately beside the step
  that blocks progress. Snackbars can supplement a failure, but they are not the
  only required-field feedback.
- Multi-step editors block forward movement until the current step validates.
  Users should never reach a later step while a required earlier field is empty
  or invalid.
- Form copy is short and human. Labels name the data, helper text explains only
  unusual rules, and error text says exactly what to fix.
- Time-sensitive controls, including OTP resend timers, show a compact progress
  indicator plus remaining time. Do not use a plain countdown sentence when the
  user is waiting to act.
- Async link and button actions use `AppActionButton` or `AppAsyncAction`.
  They show immediate press feedback, expose a slim loading bar when work may
  take time, and ignore repeat taps while the first request is in flight.
- Button motion is a small press scale plus Material ink/color feedback. Avoid
  slide, fade, bounce, or delayed staged motion for button clicks.
- Route transitions use the BeFam scale-only page transition. It should feel
  like focus settling into place, not a card sliding across the screen.
- Reduced motion must still show state changes and loading/progress without
  movement.

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
