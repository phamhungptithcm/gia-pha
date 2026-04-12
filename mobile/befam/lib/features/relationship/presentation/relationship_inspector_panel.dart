import 'package:flutter/material.dart';

import '../../../core/widgets/app_workspace_chrome.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../member/models/member_profile.dart';
import '../models/relationship_record.dart';
import '../services/relationship_repository.dart';

class RelationshipInspectorPanel extends StatefulWidget {
  const RelationshipInspectorPanel({
    super.key,
    required this.session,
    required this.member,
    required this.members,
    required this.repository,
    this.onOpenMemberDetail,
  });

  final AuthSession session;
  final MemberProfile member;
  final List<MemberProfile> members;
  final RelationshipRepository repository;
  final ValueChanged<MemberProfile>? onOpenMemberDetail;

  @override
  State<RelationshipInspectorPanel> createState() =>
      _RelationshipInspectorPanelState();
}

class _RelationshipInspectorPanelState
    extends State<RelationshipInspectorPanel> {
  bool _isLoading = true;
  RelationshipRepositoryErrorCode? _error;
  List<RelationshipRecord> _relationships = const [];

  @override
  void initState() {
    super.initState();
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

    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.relationshipInspectorTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            _RelationshipMessage(
              title: l10n.relationshipErrorTitle,
              description: _relationshipErrorText(l10n, _error!),
              icon: Icons.error_outline,
              color: Theme.of(context).colorScheme.errorContainer,
            ),
            const SizedBox(height: 14),
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
              title: l10n.pick(vi: 'Cha/mẹ', en: 'Parents'),
              emptyLabel: l10n.pick(
                vi: 'Chưa có liên kết cha/mẹ.',
                en: 'No parent links yet.',
              ),
              relationships: parentRelationships,
              currentMemberId: widget.member.id,
              memberById: memberById,
              onOpenMemberDetail: widget.onOpenMemberDetail,
            ),
            const SizedBox(height: 14),
            _RelationshipGroup(
              title: l10n.pick(vi: 'Vợ/chồng', en: 'Spouses'),
              emptyLabel: l10n.pick(
                vi: 'Chưa có liên kết vợ/chồng.',
                en: 'No spouse links yet.',
              ),
              relationships: spouseRelationships,
              currentMemberId: widget.member.id,
              memberById: memberById,
              onOpenMemberDetail: widget.onOpenMemberDetail,
            ),
            const SizedBox(height: 14),
            _RelationshipGroup(
              title: l10n.pick(vi: 'Con', en: 'Children'),
              emptyLabel: l10n.relationshipNoChildren,
              relationships: childRelationships,
              currentMemberId: widget.member.id,
              memberById: memberById,
              onOpenMemberDetail: widget.onOpenMemberDetail,
            ),
          ],
        ],
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
    required this.onOpenMemberDetail,
  });

  final String title;
  final String emptyLabel;
  final List<RelationshipRecord> relationships;
  final String currentMemberId;
  final Map<String, MemberProfile> memberById;
  final ValueChanged<MemberProfile>? onOpenMemberDetail;

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
                _buildRelatedMemberChip(context, relationship),
            ],
          ),
      ],
    );
  }

  Widget _buildRelatedMemberChip(
    BuildContext context,
    RelationshipRecord relationship,
  ) {
    final relatedId = relationship.relatedMemberIdFor(currentMemberId);
    final relatedMember = relatedId == null ? null : memberById[relatedId];
    final relatedLabel =
        relatedMember?.fullName ?? relatedId ?? currentMemberId;

    if (relatedMember != null && onOpenMemberDetail != null) {
      return ActionChip(
        tooltip: context.l10n.pick(
          vi: 'Xem chi tiết thành viên',
          en: 'View member details',
        ),
        avatar: const Icon(Icons.open_in_new, size: 16),
        label: Text(relatedLabel),
        onPressed: () => onOpenMemberDetail!(relatedMember),
      );
    }

    return Chip(label: Text(relatedLabel));
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
