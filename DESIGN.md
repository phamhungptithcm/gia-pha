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

Motion should make the app feel responsive, not slower.

- Shared page transitions use short fade/slide motion through
  `BeFamPageTransitionsBuilder`.
- Workspace surfaces use `AppPageEntrance` and `RepaintBoundary` so page changes
  feel lighter without re-laying out unrelated content.
- Home shortcut cards use staggered entrance animation so iOS, Android, and web
  feel alive without delaying interaction.
- Web landing uses subtle panel float and lineage-ring pulse only. Reduced
  motion disables these effects.
- Motion helpers must check reduced-motion settings before animating.
- Page/sheet entrance: 160-220ms, easeOutCubic.
- Button press/selection: 120-180ms, subtle scale or color transition.
- Success confirmation: check/status icon with 180-260ms fade/scale.
- Genealogy focus jump: pan/zoom animation 260-320ms, preserve orientation.
- Loading: skeleton or shimmer only for content regions, not whole-screen
  spinners after initial auth/bootstrap.
- Respect platform reduced-motion settings where available.

Avoid decorative background blobs, long bounce effects, oversized hero cards in
operational screens, and animation that moves financial or governance content
after it becomes readable.

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
- Loading, empty, error, success, and permission-denied states exist for every
  release-critical workspace.
- Motion is short, purposeful, and does not obscure clan, money, or governance
  data.
