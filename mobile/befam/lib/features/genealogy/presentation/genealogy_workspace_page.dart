import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/theme/app_ui_tokens.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../../core/services/kinship_title_resolver.dart';
import '../../../core/services/performance_measurement_logger.dart';
import '../../../core/widgets/address_action_tools.dart';
import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_compact_controls.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/member_phone_action.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../clan/models/branch_draft.dart';
import '../../clan/models/clan_draft.dart';
import '../../clan/services/clan_repository.dart';
import '../../member/models/member_profile.dart';
import '../../member/presentation/member_workspace_page.dart';
import '../../member/services/member_repository.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/onboarding_scope.dart';
import '../models/genealogy_graph.dart';
import '../models/genealogy_read_segment.dart';
import '../models/genealogy_scope.dart';
import '../services/genealogy_graph_algorithms.dart';
import '../services/genealogy_read_repository.dart';

class GenealogyWorkspacePage extends StatefulWidget {
  const GenealogyWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.clanRepository,
  });

  final AuthSession session;
  final GenealogyReadRepository repository;
  final ClanRepository? clanRepository;

  @override
  State<GenealogyWorkspacePage> createState() => _GenealogyWorkspacePageState();
}

enum _GenealogyHonorBadge {
  giaTruong,
  dichTonGiaDinh,
  dichTonChi,
  dichTonHo,
  dichTonToc,
}

enum _TreeExportPaperSize { a3, a2 }

class _GenealogyWorkspacePageState extends State<GenealogyWorkspacePage>
    with TickerProviderStateMixin {
  static const _minTreeScale = 0.22;
  static const _maxTreeScale = 2.8;
  static const _nodeWidth = 232.0;
  static const _nodeHeight = 146.0;
  static const _rowSpacing = 136.0;
  static const _columnSpacing = 58.0;
  static const _canvasPadding = 40.0;
  static const _maxVisibleMembers = 320;

  final GlobalKey _treePrintBoundaryKey = GlobalKey();
  final GlobalKey _treeCanvasPrintBoundaryKey = GlobalKey();
  late final TransformationController _transformController;
  final _layoutProfiler = _TreeLayoutProfiler(windowSize: 20);
  final _performanceLogger = PerformanceMeasurementLogger(
    defaultSlowThreshold: const Duration(milliseconds: 120),
  );
  AnimationController? _centerAnimController;
  late final ClanRepository _clanRepository;
  late final OnboardingCoordinator _onboardingCoordinator;

  late GenealogyScopeType _scopeType;
  GenealogyReadSegment? _segment;
  Object? _error;
  bool _isLoading = true;
  bool _isSubmittingAddClan = false;
  bool _isSubmittingAddBranch = false;
  bool _showAddFabMenu = false;
  bool _shouldAutoFitTree = true;
  bool _hasScheduledOnboarding = false;

  String? _rootMemberId;
  String? _selectedMemberId;
  _TreeScene? _cachedScene;
  GenealogyReadSegment? _cachedSceneSegment;
  String _cachedSceneRootId = '';
  GenealogyGraph? _cachedDerivedGraph;
  String? _cachedDerivedViewerId;
  Map<String, int?>? _cachedRelativeLevelsByCurrentUser;
  Map<String, int>? _cachedSiblingOrdersByMember;
  Map<String, List<_GenealogyHonorBadge>>? _cachedHonorBadgesByMember;
  Map<String, int>? _cachedHonorBadgesSiblingOrders;

  @override
  void initState() {
    super.initState();
    _scopeType = GenealogyScopeType.clan;
    _transformController = TransformationController();
    _clanRepository =
        widget.clanRepository ??
        createDefaultClanRepository(session: widget.session);
    _onboardingCoordinator = createDefaultOnboardingCoordinator(
      session: widget.session,
    );
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant GenealogyWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _onboardingCoordinator.updateSession(widget.session);
      _hasScheduledOnboarding = false;
    }
  }

  @override
  void dispose() {
    _centerAnimController?.dispose();
    _transformController.dispose();
    unawaited(_onboardingCoordinator.interrupt());
    _onboardingCoordinator.dispose();
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
    final relativeLevelsByCurrentUser = _resolveRelativeLevelsByCurrentUser(
      segment.graph,
    );
    final hasClanContext = (widget.session.clanId ?? '').trim().isNotEmpty;
    final canAddBranchAction =
        hasClanContext &&
        GovernanceRoleMatrix.canManageBranches(widget.session);
    final canAddMemberAction =
        hasClanContext && GovernanceRoleMatrix.canManageMembers(widget.session);
    final viewer = _viewerMemberForGraph(segment.graph);
    final siblingOrdersByMember = _resolveSiblingOrders(segment.graph);
    final honorBadgesByMember = _resolveHonorBadges(
      segment.graph,
      siblingOrdersByMember,
    );

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _load(allowCached: false),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              _LandingCard(
                scopeType: _scopeType,
                isLoading: _isLoading,
                isFromCache: segment.fromCache,
                onRefresh: _isLoading ? null : () => _load(allowCached: false),
                onScopeChanged: _updateScope,
                allowBranchScope: false,
                session: widget.session,
                memberCount: segment.graph.membersById.length,
                branchCount: segment.branches.length,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 620,
                child: RepaintBoundary(
                  key: _treePrintBoundaryKey,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewport = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        if (_shouldAutoFitTree && scene.nodeRects.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || !_shouldAutoFitTree) {
                              return;
                            }
                            _shouldAutoFitTree = false;
                            _fitTreeToViewport(
                              scene: scene,
                              viewport: viewport,
                              focusMemberId: _rootMemberId,
                            );
                          });
                        }
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                constrained: false,
                                boundaryMargin: const EdgeInsets.all(220),
                                minScale: _minTreeScale,
                                maxScale: _maxTreeScale,
                                child: RepaintBoundary(
                                  key: _treeCanvasPrintBoundaryKey,
                                  child: SizedBox(
                                    width: scene.canvasSize.width,
                                    height: scene.canvasSize.height,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            key: const Key('tree-connectors'),
                                            painter: _TreeConnectorPainter(
                                              connectorGroups:
                                                  scene.connectorGroups,
                                              selectedMemberId:
                                                  _selectedMemberId,
                                            ),
                                          ),
                                        ),
                                        for (final entry
                                            in scene.nodeRects.entries)
                                          Positioned(
                                            left: entry.value.left,
                                            top: entry.value.top,
                                            width: entry.value.width,
                                            height: entry.value.height,
                                            child: _MemberNodeCard(
                                              key: Key(
                                                'tree-node-${entry.key}',
                                              ),
                                              member: segment
                                                  .graph
                                                  .membersById[entry.key]!,
                                              siblingOrderLabel:
                                                  _siblingOrderLabel(
                                                    l10n,
                                                    siblingOrdersByMember[entry
                                                            .key] ??
                                                        segment
                                                            .graph
                                                            .membersById[entry
                                                                .key]!
                                                            .siblingOrder,
                                                  ),
                                              honorBadges: _honorBadgeLabels(
                                                l10n,
                                                honorBadgesByMember[entry
                                                        .key] ??
                                                    const [],
                                              ),
                                              generationLabel:
                                                  _memberGenerationLabelForDisplay(
                                                    l10n: l10n,
                                                    member:
                                                        segment
                                                            .graph
                                                            .membersById[entry
                                                            .key]!,
                                                    viewer: viewer,
                                                    membersById: segment
                                                        .graph
                                                        .membersById,
                                                    relativeLevel:
                                                        relativeLevelsByCurrentUser[entry
                                                            .key],
                                                    compact: true,
                                                  ),
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
                                                segment.graph.membersById[entry
                                                    .key]!,
                                              ),
                                              aliveStatusLabel: l10n
                                                  .genealogyMemberAliveStatus,
                                              deceasedStatusLabel: l10n
                                                  .genealogyMemberDeceasedStatus,
                                              isSelected:
                                                  _selectedMemberId ==
                                                  entry.key,
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
                                                    relativeLevelsByCurrentUser:
                                                        relativeLevelsByCurrentUser,
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
                                                    relativeLevelsByCurrentUser:
                                                        relativeLevelsByCurrentUser,
                                                  ),
                                                );
                                              },
                                              viewInfoTooltip: l10n
                                                  .genealogyViewMemberInfoAction,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: _TreeZoomControls(
                                onZoomIn: _zoomIn,
                                onZoomOut: _zoomOut,
                                onReset: _resetTreeViewport,
                                onExport: _openTreeExportSheet,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: _AddActionFab(
            isMenuOpen: _showAddFabMenu,
            canAddGenealogy: !_isSubmittingAddClan,
            showAddBranch: canAddBranchAction,
            canAddBranch: canAddBranchAction && !_isSubmittingAddBranch,
            showAddMember: canAddMemberAction,
            canAddMember: canAddMemberAction,
            onToggleMenu: () {
              setState(() {
                _showAddFabMenu = !_showAddFabMenu;
              });
            },
            onAddGenealogy: () async {
              setState(() {
                _showAddFabMenu = false;
              });
              await _openAddPrivateGenealogySheet();
            },
            onAddBranch: () async {
              setState(() {
                _showAddFabMenu = false;
              });
              await _openAddPrivateBranchSheet();
            },
            onAddMember: () async {
              setState(() {
                _showAddFabMenu = false;
              });
              await _openAddMemberWorkspace();
            },
          ),
        ),
      ],
    );
    return OnboardingScope(controller: _onboardingCoordinator, child: content);
  }

  Future<void> _load({bool allowCached = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _invalidateTreeSceneCache();
      _invalidateDerivedGraphCaches();
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
        _rootMemberId = _rootMemberId ?? initialFocus;
        _selectedMemberId = _selectedMemberId ?? initialFocus;
        _shouldAutoFitTree = true;
        _invalidateTreeSceneCache();
      });
      _scheduleWorkspaceOnboardingIfNeeded();

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

  void _scheduleWorkspaceOnboardingIfNeeded() {
    if (_hasScheduledOnboarding || !mounted) {
      return;
    }
    _hasScheduledOnboarding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _onboardingCoordinator.scheduleTrigger(
          const OnboardingTrigger(
            id: 'genealogy_workspace_opened',
            routeId: 'genealogy_workspace',
          ),
          delay: const Duration(milliseconds: 1100),
        ),
      );
    });
  }

  void _updateScope(GenealogyScopeType value) {
    if (value != GenealogyScopeType.clan) {
      return;
    }
    if (_scopeType == value) {
      return;
    }
    setState(() {
      _scopeType = value;
      _rootMemberId = null;
      _selectedMemberId = null;
      _transformController.value = Matrix4.identity();
      _shouldAutoFitTree = true;
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

      String createdClanId = '';
      try {
        createdClanId = await _callBootstrapAdditionalClan(
          payload: payload,
          duplicateOverride: false,
        );
      } on FirebaseFunctionsException catch (error) {
        final candidates = _extractDuplicateCandidates(error);
        if (!_isPotentialDuplicateError(error) || candidates.isEmpty) {
          rethrow;
        }

        final acceptedOverride = await _confirmDuplicateClanOverride(
          candidates: candidates,
        );
        if (!acceptedOverride) {
          return;
        }
        createdClanId = await _callBootstrapAdditionalClan(
          payload: payload,
          duplicateOverride: true,
        );
      }

      if (!mounted) {
        return;
      }
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
                      vi: 'Đã tạo gia phả riêng. Bạn vẫn thuộc gia phả hiện tại.',
                      en: 'Private genealogy created. You still remain in the current clan.',
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

  Future<String> _callBootstrapAdditionalClan({
    required _AdditionalClanPayload payload,
    required bool duplicateOverride,
  }) async {
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
      'duplicateOverride': duplicateOverride,
    });
    final data = response.data;
    if (data is Map) {
      return (data['clanId'] as String? ?? '').trim();
    }
    return '';
  }

  bool _isPotentialDuplicateError(FirebaseFunctionsException error) {
    if (error.code != 'already-exists') {
      return false;
    }
    if (error.details is! Map) {
      return false;
    }
    final details = error.details as Map;
    return (details['reason'] as String?) == 'potential_duplicate_genealogy';
  }

  List<_DuplicateGenealogyCandidate> _extractDuplicateCandidates(
    FirebaseFunctionsException error,
  ) {
    if (error.details is! Map) {
      return const [];
    }
    final details = error.details as Map;
    final rawCandidates = details['candidates'];
    if (rawCandidates is! List) {
      return const [];
    }
    return rawCandidates
        .whereType<Map>()
        .map((item) => _DuplicateGenealogyCandidate.fromUnknownMap(item))
        .whereType<_DuplicateGenealogyCandidate>()
        .toList(growable: false);
  }

  Future<bool> _confirmDuplicateClanOverride({
    required List<_DuplicateGenealogyCandidate> candidates,
  }) async {
    if (!mounted) {
      return false;
    }
    final l10n = context.l10n;
    return await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) {
            final theme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(
                        vi: 'Phát hiện gia phả có thể bị trùng',
                        en: 'Potential duplicate genealogy detected',
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.pick(
                        vi: 'Vui lòng kiểm tra các gia phả bên dưới trước khi tạo mới. Bạn vẫn có thể tiếp tục nếu chắc chắn đây là gia phả khác.',
                        en: 'Please review the candidates below before creating a new tree. You can still continue if this is intentionally different.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate.genealogyName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.pick(
                                      vi: 'Trưởng tộc: ${candidate.leaderName}\nKhu vực: ${candidate.provinceCity.isEmpty ? 'Chưa cập nhật' : candidate.provinceCity}\nĐộ tương đồng: ${candidate.score}%',
                                      en: 'Leader: ${candidate.leaderName}\nLocation: ${candidate.provinceCity.isEmpty ? 'Not specified' : candidate.provinceCity}\nSimilarity: ${candidate.score}%',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              l10n.pick(vi: 'Kiểm tra lại', en: 'Review first'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              l10n.pick(
                                vi: 'Vẫn tạo gia phả mới',
                                en: 'Create anyway',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
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

  Future<void> _openAddMemberWorkspace() async {
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
                vi: 'Cần chọn gia phả đang hoạt động trước khi thêm thành viên.',
                en: 'Please select an active clan before adding a member.',
              ),
            ),
          ),
        );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MemberWorkspacePage(
          session: widget.session,
          repository: createDefaultMemberRepository(session: widget.session),
        ),
      ),
    );
  }

  _TreeScene _resolveTreeScene(GenealogyReadSegment segment) {
    final rootId = _effectiveRootId(segment);
    final canReuse =
        _cachedScene != null &&
        identical(_cachedSceneSegment, segment) &&
        _cachedSceneRootId == rootId;
    if (canReuse) {
      return _cachedScene!;
    }

    final scene = _buildTreeScene(segment, rootId: rootId);
    _cachedScene = scene;
    _cachedSceneSegment = segment;
    _cachedSceneRootId = rootId;
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

  void _prepareDerivedGraphCache(GenealogyGraph graph) {
    if (identical(_cachedDerivedGraph, graph)) {
      return;
    }
    _cachedDerivedGraph = graph;
    _cachedDerivedViewerId = null;
    _cachedRelativeLevelsByCurrentUser = null;
    _cachedSiblingOrdersByMember = null;
    _cachedHonorBadgesByMember = null;
    _cachedHonorBadgesSiblingOrders = null;
  }

  void _invalidateDerivedGraphCaches() {
    _cachedDerivedGraph = null;
    _cachedDerivedViewerId = null;
    _cachedRelativeLevelsByCurrentUser = null;
    _cachedSiblingOrdersByMember = null;
    _cachedHonorBadgesByMember = null;
    _cachedHonorBadgesSiblingOrders = null;
  }

  _TreeScene _buildTreeScene(
    GenealogyReadSegment segment, {
    required String rootId,
  }) {
    final stopwatch = Stopwatch()..start();
    final graph = segment.graph;
    final maxVisibleMembers = _resolveMaxVisibleMembersForDevice();
    final visibleMemberIds = _buildVisibleMemberIds(
      graph: graph,
      rootId: rootId,
      maxVisibleMembers: maxVisibleMembers,
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
    final optimizedRows = _optimizeRowOrdering(
      sortedLevels: sortedLevels,
      idsByLevel: idsByLevel,
      graph: graph,
      levels: levels,
    );
    for (final entry in optimizedRows.entries) {
      idsByLevel[entry.key] = entry.value;
    }

    final rowGaps = _computeRowGaps(
      sortedLevels: sortedLevels,
      idsByLevel: idsByLevel,
      graph: graph,
      levels: levels,
    );
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
        rowGaps.fold<double>(0, (sum, gap) => sum + gap);

    final nodeRects = <String, Rect>{};
    var top = _canvasPadding;
    for (var levelIndex = 0; levelIndex < sortedLevels.length; levelIndex++) {
      final level = sortedLevels[levelIndex];
      final row = idsByLevel[level]!;
      final rowWidth =
          (row.length * _nodeWidth) + ((row.length - 1) * _columnSpacing);
      final startX = (canvasWidth - rowWidth) / 2;
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final left = startX + (columnIndex * (_nodeWidth + _columnSpacing));
        nodeRects[row[columnIndex]] = Rect.fromLTWH(
          left,
          top,
          _nodeWidth,
          _nodeHeight,
        );
      }
      if (levelIndex < rowGaps.length) {
        top += _nodeHeight + rowGaps[levelIndex];
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

    final connectorGroups = _buildConnectorGroups(
      parentChildEdges: parentChildEdges,
      nodeRects: nodeRects,
    );
    final connectorSegmentCount = connectorGroups.fold<int>(
      0,
      (sum, group) => sum + group.segmentCount,
    );

    stopwatch.stop();
    final layoutProfile = _layoutProfiler.push(stopwatch.elapsed);
    _performanceLogger.logDuration(
      metric: 'genealogy.tree_scene_build',
      elapsed: stopwatch.elapsed,
      dimensions: {
        'nodes': visibleMemberIds.length,
        'edges': parentChildEdges.length + spouseEdges.length,
        'connector_groups': connectorGroups.length,
        'connector_segments': connectorSegmentCount,
        'row_gap_max': rowGaps.isEmpty
            ? 0
            : rowGaps.reduce((left, right) => math.max(left, right)).round(),
        'layout_latest_ms': layoutProfile.latestMs,
        'layout_average_ms': layoutProfile.averageMs,
        'layout_peak_ms': layoutProfile.peakMs,
        'layout_samples': layoutProfile.sampleCount,
        'visible_cap': maxVisibleMembers,
        'truncated': graph.membersById.length > maxVisibleMembers ? 1 : 0,
      },
    );

    return _TreeScene(
      canvasSize: Size(canvasWidth, canvasHeight),
      nodeRects: nodeRects,
      parentChildEdges: parentChildEdges,
      spouseEdges: spouseEdges,
      connectorGroups: connectorGroups,
      visibleMemberIds: visibleMemberIds,
      layoutProfile: layoutProfile,
    );
  }

  int _resolveMaxVisibleMembersForDevice() {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return _maxVisibleMembers;
    }
    final shortestSide = mediaQuery.size.shortestSide;
    final longestSide = mediaQuery.size.longestSide;
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final compactPhone = shortestSide <= 390 || longestSide <= 780;
    final veryCompactPhone = shortestSide <= 360 || longestSide <= 700;
    final lowDensityDisplay = devicePixelRatio <= 2.0;
    final veryLowDensityDisplay = devicePixelRatio <= 1.8;
    final lowDensityCompact = lowDensityDisplay && shortestSide <= 500;

    if (veryCompactPhone || (compactPhone && veryLowDensityDisplay)) {
      return 220;
    }
    if (compactPhone || lowDensityCompact) {
      return 240;
    }
    return _maxVisibleMembers;
  }

  List<_TreeConnectorGroupGeometry> _buildConnectorGroups({
    required List<_TreeEdge> parentChildEdges,
    required Map<String, Rect> nodeRects,
  }) {
    if (parentChildEdges.isEmpty || nodeRects.isEmpty) {
      return const [];
    }

    final parentsByChild = <String, Set<String>>{};
    for (final edge in parentChildEdges) {
      parentsByChild.putIfAbsent(edge.toId, () => <String>{}).add(edge.fromId);
    }
    final childrenByParentGroup = <String, List<String>>{};
    final parentsForGroup = <String, List<String>>{};
    for (final entry in parentsByChild.entries) {
      final childId = entry.key;
      final childRect = nodeRects[childId];
      if (childRect == null) {
        continue;
      }
      final sortedParents =
          entry.value.where(nodeRects.containsKey).toList(growable: false)
            ..sort((left, right) {
              final leftRect = nodeRects[left]!;
              final rightRect = nodeRects[right]!;
              return leftRect.center.dx.compareTo(rightRect.center.dx);
            });
      if (sortedParents.isEmpty) {
        continue;
      }
      final groupKey = sortedParents.join('|');
      childrenByParentGroup
          .putIfAbsent(groupKey, () => <String>[])
          .add(childId);
      parentsForGroup[groupKey] = sortedParents;
    }

    final joinLaneAllocator = _HorizontalLaneAllocator(step: 10, padding: 18);
    final splitLaneAllocator = _HorizontalLaneAllocator(step: 8, padding: 14);

    final orderedGroupKeys = childrenByParentGroup.keys.toList(growable: false)
      ..sort((left, right) {
        final leftParents = parentsForGroup[left];
        final rightParents = parentsForGroup[right];
        if (leftParents == null || leftParents.isEmpty) {
          return 1;
        }
        if (rightParents == null || rightParents.isEmpty) {
          return -1;
        }
        final leftRect = nodeRects[leftParents.first];
        final rightRect = nodeRects[rightParents.first];
        if (leftRect == null || rightRect == null) {
          return 0;
        }
        return leftRect.center.dx.compareTo(rightRect.center.dx);
      });

    final groups = <_TreeConnectorGroupGeometry>[];
    for (final groupKey in orderedGroupKeys) {
      final parentIds = parentsForGroup[groupKey];
      final childIds = childrenByParentGroup[groupKey];
      if (parentIds == null ||
          parentIds.isEmpty ||
          childIds == null ||
          childIds.isEmpty) {
        continue;
      }

      final childAnchors = <({String childId, double x, double top})>[];
      for (final childId in childIds) {
        final childRect = nodeRects[childId];
        if (childRect == null) {
          continue;
        }
        childAnchors.add((
          childId: childId,
          x: childRect.center.dx,
          top: childRect.top - 2,
        ));
      }
      if (childAnchors.isEmpty) {
        continue;
      }
      childAnchors.sort((left, right) => left.x.compareTo(right.x));

      final parentAnchors = <({String parentId, double x, double bottom})>[];
      for (final parentId in parentIds) {
        final parentRect = nodeRects[parentId];
        if (parentRect == null) {
          continue;
        }
        parentAnchors.add((
          parentId: parentId,
          x: parentRect.center.dx,
          bottom: parentRect.bottom + 2,
        ));
      }
      if (parentAnchors.isEmpty) {
        continue;
      }
      parentAnchors.sort((left, right) => left.x.compareTo(right.x));

      final minChildTop = childAnchors
          .map((anchor) => anchor.top)
          .reduce(math.min);
      final firstChildX = childAnchors.first.x;
      final lastChildX = childAnchors.last.x;
      final childCenterX = (firstChildX + lastChildX) / 2;

      final maxParentBottom = parentAnchors
          .map((anchor) => anchor.bottom)
          .reduce(math.max);
      final verticalGap = minChildTop - maxParentBottom;
      if (verticalGap <= 8) {
        // Avoid inverse vertical connectors for malformed graph links.
        continue;
      }

      final minParentX = parentAnchors
          .map((anchor) => anchor.x)
          .reduce(math.min);
      final maxParentX = parentAnchors
          .map((anchor) => anchor.x)
          .reduce(math.max);
      final groupMinX = math.min(minParentX, firstChildX);
      final groupMaxX = math.max(maxParentX, lastChildX);

      final minJoinY = maxParentBottom + 4;
      final maxJoinY = minChildTop - 22;
      if (maxJoinY <= minJoinY) {
        continue;
      }
      final preferredJoinY =
          (parentAnchors.length > 1
                  ? maxParentBottom + 16
                  : maxParentBottom + 8)
              .clamp(minJoinY, maxJoinY)
              .toDouble();
      final joinY = joinLaneAllocator.reserve(
        preferredY: preferredJoinY,
        minY: minJoinY,
        maxY: maxJoinY,
        left: groupMinX,
        right: groupMaxX,
      );

      final parentCenterX = (parentAnchors.first.x + parentAnchors.last.x) / 2;
      final trunkX = childAnchors.length == 1
          ? childAnchors.first.x
          : childCenterX;

      final sharedSegments = <_TreeLineSegment>[];
      final childSegments = <_TreeChildLineSegment>[];

      void addSharedSegment(Offset from, Offset to) {
        if ((from.dx - to.dx).abs() <= 0.5 && (from.dy - to.dy).abs() <= 0.5) {
          return;
        }
        sharedSegments.add(_TreeLineSegment(from: from, to: to));
      }

      void addChildSegment({
        required String childId,
        required Offset from,
        required Offset to,
      }) {
        if ((from.dx - to.dx).abs() <= 0.5 && (from.dy - to.dy).abs() <= 0.5) {
          return;
        }
        childSegments.add(
          _TreeChildLineSegment(childId: childId, from: from, to: to),
        );
      }

      for (final parent in parentAnchors) {
        if (joinY - parent.bottom > 0.5) {
          addSharedSegment(
            Offset(parent.x, parent.bottom),
            Offset(parent.x, joinY),
          );
        }
      }
      if (parentAnchors.length > 1) {
        addSharedSegment(
          Offset(parentAnchors.first.x, joinY),
          Offset(parentAnchors.last.x, joinY),
        );
      }

      if ((trunkX - parentCenterX).abs() > 0.5) {
        addSharedSegment(Offset(parentCenterX, joinY), Offset(trunkX, joinY));
      }

      if (childAnchors.length == 1) {
        final onlyChild = childAnchors.first;
        if (onlyChild.top - joinY > 0.5) {
          addChildSegment(
            childId: onlyChild.childId,
            from: Offset(trunkX, joinY),
            to: Offset(trunkX, onlyChild.top),
          );
        }
      } else {
        final minSplitY = joinY + 18;
        final maxSplitY = minChildTop - 18;
        if (maxSplitY > minSplitY) {
          final preferredSplitY = (joinY + ((minChildTop - joinY) * 0.42))
              .clamp(minSplitY, maxSplitY)
              .toDouble();
          final splitY = splitLaneAllocator.reserve(
            preferredY: preferredSplitY,
            minY: minSplitY,
            maxY: maxSplitY,
            left: firstChildX,
            right: lastChildX,
          );

          if (splitY - joinY > 0.5) {
            addSharedSegment(Offset(trunkX, joinY), Offset(trunkX, splitY));
          }

          final splitLeftX = math.min(firstChildX, trunkX);
          final splitRightX = math.max(lastChildX, trunkX);
          if ((splitRightX - splitLeftX).abs() > 0.5) {
            addSharedSegment(
              Offset(splitLeftX, splitY),
              Offset(splitRightX, splitY),
            );
          }

          for (final anchor in childAnchors) {
            if (anchor.top - splitY > 0.5) {
              addChildSegment(
                childId: anchor.childId,
                from: Offset(anchor.x, splitY),
                to: Offset(anchor.x, anchor.top),
              );
            }
          }
        }
      }

      if (sharedSegments.isEmpty && childSegments.isEmpty) {
        continue;
      }

      final groupMemberIds = <String>{
        ...parentAnchors.map((anchor) => anchor.parentId),
        ...childAnchors.map((anchor) => anchor.childId),
      };
      groups.add(
        _TreeConnectorGroupGeometry(
          memberIds: groupMemberIds,
          sharedSegments: sharedSegments,
          childSegments: childSegments,
        ),
      );
    }
    return groups;
  }

  Map<int, List<String>> _optimizeRowOrdering({
    required List<int> sortedLevels,
    required Map<int, List<String>> idsByLevel,
    required GenealogyGraph graph,
    required Map<String, int> levels,
  }) {
    final orderedByLevel = <int, List<String>>{};
    for (final level in sortedLevels) {
      final row = List<String>.from(idsByLevel[level] ?? const []);
      row.sort((left, right) => _compareMembersForLayout(left, right, graph));
      orderedByLevel[level] = row;
    }

    final totalNodes = orderedByLevel.values.fold<int>(
      0,
      (sum, row) => sum + row.length,
    );
    final sweepIterations = totalNodes >= 220 ? 2 : 4;

    // Multi-pass barycenter sweeps (top-down + bottom-up) to reduce crossings.
    for (var iteration = 0; iteration < sweepIterations; iteration++) {
      for (var index = 1; index < sortedLevels.length; index++) {
        _sortRowWithBarycenter(
          level: sortedLevels[index],
          orderedByLevel: orderedByLevel,
          graph: graph,
          levels: levels,
          preferParents: true,
        );
      }
      for (var index = sortedLevels.length - 2; index >= 0; index--) {
        _sortRowWithBarycenter(
          level: sortedLevels[index],
          orderedByLevel: orderedByLevel,
          graph: graph,
          levels: levels,
          preferParents: false,
        );
      }
    }

    for (final level in sortedLevels) {
      final row = orderedByLevel[level];
      if (row == null || row.length < 2) {
        continue;
      }
      final compactedSpouses = _compactSpouseBlocks(
        row: row,
        graph: graph,
        levels: levels,
        level: level,
      );
      orderedByLevel[level] = _compactSiblingBlocks(
        row: compactedSpouses,
        graph: graph,
        levels: levels,
        level: level,
      );
    }
    return orderedByLevel;
  }

  void _sortRowWithBarycenter({
    required int level,
    required Map<int, List<String>> orderedByLevel,
    required GenealogyGraph graph,
    required Map<String, int> levels,
    required bool preferParents,
  }) {
    final row = orderedByLevel[level];
    if (row == null || row.length < 2) {
      return;
    }

    final positionByMember = _positionIndexMap(orderedByLevel);
    final barycenterByMember = <String, double?>{};
    for (final memberId in row) {
      final anchors = <double>[];
      final neighborIds = preferParents
          ? graph.parentsOf(memberId)
          : graph.childrenOf(memberId);
      for (final neighborId in neighborIds) {
        final index = positionByMember[neighborId];
        if (index != null) {
          anchors.add(index);
        }
      }
      for (final spouseId in graph.spousesOf(memberId)) {
        if (levels[spouseId] != level) {
          continue;
        }
        final index = positionByMember[spouseId];
        if (index != null) {
          anchors.add(index);
        }
      }
      if (anchors.isEmpty) {
        barycenterByMember[memberId] = null;
      } else {
        final sum = anchors.reduce((a, b) => a + b);
        barycenterByMember[memberId] = sum / anchors.length;
      }
    }

    row.sort((left, right) {
      final leftAnchor = barycenterByMember[left];
      final rightAnchor = barycenterByMember[right];
      if (leftAnchor != null && rightAnchor != null) {
        final byAnchor = leftAnchor.compareTo(rightAnchor);
        if (byAnchor != 0) {
          return byAnchor;
        }
      } else if (leftAnchor != null) {
        return -1;
      } else if (rightAnchor != null) {
        return 1;
      }
      final leftPos = positionByMember[left];
      final rightPos = positionByMember[right];
      if (leftPos != null && rightPos != null) {
        final byPreviousPosition = leftPos.compareTo(rightPos);
        if (byPreviousPosition != 0) {
          return byPreviousPosition;
        }
      }
      return _compareMembersForLayout(left, right, graph);
    });

    final compactedSpouses = _compactSpouseBlocks(
      row: row,
      graph: graph,
      levels: levels,
      level: level,
    );
    orderedByLevel[level] = _compactSiblingBlocks(
      row: compactedSpouses,
      graph: graph,
      levels: levels,
      level: level,
    );
  }

  Map<String, double> _positionIndexMap(Map<int, List<String>> orderedByLevel) {
    final result = <String, double>{};
    for (final row in orderedByLevel.values) {
      for (var index = 0; index < row.length; index++) {
        result[row[index]] = index.toDouble();
      }
    }
    return result;
  }

  List<String> _compactSpouseBlocks({
    required List<String> row,
    required GenealogyGraph graph,
    required Map<String, int> levels,
    required int level,
  }) {
    if (row.length < 3) {
      return row;
    }

    final indexById = <String, int>{
      for (var index = 0; index < row.length; index++) row[index]: index,
    };
    final parent = <String, String>{for (final id in row) id: id};

    String find(String id) {
      var cursor = id;
      while (parent[cursor] != cursor) {
        parent[cursor] = parent[parent[cursor]!]!;
        cursor = parent[cursor]!;
      }
      return cursor;
    }

    void union(String left, String right) {
      final leftRoot = find(left);
      final rightRoot = find(right);
      if (leftRoot == rightRoot) {
        return;
      }
      final leftIndex = indexById[leftRoot] ?? 0;
      final rightIndex = indexById[rightRoot] ?? 0;
      if (leftIndex <= rightIndex) {
        parent[rightRoot] = leftRoot;
      } else {
        parent[leftRoot] = rightRoot;
      }
    }

    for (final memberId in row) {
      for (final spouseId in graph.spousesOf(memberId)) {
        if (levels[spouseId] != level || !indexById.containsKey(spouseId)) {
          continue;
        }
        union(memberId, spouseId);
      }
    }

    final blocksByRoot = <String, List<String>>{};
    for (final memberId in row) {
      final root = find(memberId);
      blocksByRoot.putIfAbsent(root, () => <String>[]).add(memberId);
    }
    if (blocksByRoot.length == row.length) {
      return row;
    }

    final blocks = blocksByRoot.values.toList(growable: false);
    for (final block in blocks) {
      block.sort(
        (left, right) =>
            (indexById[left] ?? 0).compareTo(indexById[right] ?? 0),
      );
    }
    blocks.sort((left, right) {
      final leftAnchor =
          left.map((id) => indexById[id] ?? 0).reduce((a, b) => a + b) /
          left.length;
      final rightAnchor =
          right.map((id) => indexById[id] ?? 0).reduce((a, b) => a + b) /
          right.length;
      return leftAnchor.compareTo(rightAnchor);
    });

    return blocks.expand((block) => block).toList(growable: false);
  }

  List<String> _compactSiblingBlocks({
    required List<String> row,
    required GenealogyGraph graph,
    required Map<String, int> levels,
    required int level,
  }) {
    if (row.length < 3) {
      return row;
    }
    final indexById = <String, int>{
      for (var index = 0; index < row.length; index++) row[index]: index,
    };
    final groupsByKey = <String, List<String>>{};
    for (final memberId in row) {
      final directParents =
          graph
              .parentsOf(memberId)
              .where((parentId) {
                return levels[parentId] == level - 1;
              })
              .toList(growable: false)
            ..sort();
      final key = directParents.isEmpty
          ? 'solo:$memberId'
          : 'parents:${directParents.join('|')}';
      groupsByKey.putIfAbsent(key, () => <String>[]).add(memberId);
    }
    if (groupsByKey.length == row.length) {
      return row;
    }

    final groups = groupsByKey.values.toList(growable: false);
    for (final group in groups) {
      group.sort(
        (left, right) =>
            (indexById[left] ?? 0).compareTo(indexById[right] ?? 0),
      );
    }
    groups.sort((left, right) {
      final leftAnchor =
          left.map((id) => indexById[id] ?? 0).reduce((a, b) => a + b) /
          left.length;
      final rightAnchor =
          right.map((id) => indexById[id] ?? 0).reduce((a, b) => a + b) /
          right.length;
      return leftAnchor.compareTo(rightAnchor);
    });
    return groups.expand((group) => group).toList(growable: false);
  }

  List<double> _computeRowGaps({
    required List<int> sortedLevels,
    required Map<int, List<String>> idsByLevel,
    required GenealogyGraph graph,
    required Map<String, int> levels,
  }) {
    if (sortedLevels.length < 2) {
      return const [];
    }
    final gaps = <double>[];
    for (var index = 0; index < sortedLevels.length - 1; index++) {
      final parentLevel = sortedLevels[index];
      final childLevel = sortedLevels[index + 1];
      final parentRowSet = (idsByLevel[parentLevel] ?? const <String>[])
          .toSet();
      final childRow = idsByLevel[childLevel] ?? const <String>[];
      final parentGroups = <String>{};
      var connectedChildren = 0;
      for (final childId in childRow) {
        final directParents =
            graph
                .parentsOf(childId)
                .where(parentRowSet.contains)
                .toList(growable: false)
              ..sort();
        if (directParents.isEmpty) {
          continue;
        }
        connectedChildren += 1;
        parentGroups.add(directParents.join('|'));
      }

      final densityScore =
          (parentGroups.length * 2) + (connectedChildren / 2).round();
      final extraGap = math.min(120.0, math.max(0, densityScore - 4) * 6.0);
      final irregularLevelJump = (childLevel - parentLevel).abs() > 1
          ? 10.0
          : 0.0;
      final spouseCompressionBoost = _estimateSpouseCompressionBoost(
        row: idsByLevel[childLevel] ?? const <String>[],
        graph: graph,
        levels: levels,
        level: childLevel,
      );
      gaps.add(
        _rowSpacing + extraGap + irregularLevelJump + spouseCompressionBoost,
      );
    }
    return gaps;
  }

  double _estimateSpouseCompressionBoost({
    required List<String> row,
    required GenealogyGraph graph,
    required Map<String, int> levels,
    required int level,
  }) {
    if (row.length < 3) {
      return 0;
    }
    var spousePairCount = 0;
    final seenPairs = <String>{};
    for (final memberId in row) {
      for (final spouseId in graph.spousesOf(memberId)) {
        if (levels[spouseId] != level) {
          continue;
        }
        final ordered = [memberId, spouseId]..sort();
        final key = '${ordered.first}|${ordered.last}';
        if (seenPairs.add(key)) {
          spousePairCount += 1;
        }
      }
    }
    return math.min(36.0, spousePairCount * 4.0);
  }

  int _compareMembersForLayout(
    String left,
    String right,
    GenealogyGraph graph,
  ) {
    final leftMember = graph.membersById[left]!;
    final rightMember = graph.membersById[right]!;
    final byGeneration = leftMember.generation.compareTo(
      rightMember.generation,
    );
    if (byGeneration != 0) {
      return byGeneration;
    }
    final byName = leftMember.fullName.compareTo(rightMember.fullName);
    if (byName != 0) {
      return byName;
    }
    return left.compareTo(right);
  }

  Set<String> _buildVisibleMemberIds({
    required GenealogyGraph graph,
    required String rootId,
    required int maxVisibleMembers,
  }) {
    final allMemberIds = graph.membersById.keys.toSet();
    if (allMemberIds.length <= maxVisibleMembers) {
      return allMemberIds;
    }
    if (!allMemberIds.contains(rootId)) {
      return allMemberIds.take(maxVisibleMembers).toSet();
    }

    final visible = <String>{rootId};
    final queue = Queue<String>()..add(rootId);
    while (queue.isNotEmpty && visible.length < maxVisibleMembers) {
      final currentId = queue.removeFirst();
      final related =
          <String>{
              ...graph.parentsOf(currentId),
              ...graph.childrenOf(currentId),
              ...graph.spousesOf(currentId),
            }.toList(growable: false)
            ..sort(_compareMembersForLayoutWithFallback(graph));
      for (final relatedId in related) {
        if (!allMemberIds.contains(relatedId) || !visible.add(relatedId)) {
          continue;
        }
        queue.addLast(relatedId);
        if (visible.length >= maxVisibleMembers) {
          break;
        }
      }
    }

    if (visible.length >= maxVisibleMembers) {
      return visible;
    }

    final remaining = allMemberIds.difference(visible).toList(growable: false)
      ..sort(_compareMembersForLayoutWithFallback(graph));
    for (final memberId in remaining) {
      visible.add(memberId);
      if (visible.length >= maxVisibleMembers) {
        break;
      }
    }
    return visible;
  }

  int Function(String, String) _compareMembersForLayoutWithFallback(
    GenealogyGraph graph,
  ) {
    return (left, right) {
      final hasLeft = graph.membersById.containsKey(left);
      final hasRight = graph.membersById.containsKey(right);
      if (hasLeft && hasRight) {
        return _compareMembersForLayout(left, right, graph);
      }
      if (hasLeft) {
        return -1;
      }
      if (hasRight) {
        return 1;
      }
      return left.compareTo(right);
    };
  }

  Map<String, int> _buildRelativeLevels({
    required GenealogyGraph graph,
    required String rootId,
    required Set<String> visibleMemberIds,
  }) {
    final levels = <String, int>{};
    final rootGeneration = graph.membersById[rootId]?.generation ?? 1;
    for (final memberId in visibleMemberIds) {
      levels[memberId] =
          (graph.membersById[memberId]?.generation ?? rootGeneration) -
          rootGeneration;
    }
    if (rootId.isNotEmpty && visibleMemberIds.contains(rootId)) {
      levels[rootId] = 0;
    }

    final maxIterations = (visibleMemberIds.length * 4) + 12;
    var converged = false;
    for (var iteration = 0; iteration < maxIterations; iteration++) {
      var changed = false;
      for (final childId in visibleMemberIds) {
        var childLevel = levels[childId] ?? 0;
        for (final parentId in graph.parentsOf(childId)) {
          if (!visibleMemberIds.contains(parentId)) {
            continue;
          }
          final parentLevel = levels[parentId] ?? 0;
          final requiredChildLevel = parentLevel + 1;
          if (childLevel < requiredChildLevel) {
            childLevel = requiredChildLevel;
            levels[childId] = childLevel;
            changed = true;
          }
        }
      }
      if (!changed) {
        converged = true;
        break;
      }
    }

    if (!converged) {
      AppLogger.warning(
        'Tree level constraints did not fully converge. Check parent-child cycles or invalid source links.',
      );
    }
    return levels;
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
      _minTreeScale,
      _maxTreeScale,
    );
    final target = Matrix4.identity()
      ..translateByDouble(
        (view.width / 2) - ((rect.left + (rect.width / 2)) * scale),
        (view.height / 2) - ((rect.top + (rect.height / 2)) * scale),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);

    _animateTransformTo(target, duration: const Duration(milliseconds: 260));
  }

  Future<void> _openMemberDetailSheet({
    required MemberProfile member,
    required GenealogyGraph graph,
    required List<BranchProfile> branches,
    required int? siblingOrder,
    required List<_GenealogyHonorBadge> honorBadges,
    required Map<String, int?> relativeLevelsByCurrentUser,
  }) async {
    final l10n = context.l10n;
    final viewer = _viewerMemberForGraph(graph);
    final ancestry = GenealogyGraphAlgorithms.buildAncestryPath(
      graph: graph,
      memberId: member.id,
    );
    final descendants = GenealogyGraphAlgorithms.buildDescendantsTraversal(
      graph: graph,
      memberId: member.id,
    );
    final statusLabel = _isMemberAlive(member)
        ? l10n.genealogyMemberAliveStatus
        : l10n.genealogyMemberDeceasedStatus;
    final generationLabel = _memberGenerationLabelForDisplay(
      l10n: l10n,
      member: member,
      viewer: viewer,
      membersById: graph.membersById,
      relativeLevel: relativeLevelsByCurrentUser[member.id],
      compact: true,
    );
    final siblingLabel =
        _siblingOrderLabel(l10n, siblingOrder) ?? l10n.memberFieldUnset;
    final honorBadgeLabels = _honorBadgeLabels(l10n, honorBadges);
    final honorBadgeLabel = honorBadgeLabels.isEmpty
        ? l10n.memberFieldUnset
        : honorBadgeLabels.join(' • ');

    final compactFacts = <_CompactFactItem>[
      _CompactFactItem(
        label: l10n.genealogyMemberStatusLabel,
        value: statusLabel,
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Đời trong gia phả', en: 'Generation'),
        value: generationLabel,
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Thứ bậc anh/chị/em', en: 'Sibling order'),
        value: siblingLabel,
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Vai trò trong họ', en: 'Honor badges'),
        value: honorBadgeLabel,
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Số cha/mẹ', en: 'Parents'),
        value: '${graph.parentsOf(member.id).length}',
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Số con', en: 'Children'),
        value: '${graph.childrenOf(member.id).length}',
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Số vợ/chồng', en: 'Spouses'),
        value: '${graph.spousesOf(member.id).length}',
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Tổng con cháu', en: 'Descendants'),
        value: '${descendants.length}',
      ),
      _CompactFactItem(
        label: l10n.pick(vi: 'Số đời tổ tiên', en: 'Ancestry depth'),
        value: '${ancestry.length}',
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final tokens = context.uiTokens;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (member.nickName.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              member.nickName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: tokens.spaceSm),
                    AppCompactTextButton(
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
                            relativeLevelsByCurrentUser:
                                relativeLevelsByCurrentUser,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new, size: 16),
                          SizedBox(width: tokens.spaceSm),
                          Text(l10n.pick(vi: 'Xem chi tiết', en: 'Details')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CompactFactGrid(items: compactFacts),
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
    required Map<String, int?> relativeLevelsByCurrentUser,
  }) async {
    final l10n = context.l10n;
    final viewer = _viewerMemberForGraph(graph);
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
            generationLabel: _memberGenerationLabelForDisplay(
              l10n: l10n,
              member: member,
              viewer: viewer,
              membersById: graph.membersById,
              relativeLevel: relativeLevelsByCurrentUser[member.id],
            ),
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
      return l10n.pick(vi: 'Con trưởng', en: 'First-born child');
    }
    return l10n.pick(vi: 'Con thứ $siblingOrder', en: 'Child #$siblingOrder');
  }

  String _memberGenerationLabelForDisplay({
    required AppLocalizations l10n,
    required MemberProfile member,
    required MemberProfile? viewer,
    required Map<String, MemberProfile> membersById,
    required int? relativeLevel,
    bool compact = false,
  }) {
    final base = compact
        ? l10n.pick(
            vi: 'Đời ${member.generation}',
            en: 'Gen ${member.generation}',
          )
        : l10n.pick(
            vi: 'Đời thứ ${member.generation}',
            en: 'Generation ${member.generation}',
          );
    if (relativeLevel == null) {
      return base;
    }
    final relativeTitle = viewer == null
        ? _relativeGenerationTitleFromLevel(
            l10n: l10n,
            relativeLevel: relativeLevel,
          )
        : KinshipTitleResolver.resolve(
            l10n: l10n,
            viewer: viewer,
            member: member,
            membersById: membersById,
          );
    return compact
        ? '$base • $relativeTitle'
        : l10n.pick(
            vi: '$base ($relativeTitle so với bạn)',
            en: '$base ($relativeTitle relative to you)',
          );
  }

  MemberProfile? _viewerMemberForGraph(GenealogyGraph graph) {
    final viewerId = widget.session.memberId?.trim();
    if (viewerId == null || viewerId.isEmpty) {
      return null;
    }
    return graph.membersById[viewerId];
  }

  Map<String, int?> _resolveRelativeLevelsByCurrentUser(GenealogyGraph graph) {
    _prepareDerivedGraphCache(graph);
    final fallback = {
      for (final entry in graph.generationLabels.entries)
        entry.key: entry.value.relativeLevel,
    };
    final viewerId = widget.session.memberId?.trim();
    if (_cachedRelativeLevelsByCurrentUser != null &&
        _cachedDerivedViewerId == viewerId) {
      return _cachedRelativeLevelsByCurrentUser!;
    }
    if (viewerId == null ||
        viewerId.isEmpty ||
        !graph.membersById.containsKey(viewerId)) {
      _cachedDerivedViewerId = viewerId;
      _cachedRelativeLevelsByCurrentUser = fallback;
      return fallback;
    }

    final labels = GenealogyGraphAlgorithms.buildGenerationLabels(
      membersById: graph.membersById,
      parentMap: graph.parentMap,
      childMap: graph.childMap,
      spouseMap: graph.spouseMap,
      focusMemberId: viewerId,
    );
    final resolved = {
      for (final entry in labels.entries) entry.key: entry.value.relativeLevel,
    };
    _cachedDerivedViewerId = viewerId;
    _cachedRelativeLevelsByCurrentUser = resolved;
    return resolved;
  }

  String _relativeGenerationTitleFromLevel({
    required AppLocalizations l10n,
    required int relativeLevel,
  }) {
    switch (relativeLevel) {
      case -4:
        return l10n.pick(vi: 'Cụ kỵ', en: 'Great-great-grandparent');
      case -3:
        return l10n.pick(vi: 'Cụ', en: 'Great-grandparent');
      case -2:
        return l10n.pick(vi: 'Ông/Bà', en: 'Grandparents');
      case -1:
        return l10n.pick(vi: 'Cha/Mẹ', en: 'Parents');
      case 0:
        return l10n.pick(vi: 'Tôi', en: 'Me');
      case 1:
        return l10n.pick(vi: 'Con', en: 'Child');
      case 2:
        return l10n.pick(vi: 'Cháu', en: 'Grandchild');
      case 3:
        return l10n.pick(vi: 'Chắt', en: 'Great-grandchild');
      case 4:
        return l10n.pick(vi: 'Chít', en: 'Great-great-grandchild');
      default:
        if (relativeLevel < -4) {
          return l10n.pick(vi: 'Cụ kỵ', en: 'Great-great-grandparent');
        }
        return l10n.pick(vi: 'Hậu duệ', en: 'Descendant');
    }
  }

  Map<String, int> _resolveSiblingOrders(GenealogyGraph graph) {
    _prepareDerivedGraphCache(graph);
    if (_cachedSiblingOrdersByMember != null) {
      return _cachedSiblingOrdersByMember!;
    }
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
    _cachedSiblingOrdersByMember = orders;
    return orders;
  }

  Map<String, List<_GenealogyHonorBadge>> _resolveHonorBadges(
    GenealogyGraph graph,
    Map<String, int> siblingOrders,
  ) {
    _prepareDerivedGraphCache(graph);
    if (_cachedHonorBadgesByMember != null &&
        identical(_cachedHonorBadgesSiblingOrders, siblingOrders)) {
      return _cachedHonorBadgesByMember!;
    }
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
    final resolved = {
      for (final entry in badges.entries)
        entry.key: entry.value.toList(growable: false)
          ..sort(
            (left, right) =>
                (priority[left] ?? 99).compareTo(priority[right] ?? 99),
          ),
    };
    _cachedHonorBadgesSiblingOrders = siblingOrders;
    _cachedHonorBadgesByMember = resolved;
    return resolved;
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

  bool _isMemberAlive(MemberProfile member) {
    final deathDate = member.deathDate?.trim() ?? '';
    if (deathDate.isNotEmpty) {
      return false;
    }
    final normalizedStatus = member.status.trim().toLowerCase();
    return normalizedStatus != 'deceased' && normalizedStatus != 'dead';
  }

  void _zoomIn() => _scaleTree(1.16);

  void _zoomOut() => _scaleTree(0.86);

  void _resetTreeViewport() {
    setState(() {
      _shouldAutoFitTree = true;
    });
  }

  Future<void> _openTreeExportSheet() async {
    final selectedAction = await showModalBottomSheet<_TreeExportAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _TreeExportSheet(),
    );

    if (selectedAction == null) {
      return;
    }

    await _runTreeExport(action: selectedAction);
  }

  Future<void> _runTreeExport({required _TreeExportAction action}) async {
    final l10n = context.l10n;
    try {
      final pdfBytes = await _buildTreePdf(
        paperSize: action.paperSize,
        preferLandscape: true,
        layout: action.layout,
      );
      if (!mounted) {
        return;
      }

      if (action.mode == _TreeExportMode.print) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
        return;
      }

      final fileName = _treePdfFileName(action.paperSize);
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                vi: action.layout == _TreeExportLayout.poster
                    ? 'Đã tạo PDF dạng poster nhiều trang. Bạn có thể lưu vào Files hoặc chia sẻ.'
                    : 'Đã tạo PDF. Bạn có thể lưu vào Files hoặc chia sẻ.',
                en: action.layout == _TreeExportLayout.poster
                    ? 'Poster PDF is ready. You can save it to Files or share it now.'
                    : 'PDF is ready. You can save it to Files or share it now.',
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
              l10n.pick(
                vi: 'Chưa thể xuất cây lúc này. Vui lòng thử lại sau.',
                en: 'Could not export the tree right now. Please try again.',
              ),
            ),
          ),
        );
    }
  }

  Future<Uint8List> _buildTreePdf({
    required _TreeExportPaperSize paperSize,
    required bool preferLandscape,
    required _TreeExportLayout layout,
    bool allowPosterFallback = true,
  }) async {
    final exportStopwatch = Stopwatch()..start();
    final boundaryContext = _treeCanvasPrintBoundaryKey.currentContext;
    final boundary =
        boundaryContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Tree canvas print boundary is not ready.');
    }

    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    if (layout == _TreeExportLayout.poster) {
      final posterBytes = await _buildTreePosterPdf(
        boundary: boundary,
        paperSize: paperSize,
        preferLandscape: preferLandscape,
      );
      exportStopwatch.stop();
      AppLogger.info(
        'genealogy tree poster export ready '
        '(size=${boundary.size.width.toStringAsFixed(0)}x${boundary.size.height.toStringAsFixed(0)}, '
        'elapsedMs=${exportStopwatch.elapsedMilliseconds}, '
        'pdfBytes=${posterBytes.length})',
      );
      return posterBytes;
    }

    final exportPixelRatio = _resolveTreeExportPixelRatio(boundary.size);
    final estimatedTileCount = _estimateTreeExportTileCount(
      boundarySize: boundary.size,
      pixelRatio: exportPixelRatio,
    );
    if (allowPosterFallback && estimatedTileCount > 24) {
      AppLogger.warning(
        'tree export fit->poster fallback due to heavy scene '
        '(estimatedTiles=$estimatedTileCount, '
        'size=${boundary.size.width.toStringAsFixed(0)}x${boundary.size.height.toStringAsFixed(0)})',
      );
      final posterBytes = await _buildTreePosterPdf(
        boundary: boundary,
        paperSize: paperSize,
        preferLandscape: preferLandscape,
      );
      exportStopwatch.stop();
      AppLogger.info(
        'genealogy tree auto poster export ready '
        '(elapsedMs=${exportStopwatch.elapsedMilliseconds}, '
        'pdfBytes=${posterBytes.length})',
      );
      return posterBytes;
    }
    final tiles = await _captureTreePdfTiles(
      boundary: boundary,
      pixelRatio: exportPixelRatio,
    );
    if (tiles.isEmpty) {
      throw StateError('Tree export did not capture any image tile.');
    }

    final pdf = pw.Document();
    final baseFormat = _pageFormatForPaperSize(paperSize);
    final useLandscape =
        preferLandscape && boundary.size.width >= boundary.size.height;
    final pageFormat = useLandscape ? baseFormat.landscape : baseFormat;
    const pageMargin = 10.0;
    final availableWidth = math.max(1.0, pageFormat.width - (pageMargin * 2));
    final availableHeight = math.max(1.0, pageFormat.height - (pageMargin * 2));
    final fitScale = math.min(
      availableWidth / boundary.size.width,
      availableHeight / boundary.size.height,
    );
    final contentWidth = boundary.size.width * fitScale;
    final contentHeight = boundary.size.height * fitScale;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(pageMargin),
        build: (context) {
          return pw.Center(
            child: pw.Container(
              width: contentWidth,
              height: contentHeight,
              child: pw.Stack(
                children: [
                  for (final tile in tiles)
                    pw.Positioned(
                      left: tile.logicalBounds.left * fitScale,
                      top: tile.logicalBounds.top * fitScale,
                      child: pw.SizedBox(
                        width: tile.logicalBounds.width * fitScale,
                        height: tile.logicalBounds.height * fitScale,
                        child: pw.Image(
                          pw.MemoryImage(tile.pngBytes),
                          fit: pw.BoxFit.fill,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    exportStopwatch.stop();
    AppLogger.info(
      'genealogy tree export ready '
      '(size=${boundary.size.width.toStringAsFixed(0)}x${boundary.size.height.toStringAsFixed(0)}, '
      'pixelRatio=${exportPixelRatio.toStringAsFixed(2)}, '
      'tiles=${tiles.length}, '
      'elapsedMs=${exportStopwatch.elapsedMilliseconds}, '
      'pdfBytes=${pdfBytes.length})',
    );
    return pdfBytes;
  }

  Future<Uint8List> _buildTreePosterPdf({
    required RenderRepaintBoundary boundary,
    required _TreeExportPaperSize paperSize,
    required bool preferLandscape,
  }) async {
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer as OffsetLayer?;
    if (layer == null) {
      return _buildTreePdf(
        paperSize: paperSize,
        preferLandscape: preferLandscape,
        layout: _TreeExportLayout.fit,
        allowPosterFallback: false,
      );
    }

    final baseFormat = _pageFormatForPaperSize(paperSize);
    final useLandscape =
        preferLandscape && boundary.size.width >= boundary.size.height;
    final pageFormat = useLandscape ? baseFormat.landscape : baseFormat;
    const pageMargin = 12.0;
    final printableWidth = math.max(1.0, pageFormat.width - (pageMargin * 2));
    final printableHeight = math.max(1.0, pageFormat.height - (pageMargin * 2));
    final posterLayout = _resolveTreePosterLayout(
      canvasSize: boundary.size,
      printableSize: Size(printableWidth, printableHeight),
      maxPages: 30,
    );
    final exportPixelRatio = _resolveTreePosterPixelRatio(
      basePixelRatio: _resolveTreeExportPixelRatio(boundary.size),
      posterScale: posterLayout.posterScale,
    );
    final pdf = pw.Document();
    final totalPages = posterLayout.columns * posterLayout.rows;
    var pageNumber = 0;

    for (var row = 0; row < posterLayout.rows; row++) {
      for (var column = 0; column < posterLayout.columns; column++) {
        final logicalRect = Rect.fromLTWH(
          column * posterLayout.logicalPageWidth,
          row * posterLayout.logicalPageHeight,
          math.min(
            posterLayout.logicalPageWidth,
            boundary.size.width - (column * posterLayout.logicalPageWidth),
          ),
          math.min(
            posterLayout.logicalPageHeight,
            boundary.size.height - (row * posterLayout.logicalPageHeight),
          ),
        );
        final ui.Image tileImage = await layer.toImage(
          logicalRect,
          pixelRatio: exportPixelRatio,
        );
        Uint8List imageBytes;
        try {
          final byteData = await tileImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('Could not encode tree poster page image.');
          }
          imageBytes = byteData.buffer.asUint8List();
        } finally {
          tileImage.dispose();
        }

        pageNumber += 1;
        final pageImage = pw.MemoryImage(imageBytes);
        final targetWidth = logicalRect.width * posterLayout.posterScale;
        final targetHeight = logicalRect.height * posterLayout.posterScale;
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(pageMargin),
            build: (context) {
              return pw.Stack(
                children: [
                  pw.Positioned(
                    left: 0,
                    top: 0,
                    child: pw.SizedBox(
                      width: targetWidth,
                      height: targetHeight,
                      child: pw.Image(pageImage, fit: pw.BoxFit.fill),
                    ),
                  ),
                  pw.Positioned(
                    right: 0,
                    bottom: 0,
                    child: pw.Text(
                      'Page $pageNumber / $totalPages',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
      if (row % 2 == 1) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    AppLogger.info(
      'genealogy poster layout '
      '(rows=${posterLayout.rows}, cols=${posterLayout.columns}, '
      'scale=${posterLayout.posterScale.toStringAsFixed(3)}, '
      'logicalPage=${posterLayout.logicalPageWidth.toStringAsFixed(1)}x'
      '${posterLayout.logicalPageHeight.toStringAsFixed(1)}, '
      'pixelRatio=${exportPixelRatio.toStringAsFixed(2)})',
    );
    return pdf.save();
  }

  Future<List<_TreePdfTile>> _captureTreePdfTiles({
    required RenderRepaintBoundary boundary,
    required double pixelRatio,
  }) async {
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer as OffsetLayer?;
    if (layer == null) {
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Could not encode tree image.');
        }
        return [
          _TreePdfTile(
            logicalBounds: Rect.fromLTWH(
              0,
              0,
              boundary.size.width,
              boundary.size.height,
            ),
            pngBytes: byteData.buffer.asUint8List(),
          ),
        ];
      } finally {
        image.dispose();
      }
    }

    final tileEdge = _resolveTreeExportTileLogicalEdge(pixelRatio);
    final tiles = <_TreePdfTile>[];
    var rowIndex = 0;
    for (var top = 0.0; top < boundary.size.height; top += tileEdge) {
      for (var left = 0.0; left < boundary.size.width; left += tileEdge) {
        final tileRect = Rect.fromLTWH(
          left,
          top,
          math.min(tileEdge, boundary.size.width - left),
          math.min(tileEdge, boundary.size.height - top),
        );
        final ui.Image tileImage = await layer.toImage(
          tileRect,
          pixelRatio: pixelRatio,
        );
        try {
          final byteData = await tileImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('Could not encode tree tile image.');
          }
          tiles.add(
            _TreePdfTile(
              logicalBounds: tileRect,
              pngBytes: byteData.buffer.asUint8List(),
            ),
          );
        } finally {
          tileImage.dispose();
        }
      }
      rowIndex += 1;
      if (rowIndex % 2 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return tiles;
  }

  double _resolveTreeExportPixelRatio(Size boundarySize) {
    const minPixelRatio = 0.95;
    const maxPixelRatio = 1.6;
    const maxPixels = 10000000.0; // Keep export stable for large trees.
    final estimatedPixels = boundarySize.width * boundarySize.height;
    if (estimatedPixels <= 0) {
      return minPixelRatio;
    }
    final adaptiveRatio = math.sqrt(maxPixels / estimatedPixels);
    return adaptiveRatio.clamp(minPixelRatio, maxPixelRatio).toDouble();
  }

  double _resolveTreeExportTileLogicalEdge(double pixelRatio) {
    const maxTilePixels = 3500000.0;
    final safeRatio = math.max(0.2, pixelRatio);
    final edge = math.sqrt(maxTilePixels / (safeRatio * safeRatio));
    return edge.clamp(560.0, 1400.0).toDouble();
  }

  int _estimateTreeExportTileCount({
    required Size boundarySize,
    required double pixelRatio,
  }) {
    final tileEdge = _resolveTreeExportTileLogicalEdge(pixelRatio);
    final rows = math.max(1, (boundarySize.height / tileEdge).ceil());
    final cols = math.max(1, (boundarySize.width / tileEdge).ceil());
    return rows * cols;
  }

  _TreePosterLayout _resolveTreePosterLayout({
    required Size canvasSize,
    required Size printableSize,
    required int maxPages,
  }) {
    final safeMaxPages = math.max(6, maxPages);
    var posterScale = 1.0;
    var cols = 1;
    var rows = 1;
    for (var i = 0; i < 8; i++) {
      final logicalPageWidth = printableSize.width / posterScale;
      final logicalPageHeight = printableSize.height / posterScale;
      cols = math.max(1, (canvasSize.width / logicalPageWidth).ceil());
      rows = math.max(1, (canvasSize.height / logicalPageHeight).ceil());
      final pageCount = cols * rows;
      if (pageCount <= safeMaxPages) {
        break;
      }
      final nextScale = (posterScale * math.sqrt(safeMaxPages / pageCount))
          .clamp(0.46, 1.0)
          .toDouble();
      if ((nextScale - posterScale).abs() < 0.01) {
        posterScale = nextScale;
        break;
      }
      posterScale = nextScale;
    }

    final logicalPageWidth = printableSize.width / posterScale;
    final logicalPageHeight = printableSize.height / posterScale;
    final boundedCols = math.max(
      1,
      (canvasSize.width / logicalPageWidth).ceil(),
    );
    final boundedRows = math.max(
      1,
      (canvasSize.height / logicalPageHeight).ceil(),
    );
    return _TreePosterLayout(
      posterScale: posterScale,
      logicalPageWidth: logicalPageWidth,
      logicalPageHeight: logicalPageHeight,
      columns: boundedCols,
      rows: boundedRows,
    );
  }

  double _resolveTreePosterPixelRatio({
    required double basePixelRatio,
    required double posterScale,
  }) {
    final ratio = (basePixelRatio * 0.92 * posterScale).clamp(0.82, 1.28);
    return ratio.toDouble();
  }

  PdfPageFormat _pageFormatForPaperSize(_TreeExportPaperSize size) {
    return switch (size) {
      _TreeExportPaperSize.a3 => PdfPageFormat.a3,
      _TreeExportPaperSize.a2 => PdfPageFormat(
        420 * PdfPageFormat.mm,
        594 * PdfPageFormat.mm,
      ),
    };
  }

  String _treePdfFileName(_TreeExportPaperSize size) {
    final now = DateTime.now().toLocal();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final paper = size.name.toUpperCase();
    return 'befam-family-tree-$paper-$year$month$day.pdf';
  }

  void _scaleTree(double ratio) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * ratio).clamp(
      _minTreeScale,
      _maxTreeScale,
    );
    if ((targetScale - currentScale).abs() < 0.0001) {
      return;
    }
    final factor = targetScale / currentScale;
    _transformController.value = _transformController.value.clone()
      ..scaleByDouble(factor, factor, factor, 1);
  }

  void _fitTreeToViewport({
    required _TreeScene scene,
    required Size viewport,
    String? focusMemberId,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return;
    }

    const fitPadding = 24.0;
    final availableWidth = math.max(1.0, viewport.width - (fitPadding * 2));
    final availableHeight = math.max(1.0, viewport.height - (fitPadding * 2));
    final fitScale = math.min(
      availableWidth / scene.canvasSize.width,
      availableHeight / scene.canvasSize.height,
    );
    final targetScale = fitScale.clamp(_minTreeScale, _maxTreeScale);
    final contentWidth = scene.canvasSize.width * targetScale;
    final contentHeight = scene.canvasSize.height * targetScale;

    final focusedRect = focusMemberId == null
        ? null
        : scene.nodeRects[focusMemberId];
    final preferredDx = focusedRect == null
        ? (viewport.width - contentWidth) / 2
        : (viewport.width / 2) -
              ((focusedRect.left + (focusedRect.width / 2)) * targetScale);
    final minDx = viewport.width - contentWidth - fitPadding;
    final maxDx = fitPadding;
    final dx = (contentWidth + (fitPadding * 2) <= viewport.width)
        ? (viewport.width - contentWidth) / 2
        : preferredDx.clamp(minDx, maxDx).toDouble();

    final preferredDy = (viewport.height - contentHeight) / 2;
    final minDy = viewport.height - contentHeight - fitPadding;
    final maxDy = fitPadding;
    final dy = (contentHeight + (fitPadding * 2) <= viewport.height)
        ? preferredDy
        : preferredDy.clamp(minDy, maxDy).toDouble();

    final target = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, targetScale, 1);
    _animateTransformTo(target, duration: const Duration(milliseconds: 320));
  }

  void _animateTransformTo(Matrix4 target, {required Duration duration}) {
    _centerAnimController?.dispose();
    _centerAnimController = AnimationController(
      vsync: this,
      duration: duration,
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
}

class _AdditionalClanPayload {
  const _AdditionalClanPayload({required this.draft});

  final ClanDraft draft;
}

class _DuplicateGenealogyCandidate {
  const _DuplicateGenealogyCandidate({
    required this.clanId,
    required this.genealogyName,
    required this.leaderName,
    required this.provinceCity,
    required this.score,
  });

  final String clanId;
  final String genealogyName;
  final String leaderName;
  final String provinceCity;
  final int score;

  static _DuplicateGenealogyCandidate? fromUnknownMap(Map raw) {
    final clanId = '${raw['clanId'] ?? ''}'.trim();
    if (clanId.isEmpty) {
      return null;
    }
    return _DuplicateGenealogyCandidate(
      clanId: clanId,
      genealogyName: '${raw['genealogyName'] ?? clanId}'.trim(),
      leaderName: '${raw['leaderName'] ?? ''}'.trim(),
      provinceCity: '${raw['provinceCity'] ?? ''}'.trim(),
      score: _parseScore(raw['score']),
    );
  }

  static int _parseScore(Object? value) {
    if (value is int) {
      return value.clamp(0, 100);
    }
    if (value is num) {
      return value.round().clamp(0, 100);
    }
    return 0;
  }
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
                      flex: 5,
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 7,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: Text(
                          l10n.pick(
                            vi: 'Tạo gia phả riêng',
                            en: 'Create private tree',
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
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
                      flex: 5,
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 7,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.call_split_outlined),
                        label: Text(
                          l10n.pick(vi: 'Tạo nhánh riêng', en: 'Create branch'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
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
    required this.allowBranchScope,
    required this.session,
    required this.memberCount,
    required this.branchCount,
  });

  final GenealogyScopeType scopeType;
  final bool isLoading;
  final bool isFromCache;
  final VoidCallback? onRefresh;
  final ValueChanged<GenealogyScopeType> onScopeChanged;
  final bool allowBranchScope;
  final AuthSession session;
  final int memberCount;
  final int branchCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final tokens = context.uiTokens;

    return Container(
      key: const Key('genealogy-landing-card'),
      padding: EdgeInsets.all(tokens.spaceXl + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(tokens.radiusLg + 4),
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
              AppCompactIconButton(
                key: const Key('genealogy-refresh-icon'),
                onPressed: onRefresh,
                tooltip: l10n.genealogyRefreshAction,
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
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceMd - 2,
            runSpacing: tokens.spaceMd - 2,
            children: [
              _LandingInfoChip(
                icon: Icons.visibility_outlined,
                label: l10n.pick(
                  vi: 'Đang xem: ${scopeType == GenealogyScopeType.clan ? 'Cả họ' : 'Chi hiện tại'}',
                  en: 'Viewing: ${scopeType == GenealogyScopeType.clan ? 'Whole clan' : 'Current branch'}',
                ),
              ),
              _LandingInfoChip(
                icon: Icons.groups_2_outlined,
                label: l10n.pick(
                  vi: '$memberCount thành viên',
                  en: '$memberCount members',
                ),
              ),
              _LandingInfoChip(
                icon: Icons.account_tree_outlined,
                label: l10n.pick(
                  vi: '$branchCount chi',
                  en: '$branchCount branches',
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceLg),
          if (allowBranchScope)
            Wrap(
              spacing: tokens.spaceMd,
              runSpacing: tokens.spaceMd - 2,
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
                    onSelected: (_) =>
                        onScopeChanged(GenealogyScopeType.branch),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LandingInfoChip extends StatelessWidget {
  const _LandingInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.uiTokens;
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          SizedBox(width: tokens.spaceXs + 2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddActionFab extends StatelessWidget {
  const _AddActionFab({
    required this.isMenuOpen,
    required this.canAddGenealogy,
    required this.showAddBranch,
    required this.canAddBranch,
    required this.showAddMember,
    required this.canAddMember,
    required this.onToggleMenu,
    required this.onAddGenealogy,
    required this.onAddBranch,
    required this.onAddMember,
  });

  final bool isMenuOpen;
  final bool canAddGenealogy;
  final bool showAddBranch;
  final bool canAddBranch;
  final bool showAddMember;
  final bool canAddMember;
  final VoidCallback onToggleMenu;
  final Future<void> Function() onAddGenealogy;
  final Future<void> Function() onAddBranch;
  final Future<void> Function() onAddMember;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMenuOpen) ...[
          FloatingActionButton.extended(
            heroTag: 'genealogy-add-tree-fab',
            onPressed: canAddGenealogy
                ? () => unawaited(onAddGenealogy())
                : null,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(l10n.pick(vi: 'Thêm gia phả', en: 'Add genealogy')),
          ),
          if (showAddBranch) ...[
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'genealogy-add-branch-fab',
              onPressed: canAddBranch ? () => unawaited(onAddBranch()) : null,
              icon: const Icon(Icons.call_split_outlined),
              label: Text(l10n.pick(vi: 'Thêm nhánh', en: 'Add branch')),
            ),
          ],
          if (showAddMember) ...[
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'genealogy-add-member-fab',
              onPressed: canAddMember ? () => unawaited(onAddMember()) : null,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.memberAddAction),
            ),
          ],
          const SizedBox(height: 10),
        ],
        OnboardingAnchor(
          anchorId: 'genealogy.main_add_fab',
          child: FloatingActionButton(
            heroTag: 'genealogy-main-add-fab',
            onPressed: onToggleMenu,
            tooltip: l10n.pick(vi: 'Thêm mới', en: 'Add'),
            child: Icon(isMenuOpen ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }
}

class _TreeZoomControls extends StatelessWidget {
  const _TreeZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onExport,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final tokens = context.uiTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceXs + 2,
          vertical: tokens.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCompactIconButton(
              key: const Key('tree-zoom-out'),
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove),
              tooltip: l10n.pick(vi: 'Thu nhỏ cây', en: 'Zoom out tree'),
            ),
            OnboardingAnchor(
              anchorId: 'genealogy.zoom_in',
              child: AppCompactIconButton(
                key: const Key('tree-zoom-in'),
                onPressed: onZoomIn,
                icon: const Icon(Icons.add),
                tooltip: l10n.pick(vi: 'Phóng to cây', en: 'Zoom in tree'),
              ),
            ),
            AppCompactIconButton(
              key: const Key('tree-zoom-reset'),
              onPressed: onReset,
              icon: const Icon(Icons.filter_center_focus),
              tooltip: l10n.pick(
                vi: 'Đặt lại vị trí cây',
                en: 'Reset tree view',
              ),
            ),
            AppAsyncAction(
              onPressed: onExport,
              builder: (context, onPressed, isLoading) {
                return AppCompactIconButton(
                  key: const Key('tree-print'),
                  onPressed: onPressed,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: l10n.pick(
                    vi: 'In hoặc tải xuống cây gia phả',
                    en: 'Print or download family tree',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _TreeExportMode { print, download }

enum _TreeExportLayout { fit, poster }

class _TreeExportAction {
  const _TreeExportAction({
    required this.mode,
    required this.paperSize,
    required this.layout,
  });

  final _TreeExportMode mode;
  final _TreeExportPaperSize paperSize;
  final _TreeExportLayout layout;
}

class _TreeExportSheet extends StatelessWidget {
  const _TreeExportSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = <_TreeExportAction>[
      const _TreeExportAction(
        mode: _TreeExportMode.print,
        paperSize: _TreeExportPaperSize.a3,
        layout: _TreeExportLayout.poster,
      ),
      const _TreeExportAction(
        mode: _TreeExportMode.download,
        paperSize: _TreeExportPaperSize.a3,
        layout: _TreeExportLayout.poster,
      ),
      const _TreeExportAction(
        mode: _TreeExportMode.print,
        paperSize: _TreeExportPaperSize.a2,
        layout: _TreeExportLayout.fit,
      ),
      const _TreeExportAction(
        mode: _TreeExportMode.download,
        paperSize: _TreeExportPaperSize.a2,
        layout: _TreeExportLayout.fit,
      ),
      const _TreeExportAction(
        mode: _TreeExportMode.print,
        paperSize: _TreeExportPaperSize.a3,
        layout: _TreeExportLayout.fit,
      ),
      const _TreeExportAction(
        mode: _TreeExportMode.download,
        paperSize: _TreeExportPaperSize.a3,
        layout: _TreeExportLayout.fit,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Xuất cây gia phả', en: 'Export family tree'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pick(
              vi: 'Khuyên dùng poster nhiều trang cho cây lớn để chữ rõ và tránh quá tải bộ nhớ.',
              en: 'For large trees, multi-page poster mode is recommended for better readability and lower memory load.',
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < actions.length; index++) ...[
            Builder(
              builder: (context) {
                final action = actions[index];
                return ListTile(
                  key: Key(
                    'tree-export-${action.mode.name}-${action.paperSize.name}',
                  ),
                  leading: Icon(
                    action.mode == _TreeExportMode.print
                        ? Icons.print_outlined
                        : Icons.download_outlined,
                  ),
                  title: Text(
                    l10n.pick(
                      vi: _treeExportActionTitleVi(action),
                      en: _treeExportActionTitleEn(action),
                    ),
                  ),
                  subtitle: Text(
                    l10n.pick(
                      vi: _treeExportActionSubtitleVi(action),
                      en: _treeExportActionSubtitleEn(action),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).pop(action),
                );
              },
            ),
            if (index != actions.length - 1)
              const Divider(height: 1, thickness: 0.5),
          ],
        ],
      ),
    );
  }
}

String _treeExportActionTitleVi(_TreeExportAction action) {
  final paper = action.paperSize.name.toUpperCase();
  if (action.layout == _TreeExportLayout.poster) {
    return action.mode == _TreeExportMode.print
        ? 'In poster nhiều trang ($paper)'
        : 'Tải poster PDF nhiều trang ($paper)';
  }
  return action.mode == _TreeExportMode.print
      ? 'In PDF 1 trang ($paper)'
      : 'Tải PDF 1 trang ($paper)';
}

String _treeExportActionTitleEn(_TreeExportAction action) {
  final paper = action.paperSize.name.toUpperCase();
  if (action.layout == _TreeExportLayout.poster) {
    return action.mode == _TreeExportMode.print
        ? 'Print multi-page poster ($paper)'
        : 'Download multi-page poster PDF ($paper)';
  }
  return action.mode == _TreeExportMode.print
      ? 'Print single-page PDF ($paper)'
      : 'Download single-page PDF ($paper)';
}

String _treeExportActionSubtitleVi(_TreeExportAction action) {
  if (action.layout == _TreeExportLayout.poster) {
    return action.mode == _TreeExportMode.print
        ? 'Giữ chữ rõ hơn cho cây lớn, mở hộp thoại in theo nhiều trang.'
        : 'Tạo PDF nhiều trang để lưu/chia sẻ dễ in khổ lớn.';
  }
  return action.mode == _TreeExportMode.print
      ? 'Mở hộp thoại in và dồn toàn bộ cây vào một trang.'
      : 'Lưu một tệp PDF 1 trang để chia sẻ nhanh.';
}

String _treeExportActionSubtitleEn(_TreeExportAction action) {
  if (action.layout == _TreeExportLayout.poster) {
    return action.mode == _TreeExportMode.print
        ? 'Keeps text readable on large trees and opens print dialog in multi-page poster mode.'
        : 'Generates a multi-page PDF that is easier to print in large formats.';
  }
  return action.mode == _TreeExportMode.print
      ? 'Opens print dialog and fits the entire tree into a single page.'
      : 'Creates a single-page PDF for quick sharing.';
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
    final tokens = context.uiTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceSm,
          vertical: tokens.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            SizedBox(width: tokens.spaceXs),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _TreeConnectorPainter extends CustomPainter {
  const _TreeConnectorPainter({
    required this.connectorGroups,
    required this.selectedMemberId,
  });

  final List<_TreeConnectorGroupGeometry> connectorGroups;
  final String? selectedMemberId;

  @override
  void paint(Canvas canvas, Size size) {
    final segmentCount = connectorGroups.fold<int>(
      0,
      (sum, group) => sum + group.segmentCount,
    );
    final drawHalo = segmentCount <= 220;
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFF8FAFC);
    final parentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF6B7280);
    final selectedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2563EB);

    void drawSegment(Offset from, Offset to, Paint paint) {
      if (drawHalo) {
        canvas.drawLine(from, to, haloPaint);
      }
      canvas.drawLine(from, to, paint);
    }

    for (final group in connectorGroups) {
      final isGroupSelected =
          selectedMemberId != null &&
          group.memberIds.contains(selectedMemberId);
      final sharedPaint = isGroupSelected ? selectedPaint : parentPaint;
      for (final segment in group.sharedSegments) {
        drawSegment(segment.from, segment.to, sharedPaint);
      }
      for (final segment in group.childSegments) {
        final edgePaint = isGroupSelected || segment.childId == selectedMemberId
            ? selectedPaint
            : parentPaint;
        drawSegment(segment.from, segment.to, edgePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) {
    return oldDelegate.connectorGroups != connectorGroups ||
        oldDelegate.selectedMemberId != selectedMemberId;
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.label,
    required this.value,
    this.isLast = false,
    this.trailing,
  });

  final String label;
  final String value;
  final bool isLast;
  final Widget? trailing;

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
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(value)),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Align(alignment: Alignment.centerRight, child: trailing!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactFactItem {
  const _CompactFactItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _CompactFactGrid extends StatelessWidget {
  const _CompactFactGrid({required this.items});

  final List<_CompactFactItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 62,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _CompactFactCard(item: item);
          },
        );
      },
    );
  }
}

class _CompactFactCard extends StatelessWidget {
  const _CompactFactCard({required this.item});

  final _CompactFactItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
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
                      trailing: MemberPhoneActionIconButton(
                        phoneNumber: member.phoneE164 ?? '',
                        contactName: member.displayName,
                      ),
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
                        vi: 'Thứ bậc anh/chị/em',
                        en: 'Sibling order',
                      ),
                      value: siblingOrderLabel ?? l10n.memberFieldUnset,
                    ),
                    _FactLine(
                      label: l10n.pick(
                        vi: 'Vai trò trong họ',
                        en: 'Honor badges',
                      ),
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
                      trailing: AddressDirectionIconButton(
                        address: member.addressText ?? '',
                        label: member.displayName,
                      ),
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
                      label: l10n.pick(vi: 'Số cha/mẹ', en: 'Parents'),
                      value: '$parentCount',
                    ),
                    _FactLine(
                      label: l10n.pick(vi: 'Số con', en: 'Children'),
                      value: '$childCount',
                    ),
                    _FactLine(
                      label: l10n.pick(vi: 'Số vợ/chồng', en: 'Spouses'),
                      value: '$spouseCount',
                    ),
                    _FactLine(
                      label: l10n.pick(vi: 'Tổng con cháu', en: 'Descendants'),
                      value: '$descendantCount',
                    ),
                    _FactLine(
                      label: l10n.pick(
                        vi: 'Số đời tổ tiên',
                        en: 'Ancestry depth',
                      ),
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
    required this.connectorGroups,
    required this.visibleMemberIds,
    required this.layoutProfile,
  });

  final Size canvasSize;
  final Map<String, Rect> nodeRects;
  final List<_TreeEdge> parentChildEdges;
  final List<_TreeEdge> spouseEdges;
  final List<_TreeConnectorGroupGeometry> connectorGroups;
  final Set<String> visibleMemberIds;
  final _TreeLayoutProfile layoutProfile;
}

class _TreeEdge {
  const _TreeEdge({required this.fromId, required this.toId});

  final String fromId;
  final String toId;
}

class _TreeConnectorGroupGeometry {
  const _TreeConnectorGroupGeometry({
    required this.memberIds,
    required this.sharedSegments,
    required this.childSegments,
  });

  final Set<String> memberIds;
  final List<_TreeLineSegment> sharedSegments;
  final List<_TreeChildLineSegment> childSegments;

  int get segmentCount => sharedSegments.length + childSegments.length;
}

class _TreeLineSegment {
  const _TreeLineSegment({required this.from, required this.to});

  final Offset from;
  final Offset to;
}

class _TreeChildLineSegment {
  const _TreeChildLineSegment({
    required this.childId,
    required this.from,
    required this.to,
  });

  final String childId;
  final Offset from;
  final Offset to;
}

class _TreePdfTile {
  const _TreePdfTile({required this.logicalBounds, required this.pngBytes});

  final Rect logicalBounds;
  final Uint8List pngBytes;
}

class _TreePosterLayout {
  const _TreePosterLayout({
    required this.posterScale,
    required this.logicalPageWidth,
    required this.logicalPageHeight,
    required this.columns,
    required this.rows,
  });

  final double posterScale;
  final double logicalPageWidth;
  final double logicalPageHeight;
  final int columns;
  final int rows;
}

class _HorizontalLaneAllocator {
  _HorizontalLaneAllocator({required this.step, required this.padding});

  final double step;
  final double padding;
  final Map<int, List<_HorizontalLaneInterval>> _intervalsByBucket = {};

  double reserve({
    required double preferredY,
    required double minY,
    required double maxY,
    required double left,
    required double right,
  }) {
    if (maxY <= minY) {
      return minY;
    }

    final preferred = preferredY.clamp(minY, maxY).toDouble();
    for (var ring = 0; ring < 140; ring++) {
      final offsets = ring == 0
          ? <double>[0]
          : <double>[ring * step, -ring * step];
      for (final offset in offsets) {
        final candidateY = preferred + offset;
        if (candidateY < minY || candidateY > maxY) {
          continue;
        }
        final bucket = (candidateY / step).round();
        final intervals = _intervalsByBucket.putIfAbsent(
          bucket,
          () => <_HorizontalLaneInterval>[],
        );
        final overlaps = intervals.any(
          (segment) =>
              !(right + padding < segment.left ||
                  left - padding > segment.right),
        );
        if (!overlaps) {
          intervals.add(_HorizontalLaneInterval(left: left, right: right));
          return candidateY;
        }
      }
    }

    final fallbackY = maxY;
    final fallbackBucket = (fallbackY / step).round();
    _intervalsByBucket
        .putIfAbsent(fallbackBucket, () => <_HorizontalLaneInterval>[])
        .add(_HorizontalLaneInterval(left: left, right: right));
    return fallbackY;
  }
}

class _HorizontalLaneInterval {
  const _HorizontalLaneInterval({required this.left, required this.right});

  final double left;
  final double right;
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
