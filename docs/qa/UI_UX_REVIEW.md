# BeFam Website UI/UX QA Review

Date: 2026-05-18
Reviewer role: Senior UI/UX QA Agent
Scope: Website/browser only
Environment: Staging emulator

## Decision

UI/UX status: **PARTIAL APPROVAL / PRODUCTION NOT APPROVED**.

The public website now matches the cleaner BeFam direction more closely:
compact content, lighter language, BF branding, stable navigation, improved
footer behavior, desktop/tablet/mobile screenshots, and consistent page rhythm.
The authenticated `/app` entry also renders the refreshed auth surface.

Production UI/UX cannot be fully approved until the post-login website flow is
reviewed after a completed staging login. Automated QA reached the reCAPTCHA
challenge but not AppShell.

## Feedback

### WEB-UIUX-001

- ID: `WEB-UIUX-001`
- Severity: `P1`
- Page/component: Footer
- Viewport: Desktop/tablet/mobile
- Problem: Footer behaved like a large fixed overlay and could cover content.
- Why it matters: Users lose context when persistent chrome competes with the main page.
- Recommended fix: Make footer compact and let it live in page flow while keeping the visual language.
- Evidence: `screens/web-home-after-csp-1440x900.png`
- Status: `Verified`
- Retest result: Footer is compact and no longer blocks content.

### WEB-UIUX-002

- ID: `WEB-UIUX-002`
- Severity: `P2`
- Page/component: Header navigation
- Viewport: Tablet
- Problem: Tablet nav collapsed too early and made the website feel less complete.
- Why it matters: Tablet users have enough width for primary links and should not get unnecessary hiding.
- Recommended fix: Keep primary nav visible until mobile breakpoint.
- Evidence: `screens/web-home-tablet-after-csp-834x1112.png`
- Status: `Verified`
- Retest result: Tablet layout keeps a stronger brand/navigation structure.

### WEB-UIUX-003

- ID: `WEB-UIUX-003`
- Severity: `P2`
- Page/component: Mobile hero
- Viewport: Mobile 390x844
- Problem: Hero type and line breaks were too aggressive.
- Why it matters: The first viewport should feel calm and readable, not cramped.
- Recommended fix: Increase usable line width and tune mobile hero size.
- Evidence: `screens/web-home-mobile-after-csp-390x844.png`
- Status: `Verified`
- Retest result: Mobile hero is more readable and balanced.

### WEB-UIUX-004

- ID: `WEB-UIUX-004`
- Severity: `P2`
- Page/component: CTA copy
- Viewport: Desktop/tablet/mobile
- Problem: CTA labels were not fully consistent across public pages.
- Why it matters: Clear repeated actions reduce hesitation.
- Recommended fix: Normalize primary app entry copy to `Mở ứng dụng`.
- Evidence: web marketing widget tests.
- Status: `Verified`
- Retest result: Tests confirm the expected CTA copy.

### WEB-UIUX-005

- ID: `WEB-UIUX-005`
- Severity: `P1`
- Page/component: Auth/AppShell after login
- Viewport: Desktop browser
- Problem: Full post-login website UX could not be reviewed because Firebase reCAPTCHA required human interaction.
- Why it matters: Release approval requires evidence for authenticated navigation, forms, empty states, and permission states.
- Recommended fix: Complete a redacted manual staging login pass or configure a staging QA bypass that still preserves production security.
- Evidence: `logs/web-live-login-coordinate-run.txt`
- Status: `Open`
- Retest result: Pending.

## UI/UX Sign-Off

- Public website visual QA: **approved for release candidate**
- Responsive public pages: **approved**
- Auth entry before OTP: **approved**
- Authenticated website after login: **not approved yet**
