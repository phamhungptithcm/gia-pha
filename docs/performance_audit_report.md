# BeFam Flutter/Firebase Performance Audit Report

**Audited branch:** `codex/e2e-automation-testing-setup`
**App:** BeFam (mobile/befam) — Flutter 3.x, Firebase backend
**Platforms:** iOS 15+, Android
**Date:** 2026-03-22
**Auditor:** Senior Mobile Performance Engineer

---

## Table of Contents

1. [Critical Performance Issues](#1-critical-performance-issues)
2. [Medium Impact Improvements](#2-medium-impact-improvements)
3. [Low Priority Optimizations](#3-low-priority-optimizations)
4. [Architecture Recommendations](#4-architecture-recommendations)
5. [Code Examples](#5-code-examples)
6. [Performance Profiling Guide](#6-performance-profiling-guide)

---

## 1. Critical Performance Issues

### 🔴 CRIT-01 — `FirebaseSessionAccessSync` Called on Every Repository Operation

**Files affected:**
- `lib/features/member/services/firebase_member_repository.dart`
- `lib/features/genealogy/services/firebase_genealogy_read_repository.dart`
- `lib/features/funds/services/firebase_fund_repository.dart`
- `lib/features/events/services/firebase_event_repository.dart`
- `lib/features/clan/services/firebase_clan_repository.dart`
- `lib/features/relationship/services/firebase_relationship_repository.dart`

**Problem:**

Every single repository method — reads and writes alike — begins with:

```dart
await FirebaseSessionAccessSync.ensureUserSessionDocument(
  firestore: _firestore,
  session: session,
);
```

`ensureUserSessionDocument()` does the following on **each call**:
1. `FirebaseAuth.instance.currentUser?.getIdTokenResult()` — a **network round-trip** to refresh the Firebase ID token and read custom claims.
2. `firestore.collection('users').doc(uid).set({...}, SetOptions(merge: true))` — a **Firestore write** to update the session document.

This means that every `loadWorkspace()`, `saveMember()`, `loadClanSegment()`, `saveTransaction()` call incurs **2 additional network/IO operations before** it even starts its intended work. On a typical screen load that fires 3–4 parallel repository calls via `Future.wait(...)`, this generates **6–8 extra Firestore writes and token fetches simultaneously**.

**Impact:** Severe latency on all data loads, unnecessary Firestore write costs, and quota/billing implications.

**Recommended Fix:**
Call `ensureUserSessionDocument` **once per session start** (e.g., in `AppBootstrap` or immediately after `AuthController` finalises a session), and cache a boolean `_sessionSynced` flag per session UID. See [Code Example CE-01](#ce-01--session-sync-guard-with-per-session-cache).

---

### 🔴 CRIT-02 — Unbounded Full-Collection Firestore Reads

**Files affected:**
- `lib/features/member/services/firebase_member_repository.dart` (line 60–62)
- `lib/features/genealogy/services/firebase_genealogy_read_repository.dart` (lines 62–66)
- `lib/features/funds/services/firebase_fund_repository.dart` (line 54)
- `lib/features/events/services/firebase_event_repository.dart`

**Problem:**

The `loadWorkspace()` methods download **entire collections** scoped only by `clanId`:

```dart
// firebase_member_repository.dart
final results = await Future.wait([
  _members.where('clanId', isEqualTo: clanId).get(),   // ALL members, no limit
  _branches.where('clanId', isEqualTo: clanId).get(),  // ALL branches, no limit
]);

// firebase_genealogy_read_repository.dart
final results = await Future.wait([
  _members.where('clanId', isEqualTo: clanId).get(),        // ALL members again
  _branches.where('clanId', isEqualTo: clanId).get(),       // ALL branches again
  _relationships.where('clanId', isEqualTo: clanId).get(),  // ALL relationships
]);
```

For a clan with 500 members, each genealogy load downloads **500 member docs + 500 relationship docs + branch docs**, serialised to JSON, allocated to heap, and then sorted. With no `limit()` clause, this scales unboundedly.

**Impact:** Slow first load (multiple seconds on poor connections), high memory allocation, excessive Firestore read costs.

**Recommended Fixes:**
- Apply `.limit(N)` with cursor-based pagination for list views.
- Use `source: Source.cache` for repeat loads where freshness is acceptable.
- For genealogy, consider a Cloud Function that returns a pre-aggregated graph payload instead of raw collection downloads.

---

### 🔴 CRIT-03 — Duplicate Firestore Reads: Members & Branches Fetched Twice

**Files affected:**
- `lib/features/member/services/firebase_member_repository.dart`
- `lib/features/genealogy/services/firebase_genealogy_read_repository.dart`

**Problem:**

`AppShellPage` initialises both `MemberWorkspacePage` and `GenealogyWorkspacePage`. Each page initialises its own controller, which triggers its own `loadWorkspace()` call. Both repositories independently query:

```
members   WHERE clanId == X
branches  WHERE clanId == X
```

This doubles the Firestore read cost (and latency) for the **same data** on every app launch. The genealogy repository additionally fetches `relationships`, so the full duplicate cost on launch is:

| Repository | Reads |
|---|---|
| MemberRepository.loadWorkspace | members + branches |
| GenealogyRepository.loadClanSegment | members + branches + relationships |
| **Total** | **2× members, 2× branches, 1× relationships** |

**Recommended Fix:**
Introduce a shared `ClanDataCache` service that holds the `members` and `branches` snapshots. Both repositories should hydrate from this cache and only re-fetch when the cache is stale or explicitly invalidated. See [Architecture Recommendation AR-01](#ar-01--shared-clan-data-cache).

---

### 🔴 CRIT-04 — Transaction Fallback Removes `.limit(400)` — Unbounded Read Risk

**File:** `lib/features/funds/services/firebase_fund_repository.dart` (lines 80–103)

**Problem:**

```dart
Future<QuerySnapshot<Map<String, dynamic>>> _loadTransactionSnapshot({
  required String clanId,
}) async {
  final baseQuery = _transactions.where('clanId', isEqualTo: clanId);
  try {
    return await baseQuery
        .orderBy('occurredAt', descending: true)
        .limit(400)           // ← limit applied here
        .get();
  } on FirebaseException catch (error) {
    if (!_isIndexError(error)) rethrow;
    return await baseQuery.get();  // ← fallback: NO limit, downloads EVERYTHING
  }
}
```

When the Firestore composite index for `(clanId, occurredAt DESC)` is missing (which happens silently in development and on new environments), the query falls back to **downloading the entire transactions collection** for the clan with no limit whatsoever. This is a silent unbounded read that could download thousands of documents and cause an OOM crash.

**Recommended Fix:**
Apply `.limit(400)` (or a reasonable cap) on **both** the primary and fallback query paths. Log or report the missing-index error to Crashlytics. See [Code Example CE-02](#ce-02--safe-transaction-fallback-with-limit).

---

### 🔴 CRIT-05 — Android Release Build: No R8 Minification, Signed with Debug Keys

**File:** `mobile/befam/android/app/build.gradle.kts`

**Problem:**

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
        // minifyEnabled is absent — R8 is NOT enabled
        // shrinkResources is absent
    }
}
```

Two critical issues:
1. **No R8/ProGuard minification**: Dead code is not removed, class/method names are not obfuscated, resources are not shrunk. The release APK/AAB is significantly larger than necessary (commonly 20–40% larger without R8 for Firebase-heavy apps).
2. **Debug signing key on release builds**: Any release build pushed to a store or distributed would be signed with the debug keystore, which is not production-appropriate.

**Recommended Fix:**
Enable `minifyEnabled = true`, `shrinkResources = true`, add a ProGuard rules file, and configure a proper release signing config. See [Code Example CE-03](#ce-03--android-release-build-with-r8).

---

## 2. Medium Impact Improvements

### 🟠 MED-01 — `_accessibleMembers` and `generationOptions` Recompute on Every Access

**File:** `lib/features/member/presentation/member_controller.dart`

**Problem:**

```dart
List<MemberProfile> get _accessibleMembers {
  return _members
      .where((member) => permissions.canViewMember(member, _session))
      .toList(growable: false);  // new list allocated on every getter access
}

List<int> get generationOptions {
  final values =
      _accessibleMembers           // calls _accessibleMembers again (another full scan)
          .map((member) => member.generation)
          .toSet()
          .toList()
        ..sort();
  return values;
}
```

`_accessibleMembers` performs a full O(n) filter on the entire members list every time it is accessed. `generationOptions` then calls `_accessibleMembers` again, resulting in **two full scans** per call. In widget `build()` methods that reference both, these fire on every rebuild.

**Recommended Fix:**
Cache computed results. Invalidate when `_members` or `_session` changes.

```dart
List<MemberProfile>? _cachedAccessibleMembers;

List<MemberProfile> get _accessibleMembers {
  return _cachedAccessibleMembers ??= _members
      .where((member) => permissions.canViewMember(member, _session))
      .toList(growable: false);
}

// In refresh() and after saves, add:
_cachedAccessibleMembers = null;
```

---

### 🟠 MED-02 — No Image Caching for Firebase Storage Avatars

**Files affected:**
- `lib/features/profile/presentation/profile_workspace_page.dart`
- `lib/features/billing/presentation/billing_workspace_page.dart`
- Any widget rendering `member.avatarUrl`

**Problem:**

Firebase Storage URLs are used directly in `Image.network()` with no caching layer. Every time a widget showing an avatar is rebuilt (e.g., tab switch, scroll), it issues a new HTTP request if the image is not in the platform HTTP cache (which has limited size and no eviction control).

**Recommended Fix:**
Add `cached_network_image` to `pubspec.yaml` and replace `Image.network()` with `CachedNetworkImage()`. For Firebase Storage, also consider using Firebase Hosting or a CDN with image resizing transforms to reduce transfer size.

```yaml
# pubspec.yaml
dependencies:
  cached_network_image: ^3.3.1
```

```dart
// Before
Image.network(member.avatarUrl!, width: 48, height: 48)

// After
CachedNetworkImage(
  imageUrl: member.avatarUrl!,
  width: 48,
  height: 48,
  placeholder: (context, url) => const CircleAvatar(child: Icon(Icons.person)),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  memCacheWidth: 96,   // 2× for HiDPI, keeps memory footprint small
  memCacheHeight: 96,
)
```

---

### 🟠 MED-03 — `AppShellPage` Is a Monolithic 1700-Line StatefulWidget

**File:** `lib/app/home/app_shell_page.dart`

**Problem:**

`AppShellPage` is a single `StatefulWidget` containing:
- Bottom navigation logic
- Notification deep-link routing
- Billing entitlement refresh
- Ad banner auto-hide timer with `setState`
- Clan context switching (load, spinner, switch)
- All 5 workspace page instantiations
- `PushNotificationService` lifecycle

Any `setState()` call in `_AppShellPageState` — triggered by the ad-banner timer, a notification deep link, or a clan context switch — rebuilds **the entire shell subtree**, including all workspace pages that were not actually affected.

Specific hot paths:
- `_syncAdBannerAutoHideTimer()` → `Timer` → `setState(() { _showAdBanner = false; })` after 10 seconds.
- `_handleNotificationDeepLink()` → `setState(() { _selectedIndex = 2; ... })`.
- `_loadClanContexts()` → multiple `setState` calls during loading spinner transitions.

**Recommended Fix:**
- Extract `_AdBannerWidget` as a `StatefulWidget` managing its own hide timer internally.
- Extract `_ClanContextSwitcher` as a separate `StatefulWidget`.
- Wrap stable sub-trees (workspace pages that don't change) in `RepaintBoundary`.
- Use `IndexedStack` with lazy initialisation to avoid rebuilding inactive tabs.

---

### 🟠 MED-04 — `GenealogySegmentCache` Has No TTL or Invalidation After Mutations

**File:** `lib/features/genealogy/services/genealogy_segment_cache.dart`

**Problem:**

```dart
class GenealogySegmentCache {
  final Map<String, GenealogyReadSegment> _entries = {};

  GenealogyReadSegment? read(GenealogyScope scope) {
    return _entries[scope.cacheKey]?.copyWith(fromCache: true);
  }

  void write(GenealogyReadSegment segment) { ... }
  void clear([GenealogyScope? scope]) { ... }
}
```

The singleton cache stores segments indefinitely with no time-to-live. If a user adds a member, edits a relationship, or another device modifies data, the cache returns stale graph data until `clear()` is explicitly called. There is also no upper bound on cache size — for apps with multi-clan access, every visited clan adds another entry that is never evicted.

**Recommended Fix:**
- Add a `DateTime _cachedAt` field to each entry.
- Evict entries older than a configurable TTL (e.g., 5 minutes) on `read()`.
- Call `cache.clear(scope)` after any successful member save or relationship change.

---

### 🟠 MED-05 — Push Notification Service Re-Registers on Session Change Without Debounce

**File:** `lib/features/notifications/services/push_notification_service.dart`
**Caller:** `lib/app/home/app_shell_page.dart` — `didUpdateWidget`

**Problem:**

`AppShellPage.didUpdateWidget` calls `_pushNotificationService.start(session: _session, ...)` whenever `widget.session != oldWidget.session`. `start()` calls:
1. `messaging.requestPermission(...)` — system permission dialog or check
2. `messaging.getToken()` — FCM server request
3. `_registerToken()` → Firestore write to register device token

This full sequence re-executes on every session refresh even if the underlying FCM token hasn't changed. The service already has a `_activeRegistrationContext` equality guard, which is good — but `requestPermission` is still called unconditionally before the guard check (line 158), incurring a syscall on every session update.

**Recommended Fix:**
Move the `_activeRegistrationContext` equality check to the top of `start()` — **before** any I/O including `requestPermission` — so that re-entry with an identical context is a complete no-op.

---

### 🟠 MED-06 — `resolveAutoRoleForDraft()` Does Multiple Full O(n) Passes

**File:** `lib/features/member/presentation/member_controller.dart` (lines 336–372)

**Problem:**

```dart
String resolveAutoRoleForDraft(MemberDraft draft) {
  final normalizedRoles = _members               // O(n) map
      .map((member) => GovernanceRoleMatrix.normalizeRole(member.primaryRole))
      .toSet();
  final hasClanLeadership = normalizedRoles.any(...);  // O(k)

  if (resolvedBranchId != null && resolvedBranchId.isNotEmpty) {
    final hasBranchAdmin = _members.any(          // second O(n) scan
      (member) =>
          member.branchId == resolvedBranchId && ...
    );
  }
  ...
}
```

This function is called interactively (while the user fills in a member creation form). For large clans (hundreds of members), it allocates a full role set and performs two linear scans on each call. The role set could be pre-computed and cached when `_members` changes.

---

## 3. Low Priority Optimizations

### 🟡 LOW-01 — Missing `const` Constructors on Leaf Widgets

**Scope:** Various widget files in `lib/features/*/presentation/`

Flutter's tree-diffing algorithm skips subtrees rooted at `const` widgets entirely during rebuilds. Several leaf widgets (static icon rows, label containers, empty state placeholders) are constructed with `new` implicitly where `const` would be valid. Adding `const` to these constructors reduces rebuild work.

**Action:** Run `flutter analyze` with the `prefer_const_constructors` lint rule enabled and resolve all warnings.

---

### 🟡 LOW-02 — Lunar Conversion Engine on Main Isolate

**File:** `lib/features/calendar/services/lunar_conversion_engine.dart`

The dual-calendar feature includes a custom lunar-to-solar conversion engine. Depending on the algorithm complexity (table lookups, iterative calculations), this could block the UI thread during calendar initialisation or date range computation. For date ranges longer than a single month, consider offloading to a background isolate using `compute()` or `Isolate.run()`.

---

### 🟡 LOW-03 — `pdf` and `printing` Packages Increase Binary Size

**File:** `pubspec.yaml`

```yaml
pdf: ^3.11.3
printing: ^5.14.2
```

These packages add significant binary size overhead and are only needed for a specific export feature. If PDF generation is triggered from a single screen, consider loading these lazily using deferred imports (`import 'package:pdf/pdf.dart' deferred as pdfLib`) or moving the feature to a Cloud Function that generates the PDF server-side.

---

### 🟡 LOW-04 — `geolocator` / `geocoding` Loaded at App Start

**File:** `pubspec.yaml`

```yaml
geolocator: ^14.0.2
geocoding: ^4.0.0
```

GPS and geocoding plugins register platform channels and may initialise native SDKs at startup. If address lookup is only used in the member editor (an infrequently visited screen), these should be initialised lazily (first call to the address field) rather than at app boot time to reduce startup cost.

---

### 🟡 LOW-05 — `SharedPrefsAuthSessionStore` Instantiated Inline in `AppShellPage`

**File:** `lib/app/home/app_shell_page.dart` (line 89)

```dart
final AuthSessionStore _sessionStore = SharedPrefsAuthSessionStore();
```

`SharedPrefsAuthSessionStore` is instantiated directly in the widget's field initialiser, which runs during widget construction (not `initState`). This may block the constructor on Android where `SharedPreferences` performs a synchronous disk read during the first instantiation. Pass the store as a constructor argument or initialise it in `initState` asynchronously.

---

### 🟡 LOW-06 — App Startup: Firebase App Check Activation Is Synchronous in Bootstrap

**File:** `lib/app/bootstrap/app_bootstrap.dart`

Firebase App Check activation can take 200–800 ms on first install (especially on Android with Play Integrity). Currently it blocks the `initialize()` method synchronously (within the measured `bootstrap.firebase_initialize` metric). Consider activating App Check with a short timeout and continuing bootstrap if it times out, falling back gracefully.

---

## 4. Architecture Recommendations

### AR-01 — Shared Clan Data Cache

**Problem:** `members` and `branches` are downloaded independently by Member, Genealogy, Event, Fund, and Scholarship repositories.

**Solution:** Introduce a `ClanDataCache` singleton (or injectable service) that holds the last-fetched `members`, `branches`, and `relationships` snapshots with a TTL. All repositories hydrate from this cache instead of issuing independent Firestore reads.

```
AppShellPage
    └── ClanDataCache (injected, one instance per session)
          ├── MemberRepository    → reads from cache
          ├── GenealogyRepository → reads from cache
          ├── EventRepository     → reads member names from cache
          └── ScholarshipRepository → reads member data from cache
```

---

### AR-02 — Session Synchronisation as a One-Time Init Step

**Problem:** `FirebaseSessionAccessSync.ensureUserSessionDocument()` is called before every repository operation, generating redundant `getIdToken` and Firestore writes.

**Solution:** Move `ensureUserSessionDocument()` to be called **once** in `AppBootstrap` or during post-login session finalisation in `AuthController`. Maintain a `_synced: Set<String>` keyed on `session.uid` so re-entry after a session change re-syncs once, not on every query.

---

### AR-03 — Offline-First Strategy with Firestore Persistence

**Problem:** The app makes live Firestore reads on every load with no offline fallback.

**Solution:** Enable Firestore offline persistence (already supported by the `cloud_firestore` package). On load, use `source: Source.cache` for the initial render, then `source: Source.server` for a background refresh with a UI diff update. This makes the app feel instant even on poor connections.

```dart
// Fast initial render from cache
final cached = await _members
    .where('clanId', isEqualTo: clanId)
    .get(const GetOptions(source: Source.cache));

// Background server refresh
unawaited(_members
    .where('clanId', isEqualTo: clanId)
    .get(const GetOptions(source: Source.server))
    .then((fresh) => _updateMembers(fresh)));
```

---

### AR-04 — Pagination for Member and Transaction Lists

**Problem:** All members and up to 400 transactions are loaded into memory at once.

**Solution:**
- Use Firestore cursor-based pagination (`startAfterDocument`) for member lists (e.g., 50 per page).
- Use `MemberWorkspacePage`'s existing `_memberBatchSize = 20` virtual scroll as the display layer, but back it with server-side pagination so the full collection is not downloaded.
- For transactions, reduce the default limit from 400 to 50 and add infinite scroll with `startAfterDocument(lastDoc)`.

---

### AR-05 — Extract `AppShellPage` into Composable Sub-Widgets

**Problem:** The 1700-line monolithic shell causes unnecessary rebuilds.

**Solution:**
```
AppShellPage (thin coordinator)
├── _AdBannerController (StatefulWidget, self-managed timer)
├── _ClanContextSwitcher (StatefulWidget)
├── _NotificationDeepLinkHandler (StatefulWidget)
└── IndexedStack
    ├── RepaintBoundary → MemberWorkspacePage
    ├── RepaintBoundary → GenealogyWorkspacePage
    ├── RepaintBoundary → EventWorkspacePage
    ├── RepaintBoundary → BillingWorkspacePage
    └── RepaintBoundary → ProfileWorkspacePage
```

---

## 5. Code Examples

### CE-01 — Session Sync Guard with Per-Session Cache

```dart
// lib/core/services/firebase_session_access_sync.dart

class FirebaseSessionAccessSync {
  FirebaseSessionAccessSync._();

  // Cache of UIDs that have been synced in this app lifecycle.
  static final Set<String> _syncedUids = {};

  static Future<void> ensureUserSessionDocument({
    required FirebaseFirestore firestore,
    required AuthSession session,
    FirebaseAuth? auth,
    bool forceRefresh = false,  // pass true only after role changes
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) return;

    // Skip if already synced in this session and no force refresh.
    if (!forceRefresh && _syncedUids.contains(uid)) return;

    final claims = await _resolveClaims(auth);
    // ... rest of existing logic unchanged ...

    await firestore.collection('users').doc(uid).set({
      // ... existing payload ...
    }, SetOptions(merge: true));

    _syncedUids.add(uid);  // Mark as synced
  }

  /// Call this when the session is invalidated (logout).
  static void invalidate(String uid) => _syncedUids.remove(uid);
}
```

---

### CE-02 — Safe Transaction Fallback with Limit

```dart
// lib/features/funds/services/firebase_fund_repository.dart

Future<QuerySnapshot<Map<String, dynamic>>> _loadTransactionSnapshot({
  required String clanId,
  int limit = 400,
}) async {
  final baseQuery = _transactions.where('clanId', isEqualTo: clanId);
  try {
    return await baseQuery
        .orderBy('occurredAt', descending: true)
        .limit(limit)
        .get();
  } on FirebaseException catch (error) {
    if (!_isIndexError(error)) rethrow;
    // Index missing — report it and still apply the limit to prevent OOM.
    AppLogger.warning(
      'Firestore composite index missing for transactions. '
      'Falling back to unordered query with limit $limit.',
    );
    // IMPORTANT: apply limit on fallback to prevent unbounded download.
    return await baseQuery.limit(limit).get();
  }
}
```

---

### CE-03 — Android Release Build with R8

```kotlin
// mobile/befam/android/app/build.gradle.kts

android {
    buildTypes {
        release {
            isMinifyEnabled = true          // Enable R8 code shrinking
            isShrinkResources = true        // Remove unused resources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // signingConfig = signingConfigs.getByName("release")  // Use a real keystore
        }
        debug {
            isMinifyEnabled = false
        }
    }
}
```

```pro
# mobile/befam/android/app/proguard-rules.pro

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Dart/Flutter generated
-keep class com.familyclanapp.befam.** { *; }

# Freezed / json_serializable
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
```

---

### CE-04 — Cached Network Image for Avatars

```dart
// pubspec.yaml — add dependency
// cached_network_image: ^3.3.1

// Before (no caching):
Image.network(
  avatarUrl,
  width: 48,
  height: 48,
  fit: BoxFit.cover,
)

// After (with disk + memory cache):
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: avatarUrl,
  width: 48,
  height: 48,
  fit: BoxFit.cover,
  memCacheWidth: 96,    // 2× logical pixels for HiDPI
  memCacheHeight: 96,
  placeholder: (context, url) => const CircleAvatar(
    backgroundColor: Colors.grey,
    child: Icon(Icons.person, color: Colors.white),
  ),
  errorWidget: (context, url, error) => const CircleAvatar(
    child: Icon(Icons.person_outline),
  ),
)
```

---

### CE-05 — Genealogy Cache With TTL

```dart
// lib/features/genealogy/services/genealogy_segment_cache.dart

class _CacheEntry {
  const _CacheEntry({required this.segment, required this.cachedAt});
  final GenealogyReadSegment segment;
  final DateTime cachedAt;
}

class GenealogySegmentCache {
  GenealogySegmentCache._();
  static final GenealogySegmentCache _shared = GenealogySegmentCache._();
  factory GenealogySegmentCache.shared() => _shared;

  static const Duration _ttl = Duration(minutes: 5);
  final Map<String, _CacheEntry> _entries = {};

  GenealogyReadSegment? read(GenealogyScope scope) {
    final entry = _entries[scope.cacheKey];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      _entries.remove(scope.cacheKey);  // Evict stale entry
      return null;
    }
    return entry.segment.copyWith(fromCache: true);
  }

  void write(GenealogyReadSegment segment) {
    _entries[segment.scope.cacheKey] = _CacheEntry(
      segment: segment.copyWith(fromCache: false),
      cachedAt: DateTime.now(),
    );
  }

  void clear([GenealogyScope? scope]) {
    if (scope == null) {
      _entries.clear();
    } else {
      _entries.remove(scope.cacheKey);
    }
  }
}
```

---

### CE-06 — `RepaintBoundary` Around Workspace Tabs

```dart
// lib/app/home/app_shell_page.dart

// Wrap each tab body in RepaintBoundary so tab switching doesn't repaint
// pages that are not currently visible.
IndexedStack(
  index: _selectedIndex,
  children: [
    RepaintBoundary(
      child: _visitedDestinationIndexes.contains(0)
          ? MemberWorkspacePage(session: _session, ...)
          : const SizedBox.shrink(),
    ),
    RepaintBoundary(
      child: _visitedDestinationIndexes.contains(1)
          ? GenealogyWorkspacePage(session: _session, ...)
          : const SizedBox.shrink(),
    ),
    // ... repeat for all tabs
  ],
)
```

---

### CE-07 — Offline-First Firestore Load Pattern

```dart
// lib/features/member/services/firebase_member_repository.dart

@override
Future<MemberWorkspaceSnapshot> loadWorkspace({
  required AuthSession session,
}) async {
  final clanId = session.clanId;
  if (clanId == null || clanId.isEmpty) {
    return const MemberWorkspaceSnapshot(members: [], branches: []);
  }

  // 1. Serve stale-while-revalidate: try cache first
  try {
    final cachedResults = await Future.wait([
      _members.where('clanId', isEqualTo: clanId)
          .get(const GetOptions(source: Source.cache)),
      _branches.where('clanId', isEqualTo: clanId)
          .get(const GetOptions(source: Source.cache)),
    ]);
    if (cachedResults[0].docs.isNotEmpty) {
      return _buildSnapshot(cachedResults[0], cachedResults[1]);
    }
  } catch (_) {
    // Cache miss — fall through to server fetch
  }

  // 2. Network fetch with pagination
  final results = await Future.wait([
    _members.where('clanId', isEqualTo: clanId)
        .orderBy('fullName')
        .limit(200)              // Paginate large clans
        .get(),
    _branches.where('clanId', isEqualTo: clanId).get(),
  ]);
  return _buildSnapshot(results[0], results[1]);
}
```

---

## 6. Performance Profiling Guide

### Flutter DevTools

```bash
# Launch app in profile mode (never debug mode for perf measurement)
flutter run --profile

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

Key DevTools tabs to use for this app:

| Tab | What to measure |
|---|---|
| **Performance** | Frame render times, jank (>16 ms frames), CPU/GPU flame chart |
| **Memory** | Heap growth over time, detect leaks after navigation |
| **Network** | Firestore HTTP/2 calls, response sizes, timing |
| **Logging** | `PerformanceMeasurementLogger` output, slow threshold warnings |

### Flutter Performance Overlay

```dart
// lib/app/app.dart — enable in debug/profile builds
MaterialApp(
  showPerformanceOverlay: !kReleaseMode,  // top bar = GPU, bottom bar = CPU
  // ...
)
```

Red bars indicate frames that exceed 16 ms (60 fps budget). Focus on:
- Tab switch from Member → Genealogy (CRIT-03 duplicate reads visible here)
- First load after login (CRIT-01 session sync latency visible here)
- Scrolling the member list (repaint cost visible here)

### Dart Timeline Events

```dart
// Wrap critical operations for Timeline visibility in DevTools
import 'dart:developer' as developer;

Future<MemberWorkspaceSnapshot> loadWorkspace({...}) async {
  developer.Timeline.startSync('MemberRepository.loadWorkspace');
  try {
    // ... existing code
  } finally {
    developer.Timeline.finishSync();
  }
}
```

### Firebase Performance Monitoring

Add `firebase_performance` to `pubspec.yaml` for automatic HTTP trace and screen render tracking:

```yaml
firebase_performance: ^0.10.0
```

Instrument critical user flows:

```dart
import 'package:firebase_performance/firebase_performance.dart';

final trace = FirebasePerformance.instance.newTrace('load_clan_workspace');
await trace.start();
try {
  await _repository.loadWorkspace(session: session);
} finally {
  await trace.stop();
}
```

This captures P50/P95/P99 load times per country, device tier, and OS version in the Firebase Console.

### Recommended Profiling Sequence

1. **Baseline**: Run `flutter run --profile`, open DevTools Memory tab, record 10-minute session navigating all tabs. Capture heap snapshot.
2. **After CRIT-01 fix**: Measure round-trip time for `loadWorkspace` — expect 200–600 ms reduction per load.
3. **After CRIT-02 fix**: Measure `members` collection read size in DevTools Network tab. Should reduce by >50% after adding `.limit(200)`.
4. **After CRIT-03 fix**: Confirm `members` and `branches` are fetched only once on the first tab load via DevTools Network.
5. **After MED-03 fix**: Enable Performance Overlay. Tab switching should produce 0 red frames once `RepaintBoundary` wraps each workspace.

---

## Summary Table

| ID | Severity | Area | Effort | Impact |
|---|---|---|---|---|
| CRIT-01 | 🔴 Critical | Firebase / Network | Medium | Removes 2 network ops per query |
| CRIT-02 | 🔴 Critical | Firestore | Medium | Reduces data transferred by 50–90% |
| CRIT-03 | 🔴 Critical | Firestore | Medium | Halves read cost on startup |
| CRIT-04 | 🔴 Critical | Firestore | Low | Prevents unbounded OOM read |
| CRIT-05 | 🔴 Critical | Build Config | Low | Smaller APK, proper release signing |
| MED-01 | 🟠 Medium | Flutter Rendering | Low | Reduces CPU on rebuilds |
| MED-02 | 🟠 Medium | Memory / Network | Low | Avoids redundant image downloads |
| MED-03 | 🟠 Medium | Flutter Rendering | High | Eliminates shell-wide rebuilds |
| MED-04 | 🟠 Medium | Data Integrity | Low | Prevents stale graph data |
| MED-05 | 🟠 Medium | Firebase | Low | Removes redundant FCM re-registration |
| MED-06 | 🟠 Medium | CPU | Low | Reduces O(n) work on user input |
| LOW-01 | 🟡 Low | Flutter Rendering | Low | Micro-optimisation on rebuilds |
| LOW-02 | 🟡 Low | CPU | Medium | Keeps UI thread free |
| LOW-03 | 🟡 Low | Binary Size | Low | Reduces APK/IPA size |
| LOW-04 | 🟡 Low | Startup Time | Low | Faster cold start |
| LOW-05 | 🟡 Low | Startup Time | Low | Non-blocking constructor |
| LOW-06 | 🟡 Low | Startup Time | Low | Faster bootstrap |
| AR-01 | Architecture | Data Layer | High | Eliminates duplicate reads system-wide |
| AR-02 | Architecture | Auth/Firebase | Medium | Centralises session sync |
| AR-03 | Architecture | Offline UX | High | Instant perceived load time |
| AR-04 | Architecture | Firestore | High | Scalable data loading |
| AR-05 | Architecture | Flutter | High | Surgical rebuilds, clean separation |
