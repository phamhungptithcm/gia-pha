# BeFam E2E Release Report

## Metadata
- Run ID: `RC-20260326-debug-ios`
- Environment: `debug`
- Device: `ios:165ECA74-B67B-45DA-B8A8-B8FC8DEB998B`
- App version: `1.0.0+1`
- Build SHA: `2dc4f42`
- Generated at (UTC): `2026-03-26T13:13:49Z`

## Inputs
- `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/artifacts/e2e-debug-ios-machine.jsonl`

## Summary
- Total cases: **106**
- PASS: **3**
- FAIL: **1**
- BLOCKED: **0**
- NOT_RUN: **102**

## Automated case results
| Case ID | Status | Actual Result |
|---|---|---|
| AUTH-001 | FAIL | PASS via Release Suite · Auth + Role Matrix [AUTH-001][P0] phone OTP flow + privacy gate + role matrix \| FAIL via Release Suite · Auth + Role Matrix [AUTH-001][P0] validate all 6 debug scenarios map to expected session context (Test failed. See exception logs above. The test description was: [AUTH-001][P0] validate all 6 debug scenarios map to expected session context) |
| AUTH-003 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-003][P0] child-code OTP flow goes to shell |
| AUTH-009 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-009][CTX-003][P0] unlinked user is stable and routed to discovery |
| CTX-003 | PASS | PASS via Release Suite · Auth + Role Matrix [AUTH-009][CTX-003][P0] unlinked user is stable and routed to discovery |
