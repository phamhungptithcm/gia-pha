# Onboarding Flow Config

This directory contains seed material for the interactive coach-mark system.

Runtime lookup order:

1. Firebase Remote Config gates rollout and selects the catalog collection.
2. Firestore collection `onboardingFlows` stores editable flow definitions.
3. The app falls back to a local catalog when Firestore does not return a flow.

Remote Config keys used by the app:

- `onboarding_enabled`
- `onboarding_firestore_catalog_enabled`
- `onboarding_catalog_collection`
- `onboarding_rollout_percent`
- `onboarding_shell_navigation_enabled`
- `onboarding_member_workspace_enabled`
- `onboarding_genealogy_workspace_enabled`
- `onboarding_genealogy_discovery_enabled`
- `onboarding_clan_detail_enabled`

Suggested Firestore shape:

- Collection: `onboardingFlows`
- One document per flow version
- Required top-level fields: `id`, `triggerId`, `version`, `enabled`, `steps`

Suggested deploy process:

1. Validate documents against `onboarding_flow.schema.json`.
2. Import `sample_onboarding_flows.json` into a staging Firebase project.
3. Enable the rollout with Remote Config only after verifying analytics and UI anchors.
4. Use `onboarding_funnel_bigquery.sql` to validate start, completion, and drop-off before widening rollout.

Seed and validation helpers:

- Validate JSON shape locally:
  - `cd firebase/functions && npm run validate:onboarding-flows`
- Upsert to Firestore staging:
  - `cd firebase/functions && FIREBASE_PROJECT_ID=<project-id> npm run seed:onboarding-flows`
- Override catalog file or collection:
  - `node scripts/seed-onboarding-flows.mjs --file ../../mobile/befam/config/onboarding/sample_onboarding_flows.json --collection onboardingFlows`
- Production safety:
  - the script refuses likely production project ids unless `--allow-production` is passed explicitly
