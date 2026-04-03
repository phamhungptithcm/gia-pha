import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../ads/services/rewarded_discovery_attempt_service.dart';
import '../../auth/models/auth_entry_method.dart';
import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/onboarding_scope.dart';
import '../models/genealogy_discovery_result.dart';
import '../models/join_request_draft.dart';
import '../models/my_join_request_item.dart';
import 'my_join_requests_page.dart';
import '../services/genealogy_discovery_analytics_service.dart';
import '../services/genealogy_discovery_repository.dart';

class GenealogyDiscoveryPage extends StatefulWidget {
  const GenealogyDiscoveryPage({
    super.key,
    required this.repository,
    this.session,
    this.onAddGenealogyRequested,
    this.initialQuery,
    this.analyticsService,
    this.onboardingCoordinator,
    this.rewardedDiscoveryAttemptService,
  });

  final GenealogyDiscoveryRepository repository;
  final AuthSession? session;
  final Future<void> Function()? onAddGenealogyRequested;
  final String? initialQuery;
  final GenealogyDiscoveryAnalyticsService? analyticsService;
  final OnboardingCoordinator? onboardingCoordinator;
  final RewardedDiscoveryAttemptService? rewardedDiscoveryAttemptService;

  @override
  State<GenealogyDiscoveryPage> createState() => _GenealogyDiscoveryPageState();
}

class _GenealogyDiscoveryPageState extends State<GenealogyDiscoveryPage> {
  final _queryController = TextEditingController();
  final _leaderController = TextEditingController();
  final _locationController = TextEditingController();

  int _searchRequestSequence = 0;
  bool _isLoading = false;
  bool _isOpeningAddAction = false;
  String? _cancelingRequestId;
  String? _errorMessage;
  String? _myRequestsErrorMessage;
  List<GenealogyDiscoveryResult> _results = const [];
  List<MyJoinRequestItem> _myRequests = const [];
  final Set<String> _submittingClanIds = <String>{};
  late final OnboardingCoordinator _onboardingCoordinator;
  late final bool _ownsOnboardingCoordinator;
  late GenealogyDiscoveryAnalyticsService _analyticsService;
  bool _hasScheduledOnboarding = false;
  int _manualSearchesUsed = 0;
  int _rewardedUnlocksUsed = 0;
  int _rewardedExtraSearchesRemaining = 0;

  @override
  void initState() {
    super.initState();
    _ownsOnboardingCoordinator = widget.onboardingCoordinator == null;
    _onboardingCoordinator =
        widget.onboardingCoordinator ??
        createDefaultOnboardingCoordinator(
          session: widget.session ?? _fallbackSession,
        );
    _analyticsService =
        widget.analyticsService ??
        createDefaultGenealogyDiscoveryAnalyticsService();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _queryController.text = initialQuery;
    }
    unawaited(
      widget.rewardedDiscoveryAttemptService?.primeRewardedDiscoveryAttempt(),
    );
    _runSearch(source: 'initial');
  }

  AuthSession get _fallbackSession => AuthSession(
    uid: 'guest_discovery',
    loginMethod: AuthEntryMethod.phone,
    phoneE164: '',
    displayName: 'Guest discovery',
    accessMode: AuthMemberAccessMode.unlinked,
    linkedAuthUid: false,
    isSandbox: true,
    signedInAtIso: DateTime.now().toIso8601String(),
  );

  @override
  void didUpdateWidget(covariant GenealogyDiscoveryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _onboardingCoordinator.updateSession(widget.session ?? _fallbackSession);
      _hasScheduledOnboarding = false;
    }
    if (oldWidget.analyticsService != widget.analyticsService) {
      _analyticsService =
          widget.analyticsService ??
          createDefaultGenealogyDiscoveryAnalyticsService();
    }
    if (oldWidget.rewardedDiscoveryAttemptService !=
        widget.rewardedDiscoveryAttemptService) {
      unawaited(
        widget.rewardedDiscoveryAttemptService?.primeRewardedDiscoveryAttempt(),
      );
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _leaderController.dispose();
    _locationController.dispose();
    unawaited(_onboardingCoordinator.interrupt());
    if (_ownsOnboardingCoordinator) {
      _onboardingCoordinator.dispose();
    }
    super.dispose();
  }

  RewardedDiscoveryAttemptService? get _rewardedService =>
      widget.rewardedDiscoveryAttemptService;

  bool get _isRewardedDiscoveryActive =>
      _rewardedService?.isRewardedDiscoveryEnabled ?? false;

  bool _sourceConsumesDiscoveryAttempt(String source) {
    return source == 'search_button' || source == 'keyboard_submit';
  }

  int get _freeSearchesRemaining {
    final service = _rewardedService;
    if (service == null) {
      return 0;
    }
    final remaining = service.freeSearchesPerSession - _manualSearchesUsed;
    if (remaining < 0) {
      return 0;
    }
    return remaining;
  }

  Future<void> _requestSearch({String source = 'manual'}) async {
    if (!_sourceConsumesDiscoveryAttempt(source)) {
      await _runSearch(source: source);
      return;
    }

    final allowed = await _tryAcquireDiscoveryAttempt();
    if (!allowed) {
      return;
    }
    await _runSearch(source: source);
  }

  Future<bool> _tryAcquireDiscoveryAttempt() async {
    final service = _rewardedService;
    if (!_isRewardedDiscoveryActive || service == null) {
      return true;
    }

    if (_freeSearchesRemaining > 0) {
      setState(() {
        _manualSearchesUsed += 1;
      });
      return true;
    }

    if (_rewardedExtraSearchesRemaining > 0) {
      setState(() {
        _rewardedExtraSearchesRemaining -= 1;
      });
      return true;
    }

    final canOfferReward = _rewardedUnlocksUsed < service.maxUnlocksPerSession;
    unawaited(
      _analyticsService.trackAttemptLimitReached(
        freeSearchesPerSession: service.freeSearchesPerSession,
        manualSearchesUsed: _manualSearchesUsed,
        rewardedUnlocksUsed: _rewardedUnlocksUsed,
        canOfferReward: canOfferReward,
      ),
    );

    if (!canOfferReward) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.pick(
                vi: 'Bạn đã dùng hết lượt khám phá thêm trong phiên này. Vui lòng thử lại sau.',
                en: 'You have used all extra discovery attempts for this session. Please try again later.',
              ),
            ),
          ),
        );
      }
      return false;
    }

    return _promptToUnlockExtraDiscoveryAttempt(service);
  }

  Future<bool> _promptToUnlockExtraDiscoveryAttempt(
    RewardedDiscoveryAttemptService service,
  ) async {
    final l10n = context.l10n;
    unawaited(
      _analyticsService.trackRewardPromptOpened(
        freeSearchesPerSession: service.freeSearchesPerSession,
        rewardedUnlocksUsed: _rewardedUnlocksUsed,
      ),
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            l10n.pick(
              vi: 'Mở thêm lượt khám phá?',
              en: 'Unlock an extra discovery attempt?',
            ),
          ),
          content: Text(
            l10n.pick(
              vi: 'Bạn đã dùng hết lượt tìm miễn phí trong phiên này. Xem một quảng cáo thưởng để mở thêm 1 lượt tìm gia phả.',
              en: 'You have used the free searches for this session. Watch a rewarded ad to unlock 1 extra genealogy search.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.pick(vi: 'Để sau', en: 'Maybe later')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pick(vi: 'Xem quảng cáo', en: 'Watch ad')),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted) {
      unawaited(
        _analyticsService.trackRewardPromptDismissed(reason: 'user_cancelled'),
      );
      return false;
    }

    final result = await service.unlockExtraDiscoveryAttempt(
      screenId: 'tree_discovery',
      placementId: 'rewarded_discovery_extra_attempt',
    );
    switch (result) {
      case RewardedDiscoveryAttemptResult.granted:
        setState(() {
          _rewardedUnlocksUsed += 1;
          _rewardedExtraSearchesRemaining += service.extraSearchesPerReward;
          _rewardedExtraSearchesRemaining = _rewardedExtraSearchesRemaining - 1;
        });
        unawaited(
          _analyticsService.trackRewardUnlocked(
            rewardedUnlocksUsed: _rewardedUnlocksUsed,
            extraSearchesGranted: service.extraSearchesPerReward,
          ),
        );
        return true;
      case RewardedDiscoveryAttemptResult.dismissed:
        unawaited(
          _analyticsService.trackRewardPromptDismissed(reason: 'ad_dismissed'),
        );
      case RewardedDiscoveryAttemptResult.unavailable:
        unawaited(
          _analyticsService.trackRewardPromptDismissed(
            reason: 'ad_unavailable',
          ),
        );
      case RewardedDiscoveryAttemptResult.failed:
        unawaited(
          _analyticsService.trackRewardPromptDismissed(reason: 'ad_failed'),
        );
      case RewardedDiscoveryAttemptResult.disabled:
        unawaited(
          _analyticsService.trackRewardPromptDismissed(
            reason: 'reward_disabled',
          ),
        );
    }

    if (!mounted) {
      return false;
    }
    final message = switch (result) {
      RewardedDiscoveryAttemptResult.dismissed => l10n.pick(
        vi: 'Bạn chưa hoàn tất quảng cáo thưởng nên chưa mở thêm lượt tìm.',
        en: 'You did not complete the rewarded ad, so no extra search was unlocked.',
      ),
      RewardedDiscoveryAttemptResult.unavailable => l10n.pick(
        vi: 'Quảng cáo thưởng tạm thời chưa sẵn sàng. Vui lòng thử lại sau.',
        en: 'Rewarded ad is not available right now. Please try again later.',
      ),
      RewardedDiscoveryAttemptResult.failed => l10n.pick(
        vi: 'Không thể phát quảng cáo thưởng lúc này. Vui lòng thử lại sau.',
        en: 'Could not show the rewarded ad right now. Please try again later.',
      ),
      RewardedDiscoveryAttemptResult.disabled => l10n.pick(
        vi: 'Mở thêm lượt khám phá hiện đang tắt.',
        en: 'Extra discovery attempts are currently disabled.',
      ),
      RewardedDiscoveryAttemptResult.granted => '',
    };
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }

  Future<void> _runSearch({String source = 'manual'}) async {
    final requestId = ++_searchRequestSequence;
    final queryLength = _queryController.text.trim().length;
    final hasLeaderFilter = _leaderController.text.trim().isNotEmpty;
    final hasLocationFilter = _locationController.text.trim().isNotEmpty;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _myRequestsErrorMessage = null;
    });

    List<GenealogyDiscoveryResult> items = const [];
    var myRequests = List<MyJoinRequestItem>.from(_myRequests);
    Object? searchError;
    Object? myRequestsError;

    await Future.wait<void>([
      () async {
        try {
          items = await widget.repository.search(
            query: _queryController.text,
            leaderQuery: _leaderController.text,
            locationQuery: _locationController.text,
          );
        } catch (error) {
          searchError = error;
        }
      }(),
      () async {
        final session = widget.session;
        if (session == null) {
          myRequests = const [];
          return;
        }
        try {
          myRequests = await widget.repository.loadMyJoinRequests(
            session: session,
          );
        } catch (error) {
          myRequestsError = error;
        }
      }(),
    ]);

    if (!mounted || requestId != _searchRequestSequence) {
      return;
    }
    if (searchError != null) {
      unawaited(
        _analyticsService.trackSearchFailed(
          queryLength: queryLength,
          hasLeaderFilter: hasLeaderFilter,
          hasLocationFilter: hasLocationFilter,
          source: source,
        ),
      );
      if (!mounted || requestId != _searchRequestSequence) {
        return;
      }
      setState(() {
        _results = const [];
        _errorMessage = context.l10n.pick(
          vi: 'Không thể tải danh sách gia phả công khai. Vui lòng thử lại.',
          en: 'Could not load public genealogy list. Please try again.',
        );
        _myRequests = myRequests;
        _myRequestsErrorMessage = myRequestsError == null
            ? null
            : context.l10n.pick(
                vi: 'Không thể tải yêu cầu bạn đã gửi. Vui lòng thử lại.',
                en: 'Could not load your submitted requests. Please try again.',
              );
      });
    } else {
      unawaited(
        _analyticsService.trackSearchSubmitted(
          queryLength: queryLength,
          hasLeaderFilter: hasLeaderFilter,
          hasLocationFilter: hasLocationFilter,
          resultCount: items.length,
          source: source,
        ),
      );
      setState(() {
        _results = items;
        if (myRequestsError == null) {
          _myRequests = myRequests;
        }
        _myRequestsErrorMessage = myRequestsError == null
            ? null
            : context.l10n.pick(
                vi: 'Không thể tải yêu cầu bạn đã gửi. Vui lòng thử lại.',
                en: 'Could not load your submitted requests. Please try again.',
              );
      });
    }

    if (mounted && requestId == _searchRequestSequence) {
      setState(() {
        _isLoading = false;
      });
      _scheduleOnboardingIfNeeded();
    }
  }

  void _scheduleOnboardingIfNeeded() {
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
            id: 'genealogy_discovery_opened',
            routeId: 'genealogy_discovery',
          ),
          delay: const Duration(milliseconds: 900),
        ),
      );
    });
  }

  Map<String, MyJoinRequestItem> get _pendingRequestsByClanId {
    final byClan = <String, MyJoinRequestItem>{};
    for (final request in _myRequests) {
      if (!request.isPending) {
        continue;
      }
      final clanId = request.clanId.trim();
      if (clanId.isEmpty) {
        continue;
      }
      final existing = byClan[clanId];
      if (existing == null ||
          request.submittedAtEpochMs >= existing.submittedAtEpochMs) {
        byClan[clanId] = request;
      }
    }
    return byClan;
  }

  Future<void> _cancelRequest(MyJoinRequestItem request) async {
    final session = widget.session;
    if (session == null || _cancelingRequestId != null) {
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            l10n.pick(
              vi: 'Hủy yêu cầu tham gia?',
              en: 'Cancel this join request?',
            ),
          ),
          content: Text(
            l10n.pick(
              vi: 'Bạn có thể gửi lại yêu cầu sau nếu cần.',
              en: 'You can submit a new request again later.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.pick(vi: 'Giữ lại', en: 'Keep')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pick(vi: 'Hủy yêu cầu', en: 'Cancel request')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _cancelingRequestId = request.id;
    });

    try {
      await widget.repository.cancelJoinRequest(
        session: session,
        requestId: request.id,
      );
      unawaited(
        _analyticsService.trackJoinRequestCanceled(
          clanId: request.clanId,
          source: 'discovery_page',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Đã hủy yêu cầu tham gia.',
              en: 'Join request canceled.',
            ),
          ),
        ),
      );
      await _runSearch(source: 'post_cancel_refresh');
    } catch (_) {
      unawaited(
        _analyticsService.trackJoinRequestCancelFailed(
          clanId: request.clanId,
          source: 'discovery_page',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Không thể hủy yêu cầu lúc này. Vui lòng thử lại.',
              en: 'Could not cancel request right now. Please retry.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && _cancelingRequestId == request.id) {
        setState(() {
          _cancelingRequestId = null;
        });
      }
    }
  }

  Future<void> _openJoinRequestSheet(GenealogyDiscoveryResult result) async {
    if (_submittingClanIds.contains(result.clanId)) {
      return;
    }
    final pendingRequest = _pendingRequestsByClanId[result.clanId];
    if (pendingRequest != null) {
      unawaited(
        _analyticsService.trackJoinRequestDuplicateBlocked(
          clanId: result.clanId,
        ),
      );
      final sentDate = _formatShortDate(pendingRequest.submittedAtEpochMs);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Bạn đã gửi yêu cầu vào $sentDate. Vui lòng chờ ban quản trị duyệt.',
              en: 'You already submitted this request on $sentDate. Please wait for approval.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _submittingClanIds.add(result.clanId);
    });
    unawaited(
      _analyticsService.trackJoinRequestSheetOpened(
        clanId: result.clanId,
        hasMemberLink: (widget.session?.memberId ?? '').trim().isNotEmpty,
      ),
    );
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _JoinRequestSheet(
          session: widget.session,
          result: result,
          repository: widget.repository,
          analyticsService: _analyticsService,
        );
      },
    );

    if (submitted == true && mounted) {
      final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _myRequests = [
          MyJoinRequestItem(
            id: 'local_${result.clanId}_$nowEpochMs',
            clanId: result.clanId,
            genealogyName: result.genealogyName,
            status: 'pending',
            submittedAtEpochMs: nowEpochMs,
            canCancel: false,
          ),
          ..._myRequests.where(
            (item) =>
                !(item.clanId == result.clanId &&
                    item.status.trim().toLowerCase() == 'pending'),
          ),
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Đã gửi yêu cầu tham gia gia phả. Ban quản trị sẽ phản hồi sớm.',
              en: 'Join request submitted. The governance team will review soon.',
            ),
          ),
        ),
      );
      await _runSearch(source: 'post_submit_refresh');
    } else {
      unawaited(
        _analyticsService.trackJoinRequestSheetDismissed(
          clanId: result.clanId,
          dismissalReason: submitted == false ? 'cta_cancel' : 'system_dismiss',
        ),
      );
    }
    if (mounted) {
      setState(() {
        _submittingClanIds.remove(result.clanId);
      });
    }
  }

  Future<void> _openAddGenealogyAction() async {
    final action = widget.onAddGenealogyRequested;
    if (_isOpeningAddAction || action == null) {
      return;
    }
    setState(() {
      _isOpeningAddAction = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningAddAction = false;
        });
      }
    }
  }

  Future<void> _openMyRequestsPage() async {
    final session = widget.session;
    if (session == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return MyJoinRequestsPage(
            session: session,
            repository: widget.repository,
            analyticsService: _analyticsService,
            onOpenDiscoveryRequested: (query) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    return GenealogyDiscoveryPage(
                      session: session,
                      repository: widget.repository,
                      onAddGenealogyRequested: widget.onAddGenealogyRequested,
                      initialQuery: query,
                      analyticsService: _analyticsService,
                      rewardedDiscoveryAttemptService:
                          widget.rewardedDiscoveryAttemptService,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
    if (mounted) {
      await _runSearch(source: 'post_requests_refresh');
    }
  }

  String _formatShortDate(int epochMs) {
    final locale = context.l10n.localeName;
    final formatter = DateFormat('dd/MM/yyyy', locale);
    return formatter.format(
      DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal(),
    );
  }

  String _resolveGenealogyName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return context.l10n.pick(
        vi: 'Gia phả chưa đặt tên',
        en: 'Unnamed genealogy',
      );
    }
    final normalized = trimmed.toLowerCase();
    if (normalized == 'pending join request' ||
        normalized == 'requested genealogy' ||
        normalized == 'join request') {
      return context.l10n.pick(
        vi: 'Gia phả đã gửi yêu cầu',
        en: 'Requested genealogy',
      );
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pendingRequestsByClanId = _pendingRequestsByClanId;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick(vi: 'Khám phá gia phả', en: 'Genealogy discovery'),
        ),
      ),
      floatingActionButton: widget.onAddGenealogyRequested == null
          ? null
          : OnboardingAnchor(
              anchorId: 'discovery.add_fab',
              child: FloatingActionButton(
                key: const Key('discovery-add-fab'),
                onPressed: _isOpeningAddAction
                    ? null
                    : () => unawaited(_openAddGenealogyAction()),
                tooltip: l10n.pick(vi: 'Thêm gia phả', en: 'Add genealogy'),
                child: _isOpeningAddAction
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.add),
              ),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _runSearch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(vi: 'Tìm gia phả', en: 'Find genealogies'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OnboardingAnchor(
                        anchorId: 'discovery.query_input',
                        child: TextField(
                          key: const Key('discovery-query-input'),
                          controller: _queryController,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) =>
                              _requestSearch(source: 'keyboard_submit'),
                          decoration: InputDecoration(
                            labelText: l10n.pick(
                              vi: 'Từ khóa chung',
                              en: 'General keyword',
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _leaderController,
                              enabled: !_isLoading,
                              onSubmitted: (_) =>
                                  _requestSearch(source: 'keyboard_submit'),
                              decoration: InputDecoration(
                                labelText: l10n.pick(
                                  vi: 'Trưởng tộc',
                                  en: 'Leader',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AddressAutocompleteField(
                              controller: _locationController,
                              enabled: !_isLoading,
                              cityCountryOnly: true,
                              onSubmitted: (_) =>
                                  _requestSearch(source: 'keyboard_submit'),
                              labelText: l10n.pick(
                                vi: 'Địa phương',
                                en: 'Location',
                              ),
                              hintText: l10n.pick(
                                vi: 'Ví dụ: Đà Nẵng, Việt Nam',
                                en: 'Example: Da Nang, Vietnam',
                              ),
                              textInputAction: TextInputAction.search,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OnboardingAnchor(
                        anchorId: 'discovery.search_button',
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('discovery-search-button'),
                            onPressed: _isLoading
                                ? null
                                : () => _requestSearch(source: 'search_button'),
                            icon: const Icon(Icons.travel_explore_outlined),
                            label: Text(
                              l10n.pick(
                                vi: 'Tìm gia phả',
                                en: 'Search genealogies',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_errorMessage!),
                  ),
                ),
              ],
              if (_myRequestsErrorMessage != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_myRequestsErrorMessage!),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_results.isEmpty && !_isLoading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.pick(
                        vi: 'Chưa có kết quả phù hợp.',
                        en: 'No matching genealogy found.',
                      ),
                    ),
                  ),
                )
              else
                ..._results.map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final pendingRequest =
                                    pendingRequestsByClanId[result.clanId];
                                final pendingSinceEpochMs =
                                    pendingRequest?.submittedAtEpochMs ??
                                    result.pendingJoinRequestSubmittedAtEpochMs;
                                final isPendingForCurrentUser =
                                    pendingSinceEpochMs != null ||
                                    result.hasPendingJoinRequest;
                                final isCanceling =
                                    pendingRequest != null &&
                                    _cancelingRequestId == pendingRequest.id;
                                final isSubmittingJoin = _submittingClanIds
                                    .contains(result.clanId);
                                final genealogyName = _resolveGenealogyName(
                                  result.genealogyName,
                                );
                                final leaderName =
                                    result.leaderName.trim().isEmpty
                                    ? l10n.pick(
                                        vi: 'Chưa có trưởng tộc',
                                        en: 'Leader not set',
                                      )
                                    : result.leaderName;
                                final provinceCity =
                                    result.provinceCity.trim().isEmpty
                                    ? l10n.pick(
                                        vi: 'Chưa rõ địa phương',
                                        en: 'Unknown location',
                                      )
                                    : result.provinceCity;
                                final pendingCancelAction =
                                    pendingRequest != null
                                    ? () => _cancelRequest(pendingRequest)
                                    : _openMyRequestsPage;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      genealogyName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (isPendingForCurrentUser) ...[
                                      const SizedBox(height: 8),
                                      Chip(
                                        avatar: const Icon(
                                          Icons.schedule,
                                          size: 16,
                                        ),
                                        label: Text(
                                          l10n.pick(
                                            vi: 'Đã gửi yêu cầu',
                                            en: 'Request submitted',
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.pick(
                                        vi: 'Trưởng tộc: $leaderName · $provinceCity',
                                        en: 'Leader: $leaderName · $provinceCity',
                                      ),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    if (result.summary.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        result.summary,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.pick(
                                        vi: '${result.memberCount} thành viên · ${result.branchCount} chi',
                                        en: '${result.memberCount} members · ${result.branchCount} branches',
                                      ),
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        FilledButton.tonalIcon(
                                          onPressed:
                                              isSubmittingJoin || isCanceling
                                              ? null
                                              : isPendingForCurrentUser
                                              ? pendingCancelAction
                                              : () => _openJoinRequestSheet(
                                                  result,
                                                ),
                                          icon: isSubmittingJoin
                                              ? const SizedBox.square(
                                                  dimension: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : isPendingForCurrentUser
                                              ? isCanceling
                                                    ? const SizedBox.square(
                                                        dimension: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.cancel_outlined,
                                                      )
                                              : const Icon(
                                                  Icons.how_to_reg_outlined,
                                                ),
                                          label: Text(
                                            isSubmittingJoin
                                                ? l10n.pick(
                                                    vi: 'Đang gửi...',
                                                    en: 'Submitting...',
                                                  )
                                                : isPendingForCurrentUser
                                                ? l10n.pick(
                                                    vi: 'Hủy yêu cầu',
                                                    en: 'Cancel request',
                                                  )
                                                : l10n.pick(
                                                    vi: 'Gửi yêu cầu tham gia',
                                                    en: 'Request to join',
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return OnboardingScope(controller: _onboardingCoordinator, child: scaffold);
  }
}

class _JoinRequestSheet extends StatefulWidget {
  const _JoinRequestSheet({
    required this.result,
    required this.repository,
    required this.session,
    required this.analyticsService,
  });

  final GenealogyDiscoveryResult result;
  final GenealogyDiscoveryRepository repository;
  final AuthSession? session;
  final GenealogyDiscoveryAnalyticsService analyticsService;

  @override
  State<_JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<_JoinRequestSheet> {
  late final TextEditingController _nameController;
  final _relationshipController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.session?.displayName ?? '',
    );
    _relationshipController.text = 'Con cháu trong họ';
    _contactController.text = widget.session?.phoneE164.trim() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _displayGenealogyName(AppLocalizations l10n) {
    final trimmed = widget.result.genealogyName.trim();
    if (trimmed.isEmpty) {
      return l10n.pick(vi: 'Gia phả chưa đặt tên', en: 'Unnamed genealogy');
    }
    final normalized = trimmed.toLowerCase();
    if (normalized == 'pending join request' ||
        normalized == 'requested genealogy' ||
        normalized == 'join request') {
      return l10n.pick(vi: 'Gia phả đã gửi yêu cầu', en: 'Requested genealogy');
    }
    return trimmed;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    final relationship = _relationshipController.text.trim();
    final contact = _contactController.text.trim();
    if (name.isEmpty || relationship.isEmpty || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Vui lòng nhập đủ họ tên, quan hệ và thông tin liên hệ.',
              en: 'Please fill full name, relationship, and contact info.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.repository.submitJoinRequest(
        draft: JoinRequestDraft(
          clanId: widget.result.clanId,
          applicantName: name,
          relationshipToFamily: relationship,
          contactInfo: contact,
          message: _messageController.text.trim(),
          applicantMemberId: widget.session?.memberId,
        ),
      );
      unawaited(
        widget.analyticsService.trackJoinRequestSubmitted(
          clanId: widget.result.clanId,
          hasMessage: _messageController.text.trim().isNotEmpty,
          hasMemberLink: (widget.session?.memberId ?? '').trim().isNotEmpty,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorText = error.toString().toLowerCase();
      final alreadyRequested =
          errorText.contains('already-exists') ||
          errorText.contains('already exists') ||
          errorText.contains('pending join request');
      unawaited(
        widget.analyticsService.trackJoinRequestSubmitFailed(
          clanId: widget.result.clanId,
          reason: alreadyRequested ? 'already_pending' : 'unknown',
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyRequested
                ? l10n.pick(
                    vi: 'Bạn đã có yêu cầu đang chờ duyệt cho họ tộc này. Vui lòng chờ phản hồi hoặc hủy yêu cầu cũ.',
                    en: 'You already have a pending request for this clan. Please wait for review or cancel your previous request.',
                  )
                : l10n.pick(
                    vi: 'Gửi yêu cầu thất bại. Vui lòng thử lại.',
                    en: 'Could not submit join request. Please retry.',
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick(
                  vi: 'Yêu cầu tham gia ${_displayGenealogyName(l10n)}',
                  en: 'Join request for ${_displayGenealogyName(l10n)}',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.pick(vi: 'Họ tên', en: 'Full name'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _relationshipController,
                decoration: InputDecoration(
                  labelText: l10n.pick(
                    vi: 'Quan hệ với gia phả',
                    en: 'Relationship to genealogy',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contactController,
                decoration: InputDecoration(
                  labelText: l10n.pick(
                    vi: 'Thông tin liên hệ',
                    en: 'Contact info',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.pick(
                    vi: 'Lời nhắn (tùy chọn)',
                    en: 'Message (optional)',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.pick(
                                vi: 'Gửi yêu cầu',
                                en: 'Submit request',
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
    );
  }
}
