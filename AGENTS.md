# AGENTS

_Last reviewed: April 13, 2026_

This file is the operating guide for human and AI contributors working in the
BeFam repository.

BeFam is a mobile-first genealogy and clan operations platform for Vietnamese
family clans. The codebase serves both product delivery and documentation, so
changes must protect user trust, clan data boundaries, and release stability.

## Mission

Optimize for real clan workflows, not generic feature output.

Core product priorities:

- genealogy clarity and relationship integrity
- clan operations: events, memorials, funds, scholarship flows
- secure member access and role-based governance
- mobile-first execution with production-ready Firebase backing

When tradeoffs appear, prefer:

1. trust and correctness over novelty
2. user task completion over clever UI
3. explicit governance controls over hidden automation
4. scoped improvements over broad speculative refactors

## Repository Map

- `mobile/befam/`: Flutter app for iOS and Android
- `firebase/`: Firestore rules, Storage rules, Cloud Functions
- `docs/`: product, architecture, security, devops, and release documentation
- `scripts/`: local setup, release, and helper automation
- `.github/`: CI/CD workflows and GitHub automation

Canonical entry points:

- [README.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/README.md)
- [docs/en/01-product/product-overview.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/01-product/product-overview.md)
- [docs/en/03-mobile/flutter-structure.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/03-mobile/flutter-structure.md)
- [docs/en/04-backend/cloud-functions.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/04-backend/cloud-functions.md)
- [docs/en/06-security/privacy-model.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/06-security/privacy-model.md)
- [docs/05-devops/branching-strategy.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/05-devops/branching-strategy.md)

## Product Guardrails

- BeFam is not a generic social app. Every UX change should reinforce family,
  clan, memorial, or governance workflows.
- Genealogy and membership data are sensitive. Do not loosen role checks,
  clan-scoping, or review gates for convenience.
- Billing, governance, and relationship mutations are high-trust flows. Favor
  explicit review and auditable state changes.
- AI should remain task-specific, short, advisory, and embedded in an existing
  workflow. Do not reintroduce generic assistant/chat surfaces unless product
  direction changes.
- If a workflow can be solved clearly with deterministic UI or rule-based logic,
  prefer that over AI.

## Mobile App Conventions

The Flutter app uses feature-oriented modules and controller-driven state.

- Keep app shell, bootstrap, theming, and navigation concerns in `lib/app/`
- Keep shared runtime wrappers and low-level services in `lib/core/`
- Keep feature-specific models, repositories, services, and presentation code
  inside `lib/features/<feature>/`
- Use repository interfaces to isolate Firebase/runtime dependencies
- Prefer controller-driven `ChangeNotifier` patterns already used in the app
- UI pages should bind to controller state, not perform backend writes directly

Current architectural references:

- feature-first structure in
  [docs/en/03-mobile/flutter-structure.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/03-mobile/flutter-structure.md)
- state approach in
  [docs/en/03-mobile/state-management.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/03-mobile/state-management.md)

### Flutter implementation rules

- Preserve Material 3 and the existing BeFam workspace visual language unless a
  deliberate design change is requested
- Reuse `AppWorkspaceSurface`, page chrome helpers, and existing tokens before
  introducing new visual patterns
- Add user-facing copy through localization helpers; avoid hard-coding strings
  when the surrounding screen already uses `AppLocalizations`
- Do not hand-edit generated files such as `*.g.dart`, `*.freezed.dart`, or
  `lib/l10n/generated/*`

## Backend and Firebase Conventions

Cloud Functions live in `firebase/functions` and use Firebase Functions v2 with
TypeScript.

- Centralize runtime env access in `src/config/runtime.ts`
- Keep role checks and clan access checks server-side for sensitive operations
- Favor structured logging and deterministic fallbacks over silent failures
- Maintain callable response compatibility unless the client is updated in the
  same change
- Preserve Firestore schema/index compatibility unless a coordinated migration
  is part of the task

Before changing functions, review:

- [docs/en/04-backend/cloud-functions.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/04-backend/cloud-functions.md)
- [docs/FIRESTORE_PRODUCTION_SCHEMA.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/FIRESTORE_PRODUCTION_SCHEMA.md)

## Security and Privacy Rules

These are hard requirements, not suggestions.

- Respect clan isolation and least-privilege access
- Minimize sensitive payloads, especially for AI, billing, auth, and profile
  flows
- Never introduce hard-coded secrets, API keys, or payment credentials
- Keep payment details tokenized and provider-managed
- Avoid exposing raw internal errors directly to end users when a safer
  friendly message exists
- Preserve auditability for governance, billing, and relationship mutations

Security reference:

- [docs/en/06-security/privacy-model.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/06-security/privacy-model.md)

## AI-Specific Guardrails

AI exists in this project to support real user tasks, not to decorate the app.

- Keep AI moments inside high-intent workflows such as profile quality checks,
  event drafting, and admin review support
- Keep AI output advisory unless the UI explicitly asks the user to apply it
- Always keep a safe fallback path when model output is unavailable or unstable
- Measure latency, fallback usage, and user adoption when touching AI flows
- Minimize data sent to models; send only the fields needed for the specific
  task
- Avoid AI features that overpromise insight without grounded product context

Reference:

- [docs/en/01-product/epic-vnext-ai-integration-rollout.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/en/01-product/epic-vnext-ai-integration-rollout.md)

## Local Workflow

Useful commands:

```bash
./scripts/setup_project_env.sh
cd mobile/befam && flutter pub get
cd mobile/befam && flutter analyze
cd mobile/befam && flutter test
cd firebase/functions && npm ci
cd firebase/functions && npm run build
cd firebase/functions && npm test
mkdocs build --strict
```

Helper scripts:

- `./run_flutter_targets.sh`
- `./scripts/build_mobile_release_local.sh`
- `./scripts/run_mobile_e2e.sh smoke`

When working on device-specific release builds, prefer local env files and
scripted injection over hard-coding platform secrets or release identifiers.

## Change Scope Expectations

- Keep changes narrowly scoped to one product problem or one coherent fix
- Avoid unrelated cleanup in the same commit unless it removes a direct blocker
- Update tests when behavior changes
- Update docs when architecture, workflows, config, or operational steps change
- Preserve backward compatibility for production data and release flows unless
  the task explicitly includes migration work

## Testing Expectations

At minimum, run the checks that cover the area you changed.

### Mobile changes

```bash
cd mobile/befam
flutter analyze
flutter test
```

### Functions changes

```bash
cd firebase/functions
npm run build
npm test
```

### Docs-only changes

```bash
mkdocs build --strict
```

If full-suite verification is too expensive for the task, run targeted checks
and state clearly what was and was not verified.

## Documentation and Localization

- English docs live in `docs/en/**`
- Vietnamese docs live in `docs/vi/**`
- Keep terminology consistent across product, architecture, and release docs
- If a product behavior changes meaningfully, update the most relevant canonical
  doc rather than leaving the repo in a split-brain state

## Branching and PR Guidance

- Branch from the latest `staging`
- Open PRs back into `staging` unless the task explicitly targets another base
- Keep one branch focused on one issue or one tightly related change set
- Use clear conventional commits
- Call out config, rollout, migration, and operational impact in the PR

Reference:

- [docs/05-devops/branching-strategy.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/docs/05-devops/branching-strategy.md)

## Agent Checklist

Before shipping a change, confirm:

- the change fits BeFam's real product workflows
- role checks, clan boundaries, and privacy posture remain intact
- AI changes are advisory, bounded, and measured
- the implementation follows the feature/controller/repository structure
- verification was run for the touched area
- docs were updated if the change affects behavior or operations

If any of the above is not true, stop and resolve that gap before merging.
