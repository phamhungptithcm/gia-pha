# FIRESTORE PRODUCTION SCHEMA
## Family Clan App

This schema is optimized for a high-read mobile genealogy application using Cloud Firestore.

> Implementation note (March 14, 2026): this document is the target schema
> reference. Active collection behavior and rules are summarized in
> `docs/en/04-backend/firestore-schema.md` and
> `docs/en/06-security/firebase-rules.md`.

## 1. Design Goals

- support 100k+ members across large clans and branches
- reduce recursive queries
- make search and tree construction practical on mobile
- keep write paths simple but validated
- support future analytics and exports

## 2. Firestore Modeling Principles

- Use top-level collections for core entities
- Use denormalization where read performance matters
- Avoid deeply nested collections for critical read paths
- Keep relationship edges explicit
- Store derived fields for sorting and filtering
- Use Cloud Functions for consistency checks, counters, and side effects

## 3. Collections Overview

```text
clans
branches
members
relationships
events
funds
transactions
scholarshipPrograms
awardLevels
achievementSubmissions
notifications
invites
memberSearchIndex
auditLogs
```

## 4. Collection Definitions

### 4.1 clans/{clanId}

Purpose: top-level clan metadata.

Fields:

```json
{
  "id": "clan_001",
  "name": "Nguyen Van Clan",
  "slug": "nguyen-van-clan",
  "description": "Main clan record",
  "countryCode": "VN",
  "founderName": "Nguyen Van ...",
  "logoUrl": "https://...",
  "status": "active",
  "memberCount": 1234,
  "branchCount": 23,
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id",
  "updatedAt": "timestamp"
}
```

Recommended indexes:
- `slug ASC`
- `status ASC, createdAt DESC`

### 4.2 branches/{branchId}

Purpose: branch / chi within a clan.

Fields:

```json
{
  "id": "branch_001",
  "clanId": "clan_001",
  "name": "Chi Truong",
  "code": "CT01",
  "leaderMemberId": "member_100",
  "viceLeaderMemberId": "member_101",
  "generationLevelHint": 3,
  "status": "active",
  "memberCount": 300,
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id",
  "updatedAt": "timestamp"
}
```

Recommended indexes:
- `clanId ASC, name ASC`
- `clanId ASC, status ASC`

### 4.3 members/{memberId}

Purpose: canonical member profile.

Fields:

```json
{
  "id": "member_001",
  "clanId": "clan_001",
  "branchId": "branch_001",
  "householdId": null,
  "fullName": "Nguyen Van A",
  "normalizedFullName": "nguyen van a",
  "nickName": "Be A",
  "gender": "male",
  "birthDate": "1995-10-20",
  "deathDate": null,
  "phoneE164": "+84901234567",
  "email": null,
  "addressText": "Da Nang, Vietnam",
  "jobTitle": "Software Engineer",
  "avatarUrl": "https://...",
  "bio": "Optional short note",
  "socialLinks": {
    "facebook": "https://...",
    "zalo": null,
    "linkedin": null
  },
  "parentIds": ["member_900", "member_901"],
  "childrenIds": ["member_010", "member_011"],
  "spouseIds": ["member_020"],
  "generation": 5,
  "lineagePath": ["clan_001", "branch_001"],
  "primaryRole": "MEMBER",
  "status": "active",
  "isMinor": false,
  "authUid": "firebase_uid_or_null",
  "claimedAt": "timestamp_or_null",
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id",
  "updatedAt": "timestamp",
  "updatedBy": "uid_or_member_id"
}
```

Notes:
- `parentIds`, `childrenIds`, and `spouseIds` are denormalized helpers, not the only source of truth.
- The canonical edge list remains in `relationships`.
- `normalizedFullName` supports prefix and equality search patterns via derived search docs.

Recommended indexes:
- `clanId ASC, normalizedFullName ASC`
- `clanId ASC, branchId ASC, normalizedFullName ASC`
- `clanId ASC, generation ASC`
- `phoneE164 ASC`
- `authUid ASC`

### 4.4 relationships/{relationshipId}

Purpose: canonical graph edge list.

Fields:

```json
{
  "id": "rel_001",
  "clanId": "clan_001",
  "personA": "member_900",
  "personB": "member_001",
  "type": "parent_child",
  "direction": "A_TO_B",
  "status": "active",
  "source": "manual",
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id",
  "updatedAt": "timestamp"
}
```

Allowed `type` values:
- `parent_child`
- `spouse`
- `adoptive_parent_child` optional phase 2
- `guardian_child` optional phase 2

Rules:
- spouse edges should be unique per pair
- parent_child edges must not create cycles
- max 2 biological parents in MVP validation unless future rules allow otherwise

Recommended indexes:
- `clanId ASC, personA ASC, type ASC`
- `clanId ASC, personB ASC, type ASC`

### 4.5 events/{eventId}

Fields:

```json
{
  "id": "event_001",
  "clanId": "clan_001",
  "branchId": "branch_001",
  "title": "Gio cu To",
  "description": "Memorial ceremony details",
  "eventType": "death_anniversary",
  "targetMemberId": "member_500",
  "locationName": "Tu duong branch",
  "locationAddress": "Hue, Vietnam",
  "startsAt": "timestamp",
  "endsAt": "timestamp",
  "timezone": "Asia/Ho_Chi_Minh",
  "isRecurring": true,
  "recurrenceRule": "FREQ=YEARLY",
  "reminderOffsetsMinutes": [10080, 1440, 120],
  "visibility": "clan",
  "status": "scheduled",
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id",
  "updatedAt": "timestamp"
}
```

Indexes:
- `clanId ASC, startsAt ASC`
- `clanId ASC, eventType ASC, startsAt ASC`
- `branchId ASC, startsAt ASC`

### 4.6 funds/{fundId}

Fields:

```json
{
  "id": "fund_001",
  "clanId": "clan_001",
  "branchId": null,
  "name": "Scholarship Fund",
  "description": "Supports descendants",
  "fundType": "scholarship",
  "currency": "VND",
  "balanceMinor": 125000000,
  "status": "active",
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id",
  "updatedAt": "timestamp"
}
```

### 4.7 transactions/{transactionId}

Fields:

```json
{
  "id": "txn_001",
  "fundId": "fund_001",
  "clanId": "clan_001",
  "branchId": null,
  "transactionType": "donation",
  "amountMinor": 500000,
  "currency": "VND",
  "memberId": "member_001",
  "externalReference": null,
  "occurredAt": "timestamp",
  "note": "Tet contribution",
  "receiptUrl": null,
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id"
}
```

Indexes:
- `fundId ASC, occurredAt DESC`
- `clanId ASC, transactionType ASC, occurredAt DESC`

### 4.8 scholarshipPrograms/{programId}

Fields:

```json
{
  "id": "sp_2026",
  "clanId": "clan_001",
  "title": "2026 Scholarship Program",
  "description": "Annual scholarship program",
  "year": 2026,
  "status": "open",
  "submissionOpenAt": "timestamp",
  "submissionCloseAt": "timestamp",
  "reviewCloseAt": "timestamp",
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id"
}
```

### 4.9 awardLevels/{awardLevelId}

Fields:

```json
{
  "id": "award_001",
  "programId": "sp_2026",
  "clanId": "clan_001",
  "name": "Provincial Academic Excellence",
  "description": "For provincial-level awards",
  "sortOrder": 10,
  "rewardType": "cash",
  "rewardAmountMinor": 1000000,
  "criteriaText": "Student must provide certified result",
  "status": "active",
  "createdAt": "timestamp"
}
```

### 4.10 achievementSubmissions/{submissionId}

Fields:

```json
{
  "id": "sub_001",
  "programId": "sp_2026",
  "awardLevelId": "award_001",
  "clanId": "clan_001",
  "memberId": "member_150",
  "studentNameSnapshot": "Nguyen Thi B",
  "title": "National Math Contest",
  "description": "Won second prize",
  "evidenceUrls": ["https://..."],
  "status": "pending",
  "reviewNote": null,
  "reviewedBy": null,
  "reviewedAt": null,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Indexes:
- `programId ASC, status ASC, createdAt DESC`
- `clanId ASC, memberId ASC, createdAt DESC`

### 4.11 notifications/{notificationId}

Fields:

```json
{
  "id": "notif_001",
  "memberId": "member_001",
  "clanId": "clan_001",
  "type": "event_reminder",
  "title": "Upcoming memorial event",
  "body": "Reminder for tomorrow",
  "data": {
    "eventId": "event_001"
  },
  "isRead": false,
  "sentAt": "timestamp",
  "createdAt": "timestamp"
}
```

Indexes:
- `memberId ASC, createdAt DESC`
- `memberId ASC, isRead ASC, createdAt DESC`

### 4.12 invites/{inviteId}

Fields:

```json
{
  "id": "invite_001",
  "clanId": "clan_001",
  "branchId": "branch_001",
  "memberId": "member_001",
  "inviteType": "phone_claim",
  "phoneE164": "+84901234567",
  "childIdentifier": null,
  "status": "pending",
  "expiresAt": "timestamp",
  "createdAt": "timestamp",
  "createdBy": "uid_or_member_id"
}
```

### 4.13 memberSearchIndex/{docId}

Purpose: optional denormalized searchable docs for fast prefix search or future external search migration.

Fields:

```json
{
  "id": "member_001",
  "clanId": "clan_001",
  "branchId": "branch_001",
  "normalizedFullName": "nguyen van a",
  "tokens": ["nguyen", "van", "a"],
  "generation": 5,
  "status": "active"
}
```

### 4.14 auditLogs/{logId}

Purpose: append-only audit records for sensitive changes.

Fields:

```json
{
  "id": "audit_001",
  "clanId": "clan_001",
  "actorUid": "uid_123",
  "actorMemberId": "member_100",
  "entityType": "relationship",
  "entityId": "rel_001",
  "action": "create",
  "before": null,
  "after": {"type": "parent_child"},
  "createdAt": "timestamp"
}
```

## 5. Firestore Index Strategy

At minimum create composite indexes for:
- member search by clan + branch + normalizedFullName
- events by clan + start date
- transaction history by fund + occurredAt
- submissions by program + status
- notifications by member + createdAt

## 6. Security Principles

- only authenticated users can read within their clan
- clan admins can write clan-scoped administrative records
- members can edit only their own allowed fields
- relationship changes require elevated permissions
- transaction writes should go through secured paths or Cloud Functions

## 7. Scaling Strategy

### For 10k to 50k members
- fetch members by clan in paginated chunks or branch scope
- cache normalized tree data locally
- use derived `generation` values
- use branch-scoped entry points to avoid loading everything unnecessarily

### For 50k+ members
- precompute tree segments per branch
- lazy load descendants / ancestors by depth
- maintain search index collection
- render visible subgraph only on client
- avoid full-canvas layout for all nodes at once

## 8. Data Consistency Rules

When relationship changes:
- update canonical `relationships`
- reconcile `parentIds`, `childrenIds`, `spouseIds`
- recompute generation for impacted subtree if needed
- write audit log
- invalidate cached tree snapshots if implemented

## 9. Example Firestore Rules Guidance

See `firebase-rules.md` in docs structure for implementation, but the system should enforce:
- `request.auth != null`
- user clan scope check
- own profile edit check
- admin role check for branch, event, fund, scholarship writes
