import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/my_join_request_item.dart';
import '../services/genealogy_discovery_analytics_service.dart';
import '../services/genealogy_discovery_repository.dart';

class MyJoinRequestsPage extends StatefulWidget {
  const MyJoinRequestsPage({
    super.key,
    required this.session,
    required this.repository,
    this.onOpenDiscoveryRequested,
    this.analyticsService,
  });

  final AuthSession session;
  final GenealogyDiscoveryRepository repository;
  final Future<void> Function(String query)? onOpenDiscoveryRequested;
  final GenealogyDiscoveryAnalyticsService? analyticsService;

  @override
  State<MyJoinRequestsPage> createState() => _MyJoinRequestsPageState();
}

class _MyJoinRequestsPageState extends State<MyJoinRequestsPage> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _cancelingRequestId;
  List<MyJoinRequestItem> _requests = const [];
  Map<String, String> _genealogyNameByClanId = const {};
  late GenealogyDiscoveryAnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();
    _analyticsService =
        widget.analyticsService ??
        createDefaultGenealogyDiscoveryAnalyticsService();
    _load();
  }

  @override
  void didUpdateWidget(covariant MyJoinRequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analyticsService != widget.analyticsService) {
      _analyticsService =
          widget.analyticsService ??
          createDefaultGenealogyDiscoveryAnalyticsService();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final requests = await widget.repository.loadMyJoinRequests(
        session: widget.session,
      );
      final clanNames = await _loadClanNames(requests);
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
        _genealogyNameByClanId = clanNames;
      });
      unawaited(
        _analyticsService.trackMyJoinRequestsOpened(
          totalCount: requests.length,
          pendingCount: requests.where((item) => item.isPending).length,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = context.l10n.pick(
          vi: 'Không thể tải yêu cầu bạn đã gửi. Vui lòng thử lại.',
          en: 'Could not load your submitted requests. Please retry.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>> _loadClanNames(
    List<MyJoinRequestItem> requests,
  ) async {
    final clanIds = requests
        .where((item) => (item.genealogyName ?? '').trim().isEmpty)
        .map((item) => item.clanId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (clanIds.isEmpty) {
      return const {};
    }
    try {
      final results = await widget.repository.search(limit: 200);
      final map = <String, String>{};
      for (final result in results) {
        final clanId = result.clanId.trim();
        if (!clanIds.contains(clanId)) {
          continue;
        }
        final name = result.genealogyName.trim();
        if (name.isNotEmpty) {
          map[clanId] = name;
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _cancelRequest(MyJoinRequestItem request) async {
    if (_cancelingRequestId != null || !request.canCancel) {
      return;
    }
    setState(() {
      _cancelingRequestId = request.id;
    });
    try {
      await widget.repository.cancelJoinRequest(
        session: widget.session,
        requestId: request.id,
      );
      unawaited(
        _analyticsService.trackJoinRequestCanceled(
          clanId: request.clanId,
          source: 'my_requests_page',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Đã hủy yêu cầu tham gia.',
              en: 'Join request canceled.',
            ),
          ),
        ),
      );
      await _load();
    } catch (_) {
      unawaited(
        _analyticsService.trackJoinRequestCancelFailed(
          clanId: request.clanId,
          source: 'my_requests_page',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Không thể hủy yêu cầu lúc này. Vui lòng thử lại.',
              en: 'Could not cancel the request right now. Please retry.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelingRequestId = null;
        });
      }
    }
  }

  Future<void> _openDiscovery(MyJoinRequestItem request) async {
    final action = widget.onOpenDiscoveryRequested;
    if (action == null) {
      return;
    }
    final clanName =
        _genealogyNameByClanId[request.clanId]?.trim() ??
        (request.genealogyName ?? '').trim();
    final query = clanName.isNotEmpty ? clanName : request.clanId;
    await action(query);
  }

  String _resolveGenealogyName(MyJoinRequestItem request) {
    final l10n = context.l10n;
    final resolvedFromMap =
        _genealogyNameByClanId[request.clanId]?.trim() ?? '';
    if (resolvedFromMap.isNotEmpty) {
      return resolvedFromMap;
    }
    final resolvedFromRequest = (request.genealogyName ?? '').trim();
    final normalized = resolvedFromRequest.toLowerCase();
    if (normalized == 'pending join request' ||
        normalized == 'requested genealogy' ||
        normalized == 'join request') {
      return l10n.pick(vi: 'Gia phả đã gửi yêu cầu', en: 'Requested genealogy');
    }
    if (resolvedFromRequest.isNotEmpty) {
      return resolvedFromRequest;
    }
    return l10n.pick(vi: 'Gia phả chưa đặt tên', en: 'Unnamed genealogy');
  }

  String _statusLabel(String status) {
    return switch (status.trim().toLowerCase()) {
      'pending' => context.l10n.pick(
        vi: 'Đã gửi yêu cầu',
        en: 'Request submitted',
      ),
      'approved' => context.l10n.pick(vi: 'Đã duyệt', en: 'Approved'),
      'rejected' => context.l10n.pick(vi: 'Đã từ chối', en: 'Rejected'),
      'canceled' => context.l10n.pick(vi: 'Đã hủy', en: 'Canceled'),
      _ => context.l10n.pick(vi: 'Không xác định', en: 'Unknown'),
    };
  }

  Color _statusBackground(ColorScheme scheme, String status) {
    return switch (status.trim().toLowerCase()) {
      'approved' => scheme.primaryContainer,
      'rejected' || 'canceled' => scheme.errorContainer,
      _ => scheme.secondaryContainer,
    };
  }

  Color _statusForeground(ColorScheme scheme, String status) {
    return switch (status.trim().toLowerCase()) {
      'approved' => scheme.onPrimaryContainer,
      'rejected' || 'canceled' => scheme.onErrorContainer,
      _ => scheme.onSecondaryContainer,
    };
  }

  String _submittedAtLabel(int epochMs) {
    final format = DateFormat('dd/MM/yyyy HH:mm', context.l10n.localeName);
    final date = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
    return format.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick(vi: 'Yêu cầu bạn đã gửi', en: 'Your join requests'),
        ),
        actions: [
          IconButton(
            tooltip: l10n.pick(vi: 'Làm mới', en: 'Refresh'),
            onPressed: _isLoading || _cancelingRequestId != null ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? AppLoadingState(
                message: l10n.pick(
                  vi: 'Đang tải yêu cầu đã gửi...',
                  en: 'Loading your requests...',
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    if (_errorMessage != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(_errorMessage!),
                        ),
                      ),
                    if (_requests.isEmpty && _errorMessage == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.pick(
                              vi: 'Bạn chưa gửi yêu cầu tham gia nào.',
                              en: 'You have not submitted any join requests.',
                            ),
                          ),
                        ),
                      ),
                    for (final request in _requests)
                      Builder(
                        builder: (context) {
                          final isPending = request.isPending;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _resolveGenealogyName(request),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Chip(
                                      avatar: isPending
                                          ? const Icon(Icons.schedule, size: 16)
                                          : null,
                                      backgroundColor: _statusBackground(
                                        theme.colorScheme,
                                        request.status,
                                      ),
                                      side: BorderSide.none,
                                      label: Text(
                                        _statusLabel(request.status),
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: _statusForeground(
                                                theme.colorScheme,
                                                request.status,
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.pick(
                                        vi: 'Đã gửi: ${_submittedAtLabel(request.submittedAtEpochMs)}',
                                        en: 'Submitted: ${_submittedAtLabel(request.submittedAtEpochMs)}',
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        if (widget.onOpenDiscoveryRequested !=
                                            null)
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _openDiscovery(request),
                                            icon: const Icon(
                                              Icons.travel_explore_outlined,
                                            ),
                                            label: Text(
                                              l10n.pick(
                                                vi: 'Xem trong tìm kiếm',
                                                en: 'Open in discovery',
                                              ),
                                            ),
                                          ),
                                        if (request.canCancel)
                                          FilledButton.tonalIcon(
                                            onPressed:
                                                _cancelingRequestId ==
                                                    request.id
                                                ? null
                                                : () => _cancelRequest(request),
                                            icon:
                                                _cancelingRequestId ==
                                                    request.id
                                                ? const SizedBox.square(
                                                    dimension: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.cancel_outlined,
                                                  ),
                                            label: Text(
                                              l10n.pick(
                                                vi: 'Hủy yêu cầu',
                                                en: 'Cancel request',
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
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
