# User Personas

_Last reviewed: March 14, 2026_

## Primary personas

### Clan Admin (Truong toc)

Responsibilities:

- sets up clan profile and branch structure
- assigns leadership roles and approves sensitive edits
- oversees data quality and release readiness for production use

Key needs:

- clear governance controls and audit visibility
- safe permission boundaries
- reliable release workflow from `staging` to `main`

### Branch Admin (Truong chi / Pho chi)

Responsibilities:

- manages members within an assigned branch
- maintains relationship quality for branch members
- helps onboard parents and child accounts

Key needs:

- branch-scoped edit permissions
- fast member search and filtering
- simple forms with large tap targets

### Member

Responsibilities:

- views genealogy and member profiles
- updates self profile and avatar
- receives event and scholarship notifications

Key needs:

- easy reading on mobile
- fast load times and clear Vietnamese copy by default
- confidence that private data is protected

### Parent Proxy

Responsibilities:

- verifies child login flow via OTP
- supports minors who do not have their own phone number

Key needs:

- low-friction OTP flow
- clear destination masking and role context
- safe child-account claim behavior

### Release Maintainer (engineering/ops)

Responsibilities:

- keeps CI/CD healthy and branch rules enforced
- ships weekly promotion PRs and production releases
- ensures docs and Firebase deployments stay aligned

Key needs:

- predictable checks (`ci-docs`, `ci-functions`, `ci-mobile`)
- automated release notes/tags/assets
- post-release issue and epic closure automation
