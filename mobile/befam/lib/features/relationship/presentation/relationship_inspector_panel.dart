import 'package:flutter/material.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../member/models/member_profile.dart';
import '../models/relationship_record.dart';
import '../services/relationship_permissions.dart';
import '../services/relationship_repository.dart';

class RelationshipInspectorPanel extends StatefulWidget {
  const RelationshipInspectorPanel({
    super.key,
    required this.session,
    required this.member,
    required this.members,
    required this.repository,
    required this.onRelationshipsChanged,
  });

  final AuthSession session;
  final MemberProfile member;
  final List<MemberProfile> members;
  final RelationshipRepository repository;
  final Future<void> Function() onRelationshipsChanged;

  @override
  State<RelationshipInspectorPanel> createState() =>
      _RelationshipInspectorPanelState();
}

class _RelationshipInspectorPanelState
    extends State<RelationshipInspectorPanel> {
  late final RelationshipPermissions _permissions;

  bool _isLoading = true;
  bool _isMutating = false;
  RelationshipRepositoryErrorCode? _error;
  List<RelationshipRecord> _relationships = const [];

  @override
  void initState() {
    super.initState();
    _permissions = RelationshipPermissions.forSession(widget.session);
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final relationships = await widget.repository.loadRelationshipsForMember(
        session: widget.session,
        memberId: widget.member.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _relationships = relationships;
        _isLoading = false;
      });
    } on RelationshipRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.code;
        _isLoading = false;
      });
    }
  }

  Future<void> _createRelationship(_RelationshipAction action) async {
    final selectedMember = await _pickMemberForAction(action);
    if (selectedMember == null || !mounted) {
      return;
    }

    setState(() {
      _isMutating = true;
      _error = null;
    });

    try {
      switch (action) {
        case _RelationshipAction.parent:
          await widget.repository.createParentChildRelationship(
            session: widget.session,
            parentId: selectedMember.id,
            childId: widget.member.id,
          );
        case _RelationshipAction.child:
          await widget.repository.createParentChildRelationship(
            session: widget.session,
            parentId: widget.member.id,
            childId: selectedMember.id,
          );
        case _RelationshipAction.spouse:
          await widget.repository.createSpouseRelationship(
            session: widget.session,
            memberId: widget.member.id,
            spouseId: selectedMember.id,
          );
      }

      await widget.onRelationshipsChanged();
      await _loadRelationships();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            _RelationshipAction.parent =>
              context.l10n.relationshipParentAddedSuccess,
            _RelationshipAction.child =>
              context.l10n.relationshipChildAddedSuccess,
            _RelationshipAction.spouse =>
              context.l10n.relationshipSpouseAddedSuccess,
          }),
        ),
      );
    } on RelationshipRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.code;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<MemberProfile?> _pickMemberForAction(
    _RelationshipAction action,
  ) async {
    final excludedIds = switch (action) {
      _RelationshipAction.parent => {
        widget.member.id,
        ..._relatedIdsFor(
          _relationships.where(
            (relationship) =>
                relationship.type == RelationshipType.parentChild &&
                relationship.personBId == widget.member.id,
          ),
        ),
      },
      _RelationshipAction.child => {
        widget.member.id,
        ..._relatedIdsFor(
          _relationships.where(
            (relationship) =>
                relationship.type == RelationshipType.parentChild &&
                relationship.personAId == widget.member.id,
          ),
        ),
      },
      _RelationshipAction.spouse => {
        widget.member.id,
        ..._relatedIdsFor(
          _relationships.where(
            (relationship) => relationship.type == RelationshipType.spouse,
          ),
        ),
      },
    };

    final candidates =
        widget.members
            .where((candidate) => !excludedIds.contains(candidate.id))
            .where(
              (candidate) =>
                  _permissions.canMutateBetween(widget.member, candidate),
            )
            .toList(growable: false)
          ..sort((left, right) => left.fullName.compareTo(right.fullName));

    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.relationshipNoCandidates)),
        );
      }
      return null;
    }

    return showModalBottomSheet<MemberProfile>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        switch (action) {
                          _RelationshipAction.parent =>
                            context.l10n.relationshipPickParentTitle,
                          _RelationshipAction.child =>
                            context.l10n.relationshipPickChildTitle,
                          _RelationshipAction.spouse =>
                            context.l10n.relationshipPickSpouseTitle,
                        },
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return ListTile(
                      key: Key('relationship-candidate-${candidate.id}'),
                      title: Text(candidate.fullName),
                      subtitle: Text(
                        candidate.nickName.trim().isEmpty
                            ? candidate.branchId
                            : candidate.nickName,
                      ),
                      onTap: () => Navigator.of(context).pop(candidate),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final memberById = {for (final member in widget.members) member.id: member};
    final parentRelationships = _relationships
        .where(
          (relationship) =>
              relationship.type == RelationshipType.parentChild &&
              relationship.personBId == widget.member.id,
        )
        .toList(growable: false);
    final childRelationships = _relationships
        .where(
          (relationship) =>
              relationship.type == RelationshipType.parentChild &&
              relationship.personAId == widget.member.id,
        )
        .toList(growable: false);
    final spouseRelationships = _relationships
        .where((relationship) => relationship.type == RelationshipType.spouse)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.relationshipInspectorTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.relationshipInspectorDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: l10n.relationshipRefreshAction,
                  onPressed: _isLoading ? null : _loadRelationships,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_permissions.canEditSensitiveRelationships) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    key: const Key('relationship-add-parent-button'),
                    onPressed: _isMutating
                        ? null
                        : () => _createRelationship(_RelationshipAction.parent),
                    icon: const Icon(Icons.north_outlined),
                    label: Text(l10n.relationshipAddParentAction),
                  ),
                  OutlinedButton.icon(
                    key: const Key('relationship-add-child-button'),
                    onPressed: _isMutating
                        ? null
                        : () => _createRelationship(_RelationshipAction.child),
                    icon: const Icon(Icons.south_outlined),
                    label: Text(l10n.relationshipAddChildAction),
                  ),
                  OutlinedButton.icon(
                    key: const Key('relationship-add-spouse-button'),
                    onPressed: _isMutating
                        ? null
                        : () => _createRelationship(_RelationshipAction.spouse),
                    icon: const Icon(Icons.favorite_border),
                    label: Text(l10n.relationshipAddSpouseAction),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              _RelationshipMessage(
                title: l10n.relationshipErrorTitle,
                description: _relationshipErrorText(l10n, _error!),
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.errorContainer,
              ),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              AppLoadingState(
                message: l10n.pick(
                  vi: 'Đang tải quan hệ...',
                  en: 'Loading relationships...',
                ),
              )
            else ...[
              _RelationshipGroup(
                title: l10n.relationshipParentsTitle,
                emptyLabel: l10n.relationshipNoParents,
                relationships: parentRelationships,
                currentMemberId: widget.member.id,
                memberById: memberById,
              ),
              const SizedBox(height: 14),
              _RelationshipGroup(
                title: l10n.relationshipChildrenTitle,
                emptyLabel: l10n.relationshipNoChildren,
                relationships: childRelationships,
                currentMemberId: widget.member.id,
                memberById: memberById,
              ),
              const SizedBox(height: 14),
              _RelationshipGroup(
                title: l10n.relationshipSpousesTitle,
                emptyLabel: l10n.relationshipNoSpouses,
                relationships: spouseRelationships,
                currentMemberId: widget.member.id,
                memberById: memberById,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.relationshipCanonicalEdgeTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (_relationships.isEmpty)
                Text(l10n.relationshipNoEdges)
              else
                Column(
                  children: [
                    for (final relationship in _relationships)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: relationship == _relationships.last ? 0 : 12,
                        ),
                        child: _RelationshipEdgeCard(
                          key: Key('relationship-record-${relationship.id}'),
                          relationship: relationship,
                          currentMemberId: widget.member.id,
                          memberById: memberById,
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RelationshipGroup extends StatelessWidget {
  const _RelationshipGroup({
    required this.title,
    required this.emptyLabel,
    required this.relationships,
    required this.currentMemberId,
    required this.memberById,
  });

  final String title;
  final String emptyLabel;
  final List<RelationshipRecord> relationships;
  final String currentMemberId;
  final Map<String, MemberProfile> memberById;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (relationships.isEmpty)
          Text(emptyLabel)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final relationship in relationships)
                Chip(
                  label: Text(
                    memberById[relationship.relatedMemberIdFor(currentMemberId)]
                            ?.fullName ??
                        relationship.relatedMemberIdFor(currentMemberId) ??
                        currentMemberId,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _RelationshipEdgeCard extends StatelessWidget {
  const _RelationshipEdgeCard({
    super.key,
    required this.relationship,
    required this.currentMemberId,
    required this.memberById,
  });

  final RelationshipRecord relationship;
  final String currentMemberId;
  final Map<String, MemberProfile> memberById;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstName =
        memberById[relationship.personAId]?.fullName ?? relationship.personAId;
    final secondName =
        memberById[relationship.personBId]?.fullName ?? relationship.personBId;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (relationship.type) {
                RelationshipType.parentChild =>
                  l10n.relationshipEdgeParentChild,
                RelationshipType.spouse => l10n.relationshipEdgeSpouse,
              },
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text('$firstName -> $secondName'),
            const SizedBox(height: 4),
            Text(
              '${l10n.relationshipSourceLabel}: ${relationship.source}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipMessage extends StatelessWidget {
  const _RelationshipMessage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RelationshipAction { parent, child, spouse }

String _relationshipErrorText(
  AppLocalizations l10n,
  RelationshipRepositoryErrorCode code,
) {
  return switch (code) {
    RelationshipRepositoryErrorCode.duplicateSpouse =>
      l10n.relationshipErrorDuplicateSpouse,
    RelationshipRepositoryErrorCode.duplicateParentChild =>
      l10n.relationshipErrorDuplicateParentChild,
    RelationshipRepositoryErrorCode.cycleDetected =>
      l10n.relationshipErrorCycle,
    RelationshipRepositoryErrorCode.permissionDenied =>
      l10n.relationshipErrorPermissionDenied,
    RelationshipRepositoryErrorCode.memberNotFound =>
      l10n.relationshipErrorMemberNotFound,
    RelationshipRepositoryErrorCode.sameMember =>
      l10n.relationshipErrorSameMember,
  };
}

Set<String> _relatedIdsFor(Iterable<RelationshipRecord> relationships) {
  return relationships
      .expand(
        (relationship) => [relationship.personAId, relationship.personBId],
      )
      .toSet();
}
