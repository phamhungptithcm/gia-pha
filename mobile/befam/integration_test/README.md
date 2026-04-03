# BeFam E2E Automation

This suite maps release test cases from:

- `/docs/vi/05-devops/release-test-execution-template.csv`
- `/docs/vi/05-devops/release-test-execution-template.xlsx`
- `/docs/vi/05-devops/release-test-dashboard-template.csv`

The full release catalog (`106` cases) is embedded in:

- `/mobile/befam/integration_test/support/release_case_catalog.dart`

Automated E2E IDs are defined in:

- `/mobile/befam/integration_test/support/release_suite_registry.dart`

Contract check (catalog <-> automated IDs):

- `/mobile/befam/integration_test/e2e_release_catalog_contract_test.dart`

## Automated release cases (current)

- `AUTH-001` `P0` login by phone OTP reaches claimed shell context.
- `AUTH-009` `P0` unlinked user login remains stable with no crash.
- `CTX-003` `P0` unlinked user opens genealogy discovery from tree tab.
- `CTX-007` `P1` language switch updates shell labels.
- `MEM-001` `P0` member workspace can be opened and used without runtime errors.

Case registry source:

- `/mobile/befam/integration_test/support/release_suite_registry.dart`

## Run locally

```bash
./scripts/run_mobile_e2e.sh debug android smoke
./scripts/run_mobile_e2e.sh debug ios full
```

Optional live Firebase run (manual trigger):

```bash
BEFAM_E2E_TEST_PHONE="+84901234567" \
BEFAM_E2E_TEST_OTP="123456" \
./scripts/run_mobile_e2e.sh live ios smoke
```

Generated artifacts (per platform/mode):

- `mobile/befam/artifacts/e2e-<mode>-<platform>-<suite>-machine.jsonl`
- `mobile/befam/artifacts/release-execution-<mode>-<platform>-<suite>.csv`
- `mobile/befam/artifacts/release-dashboard-<mode>-<platform>-<suite>.csv`
- `mobile/befam/artifacts/e2e-report-<mode>-<platform>-<suite>.md`

Performance toggles:

- `BEFAM_E2E_FAST_MODE=true` reduces frame-settle waits in harness for CI smoke.
- `BEFAM_E2E_SKIP_SCREENSHOTS=true` skips screenshot capture to reduce I/O overhead.
- `BEFAM_E2E_IOS_MAX_ATTEMPTS=1` avoids expensive duplicate iOS rebuild retries in smoke.

## CI

- Branch CI job `ci-mobile` runs release-catalog contract checks.
- Push-gate mobile E2E runs as separate workflows on `staging` and `main`:
  - `.github/workflows/mobile-e2e.yml` -> `live + android + smoke`
  - `.github/workflows/mobile-e2e-ios.yml` -> `live + ios + smoke`
- Deep regression runs on pushes to `staging` and `main`, plus manual dispatch:
  - `.github/workflows/mobile-e2e-deep.yml`
  - Includes debug full suites (Android + iOS) and live full sanity (Android, only when live test credentials are configured).
