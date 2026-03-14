# Scalability

_Last reviewed: March 14, 2026_

## Current scalability posture

- graph reads are optimized through denormalized member relationship arrays
- canonical edge validation is kept in callables
- member search uses indexed normalized fields
- genealogy segments support local caching and scoped loading

## Near-term scaling priorities

- complete server-side reconciliation triggers for relationship denormalization
- harden event reminder scheduling at larger audience sizes
- add pagination for future notification inbox and event list views
- introduce stronger performance profiling for large genealogy trees

## Data-layer strategy

- preserve clan partitioning and indexed access patterns
- keep write amplification controlled via targeted transactional updates
- use batched notification document fan-out and chunked FCM multicast

## Operational scaling strategy

- monitor CI duration and split jobs if release pressure grows
- evolve release artifacts toward signed iOS export once signing secrets are
  configured
- consider dedicated dev/staging/prod Firebase project split if team size or
  deployment frequency increases
