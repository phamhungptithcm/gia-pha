import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_ui_tokens.dart';
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
  final _queryFocusNode = FocusNode();

  int _searchRequestSequence = 0;
  bool _isLoading = false;
  bool _isOpeningAddAction = false;
  bool _showAdvancedFilters = false;
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
    _queryFocusNode.dispose();
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
        _errorMessage = _buildDiscoveryLoadErrorMessage(searchError);
        _myRequests = myRequests;
        _myRequestsErrorMessage = myRequestsError == null
            ? null
            : _buildMyRequestsLoadErrorMessage(myRequestsError);
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
            : _buildMyRequestsLoadErrorMessage(myRequestsError);
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

  bool get _hasTypedSearchInput =>
      _queryController.text.trim().isNotEmpty ||
      _leaderController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty;

  bool get _hasAdvancedFilterValues =>
      _leaderController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty;

  void _focusSearchInput() {
    if (_isLoading) {
      return;
    }
    FocusScope.of(context).requestFocus(_queryFocusNode);
  }

  bool _looksLikeAppCheckError(Object? error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('app check') ||
        normalized.contains('appcheck') ||
        normalized.contains('firebaseappcheck.googleapis.com') ||
        normalized.contains('callable request verification failed') ||
        normalized.contains('token was rejected');
  }

  String _buildDiscoveryLoadErrorMessage(Object? error) {
    if (_looksLikeAppCheckError(error)) {
      return context.l10n.pick(
        vi: 'Dịch vụ gia phả đang được chuẩn bị. Vui lòng thử lại sau ít phút.',
        en: 'The genealogy service is being prepared. Please try again in a few minutes.',
      );
    }
    return context.l10n.pick(
      vi: 'Không thể tải danh sách gia phả công khai. Vui lòng thử lại.',
      en: 'Could not load public genealogy list. Please try again.',
    );
  }

  String _buildMyRequestsLoadErrorMessage(Object? error) {
    if (_looksLikeAppCheckError(error)) {
      return context.l10n.pick(
        vi: 'Yêu cầu đã gửi sẽ hiển thị sau khi dịch vụ sẵn sàng.',
        en: 'Your submitted requests will appear once the service is ready.',
      );
    }
    return context.l10n.pick(
      vi: 'Không thể tải yêu cầu bạn đã gửi. Vui lòng thử lại.',
      en: 'Could not load your submitted requests. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    final pendingRequestsByClanId = _pendingRequestsByClanId;
    final canAddGenealogy = widget.onAddGenealogyRequested != null;
    final canOpenMyRequests = widget.session != null;
    final hasResults = _results.isNotEmpty;
    final effectiveShowAdvancedFilters =
        _showAdvancedFilters || _hasAdvancedFilterValues;
    final combinedStatusMessage = <String>{
      if ((_errorMessage ?? '').trim().isNotEmpty) _errorMessage!.trim(),
      if ((_myRequestsErrorMessage ?? '').trim().isNotEmpty)
        _myRequestsErrorMessage!.trim(),
    }.join('\n\n');
    final heroBadgeLabel = pendingRequestsByClanId.isNotEmpty
        ? l10n.pick(
            vi: '${pendingRequestsByClanId.length} yêu cầu đang chờ',
            en: '${pendingRequestsByClanId.length} pending requests',
          )
        : l10n.pick(vi: 'Bắt đầu từ tên họ', en: 'Start with a family name');
    final heroTitle = hasResults
        ? l10n.pick(
            vi: 'Có ${_results.length} gia phả để bạn xem',
            en: '${_results.length} genealogies are ready for you',
          )
        : l10n.pick(
            vi: 'Tìm gia phả của gia đình bạn',
            en: 'Find your family genealogy',
          );
    final heroDescription = hasResults
        ? l10n.pick(
            vi: 'Chọn gia phả phù hợp để xem cây gia phả và theo dõi lịch họ.',
            en: 'Choose a matching genealogy to explore the tree and follow family events.',
          )
        : l10n.pick(
            vi: 'Xem cây gia phả, kết nối người thân và theo dõi lịch họ ở cùng một nơi.',
            en: 'Explore the family tree, stay connected, and follow family events in one place.',
          );
    final heroRequestLabel =
        _myRequestsErrorMessage == null && _myRequests.isNotEmpty
        ? l10n.pick(
            vi: 'Yêu cầu đã gửi (${_myRequests.length})',
            en: 'Submitted requests (${_myRequests.length})',
          )
        : l10n.pick(vi: 'Yêu cầu đã gửi', en: 'Submitted requests');

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(l10n.pick(vi: 'Gia phả', en: 'Genealogy')),
      ),
      floatingActionButton: null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _runSearch,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLg + 4,
              tokens.spaceMd,
              tokens.spaceLg + 4,
              tokens.space2xl + 4,
            ),
            children: [
              _DiscoverySurfaceCard(
                showAccentOrbs: true,
                padding: EdgeInsets.fromLTRB(
                  tokens.spaceLg,
                  tokens.spaceMd + 2,
                  tokens.spaceLg,
                  tokens.spaceMd + 4,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
                    theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.78,
                    ),
                    Colors.white.withValues(alpha: 0.96),
                  ],
                ),
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
                              _DiscoveryInlinePill(
                                label: heroBadgeLabel,
                                icon: Icons.account_tree_outlined,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.74,
                                ),
                              ),
                              SizedBox(height: tokens.spaceSm + 2),
                              Text(
                                heroTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                              ),
                              SizedBox(height: tokens.spaceXs + 2),
                              Text(
                                heroDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: tokens.spaceSm),
                        const _DiscoveryHeroGlyph(size: 68),
                      ],
                    ),
                    SizedBox(height: tokens.spaceMd),
                    Wrap(
                      spacing: tokens.spaceSm,
                      runSpacing: tokens.spaceSm,
                      children: [
                        FilledButton.icon(
                          onPressed: _focusSearchInput,
                          icon: const Icon(Icons.travel_explore_outlined),
                          label: Text(
                            l10n.pick(vi: 'Tìm gia phả', en: 'Find genealogy'),
                          ),
                        ),
                        if (canAddGenealogy)
                          OnboardingAnchor(
                            anchorId: 'discovery.add_fab',
                            child: FilledButton.tonalIcon(
                              onPressed: _isOpeningAddAction
                                  ? null
                                  : () => unawaited(_openAddGenealogyAction()),
                              icon: _isOpeningAddAction
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                              label: Text(
                                l10n.pick(
                                  vi: 'Tạo gia phả mới',
                                  en: 'Create a new genealogy',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              _DiscoverySurfaceCard(
                padding: EdgeInsets.all(tokens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(vi: 'Tìm nhanh', en: 'Quick search'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXs + 2),
                    Text(
                      l10n.pick(
                        vi: 'Nhập tên họ, chi hoặc địa phương để bắt đầu.',
                        en: 'Start with a family name, branch, or location.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: tokens.spaceMd),
                    OnboardingAnchor(
                      anchorId: 'discovery.query_input',
                      child: TextField(
                        key: const Key('discovery-query-input'),
                        focusNode: _queryFocusNode,
                        controller: _queryController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) =>
                            _requestSearch(source: 'keyboard_submit'),
                        decoration: InputDecoration(
                          hintText: l10n.pick(
                            vi: 'Tên họ, chi hoặc địa phương',
                            en: 'Family name, branch, or location',
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _showAdvancedFilters =
                                          !_showAdvancedFilters;
                                    });
                                  },
                            icon: Icon(
                              effectiveShowAdvancedFilters
                                  ? Icons.tune_rounded
                                  : Icons.tune_outlined,
                            ),
                            label: Text(
                              effectiveShowAdvancedFilters
                                  ? l10n.pick(
                                      vi: 'Ẩn bộ lọc',
                                      en: 'Hide filters',
                                    )
                                  : l10n.pick(
                                      vi: 'Bộ lọc nâng cao',
                                      en: 'Advanced filters',
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(width: tokens.spaceSm),
                        OnboardingAnchor(
                          anchorId: 'discovery.search_button',
                          child: FilledButton.icon(
                            key: const Key('discovery-search-button'),
                            onPressed: _isLoading
                                ? null
                                : () => _requestSearch(source: 'search_button'),
                            icon: _isLoading
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.travel_explore_outlined),
                            label: Text(
                              _isLoading
                                  ? l10n.pick(vi: 'Đang tìm', en: 'Searching')
                                  : l10n.pick(vi: 'Tìm', en: 'Search'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: effectiveShowAdvancedFilters
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: EdgeInsets.only(top: tokens.spaceMd),
                        child: Column(
                          children: [
                            TextField(
                              controller: _leaderController,
                              enabled: !_isLoading,
                              onSubmitted: (_) =>
                                  _requestSearch(source: 'keyboard_submit'),
                              decoration: InputDecoration(
                                hintText: l10n.pick(
                                  vi: 'Người đại diện',
                                  en: 'Representative',
                                ),
                              ),
                            ),
                            SizedBox(height: tokens.spaceSm),
                            AddressAutocompleteField(
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
                                vi: 'Ví dụ: Dallas, Hoa Kỳ',
                                en: 'Example: Dallas, United States',
                              ),
                              textInputAction: TextInputAction.search,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (combinedStatusMessage.isNotEmpty) ...[
                SizedBox(height: tokens.spaceMd),
                _DiscoveryStatusCard(
                  title: l10n.pick(
                    vi: 'Tạm thời chưa tải được đầy đủ dữ liệu',
                    en: 'Some data is temporarily unavailable',
                  ),
                  description: combinedStatusMessage,
                  icon: Icons.cloud_off_outlined,
                  primaryActionLabel: l10n.pick(vi: 'Thử lại', en: 'Try again'),
                  onPrimaryAction: _isLoading ? null : _runSearch,
                  secondaryActionLabel: canOpenMyRequests
                      ? heroRequestLabel
                      : null,
                  onSecondaryAction: canOpenMyRequests
                      ? _openMyRequestsPage
                      : null,
                ),
              ] else if (!hasResults && !_isLoading) ...[
                SizedBox(height: tokens.spaceMd),
                _DiscoveryStatusCard(
                  title: _hasTypedSearchInput
                      ? l10n.pick(
                          vi: 'Chưa thấy gia phả phù hợp',
                          en: 'No matching genealogy yet',
                        )
                      : l10n.pick(
                          vi: 'Bắt đầu bằng một vài thông tin quen thuộc',
                          en: 'Start with a few familiar details',
                        ),
                  description: _hasTypedSearchInput
                      ? l10n.pick(
                          vi: 'Thử đổi từ khóa, người đại diện hoặc địa phương để tìm kỹ hơn.',
                          en: 'Try another keyword, representative, or location.',
                        )
                      : l10n.pick(
                          vi: 'Tên họ, người đại diện hoặc địa phương thường là cách nhanh nhất để tìm đúng gia phả.',
                          en: 'A family name, representative, or location is usually the fastest way to find the right genealogy.',
                        ),
                  icon: Icons.search_off_rounded,
                ),
              ],
              if (hasResults) ...[
                SizedBox(height: tokens.spaceLg),
                Text(
                  l10n.pick(vi: 'Gia phả phù hợp', en: 'Matching genealogies'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
                ..._results.map(
                  (result) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.spaceMd),
                    child: Builder(
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
                        final isSubmittingJoin = _submittingClanIds.contains(
                          result.clanId,
                        );
                        final genealogyName = _resolveGenealogyName(
                          result.genealogyName,
                        );
                        final leaderName = result.leaderName.trim().isEmpty
                            ? l10n.pick(
                                vi: 'Chưa có người đại diện',
                                en: 'Representative not set',
                              )
                            : result.leaderName;
                        final provinceCity = result.provinceCity.trim().isEmpty
                            ? l10n.pick(
                                vi: 'Chưa rõ địa phương',
                                en: 'Unknown location',
                              )
                            : result.provinceCity;
                        final pendingCancelAction = pendingRequest != null
                            ? () => _cancelRequest(pendingRequest)
                            : _openMyRequestsPage;

                        return _DiscoveryResultCard(
                          genealogyName: genealogyName,
                          leaderName: leaderName,
                          locationLabel: provinceCity,
                          summary: result.summary,
                          memberCount: result.memberCount,
                          branchCount: result.branchCount,
                          isPendingForCurrentUser: isPendingForCurrentUser,
                          pendingDateLabel: pendingSinceEpochMs == null
                              ? null
                              : _formatShortDate(pendingSinceEpochMs),
                          isBusy: isSubmittingJoin || isCanceling,
                          primaryActionLabel: isSubmittingJoin
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
                          onPrimaryAction: isSubmittingJoin || isCanceling
                              ? null
                              : isPendingForCurrentUser
                              ? pendingCancelAction
                              : () => _openJoinRequestSheet(result),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return OnboardingScope(controller: _onboardingCoordinator, child: scaffold);
  }
}

VoidCallback? _deferAsyncCallback(Future<void> Function()? action) {
  if (action == null) {
    return null;
  }
  return () => unawaited(action());
}

class _DiscoverySurfaceCard extends StatelessWidget {
  const _DiscoverySurfaceCard({
    required this.child,
    this.padding,
    this.gradient,
    this.color,
    this.showAccentOrbs = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? color;
  final bool showAccentOrbs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(tokens.radiusLg + 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.88),
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.92),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (showAccentOrbs) ...[
              Positioned(
                top: -42,
                right: -26,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.secondary.withValues(alpha: 0.18),
                  ),
                  child: const SizedBox(width: 136, height: 136),
                ),
              ),
              Positioned(
                left: -36,
                bottom: -48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  child: const SizedBox(width: 132, height: 132),
                ),
              ),
            ],
            Padding(
              padding: padding ?? EdgeInsets.all(tokens.spaceLg),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryInlinePill extends StatelessWidget {
  const _DiscoveryInlinePill({
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    final resolvedForeground =
        foregroundColor ?? theme.colorScheme.onSurfaceVariant;
    final resolvedBackground =
        backgroundColor ?? Colors.white.withValues(alpha: 0.72);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.62),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceSm + 2,
          vertical: tokens.spaceXs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: resolvedForeground),
              SizedBox(width: tokens.spaceXs + 2),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: resolvedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryHeroGlyph extends StatelessWidget {
  const _DiscoveryHeroGlyph({this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  colorScheme.primaryContainer.withValues(alpha: 0.90),
                  colorScheme.secondaryContainer.withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: size * 0.14,
            right: size * 0.14,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.16,
            left: size * 0.16,
            child: Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.84),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_tree_rounded,
              size: size * 0.24,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          Positioned(
            bottom: size * 0.12,
            right: size * 0.12,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.88),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.52),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.groups_2_rounded,
                size: size * 0.12,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryStatusCard extends StatelessWidget {
  const _DiscoveryStatusCard({
    required this.title,
    required this.description,
    required this.icon,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;

    return _DiscoverySurfaceCard(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(tokens.radiusLg - 8),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceSm + 2),
              child: Icon(icon, size: 22, color: theme.colorScheme.primary),
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: tokens.spaceXs + 2),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (primaryActionLabel != null || secondaryActionLabel != null) ...[
            SizedBox(height: tokens.spaceMd),
            Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceSm,
              children: [
                if (primaryActionLabel != null)
                  FilledButton(
                    onPressed: _deferAsyncCallback(onPrimaryAction),
                    child: Text(primaryActionLabel!),
                  ),
                if (secondaryActionLabel != null)
                  TextButton(
                    onPressed: _deferAsyncCallback(onSecondaryAction),
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveryResultCard extends StatelessWidget {
  const _DiscoveryResultCard({
    required this.genealogyName,
    required this.leaderName,
    required this.locationLabel,
    required this.summary,
    required this.memberCount,
    required this.branchCount,
    required this.isPendingForCurrentUser,
    required this.isBusy,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.pendingDateLabel,
  });

  final String genealogyName;
  final String leaderName;
  final String locationLabel;
  final String summary;
  final int memberCount;
  final int branchCount;
  final bool isPendingForCurrentUser;
  final bool isBusy;
  final String primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final String? pendingDateLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    final summaryText = summary.trim().isEmpty
        ? l10n.pick(
            vi: 'Xem thông tin dòng họ, kết nối người thân và theo dõi các cập nhật quan trọng.',
            en: 'Explore the family tree, connect with relatives, and follow key updates.',
          )
        : summary.trim();
    final pendingLabel = pendingDateLabel == null
        ? l10n.pick(vi: 'Đang chờ duyệt', en: 'Pending review')
        : l10n.pick(
            vi: 'Đã gửi $pendingDateLabel',
            en: 'Sent $pendingDateLabel',
          );

    return _DiscoverySurfaceCard(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  genealogyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              if (isPendingForCurrentUser) ...[
                SizedBox(width: tokens.spaceSm),
                _DiscoveryInlinePill(
                  label: pendingLabel,
                  icon: Icons.schedule_rounded,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              _DiscoveryInlinePill(
                label: leaderName,
                icon: Icons.person_outline_rounded,
              ),
              _DiscoveryInlinePill(
                label: locationLabel,
                icon: Icons.location_on_outlined,
              ),
              _DiscoveryInlinePill(
                label: l10n.pick(
                  vi: '$memberCount người',
                  en: '$memberCount members',
                ),
                icon: Icons.groups_2_outlined,
              ),
              _DiscoveryInlinePill(
                label: l10n.pick(
                  vi: '$branchCount nhánh',
                  en: '$branchCount branches',
                ),
                icon: Icons.account_tree_outlined,
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Text(
            summaryText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: tokens.spaceLg),
          SizedBox(
            width: double.infinity,
            child: isPendingForCurrentUser
                ? FilledButton.tonalIcon(
                    onPressed: _deferAsyncCallback(onPrimaryAction),
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close_rounded),
                    label: Text(primaryActionLabel),
                  )
                : FilledButton.icon(
                    onPressed: _deferAsyncCallback(onPrimaryAction),
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(primaryActionLabel),
                  ),
          ),
        ],
      ),
    );
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
