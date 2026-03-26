# BeFam E2E Release Report

## Metadata
- Run ID: `RC-20260326-debug-ios-full`
- Environment: `debug`
- Device: `ios:165ECA74-B67B-45DA-B8A8-B8FC8DEB998B`
- App version: `1.0.0+1`
- Build SHA: `2dc4f42`
- Generated at (UTC): `2026-03-26T13:53:35Z`

## Inputs
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/artifacts/e2e-debug-ios-full-machine.jsonl`

## Summary
- Total cases: **106**
- PASS: **8**
- FAIL: **2**
- BLOCKED: **0**
- NOT_RUN: **96**

## Automated case results
| Case ID | Status | Actual Result |
|---|---|---|
| AUTH-001 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-001][P0] phone OTP flow + privacy gate + role matrix \| PASS via Release Suite · Auth + Role Matrix [AUTH-001][P0] validate all 6 debug scenarios map to expected session context |
| AUTH-003 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-003][P0] child-code OTP flow goes to shell |
| AUTH-009 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-009][CTX-003][P0] unlinked user is stable and routed to discovery |
| CTX-003 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-009][CTX-003][P0] unlinked user is stable and routed to discovery |
| CTX-007 | FAIL | FAIL via Release Suite · Genealogy + Members + Calendar + Profile [CTX-007][NOTIF-003][P1] profile language persistence + notification inbox deep-link (Test failed. See exception logs above. The test description was: [CTX-007][NOTIF-003][P1] profile language persistence + notification inbox deep-link) |
| EVT-002 | PASS | PASS via Release Suite · Genealogy + Members + Calendar + Profile [EVT-002][P0] create lunar memorial event with details |
| MEM-001 | PASS | PASS via Release Suite · Genealogy + Members + Calendar + Profile [MEM-001][P0] add member flow with sibling-order hint |
| NOTIF-003 | FAIL | FAIL via Release Suite · Genealogy + Members + Calendar + Profile [CTX-007][NOTIF-003][P1] profile language persistence + notification inbox deep-link (Test failed. See exception logs above. The test description was: [CTX-007][NOTIF-003][P1] profile language persistence + notification inbox deep-link) |
| RULE-001 | PASS | PASS via Release Suite · Genealogy + Members + Calendar + Profile [TREE-001][RULE-001][P0] genealogy tree load, scope, node navigation |
| TREE-001 | PASS | PASS via Release Suite · Genealogy + Members + Calendar + Profile [TREE-001][RULE-001][P0] genealogy tree load, scope, node navigation |
