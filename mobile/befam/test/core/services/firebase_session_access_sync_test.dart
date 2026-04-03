import 'dart:async';

import 'package:befam/core/services/firebase_session_access_sync.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FirebaseSessionAccessSync.resetForTest);
  tearDown(FirebaseSessionAccessSync.resetForTest);

  test('deduplicates concurrent syncs for the same user session', () async {
    final session = _buildSession();
    final claimsCompleter = Completer<Map<String, dynamic>?>();
    var claimCalls = 0;
    var writeCalls = 0;

    final first = FirebaseSessionAccessSync.ensureUserSessionDocument(
      session: session,
      claimsResolver: (_) async {
        claimCalls += 1;
        return claimsCompleter.future;
      },
      sessionWriter: (uid, payload) async {
        expect(uid, isNotEmpty);
        expect(payload, isNotEmpty);
        writeCalls += 1;
      },
    );
    final second = FirebaseSessionAccessSync.ensureUserSessionDocument(
      session: session,
      claimsResolver: (_) async {
        claimCalls += 1;
        return claimsCompleter.future;
      },
      sessionWriter: (uid, payload) async {
        expect(uid, isNotEmpty);
        expect(payload, isNotEmpty);
        writeCalls += 1;
      },
    );

    await pumpEventQueue();
    expect(claimCalls, 1);

    claimsCompleter.complete(_buildClaims());
    await Future.wait<void>([first, second]);

    expect(writeCalls, 1);
  });

  test('reuses cached claims within ttl for repeated sync attempts', () async {
    final session = _buildSession();
    var now = DateTime(2026, 1, 1, 10);
    var claimCalls = 0;
    var writeCalls = 0;

    Future<Map<String, dynamic>?> resolveClaims(Object? _) async {
      claimCalls += 1;
      return _buildClaims();
    }

    Future<void> writeSession(String uid, Map<String, dynamic> payload) async {
      expect(uid, isNotEmpty);
      expect(payload, isNotEmpty);
      writeCalls += 1;
    }

    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      session: session,
      claimsResolver: (_) => resolveClaims(null),
      sessionWriter: writeSession,
      nowProvider: () => now,
    );

    now = now.add(const Duration(seconds: 30));

    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      session: session,
      claimsResolver: (_) => resolveClaims(null),
      sessionWriter: writeSession,
      nowProvider: () => now,
    );

    expect(claimCalls, 1);
    expect(writeCalls, 1);
  });
}

AuthSession _buildSession() {
  return const AuthSession(
    uid: 'user-1',
    loginMethod: AuthEntryMethod.phone,
    phoneE164: '+84901234567',
    displayName: 'Test User',
    memberId: 'member-1',
    clanId: 'clan-1',
    branchId: 'branch-1',
    primaryRole: 'member',
    linkedAuthUid: true,
    signedInAtIso: '2026-01-01T10:00:00.000Z',
  );
}

Map<String, dynamic> _buildClaims() {
  return <String, dynamic>{
    'memberId': 'member-1',
    'clanId': 'clan-1',
    'clanIds': const ['clan-1'],
    'branchId': 'branch-1',
    'primaryRole': 'member',
    'memberAccessMode': 'linked',
  };
}
