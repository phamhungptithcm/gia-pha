import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/join_request_review_item.dart';
import '../services/genealogy_discovery_analytics_service.dart';
import '../services/genealogy_discovery_repository.dart';

class JoinRequestReviewPage extends StatefulWidget {
  const JoinRequestReviewPage({
    super.key,
    required this.session,
    required this.repository,
    this.analyticsService,
  });

  final AuthSession session;
  final GenealogyDiscoveryRepository repository;
  final GenealogyDiscoveryAnalyticsService? analyticsService;

  @override
  State<JoinRequestReviewPage> createState() => _JoinRequestReviewPageState();
}

class _JoinRequestReviewPageState extends State<JoinRequestReviewPage> {
  bool _isLoading = false;
  String? _submittingRequestId;
  String? _errorMessage;
  List<JoinRequestReviewItem> _requests = const [];
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
  void didUpdateWidget(covariant JoinRequestReviewPage oldWidget) {
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
      final requests = await widget.repository.loadPendingJoinRequests(
        session: widget.session,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = context.l10n.pick(
          vi: 'Không thể tải danh sách yêu cầu tham gia.',
          en: 'Could not load join requests.',
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

  Future<void> _review({
    required JoinRequestReviewItem item,
    required bool approve,
  }) async {
    if (_submittingRequestId != null) {
      return;
    }
    setState(() {
      _submittingRequestId = item.id;
    });
    try {
      await widget.repository.reviewJoinRequest(
        session: widget.session,
        requestId: item.id,
        approve: approve,
      );
      unawaited(
        _analyticsService.trackJoinRequestReviewSubmitted(
          clanId: item.clanId,
          decision: approve ? 'approve' : 'reject',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: approve
                  ? 'Đã duyệt yêu cầu tham gia.'
                  : 'Đã từ chối yêu cầu tham gia.',
              en: approve ? 'Join request approved.' : 'Join request rejected.',
            ),
          ),
        ),
      );
      await _load();
    } catch (_) {
      unawaited(
        _analyticsService.trackJoinRequestReviewFailed(
          clanId: item.clanId,
          decision: approve ? 'approve' : 'reject',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Không thể cập nhật yêu cầu. Vui lòng thử lại.',
              en: 'Could not update request. Please retry.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingRequestId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick(vi: 'Duyệt yêu cầu tham gia', en: 'Join requests'),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading || _submittingRequestId != null
                ? null
                : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? AppLoadingState(
                message: l10n.pick(
                  vi: 'Đang tải yêu cầu cần duyệt...',
                  en: 'Loading review queue...',
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
                              vi: 'Không có yêu cầu tham gia đang chờ duyệt.',
                              en: 'No pending join requests.',
                            ),
                          ),
                        ),
                      ),
                    ..._requests.map((item) {
                      final isRowSubmitting = _submittingRequestId == item.id;
                      final isSubmittingAny = _submittingRequestId != null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.applicantName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.pick(
                                    vi: 'Quan hệ: ${item.relationshipToFamily}\nLiên hệ: ${item.contactInfo}',
                                    en: 'Relationship: ${item.relationshipToFamily}\nContact: ${item.contactInfo}',
                                  ),
                                ),
                                if ((item.message ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.message!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isSubmittingAny
                                            ? null
                                            : () => _review(
                                                item: item,
                                                approve: false,
                                              ),
                                        icon: isRowSubmitting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.close),
                                        label: Text(
                                          l10n.pick(
                                            vi: 'Từ chối',
                                            en: 'Reject',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: isSubmittingAny
                                            ? null
                                            : () => _review(
                                                item: item,
                                                approve: true,
                                              ),
                                        icon: isRowSubmitting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.check),
                                        label: Text(
                                          l10n.pick(vi: 'Duyệt', en: 'Approve'),
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
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}
