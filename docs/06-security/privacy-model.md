# Privacy Model

_Last reviewed: March 14, 2026_

## Privacy principles

- clan data isolation first
- least-privilege write access
- explicit role checks for sensitive operations
- auditable identity and relationship mutations

## Access boundaries

- read access is clan-scoped (`hasClanAccess`)
- write access depends on role and operation type:
  - clan settings: `SUPER_ADMIN` / `CLAN_ADMIN`
  - branch-scoped operations: `BRANCH_ADMIN` with branch constraints
  - self profile updates: strict allowed-field diff checks

## Identity and child access

- child login flows through parent OTP verification
- member claim links `authUid` and refreshes role context claims
- session access mode (`unlinked`, `claimed`, `child`) is persisted and used by
  both app logic and rules

## Data minimization notes

- push token documents store operational metadata needed for routing only
- notification docs are member-targeted and read-state mutable by recipient
- storage uploads enforce file type and size limits

## Operational controls

- protected branches + required CI checks before merge
- production deploys scoped through GitHub environment secrets/variables
- post-release issue closure automation creates traceable story/epic outcomes
