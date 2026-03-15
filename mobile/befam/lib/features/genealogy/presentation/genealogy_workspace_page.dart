import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../models/genealogy_graph.dart';
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

enum _TreeDisplayPreset { focused, balanced, coverage, custom }

enum _MemberStatusFilter { all, alive, deceased }

class _GenealogyWorkspacePageState extends State<GenealogyWorkspacePage>
    with TickerProviderStateMixin {
  static const _nodeWidth = 232.0;
  static const _nodeHeight = 146.0;
  static const _rowSpacing = 128.0;
  static const _columnSpacing = 48.0;
  static const _canvasPadding = 40.0;

  late final TransformationController _transformController;
  final _layoutProfiler = _TreeLayoutProfiler(windowSize: 20);
  AnimationController? _centerAnimController;

  late GenealogyScopeType _scopeType;
  GenealogyReadSegment? _segment;
  Object? _error;
  bool _isLoading = true;

  String? _rootMemberId;
  String? _selectedMemberId;
  int _ancestorDepth = 1;
  int _descendantDepth = 1;
  _TreeDisplayPreset _displayPreset = _TreeDisplayPreset.focused;
  _MemberStatusFilter _statusFilter = _MemberStatusFilter.all;
  String? _branchFilterId;
  _TreeScene? _cachedScene;
  GenealogyReadSegment? _cachedSceneSegment;
  String _cachedSceneRootId = '';
  int _cachedSceneAncestorDepth = 1;
  int _cachedSceneDescendantDepth = 1;

  @override
  void initState() {
    super.initState();
    _scopeType = _resolveInitialScope(widget.session);
    _transformController = TransformationController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _centerAnimController?.dispose();
    _transformController.dispose();
    super.dispose();
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
    final scene = _resolveTreeScene(segment);
    final filteredRoots = _filteredRootEntries(segment);
    final rootEntriesForSelector = filteredRoots.isEmpty
        ? segment.rootEntries
        : filteredRoots;
    final selectedMember = _selectedMemberId == null
        ? null
        : segment.graph.membersById[_selectedMemberId!];
    final canExpandAncestors = _hasHiddenAncestors(segment.graph, scene);
    final canExpandDescendants = _hasHiddenDescendants(segment.graph, scene);

    return RefreshIndicator(
      onRefresh: () => _load(allowCached: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _LandingCard(
            scopeType: _scopeType,
            isLoading: _isLoading,
            isFromCache: segment.fromCache,
            onRefresh: _isLoading ? null : () => _load(allowCached: false),
            onScopeChanged: _updateScope,
            session: widget.session,
          ),
          if (rootEntriesForSelector.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RootSelector(
              rootEntries: rootEntriesForSelector,
              selectedRootId: _rootMemberId,
              resolveMember: (memberId) => segment.graph.membersById[memberId],
              onRootSelected: _setRootMember,
              reasonLabel: (reason) => _rootReasonLabel(l10n, reason),
            ),
          ],
          const SizedBox(height: 16),
          _ViewControlCard(
            displayPreset: _displayPreset,
            onDisplayPresetChanged: _applyDisplayPreset,
            statusFilter: _statusFilter,
            onStatusFilterChanged: (value) {
              setState(() {
                _statusFilter = value;
                _invalidateTreeSceneCache();
              });
            },
            branches: _scopeType == GenealogyScopeType.clan
                ? segment.branches
                : const [],
            selectedBranchId: _scopeType == GenealogyScopeType.clan
                ? _branchFilterId
                : null,
            onBranchFilterChanged: (branchId) {
              setState(() {
                _branchFilterId = branchId;
                _invalidateTreeSceneCache();
              });
            },
            visibleMembers: scene.visibleMemberIds.length,
            totalMembers: segment.members.length,
          ),
          const SizedBox(height: 16),
          _SummaryMetricGrid(
            items: [
              _SummaryMetricItem(
                key: Key('genealogy-summary-members-${segment.members.length}'),
                label: l10n.genealogySummaryMembers,
                value: '${segment.members.length}',
              ),
              _SummaryMetricItem(
                key: Key(
                  'genealogy-summary-relationships-${segment.relationships.length}',
                ),
                label: l10n.genealogySummaryRelationships,
                value: '${segment.relationships.length}',
              ),
              _SummaryMetricItem(
                key: Key(
                  'genealogy-summary-roots-${segment.rootEntries.length}',
                ),
                label: l10n.genealogySummaryRoots,
                value: '${segment.rootEntries.length}',
              ),
              _SummaryMetricItem(
                key: Key('genealogy-summary-scope-${segment.scope.type.name}'),
                label: l10n.genealogySummaryScope,
                value: _scopeLabel(l10n, segment.scope.type),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _DepthControl(
                    id: 'parents',
                    label: l10n.relationshipParentsTitle,
                    depth: _ancestorDepth,
                    canIncrease: canExpandAncestors,
                    canDecrease: _ancestorDepth > 1,
                    onIncrease: () {
                      setState(() {
                        _ancestorDepth += 1;
                        _displayPreset = _presetForDepths(
                          _ancestorDepth,
                          _descendantDepth,
                        );
                        _invalidateTreeSceneCache();
                      });
                    },
                    onDecrease: () {
                      setState(() {
                        _ancestorDepth = (_ancestorDepth - 1).clamp(1, 24);
                        _displayPreset = _presetForDepths(
                          _ancestorDepth,
                          _descendantDepth,
                        );
                        _invalidateTreeSceneCache();
                      });
                    },
                  ),
                  _DepthControl(
                    id: 'children',
                    label: l10n.relationshipChildrenTitle,
                    depth: _descendantDepth,
                    canIncrease: canExpandDescendants,
                    canDecrease: _descendantDepth > 1,
                    onIncrease: () {
                      setState(() {
                        _descendantDepth += 1;
                        _displayPreset = _presetForDepths(
                          _ancestorDepth,
                          _descendantDepth,
                        );
                        _invalidateTreeSceneCache();
                      });
                    },
                    onDecrease: () {
                      setState(() {
                        _descendantDepth = (_descendantDepth - 1).clamp(1, 24);
                        _displayPreset = _presetForDepths(
                          _ancestorDepth,
                          _descendantDepth,
                        );
                        _invalidateTreeSceneCache();
                      });
                    },
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('genealogy-center-selected'),
                    onPressed: selectedMember == null
                        ? null
                        : () => _centerOnMember(
                            memberId: selectedMember.id,
                            scene: scene,
                            viewport: const Size(1, 1),
                            useViewportFromLayout: true,
                          ),
                    icon: const Icon(Icons.center_focus_strong),
                    label: Text(l10n.genealogyFocusMemberTitle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 620,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(220),
                          minScale: 0.4,
                          maxScale: 2.8,
                          child: SizedBox(
                            width: scene.canvasSize.width,
                            height: scene.canvasSize.height,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    key: const Key('tree-connectors'),
                                    painter: _TreeConnectorPainter(
                                      parentChildEdges: scene.parentChildEdges,
                                      spouseEdges: scene.spouseEdges,
                                      nodeRects: scene.nodeRects,
                                      selectedMemberId: _selectedMemberId,
                                    ),
                                  ),
                                ),
                                for (final entry in scene.nodeRects.entries)
                                  Positioned(
                                    left: entry.value.left,
                                    top: entry.value.top,
                                    width: entry.value.width,
                                    height: entry.value.height,
                                    child: _MemberNodeCard(
                                      key: Key('tree-node-${entry.key}'),
                                      member:
                                          segment.graph.membersById[entry.key]!,
                                      generationLabel:
                                          segment
                                              .graph
                                              .generationLabels[entry.key]
                                              ?.compactLabel ??
                                          'G${segment.graph.membersById[entry.key]!.generation}',
                                      parentCount: segment.graph
                                          .parentsOf(entry.key)
                                          .length,
                                      childCount: segment.graph
                                          .childrenOf(entry.key)
                                          .length,
                                      spouseCount: segment.graph
                                          .spousesOf(entry.key)
                                          .length,
                                      isAlive: _isMemberAlive(
                                        segment.graph.membersById[entry.key]!,
                                      ),
                                      aliveStatusLabel:
                                          l10n.genealogyMemberAliveStatus,
                                      deceasedStatusLabel:
                                          l10n.genealogyMemberDeceasedStatus,
                                      isSelected:
                                          _selectedMemberId == entry.key,
                                      onTap: () {
                                        final member = segment
                                            .graph
                                            .membersById[entry.key]!;
                                        setState(() {
                                          _selectedMemberId = member.id;
                                        });
                                        _centerOnMember(
                                          memberId: member.id,
                                          scene: scene,
                                          viewport: viewport,
                                        );
                                        unawaited(
                                          _openMemberDetailSheet(
                                            member: member,
                                            graph: segment.graph,
                                          ),
                                        );
                                      },
                                      onViewMemberInfo: () {
                                        final member = segment
                                            .graph
                                            .membersById[entry.key]!;
                                        setState(() {
                                          _selectedMemberId = member.id;
                                        });
                                        _centerOnMember(
                                          memberId: member.id,
                                          scene: scene,
                                          viewport: viewport,
                                        );
                                        unawaited(
                                          _openMemberDetailSheet(
                                            member: member,
                                            graph: segment.graph,
                                          ),
                                        );
                                      },
                                      viewInfoTooltip:
                                          l10n.genealogyViewMemberInfoAction,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _TreeMetricCard(
                          l10n: l10n,
                          members: scene.visibleMemberIds.length,
                          edges:
                              scene.parentChildEdges.length +
                              scene.spouseEdges.length,
                          latestLayoutMs: scene.layoutProfile.latestMs,
                          averageLayoutMs: scene.layoutProfile.averageMs,
                          peakLayoutMs: scene.layoutProfile.peakMs,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _TreeZoomControls(
                          onZoomIn: _zoomIn,
                          onZoomOut: _zoomOut,
                          onReset: _resetTreeViewport,
                        ),
                      ),
                    ],
                  );
                },
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
      _invalidateTreeSceneCache();
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

      final initialFocus = _resolveInitialFocusMemberId(segment);
      setState(() {
        _segment = segment;
        _isLoading = false;
        if (_branchFilterId != null &&
            !segment.branches.any((branch) => branch.id == _branchFilterId)) {
          _branchFilterId = null;
        }
        _rootMemberId = _rootMemberId ?? initialFocus;
        _selectedMemberId = _selectedMemberId ?? initialFocus;
        _invalidateTreeSceneCache();
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
      _rootMemberId = null;
      _selectedMemberId = null;
      _ancestorDepth = 1;
      _descendantDepth = 1;
      _displayPreset = _TreeDisplayPreset.focused;
      _statusFilter = _MemberStatusFilter.all;
      _branchFilterId = null;
      _transformController.value = Matrix4.identity();
      _invalidateTreeSceneCache();
    });
    unawaited(_load());
  }

  String _resolveInitialFocusMemberId(GenealogyReadSegment segment) {
    final sessionMemberId = widget.session.memberId;
    if (sessionMemberId != null &&
        segment.graph.membersById.containsKey(sessionMemberId)) {
      return sessionMemberId;
    }
    if (segment.rootEntries.isNotEmpty) {
      return segment.rootEntries.first.memberId;
    }
    if (segment.members.isNotEmpty) {
      return segment.members.first.id;
    }
    return '';
  }

  void _setRootMember(String memberId) {
    setState(() {
      _rootMemberId = memberId;
      _selectedMemberId = memberId;
      if (_displayPreset != _TreeDisplayPreset.custom) {
        _ancestorDepth = 1;
        _descendantDepth = 1;
        _displayPreset = _TreeDisplayPreset.focused;
      }
      _transformController.value = Matrix4.identity();
      _invalidateTreeSceneCache();
    });
  }

  void _applyDisplayPreset(_TreeDisplayPreset preset) {
    setState(() {
      _displayPreset = preset;
      switch (preset) {
        case _TreeDisplayPreset.focused:
          _ancestorDepth = 1;
          _descendantDepth = 1;
        case _TreeDisplayPreset.balanced:
          _ancestorDepth = 2;
          _descendantDepth = 2;
        case _TreeDisplayPreset.coverage:
          _ancestorDepth = 4;
          _descendantDepth = 4;
        case _TreeDisplayPreset.custom:
          break;
      }
      _invalidateTreeSceneCache();
    });
  }

  _TreeDisplayPreset _presetForDepths(int ancestorDepth, int descendantDepth) {
    if (ancestorDepth == 1 && descendantDepth == 1) {
      return _TreeDisplayPreset.focused;
    }
    if (ancestorDepth == 2 && descendantDepth == 2) {
      return _TreeDisplayPreset.balanced;
    }
    if (ancestorDepth == 4 && descendantDepth == 4) {
      return _TreeDisplayPreset.coverage;
    }
    return _TreeDisplayPreset.custom;
  }

  List<GenealogyRootEntry> _filteredRootEntries(GenealogyReadSegment segment) {
    final roots = segment.rootEntries
        .where((entry) {
          final member = segment.graph.membersById[entry.memberId];
          if (member == null) {
            return false;
          }
          if (entry.memberId == _selectedMemberId ||
              entry.memberId == _rootMemberId) {
            return true;
          }
          return _matchesViewFilters(member);
        })
        .toList(growable: false);

    return roots;
  }

  _TreeScene _resolveTreeScene(GenealogyReadSegment segment) {
    final rootId = _effectiveRootId(segment);
    final canReuse =
        _cachedScene != null &&
        identical(_cachedSceneSegment, segment) &&
        _cachedSceneRootId == rootId &&
        _cachedSceneAncestorDepth == _ancestorDepth &&
        _cachedSceneDescendantDepth == _descendantDepth;
    if (canReuse) {
      return _cachedScene!;
    }

    final scene = _buildTreeScene(segment, rootId: rootId);
    _cachedScene = scene;
    _cachedSceneSegment = segment;
    _cachedSceneRootId = rootId;
    _cachedSceneAncestorDepth = _ancestorDepth;
    _cachedSceneDescendantDepth = _descendantDepth;
    return scene;
  }

  String _effectiveRootId(GenealogyReadSegment segment) {
    final fallbackRoot = _resolveInitialFocusMemberId(segment);
    return _rootMemberId?.trim().isNotEmpty == true
        ? _rootMemberId!
        : fallbackRoot;
  }

  void _invalidateTreeSceneCache() {
    _cachedScene = null;
    _cachedSceneSegment = null;
    _cachedSceneRootId = '';
  }

  _TreeScene _buildTreeScene(
    GenealogyReadSegment segment, {
    required String rootId,
  }) {
    final stopwatch = Stopwatch()..start();
    final graph = segment.graph;
    final visibleMemberIds = _buildVisibleMemberIds(
      graph: graph,
      rootId: rootId,
    );
    final levels = _buildRelativeLevels(
      graph: graph,
      rootId: rootId,
      visibleMemberIds: visibleMemberIds,
    );

    final idsByLevel = <int, List<String>>{};
    for (final memberId in visibleMemberIds) {
      idsByLevel.putIfAbsent(levels[memberId] ?? 0, () => []).add(memberId);
    }
    for (final entry in idsByLevel.entries) {
      entry.value.sort((left, right) {
        final leftMember = graph.membersById[left]!;
        final rightMember = graph.membersById[right]!;
        final byGeneration = leftMember.generation.compareTo(
          rightMember.generation,
        );
        if (byGeneration != 0) {
          return byGeneration;
        }
        return leftMember.fullName.compareTo(rightMember.fullName);
      });
    }

    final sortedLevels = idsByLevel.keys.toList()..sort();
    final maxColumns = idsByLevel.values.fold<int>(
      1,
      (current, list) => list.length > current ? list.length : current,
    );
    final canvasWidth =
        (_canvasPadding * 2) +
        (maxColumns * _nodeWidth) +
        ((maxColumns - 1) * _columnSpacing);
    final canvasHeight =
        (_canvasPadding * 2) +
        (sortedLevels.length * _nodeHeight) +
        ((sortedLevels.length - 1) * _rowSpacing);

    final nodeRects = <String, Rect>{};
    for (var levelIndex = 0; levelIndex < sortedLevels.length; levelIndex++) {
      final level = sortedLevels[levelIndex];
      final row = idsByLevel[level]!;
      final rowWidth =
          (row.length * _nodeWidth) + ((row.length - 1) * _columnSpacing);
      final startX = (canvasWidth - rowWidth) / 2;
      final top = _canvasPadding + (levelIndex * (_nodeHeight + _rowSpacing));
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final left = startX + (columnIndex * (_nodeWidth + _columnSpacing));
        nodeRects[row[columnIndex]] = Rect.fromLTWH(
          left,
          top,
          _nodeWidth,
          _nodeHeight,
        );
      }
    }

    final parentChildEdges = <_TreeEdge>[];
    final seenParentChild = <String>{};
    for (final childId in visibleMemberIds) {
      for (final parentId in graph.parentsOf(childId)) {
        if (!visibleMemberIds.contains(parentId)) {
          continue;
        }
        final key = '$parentId->$childId';
        if (seenParentChild.add(key)) {
          parentChildEdges.add(_TreeEdge(fromId: parentId, toId: childId));
        }
      }
    }

    final spouseEdges = <_TreeEdge>[];
    final seenSpouses = <String>{};
    for (final memberId in visibleMemberIds) {
      for (final spouseId in graph.spousesOf(memberId)) {
        if (!visibleMemberIds.contains(spouseId)) {
          continue;
        }
        final ordered = [memberId, spouseId]..sort();
        final key = '${ordered.first}<->${ordered.last}';
        if (seenSpouses.add(key)) {
          spouseEdges.add(_TreeEdge(fromId: ordered.first, toId: ordered.last));
        }
      }
    }

    stopwatch.stop();
    final layoutProfile = _layoutProfiler.push(stopwatch.elapsed);
    assert(() {
      developer.log(
        'Tree scene build: ${visibleMemberIds.length} nodes, '
        '${parentChildEdges.length + spouseEdges.length} edges, '
        '${layoutProfile.latestMs}ms (avg ${layoutProfile.averageMs}ms, peak ${layoutProfile.peakMs}ms)',
        name: 'GenealogyWorkspace',
      );
      return true;
    }());
    if (layoutProfile.latestMs > 120) {
      developer.log(
        'Slow tree layout detected: ${layoutProfile.latestMs}ms '
        'for ${visibleMemberIds.length} nodes and '
        '${parentChildEdges.length + spouseEdges.length} edges.',
        name: 'GenealogyWorkspace',
        level: 900,
      );
    }

    return _TreeScene(
      canvasSize: Size(canvasWidth, canvasHeight),
      nodeRects: nodeRects,
      parentChildEdges: parentChildEdges,
      spouseEdges: spouseEdges,
      visibleMemberIds: visibleMemberIds,
      layoutProfile: layoutProfile,
    );
  }

  Set<String> _buildVisibleMemberIds({
    required GenealogyGraph graph,
    required String rootId,
  }) {
    if (rootId.isEmpty || !graph.membersById.containsKey(rootId)) {
      return graph.membersById.keys.toSet();
    }

    final visible = <String>{rootId};
    var ancestors = <String>{rootId};
    for (var level = 0; level < _ancestorDepth; level++) {
      final next = <String>{};
      for (final memberId in ancestors) {
        for (final parentId in graph.parentsOf(memberId)) {
          if (visible.add(parentId)) {
            next.add(parentId);
          }
          visible.addAll(graph.spousesOf(parentId));
        }
      }
      ancestors = next;
      if (ancestors.isEmpty) {
        break;
      }
    }

    var descendants = <String>{rootId};
    for (var level = 0; level < _descendantDepth; level++) {
      final next = <String>{};
      for (final memberId in descendants) {
        for (final childId in graph.childrenOf(memberId)) {
          if (visible.add(childId)) {
            next.add(childId);
          }
          visible.addAll(graph.spousesOf(childId));
        }
      }
      descendants = next;
      if (descendants.isEmpty) {
        break;
      }
    }

    for (final memberId in visible.toList()) {
      visible.addAll(graph.spousesOf(memberId));
    }

    if (_branchFilterId == null && _statusFilter == _MemberStatusFilter.all) {
      return visible;
    }

    final filtered = <String>{};
    for (final memberId in visible) {
      final member = graph.membersById[memberId];
      if (member == null) {
        continue;
      }
      if (_matchesViewFilters(member)) {
        filtered.add(memberId);
      }
    }

    if (rootId.isNotEmpty && visible.contains(rootId)) {
      filtered.add(rootId);
    }
    if (_selectedMemberId != null && visible.contains(_selectedMemberId!)) {
      filtered.add(_selectedMemberId!);
    }

    if (filtered.isEmpty && visible.isNotEmpty) {
      filtered.add(rootId.isNotEmpty ? rootId : visible.first);
    }

    return filtered;
  }

  Map<String, int> _buildRelativeLevels({
    required GenealogyGraph graph,
    required String rootId,
    required Set<String> visibleMemberIds,
  }) {
    final levels = <String, int>{};
    if (rootId.isNotEmpty && visibleMemberIds.contains(rootId)) {
      levels[rootId] = 0;
      final queue = Queue<String>()..add(rootId);
      while (queue.isNotEmpty) {
        final currentId = queue.removeFirst();
        final currentLevel = levels[currentId]!;

        for (final parentId in graph.parentsOf(currentId)) {
          if (!visibleMemberIds.contains(parentId)) {
            continue;
          }
          final next = currentLevel - 1;
          final existing = levels[parentId];
          if (existing == null || next.abs() < existing.abs()) {
            levels[parentId] = next;
            queue.add(parentId);
          }
        }
        for (final childId in graph.childrenOf(currentId)) {
          if (!visibleMemberIds.contains(childId)) {
            continue;
          }
          final next = currentLevel + 1;
          final existing = levels[childId];
          if (existing == null || next.abs() < existing.abs()) {
            levels[childId] = next;
            queue.add(childId);
          }
        }
        for (final spouseId in graph.spousesOf(currentId)) {
          if (!visibleMemberIds.contains(spouseId)) {
            continue;
          }
          final existing = levels[spouseId];
          if (existing == null || currentLevel.abs() < existing.abs()) {
            levels[spouseId] = currentLevel;
            queue.add(spouseId);
          }
        }
      }
    }

    final rootGeneration = graph.membersById[rootId]?.generation ?? 1;
    for (final memberId in visibleMemberIds) {
      levels.putIfAbsent(
        memberId,
        () =>
            (graph.membersById[memberId]?.generation ?? rootGeneration) -
            rootGeneration,
      );
    }
    return levels;
  }

  bool _hasHiddenAncestors(GenealogyGraph graph, _TreeScene scene) {
    for (final memberId in scene.visibleMemberIds) {
      if (graph
          .parentsOf(memberId)
          .any((parent) => !scene.visibleMemberIds.contains(parent))) {
        return true;
      }
    }
    return false;
  }

  bool _hasHiddenDescendants(GenealogyGraph graph, _TreeScene scene) {
    for (final memberId in scene.visibleMemberIds) {
      if (graph
          .childrenOf(memberId)
          .any((child) => !scene.visibleMemberIds.contains(child))) {
        return true;
      }
    }
    return false;
  }

  void _centerOnMember({
    required String memberId,
    required _TreeScene scene,
    required Size viewport,
    bool useViewportFromLayout = false,
  }) {
    final rect = scene.nodeRects[memberId];
    if (rect == null) {
      return;
    }
    final view = useViewportFromLayout
        ? context.findRenderObject() is RenderBox
              ? (context.findRenderObject()! as RenderBox).size
              : viewport
        : viewport;
    if (view.width <= 0 || view.height <= 0) {
      return;
    }

    final scale = _transformController.value.getMaxScaleOnAxis().clamp(
      0.4,
      2.8,
    );
    final target = Matrix4.identity()
      ..translateByDouble(
        (view.width / 2) - ((rect.left + (rect.width / 2)) * scale),
        (view.height / 2) - ((rect.top + (rect.height / 2)) * scale),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);

    _centerAnimController?.dispose();
    _centerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final tween = Matrix4Tween(begin: _transformController.value, end: target);
    final animation = CurvedAnimation(
      parent: _centerAnimController!,
      curve: Curves.easeOutCubic,
    );
    _centerAnimController!
      ..addListener(() {
        _transformController.value = tween.evaluate(animation);
      })
      ..forward();
  }

  Future<void> _openMemberDetailSheet({
    required MemberProfile member,
    required GenealogyGraph graph,
  }) async {
    final l10n = context.l10n;
    final ancestry = GenealogyGraphAlgorithms.buildAncestryPath(
      graph: graph,
      memberId: member.id,
    );
    final descendants = GenealogyGraphAlgorithms.buildDescendantsTraversal(
      graph: graph,
      memberId: member.id,
    );
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (member.nickName.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(member.nickName, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 14),
                _FactLine(
                  label: l10n.genealogyMemberStatusLabel,
                  value: _isMemberAlive(member)
                      ? l10n.genealogyMemberAliveStatus
                      : l10n.genealogyMemberDeceasedStatus,
                ),
                _FactLine(
                  label: l10n.genealogyGenerationLabel,
                  value:
                      graph.generationLabels[member.id]?.compactLabel ??
                      'G${member.generation}',
                ),
                _FactLine(
                  label: l10n.genealogyParentCountLabel,
                  value: '${graph.parentsOf(member.id).length}',
                ),
                _FactLine(
                  label: l10n.genealogyChildCountLabel,
                  value: '${graph.childrenOf(member.id).length}',
                ),
                _FactLine(
                  label: l10n.genealogySpouseCountLabel,
                  value: '${graph.spousesOf(member.id).length}',
                ),
                _FactLine(
                  label: l10n.genealogyDescendantCountLabel,
                  value: '${descendants.length}',
                ),
                _FactLine(
                  label: l10n.genealogyAncestryPathTitle,
                  value: '${ancestry.length}',
                  isLast: true,
                ),
              ],
            ),
          ),
        );
      },
    );
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

  String _rootReasonLabel(AppLocalizations l10n, GenealogyRootReason reason) {
    return switch (reason) {
      GenealogyRootReason.currentMember =>
        l10n.genealogyRootReasonCurrentMember,
      GenealogyRootReason.clanRoot => l10n.genealogyRootReasonClanRoot,
      GenealogyRootReason.scopeRoot => l10n.genealogyRootReasonScopeRoot,
      GenealogyRootReason.branchLeader => l10n.genealogyRootReasonBranchLeader,
      GenealogyRootReason.branchViceLeader =>
        l10n.genealogyRootReasonBranchViceLeader,
    };
  }

  String _scopeLabel(AppLocalizations l10n, GenealogyScopeType scopeType) {
    return switch (scopeType) {
      GenealogyScopeType.clan => l10n.genealogyScopeClan,
      GenealogyScopeType.branch => l10n.genealogyScopeBranch,
    };
  }

  bool _isMemberAlive(MemberProfile member) {
    final deathDate = member.deathDate?.trim() ?? '';
    if (deathDate.isNotEmpty) {
      return false;
    }
    final normalizedStatus = member.status.trim().toLowerCase();
    return normalizedStatus != 'deceased' && normalizedStatus != 'dead';
  }

  bool _matchesViewFilters(MemberProfile member) {
    final branchMatches =
        _branchFilterId == null || member.branchId == _branchFilterId;
    if (!branchMatches) {
      return false;
    }
    return switch (_statusFilter) {
      _MemberStatusFilter.all => true,
      _MemberStatusFilter.alive => _isMemberAlive(member),
      _MemberStatusFilter.deceased => !_isMemberAlive(member),
    };
  }

  void _zoomIn() => _scaleTree(1.16);

  void _zoomOut() => _scaleTree(0.86);

  void _resetTreeViewport() {
    _transformController.value = Matrix4.identity();
  }

  void _scaleTree(double ratio) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * ratio).clamp(0.4, 2.8);
    if ((targetScale - currentScale).abs() < 0.0001) {
      return;
    }
    final factor = targetScale / currentScale;
    _transformController.value = _transformController.value.clone()
      ..scaleByDouble(factor, factor, factor, 1);
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({
    required this.scopeType,
    required this.isLoading,
    required this.isFromCache,
    required this.onRefresh,
    required this.onScopeChanged,
    required this.session,
  });

  final GenealogyScopeType scopeType;
  final bool isLoading;
  final bool isFromCache;
  final VoidCallback? onRefresh;
  final ValueChanged<GenealogyScopeType> onScopeChanged;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      key: const Key('genealogy-landing-card'),
      padding: const EdgeInsets.all(22),
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
          const SizedBox(height: 10),
          Text(
            l10n.genealogyWorkspaceDescription,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ChoiceChip(
                key: const Key('genealogy-scope-clan'),
                label: Text(l10n.genealogyScopeClan),
                selected: scopeType == GenealogyScopeType.clan,
                onSelected: (_) => onScopeChanged(GenealogyScopeType.clan),
              ),
              if (session.branchId != null && session.branchId!.isNotEmpty)
                ChoiceChip(
                  key: const Key('genealogy-scope-branch'),
                  label: Text(l10n.genealogyScopeBranch),
                  selected: scopeType == GenealogyScopeType.branch,
                  onSelected: (_) => onScopeChanged(GenealogyScopeType.branch),
                ),
              ActionChip(
                avatar: Icon(
                  isFromCache ? Icons.bolt_outlined : Icons.cloud_done,
                  size: 18,
                ),
                label: Text(
                  isFromCache
                      ? l10n.genealogyFromCache
                      : l10n.genealogyLiveData,
                ),
                onPressed: null,
              ),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(l10n.genealogyRefreshAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RootSelector extends StatelessWidget {
  const _RootSelector({
    required this.rootEntries,
    required this.selectedRootId,
    required this.resolveMember,
    required this.onRootSelected,
    required this.reasonLabel,
  });

  final List<GenealogyRootEntry> rootEntries;
  final String? selectedRootId;
  final MemberProfile? Function(String memberId) resolveMember;
  final ValueChanged<String> onRootSelected;
  final String Function(GenealogyRootReason reason) reasonLabel;

  Future<void> _openRootPicker(BuildContext context) async {
    final l10n = context.l10n;
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = rootEntries
                .where((root) {
                  final name =
                      resolveMember(root.memberId)?.fullName ?? root.memberId;
                  return query.isEmpty || name.toLowerCase().contains(query);
                })
                .toList(growable: false);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(
                        vi: 'Chọn điểm vào gốc',
                        en: 'Choose root entry',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: l10n.pick(
                          vi: 'Tìm theo tên thành viên',
                          en: 'Search member name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final root = filtered[index];
                          final name =
                              resolveMember(root.memberId)?.fullName ??
                              root.memberId;
                          final selected = selectedRootId == root.memberId;
                          return ListTile(
                            onTap: () {
                              Navigator.of(context).pop();
                              onRootSelected(root.memberId);
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              root.reasons.map(reasonLabel).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.genealogyRootEntriesTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openRootPicker(context),
                  icon: const Icon(Icons.manage_search),
                  label: Text(
                    l10n.pick(
                      vi: 'Xem tất cả (${rootEntries.length})',
                      en: 'View all (${rootEntries.length})',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final root in rootEntries) ...[
                    FilterChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      selected: selectedRootId == root.memberId,
                      label: Text(
                        resolveMember(root.memberId)?.fullName ?? root.memberId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onSelected: (_) => onRootSelected(root.memberId),
                      tooltip: root.reasons.map(reasonLabel).join(', '),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricItem {
  const _SummaryMetricItem({
    this.key,
    required this.label,
    required this.value,
  });

  final Key? key;
  final String label;
  final String value;
}

class _SummaryMetricGrid extends StatelessWidget {
  const _SummaryMetricGrid({required this.items});

  final List<_SummaryMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 138,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return KeyedSubtree(
              key: item.key,
              child: _SummaryMetricCard(label: item.label, value: item.value),
            );
          },
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewControlCard extends StatelessWidget {
  const _ViewControlCard({
    required this.displayPreset,
    required this.onDisplayPresetChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchFilterChanged,
    required this.visibleMembers,
    required this.totalMembers,
  });

  final _TreeDisplayPreset displayPreset;
  final ValueChanged<_TreeDisplayPreset> onDisplayPresetChanged;
  final _MemberStatusFilter statusFilter;
  final ValueChanged<_MemberStatusFilter> onStatusFilterChanged;
  final List<BranchProfile> branches;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchFilterChanged;
  final int visibleMembers;
  final int totalMembers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final branchItems = branches.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(vi: 'Bộ lọc hiển thị cây', en: 'Tree display controls'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('tree-preset-focused'),
                  selected: displayPreset == _TreeDisplayPreset.focused,
                  label: Text(l10n.pick(vi: 'Tập trung', en: 'Focused')),
                  onSelected: (_) =>
                      onDisplayPresetChanged(_TreeDisplayPreset.focused),
                ),
                ChoiceChip(
                  key: const Key('tree-preset-balanced'),
                  selected: displayPreset == _TreeDisplayPreset.balanced,
                  label: Text(l10n.pick(vi: 'Cân bằng', en: 'Balanced')),
                  onSelected: (_) =>
                      onDisplayPresetChanged(_TreeDisplayPreset.balanced),
                ),
                ChoiceChip(
                  key: const Key('tree-preset-coverage'),
                  selected: displayPreset == _TreeDisplayPreset.coverage,
                  label: Text(l10n.pick(vi: 'Độ phủ rộng', en: 'Coverage')),
                  onSelected: (_) =>
                      onDisplayPresetChanged(_TreeDisplayPreset.coverage),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilterChip(
                  key: const Key('tree-status-all'),
                  selected: statusFilter == _MemberStatusFilter.all,
                  label: Text(l10n.pick(vi: 'Tất cả', en: 'All')),
                  onSelected: (_) =>
                      onStatusFilterChanged(_MemberStatusFilter.all),
                ),
                FilterChip(
                  key: const Key('tree-status-alive'),
                  selected: statusFilter == _MemberStatusFilter.alive,
                  label: Text(l10n.pick(vi: 'Còn sống', en: 'Alive')),
                  onSelected: (_) =>
                      onStatusFilterChanged(_MemberStatusFilter.alive),
                ),
                FilterChip(
                  key: const Key('tree-status-deceased'),
                  selected: statusFilter == _MemberStatusFilter.deceased,
                  label: Text(l10n.pick(vi: 'Đã mất', en: 'Deceased')),
                  onSelected: (_) =>
                      onStatusFilterChanged(_MemberStatusFilter.deceased),
                ),
              ],
            ),
            if (branchItems.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: const Key('tree-branch-filter'),
                initialValue: selectedBranchId,
                decoration: InputDecoration(
                  labelText: l10n.pick(vi: 'Lọc theo chi', en: 'Filter branch'),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      l10n.pick(vi: 'Tất cả các chi', en: 'All branches'),
                    ),
                  ),
                  for (final branch in branchItems)
                    DropdownMenuItem<String?>(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                ],
                onChanged: onBranchFilterChanged,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.pick(
                vi: 'Đang hiển thị $visibleMembers/$totalMembers thành viên.',
                en: 'Showing $visibleMembers/$totalMembers members.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DepthControl extends StatelessWidget {
  const _DepthControl({
    required this.id,
    required this.label,
    required this.depth,
    required this.canIncrease,
    required this.canDecrease,
    required this.onIncrease,
    required this.onDecrease,
  });

  final String id;
  final String label;
  final int depth;
  final bool canIncrease;
  final bool canDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('genealogy-depth-$id-decrease'),
              visualDensity: VisualDensity.compact,
              onPressed: canDecrease ? onDecrease : null,
              icon: const Icon(Icons.remove),
              tooltip: '-',
            ),
            Text('$label $depth', key: Key('genealogy-depth-$id-value')),
            IconButton(
              key: Key('genealogy-depth-$id-increase'),
              visualDensity: VisualDensity.compact,
              onPressed: canIncrease ? onIncrease : null,
              icon: const Icon(Icons.add),
              tooltip: '+',
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeZoomControls extends StatelessWidget {
  const _TreeZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('tree-zoom-out'),
              visualDensity: VisualDensity.compact,
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove),
              tooltip: '-',
            ),
            IconButton(
              key: const Key('tree-zoom-in'),
              visualDensity: VisualDensity.compact,
              onPressed: onZoomIn,
              icon: const Icon(Icons.add),
              tooltip: '+',
            ),
            IconButton(
              key: const Key('tree-zoom-reset'),
              visualDensity: VisualDensity.compact,
              onPressed: onReset,
              icon: const Icon(Icons.filter_center_focus),
              tooltip: 'Reset',
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberNodeCard extends StatelessWidget {
  const _MemberNodeCard({
    super.key,
    required this.member,
    required this.generationLabel,
    required this.parentCount,
    required this.childCount,
    required this.spouseCount,
    required this.isAlive,
    required this.aliveStatusLabel,
    required this.deceasedStatusLabel,
    required this.isSelected,
    required this.onTap,
    required this.onViewMemberInfo,
    required this.viewInfoTooltip,
  });

  final MemberProfile member;
  final String generationLabel;
  final int parentCount;
  final int childCount;
  final int spouseCount;
  final bool isAlive;
  final String aliveStatusLabel;
  final String deceasedStatusLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onViewMemberInfo;
  final String viewInfoTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: isSelected ? colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Text(
                      member.initials,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusChip(
                          isAlive: isAlive,
                          aliveStatusLabel: aliveStatusLabel,
                          deceasedStatusLabel: deceasedStatusLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: viewInfoTooltip,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      splashRadius: 16,
                      onPressed: onViewMemberInfo,
                      icon: const Icon(Icons.info_outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MiniFactChip(
                          icon: Icons.layers_outlined,
                          label: generationLabel,
                        ),
                        const SizedBox(width: 8),
                        _MiniFactChip(
                          icon: Icons.north_outlined,
                          label: '$parentCount',
                        ),
                        const SizedBox(width: 8),
                        _MiniFactChip(
                          icon: Icons.south_outlined,
                          label: '$childCount',
                        ),
                        const SizedBox(width: 8),
                        _MiniFactChip(
                          icon: Icons.favorite_border,
                          label: '$spouseCount',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.isAlive,
    required this.aliveStatusLabel,
    required this.deceasedStatusLabel,
  });

  final bool isAlive;
  final String aliveStatusLabel;
  final String deceasedStatusLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isAlive
            ? colorScheme.tertiaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          isAlive ? aliveStatusLabel : deceasedStatusLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MiniFactChip extends StatelessWidget {
  const _MiniFactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _TreeConnectorPainter extends CustomPainter {
  const _TreeConnectorPainter({
    required this.parentChildEdges,
    required this.spouseEdges,
    required this.nodeRects,
    required this.selectedMemberId,
  });

  final List<_TreeEdge> parentChildEdges;
  final List<_TreeEdge> spouseEdges;
  final Map<String, Rect> nodeRects;
  final String? selectedMemberId;

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6B7280);
    final spousePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB45309);
    final selectedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2563EB);

    for (final edge in parentChildEdges) {
      final parentRect = nodeRects[edge.fromId];
      final childRect = nodeRects[edge.toId];
      if (parentRect == null || childRect == null) {
        continue;
      }
      final start = Offset(parentRect.center.dx, parentRect.bottom);
      final end = Offset(childRect.center.dx, childRect.top);
      final midY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, midY)
        ..lineTo(end.dx, midY)
        ..lineTo(end.dx, end.dy);
      final highlight =
          edge.fromId == selectedMemberId || edge.toId == selectedMemberId;
      canvas.drawPath(path, highlight ? selectedPaint : parentPaint);
    }

    for (final edge in spouseEdges) {
      final leftRect = nodeRects[edge.fromId];
      final rightRect = nodeRects[edge.toId];
      if (leftRect == null || rightRect == null) {
        continue;
      }
      final start = Offset(leftRect.right, leftRect.center.dy);
      final end = Offset(rightRect.left, rightRect.center.dy);
      final highlight =
          edge.fromId == selectedMemberId || edge.toId == selectedMemberId;
      canvas.drawLine(start, end, highlight ? selectedPaint : spousePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) {
    return oldDelegate.parentChildEdges != parentChildEdges ||
        oldDelegate.spouseEdges != spouseEdges ||
        oldDelegate.nodeRects != nodeRects ||
        oldDelegate.selectedMemberId != selectedMemberId;
  }
}

class _TreeMetricCard extends StatelessWidget {
  const _TreeMetricCard({
    required this.l10n,
    required this.members,
    required this.edges,
    required this.latestLayoutMs,
    required this.averageLayoutMs,
    required this.peakLayoutMs,
  });

  final AppLocalizations l10n;
  final int members;
  final int edges;
  final int latestLayoutMs;
  final int averageLayoutMs;
  final int peakLayoutMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      key: const Key('tree-metrics-card'),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DefaultTextStyle(
          style: theme.textTheme.labelMedium!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.genealogyMetricNodes(members)),
              Text(l10n.genealogyMetricEdges(edges)),
              Text(l10n.genealogyMetricLayout(latestLayoutMs)),
              Text(l10n.genealogyMetricAverage(averageLayoutMs)),
              Text(l10n.genealogyMetricPeak(peakLayoutMs)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TreeScene {
  const _TreeScene({
    required this.canvasSize,
    required this.nodeRects,
    required this.parentChildEdges,
    required this.spouseEdges,
    required this.visibleMemberIds,
    required this.layoutProfile,
  });

  final Size canvasSize;
  final Map<String, Rect> nodeRects;
  final List<_TreeEdge> parentChildEdges;
  final List<_TreeEdge> spouseEdges;
  final Set<String> visibleMemberIds;
  final _TreeLayoutProfile layoutProfile;
}

class _TreeEdge {
  const _TreeEdge({required this.fromId, required this.toId});

  final String fromId;
  final String toId;
}

class _TreeLayoutProfiler {
  _TreeLayoutProfiler({this.windowSize = 20});

  final int windowSize;
  final ListQueue<int> _samples = ListQueue<int>();

  _TreeLayoutProfile push(Duration elapsed) {
    final latestMs = elapsed.inMilliseconds;
    _samples.addLast(latestMs);
    while (_samples.length > windowSize) {
      _samples.removeFirst();
    }

    var total = 0;
    var peak = 0;
    for (final value in _samples) {
      total += value;
      if (value > peak) {
        peak = value;
      }
    }
    final average = _samples.isEmpty ? 0 : (total / _samples.length).round();

    return _TreeLayoutProfile(
      latestMs: latestMs,
      averageMs: average,
      peakMs: peak,
      sampleCount: _samples.length,
    );
  }
}

class _TreeLayoutProfile {
  const _TreeLayoutProfile({
    required this.latestMs,
    required this.averageMs,
    required this.peakMs,
    required this.sampleCount,
  });

  final int latestMs;
  final int averageMs;
  final int peakMs;
  final int sampleCount;
}
