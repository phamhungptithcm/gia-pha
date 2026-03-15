# Privacy Model

_Last reviewed: March 15, 2026_

## Privacy principles

- clan data isolation first
- least-privilege write access
- explicit role checks for sensitive operations
- auditable identity and relationship mutations
- payment-data minimization and gateway tokenization

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
- planned billing model stores only payment references and masked metadata
  (never raw card PAN/CVV)
- invoice and transaction records are clan-scoped and owner/admin-visible only
- ad telemetry (if enabled) is aggregated and plan-scoped; no personalized ad
  profiling is required for billing eligibility

## Payment data protection model (Epic #213)

- checkout requests are generated server-side with authoritative pricing
  calculation by `member_count`
- card details are collected by payment provider UI/SDK; BeFam stores provider
  token/reference only
- VNPay and card callbacks require signature verification before state changes
- webhook processing is idempotent to prevent duplicate charging side effects
- billing audit logs record actor, action, and transaction reference for
  investigation
- sensitive payment metadata is excluded/redacted from client-visible logs
- ad entitlement checks use plan metadata only (`FREE/BASE/PLUS/PRO`) and do
  not require storing sensitive personal attributes

## Retention and access controls (planned billing)

- keep transaction/invoice records for audit and compliance support windows
- restrict billing read access to clan owner/admin roles
- isolate billing data by `clanId`
- document breach-response and incident runbook for payment-related events

## Operational controls

- protected branches + required CI checks before merge
- production deploys scoped through GitHub environment secrets/variables
- post-release issue closure automation creates traceable story/epic outcomes
