import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/auth/models/clan_context_option.dart';
import 'package:befam/features/auth/services/clan_context_service.dart';

class DebugClanContextService implements ClanContextService {
  const DebugClanContextService();

  @override
  Future<ClanContextSnapshot> loadContexts({
    required AuthSession session,
  }) async {
    final contexts = _buildContexts(session);
    final active = _resolveActiveContext(session, contexts);
    if (active == null) {
      return ClanContextSnapshot(
        activeSession: session.copyWith(
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
      activeSession: _sessionFromContext(session, active),
      contexts: contexts,
    );
  }

  @override
  Future<ClanContextSnapshot> switchActiveClan({
    required AuthSession session,
    required String clanId,
  }) async {
    final contexts = _buildContexts(session);
    final normalizedClanId = clanId.trim();
    ClanContextOption? active;
    for (final context in contexts) {
      if (context.normalizedClanId == normalizedClanId) {
        active = context;
        break;
      }
    }
    if (active == null) {
      return loadContexts(session: session);
    }
    return ClanContextSnapshot(
      activeSession: _sessionFromContext(session, active),
      contexts: contexts,
    );
  }

  List<ClanContextOption> _buildContexts(AuthSession session) {
    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty ||
        session.accessMode == AuthMemberAccessMode.unlinked ||
        (session.primaryRole ?? '').trim().toUpperCase() == 'GUEST') {
      return const [];
    }

    final role = (session.primaryRole ?? 'MEMBER').trim().toUpperCase();
    final normalizedMemberId = (session.memberId ?? '').trim();
    final memberId = normalizedMemberId.isNotEmpty
        ? normalizedMemberId
        : 'member_bootstrap_${clanId.replaceAll('-', '_')}';
    final displayName = session.displayName.trim();

    if (clanId == 'clan_demo_001') {
      return [
        ClanContextOption(
          clanId: 'clan_demo_001',
          clanName: 'Gia phả demo',
          memberId: memberId,
          primaryRole: role,
          branchId: session.branchId,
          displayName: displayName.isEmpty ? null : displayName,
        ),
        ClanContextOption(
          clanId: 'clan_demo_002',
          clanName: 'Gia phả vệ tinh',
          memberId: memberId,
          primaryRole: role,
          branchId: session.branchId,
          displayName: displayName.isEmpty ? null : displayName,
        ),
      ];
    }

    return [
      ClanContextOption(
        clanId: clanId,
        clanName: 'Gia phả thử nghiệm',
        memberId: memberId,
        primaryRole: role,
        branchId: session.branchId,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    ];
  }

  ClanContextOption? _resolveActiveContext(
    AuthSession session,
    List<ClanContextOption> contexts,
  ) {
    final activeClanId = (session.clanId ?? '').trim();
    if (activeClanId.isNotEmpty) {
      for (final context in contexts) {
        if (context.normalizedClanId == activeClanId) {
          return context;
        }
      }
    }
    if (contexts.isEmpty) {
      return null;
    }
    return contexts.first;
  }

  AuthSession _sessionFromContext(AuthSession base, ClanContextOption active) {
    final displayName = (active.displayName ?? '').trim();
    return base.copyWith(
      clanId: active.clanId,
      memberId: active.memberId,
      branchId: active.branchId,
      primaryRole: active.primaryRole,
      displayName: displayName.isEmpty ? base.displayName : displayName,
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    );
  }
}
