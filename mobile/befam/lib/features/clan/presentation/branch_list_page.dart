import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../models/branch_profile.dart';
import 'clan_controller.dart';

class BranchListPage extends StatelessWidget {
  const BranchListPage({
    super.key,
    required this.controller,
    required this.onEditBranch,
  });

  final ClanController controller;
  final Future<void> Function({BranchProfile? branch}) onEditBranch;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final l10n = context.l10n;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.clanBranchListTitle)),
          body: controller.branches.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.clanBranchEmptyDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: controller.branches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final branch = controller.branches[index];
                    final leaderName = controller.memberName(
                      branch.leaderMemberId,
                    );
                    final viceLeaderName = controller.memberName(
                      branch.viceLeaderMemberId,
                    );

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        branch.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${l10n.clanBranchCodeLabel}: ${branch.code}',
                                      ),
                                    ],
                                  ),
                                ),
                                if (controller.permissions.canManageBranches)
                                  IconButton(
                                    tooltip: l10n.clanEditBranchAction,
                                    onPressed: () =>
                                        onEditBranch(branch: branch),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _BranchInfoRow(
                              label: l10n.clanLeaderLabel,
                              value: leaderName.isEmpty
                                  ? l10n.clanFieldUnset
                                  : leaderName,
                            ),
                            _BranchInfoRow(
                              label: l10n.clanViceLeaderLabel,
                              value: viceLeaderName.isEmpty
                                  ? l10n.clanFieldUnset
                                  : viceLeaderName,
                            ),
                            _BranchInfoRow(
                              label: l10n.clanGenerationHintLabel,
                              value: '${branch.generationLevelHint}',
                            ),
                            _BranchInfoRow(
                              label: l10n.clanStatMembers,
                              value: '${branch.memberCount}',
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: controller.permissions.canManageBranches
              ? FloatingActionButton.extended(
                  onPressed: () => onEditBranch(),
                  tooltip: l10n.clanAddBranchAction,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.clanAddBranchAction),
                )
              : null,
        );
      },
    );
  }
}

class _BranchInfoRow extends StatelessWidget {
  const _BranchInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
