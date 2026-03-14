import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
import '../../member/models/member_profile.dart';
import '../models/genealogy_read_segment.dart';
import '../models/genealogy_root_entry.dart';
import '../models/genealogy_scope.dart';
import '../services/genealogy_graph_algorithms.dart';
import '../services/genealogy_read_repository.dart';

class GenealogyWorkspacePage extends StatefulWidget {
  const GenealogyWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
  });

  final AuthSession session;
  final GenealogyReadRepository repository;

  @override
  State<GenealogyWorkspacePage> createState() => _GenealogyWorkspacePageState();
}

class _GenealogyWorkspacePageState extends State<GenealogyWorkspacePage> {
  late GenealogyScopeType _scopeType;
  GenealogyReadSegment? _segment;
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scopeType = _resolveInitialScope(widget.session);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading && _segment == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _segment == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.genealogyLoadFailed,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _load(allowCached: false),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.genealogyRefreshAction),
              ),
            ],
          ),
        ),
      );
    }

    final segment = _segment!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final focusMember = _resolveFocusMember(segment);
    final ancestryPath = focusMember == null
        ? const <String>[]
        : GenealogyGraphAlgorithms.buildAncestryPath(
            graph: segment.graph,
            memberId: focusMember.id,
          );
    final descendants = focusMember == null
        ? const <String>[]
        : GenealogyGraphAlgorithms.buildDescendantsTraversal(
            graph: segment.graph,
            memberId: focusMember.id,
          );

    return RefreshIndicator(
      onRefresh: () => _load(allowCached: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.genealogyWorkspaceTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.genealogyWorkspaceDescription,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      key: const Key('genealogy-scope-clan'),
                      label: Text(l10n.genealogyScopeClan),
                      selected: _scopeType == GenealogyScopeType.clan,
                      onSelected: (_) => _updateScope(GenealogyScopeType.clan),
                    ),
                    if (widget.session.branchId != null &&
                        widget.session.branchId!.isNotEmpty)
                      ChoiceChip(
                        key: const Key('genealogy-scope-branch'),
                        label: Text(l10n.genealogyScopeBranch),
                        selected: _scopeType == GenealogyScopeType.branch,
                        onSelected: (_) =>
                            _updateScope(GenealogyScopeType.branch),
                      ),
                    ActionChip(
                      avatar: Icon(
                        segment.fromCache ? Icons.bolt_outlined : Icons.cloud_done,
                        size: 18,
                      ),
                      label: Text(
                        segment.fromCache
                            ? l10n.genealogyFromCache
                            : l10n.genealogyLiveData,
                      ),
                      onPressed: null,
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isLoading
                          ? null
                          : () => _load(allowCached: false),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.genealogyRefreshAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                key: Key('genealogy-summary-members-${segment.members.length}'),
                title: l10n.genealogySummaryMembers,
                value: '${segment.members.length}',
              ),
              _SummaryCard(
                key: Key(
                  'genealogy-summary-relationships-${segment.relationships.length}',
                ),
                title: l10n.genealogySummaryRelationships,
                value: '${segment.relationships.length}',
              ),
              _SummaryCard(
                key: Key('genealogy-summary-roots-${segment.rootEntries.length}'),
                title: l10n.genealogySummaryRoots,
                value: '${segment.rootEntries.length}',
              ),
              _SummaryCard(
                key: Key('genealogy-summary-scope-${segment.scope.type.name}'),
                title: l10n.genealogySummaryScope,
                value: _scopeLabel(l10n, segment.scope.type),
              ),
            ],
          ),
          if (focusMember != null) ...[
            const SizedBox(height: 24),
            Text(
              l10n.genealogyFocusMemberTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focusMember.fullName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _FactChip(
                          icon: Icons.layers_outlined,
                          label:
                              '${l10n.genealogyGenerationLabel}: ${segment.graph.generationLabels[focusMember.id]?.compactLabel ?? 'G${focusMember.generation}'}',
                        ),
                        _FactChip(
                          icon: Icons.family_restroom_outlined,
                          label:
                              '${l10n.genealogySiblingCountLabel}: ${segment.graph.siblingsOf(focusMember.id).length}',
                        ),
                        _FactChip(
                          icon: Icons.south_outlined,
                          label:
                              '${l10n.genealogyDescendantCountLabel}: ${descendants.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.genealogyAncestryPathTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ancestryPath.isEmpty
                          ? focusMember.fullName
                          : ancestryPath
                              .map(
                                (memberId) =>
                                    segment.graph.membersById[memberId]?.displayName ??
                                    memberId,
                              )
                              .join(' -> '),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.genealogyRootEntriesTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (segment.rootEntries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.genealogyNoRootEntries),
              ),
            )
          else
            ...segment.rootEntries.map(
              (entry) => _RootEntryCard(
                key: Key('genealogy-root-entry-${entry.memberId}'),
                entry: entry,
                member: segment.graph.membersById[entry.memberId]!,
                siblingCount: segment.graph.siblingsOf(entry.memberId).length,
                labelForReason: (reason) => _rootReasonLabel(l10n, reason),
                generationLabel:
                    segment.graph.generationLabels[entry.memberId]?.compactLabel ??
                    'G${segment.graph.membersById[entry.memberId]!.generation}',
              ),
            ),
          const SizedBox(height: 24),
          Text(
            l10n.genealogyMemberStructureTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (segment.members.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.genealogyEmptyStateTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.genealogyEmptyStateDescription),
                  ],
                ),
              ),
            )
          else
            ...segment.members.take(8).map(
              (member) => Card(
                child: ListTile(
                  key: Key('genealogy-member-${member.id}'),
                  leading: CircleAvatar(child: Text(member.initials)),
                  title: Text(member.fullName),
                  subtitle: Text(
                    [
                      '${l10n.genealogyGenerationLabel}: ${segment.graph.generationLabels[member.id]?.compactLabel ?? 'G${member.generation}'}',
                      '${l10n.genealogyParentCountLabel}: ${segment.graph.parentsOf(member.id).length}',
                      '${l10n.genealogyChildCountLabel}: ${segment.graph.childrenOf(member.id).length}',
                      '${l10n.genealogySpouseCountLabel}: ${segment.graph.spousesOf(member.id).length}',
                      '${l10n.genealogySiblingCountLabel}: ${segment.graph.siblingsOf(member.id).length}',
                    ].join(' • '),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _load({bool allowCached = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final segment = _scopeType == GenealogyScopeType.clan
          ? await widget.repository.loadClanSegment(
              session: widget.session,
              allowCached: allowCached,
            )
          : await widget.repository.loadBranchSegment(
              session: widget.session,
              allowCached: allowCached,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _segment = segment;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _updateScope(GenealogyScopeType value) {
    if (_scopeType == value) {
      return;
    }

    setState(() {
      _scopeType = value;
    });
    unawaited(_load());
  }

  MemberProfile? _resolveFocusMember(GenealogyReadSegment segment) {
    final sessionMemberId = widget.session.memberId;
    if (sessionMemberId != null) {
      final sessionMember = segment.graph.membersById[sessionMemberId];
      if (sessionMember != null) {
        return sessionMember;
      }
    }

    if (segment.rootEntries.isNotEmpty) {
      return segment.graph.membersById[segment.rootEntries.first.memberId];
    }

    return segment.members.isEmpty ? null : segment.members.first;
  }

  GenealogyScopeType _resolveInitialScope(AuthSession session) {
    final role = session.primaryRole?.trim().toUpperCase();
    if (role == 'SUPER_ADMIN' || role == 'CLAN_ADMIN') {
      return GenealogyScopeType.clan;
    }
    if (session.branchId != null && session.branchId!.isNotEmpty) {
      return GenealogyScopeType.branch;
    }
    if (session.accessMode == AuthMemberAccessMode.claimed &&
        session.branchId != null &&
        session.branchId!.isNotEmpty) {
      return GenealogyScopeType.branch;
    }
    return GenealogyScopeType.clan;
  }

  String _scopeLabel(AppLocalizations l10n, GenealogyScopeType scopeType) {
    return switch (scopeType) {
      GenealogyScopeType.clan => l10n.genealogyScopeClan,
      GenealogyScopeType.branch => l10n.genealogyScopeBranch,
    };
  }

  String _rootReasonLabel(AppLocalizations l10n, GenealogyRootReason reason) {
    return switch (reason) {
      GenealogyRootReason.currentMember => l10n.genealogyRootReasonCurrentMember,
      GenealogyRootReason.clanRoot => l10n.genealogyRootReasonClanRoot,
      GenealogyRootReason.scopeRoot => l10n.genealogyRootReasonScopeRoot,
      GenealogyRootReason.branchLeader => l10n.genealogyRootReasonBranchLeader,
      GenealogyRootReason.branchViceLeader => l10n.genealogyRootReasonBranchViceLeader,
    };
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 156,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _RootEntryCard extends StatelessWidget {
  const _RootEntryCard({
    super.key,
    required this.entry,
    required this.member,
    required this.siblingCount,
    required this.labelForReason,
    required this.generationLabel,
  });

  final GenealogyRootEntry entry;
  final MemberProfile member;
  final int siblingCount;
  final String Function(GenealogyRootReason reason) labelForReason;
  final String generationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(member.initials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.genealogyGenerationLabel}: $generationLabel',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in entry.reasons)
                  Chip(label: Text(labelForReason(reason))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              [
                '${l10n.genealogyParentCountLabel}: ${member.parentIds.length}',
                '${l10n.genealogyChildCountLabel}: ${member.childrenIds.length}',
                '${l10n.genealogySpouseCountLabel}: ${member.spouseIds.length}',
                '${l10n.genealogySiblingCountLabel}: $siblingCount',
              ].join(' • '),
            ),
          ],
        ),
      ),
    );
  }
}
