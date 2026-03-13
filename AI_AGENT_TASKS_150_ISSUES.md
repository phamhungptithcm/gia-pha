# AI AGENT TASKS 150 ISSUES
## Family Clan App

This file defines an AI-friendly issue backlog. The exact count can expand beyond 150 as implementation detail grows.

Format:
- ID
- Epic
- Title
- Goal
- Acceptance criteria summary

---

## EPIC 1 - Project Bootstrap

### 1. BOOT-001 Initialize Flutter app
Goal: Create base Flutter application structure.
Acceptance:
- app boots locally
- environment config placeholder exists
- routing skeleton exists

### 2. BOOT-002 Configure linting and analysis
### 3. BOOT-003 Add freezed/json code generation
### 4. BOOT-004 Configure Firebase core initialization
### 5. BOOT-005 Set up base theme and palette
### 6. BOOT-006 Add app shell and home placeholders
### 7. BOOT-007 Configure logger and crash handling
### 8. BOOT-008 Add CI pipeline for analyze and tests
### 9. BOOT-009 Add README quickstart
### 10. BOOT-010 Add docs landing page and MkDocs nav

## EPIC 2 - Authentication

### 11. AUTH-001 Implement login method selection screen
### 12. AUTH-002 Implement phone number input validation
### 13. AUTH-003 Implement request OTP action
### 14. AUTH-004 Implement OTP verification screen
### 15. AUTH-005 Implement OTP resend cooldown
### 16. AUTH-006 Map Firebase auth errors to UI messages
### 17. AUTH-007 Persist session and silent restore
### 18. AUTH-008 Implement logout
### 19. AUTH-009 Implement child identifier input screen
### 20. AUTH-010 Resolve parent phone by child identifier
### 21. AUTH-011 Implement parent OTP verification for child login
### 22. AUTH-012 Implement claim-member-record flow
### 23. AUTH-013 Link auth UID to member profile
### 24. AUTH-014 Add auth analytics events
### 25. AUTH-015 Add auth widget tests

## EPIC 3 - Clan Management

### 26. CLAN-001 Create clan form
### 27. CLAN-002 Persist clan document
### 28. CLAN-003 Create branch form
### 29. CLAN-004 Persist branch document
### 30. CLAN-005 Assign branch leader
### 31. CLAN-006 Assign branch vice leader
### 32. CLAN-007 Clan detail screen
### 33. CLAN-008 Branch list screen
### 34. CLAN-009 Clan settings permissions check
### 35. CLAN-010 Add clan repository tests

## EPIC 4 - Member Profiles

### 36. MEMBER-001 Create member add form
### 37. MEMBER-002 Persist member profile document
### 38. MEMBER-003 Edit own profile
### 39. MEMBER-004 Upload avatar to storage
### 40. MEMBER-005 Manage social links
### 41. MEMBER-006 Member detail screen
### 42. MEMBER-007 Member list by branch
### 43. MEMBER-008 Search members by name
### 44. MEMBER-009 Filter members by generation
### 45. MEMBER-010 Filter members by branch
### 46. MEMBER-011 Validate duplicate phone handling
### 47. MEMBER-012 Add member profile tests

## EPIC 5 - Relationship Management

### 48. REL-001 Create parent-child relationship command
### 49. REL-002 Create spouse relationship command
### 50. REL-003 Prevent duplicate spouse edge
### 51. REL-004 Prevent parent-child cycle
### 52. REL-005 Reconcile parentIds and childrenIds
### 53. REL-006 Audit log on relationship mutation
### 54. REL-007 Relationship detail / inspector panel
### 55. REL-008 Relationship repository tests
### 56. REL-009 Relationship validation domain tests
### 57. REL-010 Permission checks for sensitive edits

## EPIC 6 - Genealogy Read Model

### 58. TREE-001 Fetch members by clan scope
### 59. TREE-002 Fetch members by branch scope
### 60. TREE-003 Build adjacency map from relationships
### 61. TREE-004 Build ancestry path helper
### 62. TREE-005 Build descendants traversal helper
### 63. TREE-006 Compute sibling groups
### 64. TREE-007 Add generation labeling helper
### 65. TREE-008 Cache tree segment locally
### 66. TREE-009 Load tree root entry points
### 67. TREE-010 Add tree algorithm tests

## EPIC 7 - Genealogy UI

### 68. TREEUI-001 Create tree landing screen
### 69. TREEUI-002 Render member node card
### 70. TREEUI-003 Render parent-child connectors
### 71. TREEUI-004 Render spouse connectors
### 72. TREEUI-005 Expand ancestors lazily
### 73. TREEUI-006 Expand descendants lazily
### 74. TREEUI-007 Zoom and pan support
### 75. TREEUI-008 Center on selected member
### 76. TREEUI-009 Open member detail from node tap
### 77. TREEUI-010 Tree performance profiling

## EPIC 8 - Events

### 78. EVENT-001 Event list screen
### 79. EVENT-002 Event detail screen
### 80. EVENT-003 Create event form
### 81. EVENT-004 Edit event form
### 82. EVENT-005 Validate start/end times
### 83. EVENT-006 Event type enum support
### 84. EVENT-007 Recurring yearly memorial fields
### 85. EVENT-008 Reminder offsets editor
### 86. EVENT-009 Event repository tests
### 87. EVENT-010 Event widget tests

## EPIC 9 - Notifications

### 88. NOTIF-001 Configure FCM token registration
### 89. NOTIF-002 Notification inbox screen
### 90. NOTIF-003 Mark notification as read
### 91. NOTIF-004 Deep-link from notification to event
### 92. NOTIF-005 Deep-link from notification to scholarship result
### 93. NOTIF-006 Notification settings toggle placeholders
### 94. NOTIF-007 Inbox pagination
### 95. NOTIF-008 Notification tests

## EPIC 10 - Funds

### 96. FUND-001 Fund list screen
### 97. FUND-002 Fund detail screen
### 98. FUND-003 Create fund form
### 99. FUND-004 Donation create form
### 100. FUND-005 Expense create form
### 101. FUND-006 Transaction list with filters
### 102. FUND-007 Running balance display
### 103. FUND-008 Transaction validation rules
### 104. FUND-009 Fund repository tests
### 105. FUND-010 Currency and minor units utility

## EPIC 11 - Scholarship Programs

### 106. SCH-001 Program list screen
### 107. SCH-002 Program detail screen
### 108. SCH-003 Create scholarship program form
### 109. SCH-004 Create award level form
### 110. SCH-005 Award level list
### 111. SCH-006 Submission create form
### 112. SCH-007 Upload evidence files
### 113. SCH-008 Review queue screen
### 114. SCH-009 Approve submission action
### 115. SCH-010 Reject submission action
### 116. SCH-011 Scholarship repository tests
### 117. SCH-012 Scholarship flow widget tests

## EPIC 12 - Search and Discovery

### 118. SEARCH-001 Member search provider
### 119. SEARCH-002 Search result list item UI
### 120. SEARCH-003 Branch filter chips
### 121. SEARCH-004 Generation filter controls
### 122. SEARCH-005 Search empty state
### 123. SEARCH-006 Search loading and retry state
### 124. SEARCH-007 Search analytics instrumentation
### 125. SEARCH-008 Search tests

## EPIC 13 - Profile and Settings

### 126. PROF-001 Profile screen
### 127. PROF-002 Edit profile form
### 128. PROF-003 Settings screen shell
### 129. PROF-004 Notification preference placeholders
### 130. PROF-005 Logout confirmation
### 131. PROF-006 Profile image update tests

## EPIC 14 - Permissions and Security

### 132. SEC-001 Role enum and mapping
### 133. SEC-002 Clan membership guard
### 134. SEC-003 Branch admin guard
### 135. SEC-004 Clan admin guard
### 136. SEC-005 Storage path authorization integration
### 137. SEC-006 Security unit tests
### 138. SEC-007 Rules documentation validation

## EPIC 15 - Cloud Functions Integration

### 139. CF-001 Event created notification trigger integration
### 140. CF-002 Relationship reconciliation function integration
### 141. CF-003 Fund balance recalculation integration
### 142. CF-004 Scholarship decision notification integration
### 143. CF-005 Invite expiration job integration
### 144. CF-006 Functions contract tests

## EPIC 16 - Observability and Analytics

### 145. OPS-001 Crashlytics setup
### 146. OPS-002 Analytics event constants
### 147. OPS-003 Performance measurement logging
### 148. OPS-004 Error boundary / fallback UI
### 149. OPS-005 Monitoring docs update

## EPIC 17 - Release Hardening

### 150. REL-RELEASE-001 Accessibility pass
### 151. REL-RELEASE-002 Empty/loading/error state audit
### 152. REL-RELEASE-003 Localization prep
### 153. REL-RELEASE-004 Golden path smoke test
### 154. REL-RELEASE-005 Store assets checklist
### 155. REL-RELEASE-006 Pre-release QA checklist

## Suggested GitHub Labels

- epic
- story
- task
- flutter
- firebase
- architecture
- security
- analytics
- performance
- documentation
- bug
- enhancement

## Suggested Project Workflow Columns

- Backlog
- Ready
- In Progress
- In Review
- Blocked
- Done

## Suggested Issue Template Fields

- Problem
- Scope
- Acceptance criteria
- Out of scope
- Technical notes
- Test notes
