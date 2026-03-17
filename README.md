# BeFam

BeFam is a mobile-first platform for genealogy and clan operations.
This repository is the source-of-truth workspace for product direction,
architecture, implementation, and release operations.

## Language Structure

- English docs: `docs/en/**`
- Vietnamese docs: `docs/vi/**`

## Product Snapshot

BeFam combines genealogy, clan operations, and secure membership access in one
mobile experience.

Current live capability baseline includes:

- phone OTP and child-access authentication flows
- clan/member/relationship/genealogy workspaces
- dual calendar events (solar + lunar)
- funds and scholarship modules
- discovery and join-request flow
- profile and settings baseline
- VNPay-first billing and subscription flow

## Repository Structure

- `docs/`: MkDocs documentation source
- `mobile/befam/`: Flutter mobile application
- `firebase/`: Firestore rules/indexes, Storage rules, Cloud Functions
- `.github/`: CI/CD workflows and GitHub automation
- `scripts/`: release/configuration/backlog helper scripts

## Documentation Entry Points

- Documentation site: [phamhungptithcm.github.io/gia-pha](https://phamhungptithcm.github.io/gia-pha/)
- English docs hub: `docs/en/index.md`
- Vietnamese docs hub: `docs/vi/index.md`
- Production config runbook (EN): `docs/en/05-devops/production-configuration.md`
- Production config runbook (VI): `docs/vi/05-devops/production-configuration.md`

## Local Development

### Preview docs

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

### Validate docs

```bash
mkdocs build --strict
```

### Flutter app

```bash
cd mobile/befam
flutter pub get
flutter analyze
flutter test
flutter run
```
