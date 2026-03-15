import 'dart:async';
import 'dart:collection';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/services/performance_measurement_logger.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../clan/models/branch_draft.dart';
import '../../clan/models/clan_draft.dart';
import '../../clan/services/clan_repository.dart';
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

enum _GenealogyHonorBadge {
  giaTruong,
  dichTonGiaDinh,
  dichTonChi,
  dichTonHo,
  dichTonToc,
}

class _GenealogyWorkspacePageState extends State<GenealogyWorkspacePage>
    with TickerProviderStateMixin {
  static const _nodeWidth = 232.0;
  static const _nodeHeight = 146.0;
  static const _rowSpacing = 128.0;
  static const _columnSpacing = 48.0;
  static const _canvasPadding = 40.0;

  late final TransformationController _transformController;
  final _layoutProfiler = _TreeLayoutProfiler(windowSize: 20);
  final _performanceLogger = PerformanceMeasurementLogger(
    defaultSlowThreshold: const Duration(milliseconds: 120),
  );
  AnimationController? _centerAnimController;
  late final ClanRepository _clanRepository;

  late GenealogyScopeType _scopeType;
  GenealogyReadSegment? _segment;
  Object? _error;
  bool _isLoading = true;
  bool _isSubmittingAddClan = false;
  bool _isSubmittingAddBranch = false;

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
    _clanRepository = createDefaultClanRepository(session: widget.session);
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
      return AppLoadingState(
        message: l10n.pick(
          vi: 'Đang tải cây gia phả...',
          en: 'Loading family tree...',
        ),
      );
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
    final siblingOrdersByMember = _resolveSiblingOrders(segment.graph);
    final honorBadgesByMember = _resolveHonorBadges(
      segment.graph,
      siblingOrdersByMember,
    );
    final filteredRoots = _filteredRootEntries(segment);
    final rootEntriesForSelector = filteredRoots.isEmpty
        ? segment.rootEntries
        : filteredRoots;
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
            onAddGenealogyPressed: _isSubmittingAddClan
                ? null
                : _openAddPrivateGenealogySheet,
            onAddBranchPressed: _isSubmittingAddBranch
                ? null
                : _openAddPrivateBranchSheet,
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;

                  final parentControl = _DepthControl(
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
                  );
                  final childControl = _DepthControl(
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
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        parentControl,
                        const SizedBox(height: 10),
                        childControl,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: parentControl),
                      const SizedBox(width: 12),
                      Expanded(child: childControl),
                    ],
                  );
                },
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
                                      siblingOrderLabel: _siblingOrderLabel(
                                        l10n,
                                        siblingOrdersByMember[entry.key] ??
                                            segment
                                                .graph
                                                .membersById[entry.key]!
                                                .siblingOrder,
                                      ),
                                      honorBadges: _honorBadgeLabels(
                                        l10n,
                                        honorBadgesByMember[entry.key] ??
                                            const [],
                                      ),
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
                                            branches: segment.branches,
                                            siblingOrder:
                                                siblingOrdersByMember[member
                                                    .id] ??
                                                member.siblingOrder,
                                            honorBadges:
                                                honorBadgesByMember[member
                                                    .id] ??
                                                const [],
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
                                          _openMemberDetailPage(
                                            member: member,
                                            graph: segment.graph,
                                            branches: segment.branches,
                                            siblingOrder:
                                                siblingOrdersByMember[member
                                                    .id] ??
                                                member.siblingOrder,
                                            honorBadges:
                                                honorBadgesByMember[member
                                                    .id] ??
                                                const [],
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

      // Cached snapshots keep the workspace responsive, then we immediately
      // reconcile against Firestore to avoid stale production data.
      if (allowCached && segment.fromCache) {
        unawaited(_load(allowCached: false));
      }
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

  Future<void> _openAddPrivateGenealogySheet() async {
    if (_isSubmittingAddClan) {
      return;
    }
    final l10n = context.l10n;
    final initialName = l10n.pick(
      vi: 'Gia phả riêng ${widget.session.displayName}',
      en: '${widget.session.displayName} private tree',
    );
    final payload = await showModalBottomSheet<_AdditionalClanPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdditionalClanSheet(
        initialName: initialName,
        initialFounderName: widget.session.displayName,
      ),
    );
    if (payload == null) {
      return;
    }
    await _submitAdditionalClan(payload);
  }

  Future<void> _submitAdditionalClan(_AdditionalClanPayload payload) async {
    if (_isSubmittingAddClan) {
      return;
    }
    final l10n = context.l10n;
    setState(() => _isSubmittingAddClan = true);
    try {
      if (widget.session.isSandbox) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                l10n.pick(
                  vi: 'Môi trường thử nghiệm chưa hỗ trợ tạo thêm gia phả riêng.',
                  en: 'Sandbox mode does not support creating additional private genealogy yet.',
                ),
              ),
            ),
          );
        return;
      }

      final callable = FirebaseServices.functions.httpsCallable(
        'bootstrapClanWorkspace',
      );
      final response = await callable.call(<String, dynamic>{
        'name': payload.draft.name,
        'slug': payload.draft.slug,
        'description': payload.draft.description,
        'countryCode': payload.draft.countryCode,
        'founderName': payload.draft.founderName,
        'logoUrl': payload.draft.logoUrl,
        'allowExistingClan': true,
      });

      if (!mounted) {
        return;
      }
      final data = response.data;
      final createdClanId = data is Map
          ? (data['clanId'] as String? ?? '')
          : '';
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              createdClanId.isEmpty
                  ? l10n.pick(
                      vi: 'Đã tạo gia phả riêng. Bạn có thể chuyển qua clan mới ở bộ chuyển clan.',
                      en: 'Private genealogy created. You can switch to it from the clan switcher.',
                    )
                  : l10n.pick(
                      vi: 'Đã tạo gia phả riêng ($createdClanId). Bạn vẫn thuộc gia phả hiện tại.',
                      en: 'Private genealogy created ($createdClanId). You still remain in the current clan.',
                    ),
            ),
          ),
        );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error.code) {
        'already-exists' => l10n.pick(
          vi: 'Slug gia phả đã tồn tại. Vui lòng đổi slug khác.',
          en: 'Clan slug already exists. Please use a different slug.',
        ),
        'failed-precondition' => l10n.pick(
          vi: 'Không thể tạo gia phả riêng với trạng thái tài khoản hiện tại.',
          en: 'Cannot create private genealogy with the current account state.',
        ),
        _ =>
          error.message ??
              l10n.pick(
                vi: 'Không thể tạo gia phả riêng lúc này.',
                en: 'Could not create private genealogy right now.',
              ),
      };
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                vi: 'Không thể tạo gia phả riêng lúc này.',
                en: 'Could not create private genealogy right now.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAddClan = false);
      }
    }
  }

  Future<void> _openAddPrivateBranchSheet() async {
    if (_isSubmittingAddBranch) {
      return;
    }
    if ((widget.session.clanId ?? '').trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.pick(
                vi: 'Cần chọn gia phả đang hoạt động trước khi tạo nhánh riêng.',
                en: 'Please select an active clan before creating a private branch.',
              ),
            ),
          ),
        );
      return;
    }

    final payload = await showModalBottomSheet<_PrivateBranchPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PrivateBranchSheet(
        currentMemberId: widget.session.memberId,
        members: _segment?.members ?? const [],
      ),
    );
    if (payload == null) {
      return;
    }
    await _submitPrivateBranch(payload);
  }

  Future<void> _submitPrivateBranch(_PrivateBranchPayload payload) async {
    if (_isSubmittingAddBranch) {
      return;
    }
    setState(() => _isSubmittingAddBranch = true);
    try {
      await _clanRepository.saveBranch(
        session: widget.session,
        draft: BranchDraft(
          name: payload.name,
          code: payload.code,
          generationLevelHint: payload.generationLevelHint,
          leaderMemberId: payload.leaderMemberId,
          viceLeaderMemberId: payload.viceLeaderMemberId,
        ),
      );
      await _load(allowCached: false);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.pick(
                vi: 'Đã tạo nhánh riêng thành công.',
                en: 'Private branch created successfully.',
              ),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.pick(
                vi: 'Không thể tạo nhánh riêng. Vui lòng kiểm tra quyền hoặc thử lại.',
                en: 'Could not create private branch. Please verify permissions and try again.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAddBranch = false);
      }
    }
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
    _performanceLogger.logDuration(
      metric: 'genealogy.tree_scene_build',
      elapsed: stopwatch.elapsed,
      dimensions: {
        'nodes': visibleMemberIds.length,
        'edges': parentChildEdges.length + spouseEdges.length,
        'layout_latest_ms': layoutProfile.latestMs,
        'layout_average_ms': layoutProfile.averageMs,
        'layout_peak_ms': layoutProfile.peakMs,
        'layout_samples': layoutProfile.sampleCount,
      },
    );

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
    final allMembers = graph.membersById.keys.toSet();
    if (rootId.isEmpty || !graph.membersById.containsKey(rootId)) {
      return _applyVisibilityFilters(allMembers, rootId: rootId);
    }

    final visibleFromFocus = <String>{rootId};
    var ancestors = <String>{rootId};
    for (var level = 0; level < _ancestorDepth; level++) {
      final next = <String>{};
      for (final memberId in ancestors) {
        for (final parentId in graph.parentsOf(memberId)) {
          if (visibleFromFocus.add(parentId)) {
            next.add(parentId);
          }
          visibleFromFocus.addAll(graph.spousesOf(parentId));
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
          if (visibleFromFocus.add(childId)) {
            next.add(childId);
          }
          visibleFromFocus.addAll(graph.spousesOf(childId));
        }
      }
      descendants = next;
      if (descendants.isEmpty) {
        break;
      }
    }

    for (final memberId in visibleFromFocus.toList()) {
      visibleFromFocus.addAll(graph.spousesOf(memberId));
    }

    final shouldShowScopeCoverage =
        _displayPreset == _TreeDisplayPreset.coverage;
    final baseVisible = shouldShowScopeCoverage ? allMembers : visibleFromFocus;
    return _applyVisibilityFilters(baseVisible, rootId: rootId);
  }

  Set<String> _applyVisibilityFilters(
    Set<String> baseVisible, {
    required String rootId,
  }) {
    if (_branchFilterId == null && _statusFilter == _MemberStatusFilter.all) {
      return baseVisible;
    }

    final graph = _segment?.graph;
    if (graph == null) {
      return baseVisible;
    }

    final filtered = <String>{};
    for (final memberId in baseVisible) {
      final member = graph.membersById[memberId];
      if (member == null) {
        continue;
      }
      if (_matchesViewFilters(member)) {
        filtered.add(memberId);
      }
    }

    if (rootId.isNotEmpty && baseVisible.contains(rootId)) {
      filtered.add(rootId);
    }
    if (_selectedMemberId != null && baseVisible.contains(_selectedMemberId!)) {
      filtered.add(_selectedMemberId!);
    }

    if (filtered.isEmpty && baseVisible.isNotEmpty) {
      filtered.add(rootId.isNotEmpty ? rootId : baseVisible.first);
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
    required List<BranchProfile> branches,
    required int? siblingOrder,
    required List<_GenealogyHonorBadge> honorBadges,
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
                  label: l10n.pick(
                    vi: 'Thứ tự anh/chị/em',
                    en: 'Sibling order',
                  ),
                  value:
                      _siblingOrderLabel(l10n, siblingOrder) ??
                      l10n.memberFieldUnset,
                ),
                _FactLine(
                  label: l10n.pick(vi: 'Danh vị', en: 'Honor badges'),
                  value: _honorBadgeLabels(l10n, honorBadges).isEmpty
                      ? l10n.memberFieldUnset
                      : _honorBadgeLabels(l10n, honorBadges).join(' • '),
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
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  key: const Key('genealogy-open-member-detail-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(
                      _openMemberDetailPage(
                        member: member,
                        graph: graph,
                        branches: branches,
                        siblingOrder: siblingOrder,
                        honorBadges: honorBadges,
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    l10n.pick(
                      vi: 'Mở chi tiết thành viên',
                      en: 'Open member details',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMemberDetailPage({
    required MemberProfile member,
    required GenealogyGraph graph,
    required List<BranchProfile> branches,
    required int? siblingOrder,
    required List<_GenealogyHonorBadge> honorBadges,
  }) async {
    final l10n = context.l10n;
    final ancestry = GenealogyGraphAlgorithms.buildAncestryPath(
      graph: graph,
      memberId: member.id,
    );
    final descendants = GenealogyGraphAlgorithms.buildDescendantsTraversal(
      graph: graph,
      memberId: member.id,
      maxDepth: 12,
    );
    var branchName = member.branchId;
    for (final branch in branches) {
      if (branch.id == member.branchId && branch.name.trim().isNotEmpty) {
        branchName = branch.name;
        break;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _GenealogyMemberDetailPage(
            member: member,
            branchName: branchName,
            siblingOrderLabel: _siblingOrderLabel(l10n, siblingOrder),
            honorBadges: _honorBadgeLabels(l10n, honorBadges),
            generationLabel:
                graph.generationLabels[member.id]?.compactLabel ??
                'G${member.generation}',
            ancestryCount: ancestry.length,
            descendantCount: descendants.length,
            parentCount: graph.parentsOf(member.id).length,
            childCount: graph.childrenOf(member.id).length,
            spouseCount: graph.spousesOf(member.id).length,
            isAlive: _isMemberAlive(member),
            aliveStatusLabel: l10n.genealogyMemberAliveStatus,
            deceasedStatusLabel: l10n.genealogyMemberDeceasedStatus,
          );
        },
      ),
    );
  }

  int _compareMembersBySeniority(MemberProfile left, MemberProfile right) {
    final byBirthDate = _compareNullableDate(
      _tryParseBirthDate(left.birthDate),
      _tryParseBirthDate(right.birthDate),
    );
    if (byBirthDate != 0) {
      return byBirthDate;
    }
    final byGeneration = left.generation.compareTo(right.generation);
    if (byGeneration != 0) {
      return byGeneration;
    }
    final byName = left.fullName.toLowerCase().compareTo(
      right.fullName.toLowerCase(),
    );
    if (byName != 0) {
      return byName;
    }
    return left.id.compareTo(right.id);
  }

  DateTime? _tryParseBirthDate(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  int _compareNullableDate(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  }

  String? _siblingOrderLabel(AppLocalizations l10n, int? siblingOrder) {
    if (siblingOrder == null || siblingOrder <= 0) {
      return null;
    }
    if (siblingOrder == 1) {
      return l10n.pick(vi: 'Con cả', en: 'First-born child');
    }
    return l10n.pick(vi: 'Con thứ $siblingOrder', en: 'Child #$siblingOrder');
  }

  Map<String, int> _resolveSiblingOrders(GenealogyGraph graph) {
    final orders = <String, int>{};
    for (final entry in graph.childMap.entries) {
      final rankedChildren =
          entry.value
              .map((memberId) => graph.membersById[memberId])
              .whereType<MemberProfile>()
              .toList(growable: false)
            ..sort(_compareMembersBySeniority);
      for (var index = 0; index < rankedChildren.length; index++) {
        orders[rankedChildren[index].id] = index + 1;
      }
    }
    for (final member in graph.membersById.values) {
      if (orders.containsKey(member.id)) {
        continue;
      }
      final persisted = member.siblingOrder;
      if (persisted != null && persisted > 0) {
        orders[member.id] = persisted;
      }
    }
    return orders;
  }

  Map<String, List<_GenealogyHonorBadge>> _resolveHonorBadges(
    GenealogyGraph graph,
    Map<String, int> siblingOrders,
  ) {
    final badges = <String, Set<_GenealogyHonorBadge>>{};
    void addBadge(String memberId, _GenealogyHonorBadge badge) {
      badges.putIfAbsent(memberId, () => <_GenealogyHonorBadge>{}).add(badge);
    }

    final aliveMembers = graph.membersById.values
        .where(_isMemberAlive)
        .toList(growable: false);
    if (aliveMembers.isEmpty) {
      return const {};
    }

    final rootCandidates =
        aliveMembers
            .where((member) => graph.parentsOf(member.id).isEmpty)
            .toList(growable: false)
          ..sort(_compareMembersBySeniority);
    if (rootCandidates.isNotEmpty) {
      addBadge(rootCandidates.first.id, _GenealogyHonorBadge.giaTruong);
    }

    final clanHeirCandidates =
        aliveMembers
            .where((member) => graph.parentsOf(member.id).isNotEmpty)
            .where(
              (member) =>
                  (siblingOrders[member.id] ?? member.siblingOrder) == 1,
            )
            .toList(growable: false)
          ..sort(_compareMembersBySeniority);
    if (clanHeirCandidates.isNotEmpty) {
      addBadge(clanHeirCandidates.first.id, _GenealogyHonorBadge.dichTonToc);
    }

    final lineageHeirCandidates = <String, List<MemberProfile>>{};
    for (final member in clanHeirCandidates) {
      final lineageKey = _familyNameToken(member.fullName);
      if (lineageKey == null) {
        continue;
      }
      lineageHeirCandidates
          .putIfAbsent(lineageKey, () => <MemberProfile>[])
          .add(member);
    }
    for (final entry in lineageHeirCandidates.entries) {
      final ranked = entry.value..sort(_compareMembersBySeniority);
      if (ranked.isNotEmpty) {
        addBadge(ranked.first.id, _GenealogyHonorBadge.dichTonHo);
      }
    }

    final branchHeirCandidates = <String, List<MemberProfile>>{};
    for (final member in clanHeirCandidates) {
      branchHeirCandidates
          .putIfAbsent(member.branchId, () => <MemberProfile>[])
          .add(member);
    }
    for (final entry in branchHeirCandidates.entries) {
      final ranked = entry.value..sort(_compareMembersBySeniority);
      if (ranked.isNotEmpty) {
        addBadge(ranked.first.id, _GenealogyHonorBadge.dichTonChi);
      }
    }

    for (final entry in graph.childMap.entries) {
      final rankedChildren =
          entry.value
              .map((memberId) => graph.membersById[memberId])
              .whereType<MemberProfile>()
              .where(_isMemberAlive)
              .toList(growable: false)
            ..sort(_compareMembersBySeniority);
      if (rankedChildren.isNotEmpty) {
        addBadge(rankedChildren.first.id, _GenealogyHonorBadge.dichTonGiaDinh);
      }
    }

    final priority = {
      _GenealogyHonorBadge.giaTruong: 0,
      _GenealogyHonorBadge.dichTonToc: 1,
      _GenealogyHonorBadge.dichTonHo: 2,
      _GenealogyHonorBadge.dichTonChi: 3,
      _GenealogyHonorBadge.dichTonGiaDinh: 4,
    };
    return {
      for (final entry in badges.entries)
        entry.key: entry.value.toList(growable: false)
          ..sort(
            (left, right) =>
                (priority[left] ?? 99).compareTo(priority[right] ?? 99),
          ),
    };
  }

  List<String> _honorBadgeLabels(
    AppLocalizations l10n,
    List<_GenealogyHonorBadge> badges,
  ) {
    return badges.map((badge) => _honorBadgeLabel(l10n, badge)).toList();
  }

  String _honorBadgeLabel(AppLocalizations l10n, _GenealogyHonorBadge badge) {
    return switch (badge) {
      _GenealogyHonorBadge.giaTruong => l10n.pick(
        vi: 'Gia trưởng',
        en: 'Family patriarch',
      ),
      _GenealogyHonorBadge.dichTonGiaDinh => l10n.pick(
        vi: 'Đích tôn gia đình',
        en: 'Primary family heir',
      ),
      _GenealogyHonorBadge.dichTonChi => l10n.pick(
        vi: 'Đích tôn chi',
        en: 'Primary branch heir',
      ),
      _GenealogyHonorBadge.dichTonHo => l10n.pick(
        vi: 'Đích tôn họ',
        en: 'Primary lineage heir',
      ),
      _GenealogyHonorBadge.dichTonToc => l10n.pick(
        vi: 'Đích tôn tộc',
        en: 'Primary clan heir',
      ),
    };
  }

  String? _familyNameToken(String? fullName) {
    final parts = (fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }
    return parts.first.toLowerCase();
  }

  GenealogyScopeType _resolveInitialScope(AuthSession session) {
    final role = GovernanceRoleMatrix.normalizeRole(session.primaryRole);
    if (role == GovernanceRoles.superAdmin ||
        role == GovernanceRoles.clanAdmin ||
        role == GovernanceRoles.adminSupport) {
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

class _AdditionalClanPayload {
  const _AdditionalClanPayload({required this.draft});

  final ClanDraft draft;
}

class _PrivateBranchPayload {
  const _PrivateBranchPayload({
    required this.name,
    required this.code,
    required this.generationLevelHint,
    required this.leaderMemberId,
    required this.viceLeaderMemberId,
  });

  final String name;
  final String code;
  final int generationLevelHint;
  final String? leaderMemberId;
  final String? viceLeaderMemberId;
}

class _AdditionalClanSheet extends StatefulWidget {
  const _AdditionalClanSheet({
    required this.initialName,
    required this.initialFounderName,
  });

  final String initialName;
  final String initialFounderName;

  @override
  State<_AdditionalClanSheet> createState() => _AdditionalClanSheetState();
}

class _AdditionalClanSheetState extends State<_AdditionalClanSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _founderController;
  late final TextEditingController _countryCodeController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _slugController = TextEditingController();
    _descriptionController = TextEditingController();
    _founderController = TextEditingController(text: widget.initialFounderName);
    _countryCodeController = TextEditingController(text: 'VN');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _founderController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) {
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    setState(() => _isSubmitting = true);
    final name = _nameController.text.trim();
    final customSlug = _slugController.text.trim();
    final slug = customSlug.isEmpty
        ? _normalizeSlugInput(name)
        : _normalizeSlugInput(customSlug);
    final draft = ClanDraft(
      name: name,
      slug: slug,
      description: _descriptionController.text.trim(),
      countryCode: _countryCodeController.text.trim().toUpperCase(),
      founderName: _founderController.text.trim(),
      logoUrl: '',
    );
    Navigator.of(context).pop(_AdditionalClanPayload(draft: draft));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'Thêm gia phả riêng',
                    en: 'Create private genealogy',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pick(
                    vi: 'Tạo một gia phả độc lập để quản lý nhánh gia đình nhỏ, nhưng vẫn giữ liên kết với gia phả hiện tại.',
                    en: 'Create an isolated genealogy for your smaller family branch while keeping your current clan membership.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Tên gia phả',
                      en: 'Genealogy name',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return l10n.pick(
                        vi: 'Vui lòng nhập tên gia phả.',
                        en: 'Please provide genealogy name.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Slug (tùy chọn)',
                      en: 'Slug (optional)',
                    ),
                    helperText: l10n.pick(
                      vi: 'Để trống để hệ thống tự tạo từ tên.',
                      en: 'Leave empty to auto-generate from name.',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Mô tả', en: 'Description'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _founderController,
                        decoration: InputDecoration(
                          labelText: l10n.pick(
                            vi: 'Người đại diện',
                            en: 'Founder',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 108,
                      child: TextFormField(
                        controller: _countryCodeController,
                        decoration: InputDecoration(
                          labelText: l10n.pick(vi: 'Quốc gia', en: 'Country'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: Text(
                          l10n.pick(
                            vi: 'Tạo gia phả riêng',
                            en: 'Create private tree',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateBranchSheet extends StatefulWidget {
  const _PrivateBranchSheet({
    required this.currentMemberId,
    required this.members,
  });

  final String? currentMemberId;
  final List<MemberProfile> members;

  @override
  State<_PrivateBranchSheet> createState() => _PrivateBranchSheetState();
}

class _PrivateBranchSheetState extends State<_PrivateBranchSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late int _generationHint;
  late bool _setCurrentAsLeader;
  String? _leaderMemberId;
  String? _viceLeaderMemberId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _generationHint = 1;
    _setCurrentAsLeader = (widget.currentMemberId ?? '').trim().isNotEmpty;
    _leaderMemberId = _setCurrentAsLeader ? widget.currentMemberId : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) {
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    setState(() => _isSubmitting = true);
    final name = _nameController.text.trim();
    final rawCode = _codeController.text.trim();
    final code = rawCode.isEmpty
        ? _normalizeBranchCodeInput(name)
        : _normalizeBranchCodeInput(rawCode);
    final payload = _PrivateBranchPayload(
      name: name,
      code: code,
      generationLevelHint: _generationHint,
      leaderMemberId: _leaderMemberId,
      viceLeaderMemberId: _viceLeaderMemberId,
    );
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sortedMembers = [...widget.members]
      ..sort(
        (left, right) =>
            left.fullName.toLowerCase().compareTo(right.fullName.toLowerCase()),
      );
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'Thêm nhánh riêng',
                    en: 'Create private branch',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pick(
                    vi: 'Nhánh riêng giúp gia đình nhỏ quản trị thành viên, sự kiện và quỹ độc lập.',
                    en: 'A private branch helps your small family manage members, events, and funds independently.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Tên nhánh', en: 'Branch name'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return l10n.pick(
                        vi: 'Vui lòng nhập tên nhánh.',
                        en: 'Please provide branch name.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Mã nhánh', en: 'Branch code'),
                    helperText: l10n.pick(
                      vi: 'Để trống để tự tạo mã nhánh.',
                      en: 'Leave empty to auto-generate branch code.',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _setCurrentAsLeader,
                  title: Text(
                    l10n.pick(
                      vi: 'Đặt tôi làm trưởng nhánh',
                      en: 'Set me as branch lead',
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _setCurrentAsLeader = value;
                      _leaderMemberId = value ? widget.currentMemberId : null;
                      if (_viceLeaderMemberId == _leaderMemberId) {
                        _viceLeaderMemberId = null;
                      }
                    });
                  },
                ),
                if (!_setCurrentAsLeader) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _leaderMemberId,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Trưởng nhánh',
                        en: 'Branch lead',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          l10n.pick(vi: 'Chưa chọn', en: 'Not selected'),
                        ),
                      ),
                      for (final member in sortedMembers)
                        DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(member.fullName),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _leaderMemberId = value;
                        if (_viceLeaderMemberId == value) {
                          _viceLeaderMemberId = null;
                        }
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _viceLeaderMemberId,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Phó nhánh', en: 'Deputy lead'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.pick(vi: 'Không có', en: 'None')),
                    ),
                    for (final member in sortedMembers)
                      if (member.id != _leaderMemberId)
                        DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(member.fullName),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() => _viceLeaderMemberId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _generationHint,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Đời ưu tiên hiển thị',
                      en: 'Generation hint',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (var value = 1; value <= 12; value++)
                      DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _generationHint = value);
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.call_split_outlined),
                        label: Text(
                          l10n.pick(vi: 'Tạo nhánh riêng', en: 'Create branch'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _normalizeSlugInput(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalized.length >= 3) {
    return normalized;
  }
  if (normalized.isEmpty) {
    return 'gia-pha-rieng';
  }
  return normalized.padRight(3, 'x');
}

String _normalizeBranchCodeInput(String value) {
  final normalized = value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (normalized.isNotEmpty) {
    return normalized;
  }
  return 'PRIVATE_BRANCH';
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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.genealogyWorkspaceTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const Key('genealogy-refresh-icon'),
                onPressed: onRefresh,
                tooltip: l10n.genealogyRefreshAction,
                visualDensity: VisualDensity.compact,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
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
            mainAxisExtent: 142,
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
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
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
    required this.onAddGenealogyPressed,
    required this.onAddBranchPressed,
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
  final VoidCallback? onAddGenealogyPressed;
  final VoidCallback? onAddBranchPressed;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final branchItems = branches.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconOnlyChips = constraints.maxWidth < 460;
            final denseChips = constraints.maxWidth < 740;
            final chipDensity = denseChips
                ? VisualDensity.compact
                : VisualDensity.standard;
            final chipPadding = EdgeInsets.symmetric(
              horizontal: iconOnlyChips ? 10 : 14,
              vertical: 10,
            );
            final selectedChipColor = colorScheme.secondaryContainer;
            final unselectedChipColor = colorScheme.surfaceContainerHighest;
            final chipLabelStyle = theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'Bộ lọc hiển thị cây',
                    en: 'Tree display controls',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _chipRow(
                  iconOnly: iconOnlyChips,
                  children: [
                    ChoiceChip(
                      key: const Key('tree-preset-focused'),
                      selected: displayPreset == _TreeDisplayPreset.focused,
                      showCheckmark: !iconOnlyChips,
                      visualDensity: chipDensity,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      padding: chipPadding,
                      tooltip: l10n.pick(
                        vi: 'Hiển thị tập trung quanh thành viên trung tâm',
                        en: 'Focused view around center member',
                      ),
                      label: _chipLabel(
                        iconOnly: iconOnlyChips,
                        icon: Icons.filter_center_focus,
                        label: l10n.pick(vi: 'Tập trung', en: 'Focused'),
                        style: chipLabelStyle,
                      ),
                      onSelected: (_) =>
                          onDisplayPresetChanged(_TreeDisplayPreset.focused),
                    ),
                    ChoiceChip(
                      key: const Key('tree-preset-balanced'),
                      selected: displayPreset == _TreeDisplayPreset.balanced,
                      showCheckmark: !iconOnlyChips,
                      visualDensity: chipDensity,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      padding: chipPadding,
                      tooltip: l10n.pick(
                        vi: 'Hiển thị cân bằng tổ tiên và hậu duệ',
                        en: 'Balanced ancestors and descendants view',
                      ),
                      label: _chipLabel(
                        iconOnly: iconOnlyChips,
                        icon: Icons.align_horizontal_center,
                        label: l10n.pick(vi: 'Cân bằng', en: 'Balanced'),
                        style: chipLabelStyle,
                      ),
                      onSelected: (_) =>
                          onDisplayPresetChanged(_TreeDisplayPreset.balanced),
                    ),
                    ChoiceChip(
                      key: const Key('tree-preset-coverage'),
                      selected: displayPreset == _TreeDisplayPreset.coverage,
                      showCheckmark: !iconOnlyChips,
                      visualDensity: chipDensity,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      padding: chipPadding,
                      tooltip: l10n.pick(
                        vi: 'Hiển thị phủ rộng để thấy nhiều thành viên',
                        en: 'Coverage mode to show more members',
                      ),
                      label: _chipLabel(
                        iconOnly: iconOnlyChips,
                        icon: Icons.open_in_full,
                        label: l10n.pick(vi: 'Độ phủ rộng', en: 'Coverage'),
                        style: chipLabelStyle,
                      ),
                      onSelected: (_) =>
                          onDisplayPresetChanged(_TreeDisplayPreset.coverage),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _chipRow(
                  iconOnly: iconOnlyChips,
                  children: [
                    FilterChip(
                      key: const Key('tree-status-all'),
                      selected: statusFilter == _MemberStatusFilter.all,
                      showCheckmark: !iconOnlyChips,
                      visualDensity: chipDensity,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      padding: chipPadding,
                      tooltip: l10n.pick(
                        vi: 'Hiển thị tất cả thành viên',
                        en: 'Show all members',
                      ),
                      label: _chipLabel(
                        iconOnly: iconOnlyChips,
                        icon: Icons.people_outline,
                        label: l10n.pick(vi: 'Tất cả', en: 'All'),
                        style: chipLabelStyle,
                      ),
                      onSelected: (_) =>
                          onStatusFilterChanged(_MemberStatusFilter.all),
                    ),
                    FilterChip(
                      key: const Key('tree-status-alive'),
                      selected: statusFilter == _MemberStatusFilter.alive,
                      showCheckmark: !iconOnlyChips,
                      visualDensity: chipDensity,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      padding: chipPadding,
                      tooltip: l10n.pick(
                        vi: 'Chỉ hiển thị thành viên còn sống',
                        en: 'Show alive members only',
                      ),
                      label: _chipLabel(
                        iconOnly: iconOnlyChips,
                        icon: Icons.favorite_outline,
                        label: l10n.pick(vi: 'Còn sống', en: 'Alive'),
                        style: chipLabelStyle,
                      ),
                      onSelected: (_) =>
                          onStatusFilterChanged(_MemberStatusFilter.alive),
                    ),
                    FilterChip(
                      key: const Key('tree-status-deceased'),
                      selected: statusFilter == _MemberStatusFilter.deceased,
                      showCheckmark: !iconOnlyChips,
                      visualDensity: chipDensity,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      padding: chipPadding,
                      tooltip: l10n.pick(
                        vi: 'Chỉ hiển thị thành viên đã mất',
                        en: 'Show deceased members only',
                      ),
                      label: _chipLabel(
                        iconOnly: iconOnlyChips,
                        icon: Icons.history,
                        label: l10n.pick(vi: 'Đã mất', en: 'Deceased'),
                        style: chipLabelStyle,
                      ),
                      onSelected: (_) =>
                          onStatusFilterChanged(_MemberStatusFilter.deceased),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, actionConstraints) {
                    final compactActions = actionConstraints.maxWidth < 560;
                    final addGenealogyLabel = l10n.pick(
                      vi: 'Thêm gia phả',
                      en: 'Add genealogy',
                    );
                    final addBranchLabel = l10n.pick(
                      vi: 'Thêm nhánh',
                      en: 'Add branch',
                    );

                    final addGenealogyButton = FilledButton.tonalIcon(
                      key: const Key('genealogy-action-add-tree'),
                      onPressed: onAddGenealogyPressed,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: Text(
                        addGenealogyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    );
                    final addBranchButton = OutlinedButton.icon(
                      key: const Key('genealogy-action-add-branch'),
                      onPressed: onAddBranchPressed,
                      icon: const Icon(Icons.call_split_outlined),
                      label: Text(
                        addBranchLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    );

                    if (compactActions) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: addGenealogyButton,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: addBranchButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: addGenealogyButton),
                        const SizedBox(width: 8),
                        Expanded(child: addBranchButton),
                      ],
                    );
                  },
                ),
                if (branchItems.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.pick(vi: 'Lọc theo chi', en: 'Filter branch'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    key: const Key('tree-branch-filter'),
                    initialValue: selectedBranchId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
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
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chipRow({required bool iconOnly, required List<Widget> children}) {
    if (iconOnly) {
      return _equalChipRow(children: children);
    }
    return _horizontalChipRow(children: children);
  }

  Widget _equalChipRow({required List<Widget> children}) {
    return Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(
            child: SizedBox(width: double.infinity, child: children[index]),
          ),
          if (index < children.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _horizontalChipRow({required List<Widget> children}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            children[index],
          ],
        ],
      ),
    );
  }

  Widget _chipLabel({
    required bool iconOnly,
    required IconData icon,
    required String label,
    TextStyle? style,
  }) {
    if (iconOnly) {
      return Icon(icon, size: 18);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: style,
        ),
      ],
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              key: Key('genealogy-depth-$id-decrease'),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: canDecrease ? onDecrease : null,
              icon: const Icon(Icons.remove_rounded),
              color: colorScheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                minimumSize: const Size(34, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: l10n.pick(vi: 'Giảm $label', en: 'Decrease $label'),
            ),
            Expanded(
              child: Text(
                '$label $depth',
                key: Key('genealogy-depth-$id-value'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            IconButton(
              key: Key('genealogy-depth-$id-increase'),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: canIncrease ? onIncrease : null,
              icon: const Icon(Icons.add_rounded),
              color: colorScheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                minimumSize: const Size(34, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: l10n.pick(vi: 'Tăng $label', en: 'Increase $label'),
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
    final l10n = context.l10n;
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
              tooltip: l10n.pick(vi: 'Thu nhỏ cây', en: 'Zoom out tree'),
            ),
            IconButton(
              key: const Key('tree-zoom-in'),
              visualDensity: VisualDensity.compact,
              onPressed: onZoomIn,
              icon: const Icon(Icons.add),
              tooltip: l10n.pick(vi: 'Phóng to cây', en: 'Zoom in tree'),
            ),
            IconButton(
              key: const Key('tree-zoom-reset'),
              visualDensity: VisualDensity.compact,
              onPressed: onReset,
              icon: const Icon(Icons.filter_center_focus),
              tooltip: l10n.pick(
                vi: 'Đặt lại vị trí cây',
                en: 'Reset tree view',
              ),
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
    required this.siblingOrderLabel,
    required this.honorBadges,
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
  final String? siblingOrderLabel;
  final List<String> honorBadges;
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
                      key: Key('tree-node-info-${member.id}'),
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
                        if (siblingOrderLabel != null) ...[
                          _MiniFactChip(
                            icon: Icons.format_list_numbered,
                            label: siblingOrderLabel!,
                          ),
                          const SizedBox(width: 8),
                        ],
                        for (final badge in honorBadges.take(2)) ...[
                          _MiniFactChip(
                            icon: Icons.workspace_premium_outlined,
                            label: badge,
                          ),
                          const SizedBox(width: 8),
                        ],
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

class _GenealogyMemberDetailPage extends StatelessWidget {
  const _GenealogyMemberDetailPage({
    required this.member,
    required this.branchName,
    required this.siblingOrderLabel,
    required this.honorBadges,
    required this.generationLabel,
    required this.parentCount,
    required this.childCount,
    required this.spouseCount,
    required this.ancestryCount,
    required this.descendantCount,
    required this.isAlive,
    required this.aliveStatusLabel,
    required this.deceasedStatusLabel,
  });

  final MemberProfile member;
  final String branchName;
  final String? siblingOrderLabel;
  final List<String> honorBadges;
  final String generationLabel;
  final int parentCount;
  final int childCount;
  final int spouseCount;
  final int ancestryCount;
  final int descendantCount;
  final bool isAlive;
  final String aliveStatusLabel;
  final String deceasedStatusLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberDetailTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      child: Text(
                        member.initials,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            member.nickName.trim().isEmpty
                                ? l10n.memberDetailNoNickname
                                : member.nickName,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MiniFactChip(
                                icon: Icons.account_tree_outlined,
                                label: branchName,
                              ),
                              _MiniFactChip(
                                icon: Icons.layers_outlined,
                                label: generationLabel,
                              ),
                              if (siblingOrderLabel != null)
                                _MiniFactChip(
                                  icon: Icons.format_list_numbered,
                                  label: siblingOrderLabel!,
                                ),
                              _StatusChip(
                                isAlive: isAlive,
                                aliveStatusLabel: aliveStatusLabel,
                                deceasedStatusLabel: deceasedStatusLabel,
                              ),
                              for (final badge in honorBadges)
                                _MiniFactChip(
                                  icon: Icons.workspace_premium_outlined,
                                  label: badge,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.memberDetailSummaryTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FactLine(
                      label: l10n.memberFullNameLabel,
                      value: member.fullName,
                    ),
                    _FactLine(
                      label: l10n.memberNicknameLabel,
                      value: member.nickName.trim().isEmpty
                          ? l10n.memberFieldUnset
                          : member.nickName,
                    ),
                    _FactLine(
                      label: l10n.memberPhoneLabel,
                      value: member.phoneE164 ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.memberEmailLabel,
                      value: member.email ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.memberGenderLabel,
                      value: _memberGenderLabel(l10n, member.gender),
                    ),
                    _FactLine(
                      label: l10n.pick(
                        vi: 'Thứ tự anh/chị/em',
                        en: 'Sibling order',
                      ),
                      value: siblingOrderLabel ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.pick(vi: 'Danh vị', en: 'Honor badges'),
                      value: honorBadges.isEmpty
                          ? l10n.memberFieldUnset
                          : honorBadges.join(' • '),
                    ),
                    _FactLine(
                      label: l10n.memberBirthDateLabel,
                      value: member.birthDate ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.memberDeathDateLabel,
                      value: member.deathDate ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.memberJobTitleLabel,
                      value: member.jobTitle ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.memberAddressLabel,
                      value: member.addressText ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.memberBioLabel,
                      value: member.bio ?? l10n.memberFieldUnset,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(
                        vi: 'Tóm tắt quan hệ',
                        en: 'Relationship summary',
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FactLine(
                      label: l10n.genealogyParentCountLabel,
                      value: '$parentCount',
                    ),
                    _FactLine(
                      label: l10n.genealogyChildCountLabel,
                      value: '$childCount',
                    ),
                    _FactLine(
                      label: l10n.genealogySpouseCountLabel,
                      value: '$spouseCount',
                    ),
                    _FactLine(
                      label: l10n.genealogyDescendantCountLabel,
                      value: '$descendantCount',
                    ),
                    _FactLine(
                      label: l10n.genealogyAncestryPathTitle,
                      value: '$ancestryCount',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _memberGenderLabel(AppLocalizations l10n, String? value) {
  final normalized = value?.trim().toLowerCase();
  return switch (normalized) {
    'male' => l10n.memberGenderMale,
    'female' => l10n.memberGenderFemale,
    'other' => l10n.memberGenderOther,
    _ => l10n.memberGenderUnspecified,
  };
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
