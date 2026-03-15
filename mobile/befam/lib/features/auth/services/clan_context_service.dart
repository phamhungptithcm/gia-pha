import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firebase_services.dart';
import '../models/auth_member_access_mode.dart';
import '../models/auth_session.dart';
import '../models/clan_context_option.dart';

class ClanContextSnapshot {
  const ClanContextSnapshot({
    required this.activeSession,
    required this.contexts,
  });

  final AuthSession activeSession;
  final List<ClanContextOption> contexts;
}

abstract interface class ClanContextService {
  Future<ClanContextSnapshot> loadContexts({
    required AuthSession session,
  });

  Future<ClanContextSnapshot> switchActiveClan({
    required AuthSession session,
    required String clanId,
  });
}

class DebugClanContextService implements ClanContextService {
  const DebugClanContextService();

  @override
  Future<ClanContextSnapshot> loadContexts({
    required AuthSession session,
  }) async {
    final hasClan = (session.clanId ?? '').trim().isNotEmpty;
    final contexts = hasClan
        ? [
            ClanContextOption(
              clanId: session.clanId!.trim(),
              clanName: session.clanId!.trim(),
              memberId: (session.memberId ?? '').trim(),
              branchId: (session.branchId ?? '').trim().isEmpty
                  ? null
                  : session.branchId!.trim(),
              primaryRole: (session.primaryRole ?? 'MEMBER').trim().isEmpty
                  ? 'MEMBER'
                  : session.primaryRole!.trim().toUpperCase(),
              displayName: session.displayName,
            ),
          ]
        : const <ClanContextOption>[];

    return ClanContextSnapshot(activeSession: session, contexts: contexts);
  }

  @override
  Future<ClanContextSnapshot> switchActiveClan({
    required AuthSession session,
    required String clanId,
  }) {
    return loadContexts(session: session);
  }
}

class FirebaseClanContextService implements ClanContextService {
  FirebaseClanContextService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _functions = functions ?? FirebaseServices.functions,
       _auth = auth ?? FirebaseServices.auth;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<ClanContextSnapshot> loadContexts({
    required AuthSession session,
  }) async {
    if (session.isSandbox) {
      return const DebugClanContextService().loadContexts(session: session);
    }
    final result = await _functions
        .httpsCallable('listUserClanContexts')
        .call(<String, dynamic>{});
    return _parseSnapshot(baseSession: session, raw: result.data);
  }

  @override
  Future<ClanContextSnapshot> switchActiveClan({
    required AuthSession session,
    required String clanId,
  }) async {
    if (session.isSandbox) {
      return const DebugClanContextService().switchActiveClan(
        session: session,
        clanId: clanId,
      );
    }
    final result = await _functions
        .httpsCallable('switchActiveClanContext')
        .call(<String, dynamic>{'clanId': clanId.trim()});
    await _auth.currentUser?.getIdToken(true);
    return _parseSnapshot(baseSession: session, raw: result.data);
  }

  ClanContextSnapshot _parseSnapshot({
    required AuthSession baseSession,
    required Object? raw,
  }) {
    final payload = _asMap(raw);
    final contexts = _asList(payload['contexts'])
        .map((item) => _parseContext(_asMap(item)))
        .where((item) => item.normalizedClanId.isNotEmpty)
        .toList(growable: false);
    final activeClanId = _stringOrNull(payload['activeClanId']);
    ClanContextOption? active;
    if (activeClanId != null) {
      for (final item in contexts) {
        if (item.clanId.trim() == activeClanId) {
          active = item;
          break;
        }
      }
    }
    active ??= contexts.isEmpty ? null : contexts.first;

    if (active == null) {
      return ClanContextSnapshot(
        activeSession: baseSession.copyWith(
          clanId: null,
          memberId: null,
          branchId: null,
          primaryRole: 'GUEST',
          accessMode: AuthMemberAccessMode.unlinked,
          linkedAuthUid: false,
        ),
        contexts: const [],
      );
    }

    return ClanContextSnapshot(
      activeSession: baseSession.copyWith(
        clanId: active.clanId,
        memberId: active.memberId,
        branchId: active.branchId,
        primaryRole: active.primaryRole,
        displayName: (active.displayName?.trim().isNotEmpty ?? false)
            ? active.displayName!.trim()
            : baseSession.displayName,
        accessMode: AuthMemberAccessMode.claimed,
        linkedAuthUid: true,
      ),
      contexts: contexts,
    );
  }

  ClanContextOption _parseContext(Map<String, dynamic> map) {
    return ClanContextOption(
      clanId: _stringOrNull(map['clanId']) ?? '',
      clanName: _stringOrNull(map['clanName']) ?? '',
      memberId: _stringOrNull(map['memberId']) ?? '',
      primaryRole: (_stringOrNull(map['primaryRole']) ?? 'MEMBER').toUpperCase(),
      branchId: _stringOrNull(map['branchId']),
      displayName: _stringOrNull(map['displayName']),
      status: _stringOrNull(map['status']),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }

  List<Object?> _asList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value;
  }

  String? _stringOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

ClanContextService createDefaultClanContextService({AuthSession? session}) {
  if (session?.isSandbox == true) {
    return const DebugClanContextService();
  }
  return FirebaseClanContextService();
}
