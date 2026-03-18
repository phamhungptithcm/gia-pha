import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/address_action_tools.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/genealogy_discovery_result.dart';
import '../models/join_request_draft.dart';
import '../models/my_join_request_item.dart';
import '../services/genealogy_discovery_repository.dart';

class GenealogyDiscoveryPage extends StatefulWidget {
  const GenealogyDiscoveryPage({
    super.key,
    required this.repository,
    this.session,
    this.onAddGenealogyRequested,
  });

  final GenealogyDiscoveryRepository repository;
  final AuthSession? session;
  final Future<void> Function()? onAddGenealogyRequested;

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

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _leaderController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final requestId = ++_searchRequestSequence;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _myRequestsErrorMessage = null;
    });

    List<GenealogyDiscoveryResult> items = const [];
    List<MyJoinRequestItem> myRequests = const [];
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
      setState(() {
        _results = items;
        _myRequests = myRequests;
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
    }
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
      await _runSearch();
    } catch (_) {
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
    final pendingRequest = _pendingRequestsByClanId[result.clanId];
    if (pendingRequest != null) {
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

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _JoinRequestSheet(
          session: widget.session,
          result: result,
          repository: widget.repository,
        );
      },
    );

    if (submitted == true && mounted) {
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
      await _runSearch();
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

  String _formatShortDate(int epochMs) {
    final locale = context.l10n.localeName;
    final formatter = DateFormat('dd/MM/yyyy', locale);
    return formatter.format(
      DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal(),
    );
  }

  String _joinRequestStatusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      'pending' => context.l10n.pick(
        vi: 'Đang chờ duyệt',
        en: 'Pending review',
      ),
      'approved' => context.l10n.pick(vi: 'Đã duyệt', en: 'Approved'),
      'rejected' => context.l10n.pick(vi: 'Không được duyệt', en: 'Rejected'),
      'canceled' => context.l10n.pick(vi: 'Đã hủy', en: 'Canceled'),
      _ => context.l10n.pick(vi: 'Không xác định', en: 'Unknown'),
    };
  }

  Widget _buildStatusChip(MyJoinRequestItem request) {
    final theme = Theme.of(context);
    final normalized = request.status.trim().toLowerCase();
    final Color backgroundColor;
    final Color foregroundColor;
    if (normalized == 'approved') {
      backgroundColor = theme.colorScheme.primaryContainer;
      foregroundColor = theme.colorScheme.onPrimaryContainer;
    } else if (normalized == 'rejected' || normalized == 'canceled') {
      backgroundColor = theme.colorScheme.errorContainer;
      foregroundColor = theme.colorScheme.onErrorContainer;
    } else {
      backgroundColor = theme.colorScheme.secondaryContainer;
      foregroundColor = theme.colorScheme.onSecondaryContainer;
    }
    return Chip(
      label: Text(_joinRequestStatusLabel(request.status)),
      backgroundColor: backgroundColor,
      labelStyle: theme.textTheme.labelLarge?.copyWith(color: foregroundColor),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pendingRequestsByClanId = _pendingRequestsByClanId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick(vi: 'Khám phá gia phả', en: 'Genealogy discovery'),
        ),
      ),
      floatingActionButton: widget.onAddGenealogyRequested == null
          ? null
          : FloatingActionButton(
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _runSearch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(
                          vi: 'Tìm theo trưởng tộc hoặc địa phương',
                          en: 'Search by leader or location',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _queryController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                        decoration: InputDecoration(
                          labelText: l10n.pick(
                            vi: 'Từ khóa chung',
                            en: 'General keyword',
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _leaderController,
                              enabled: !_isLoading,
                              onSubmitted: (_) => _runSearch(),
                              decoration: InputDecoration(
                                labelText: l10n.pick(
                                  vi: 'Trưởng tộc',
                                  en: 'Leader',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _locationController,
                              enabled: !_isLoading,
                              onSubmitted: (_) => _runSearch(),
                              decoration: InputDecoration(
                                labelText: l10n.pick(
                                  vi: 'Địa phương',
                                  en: 'Location',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AddressInputAssistRow(
                        controller: _locationController,
                        onChanged: () => unawaited(_runSearch()),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _runSearch,
                          icon: const Icon(Icons.travel_explore_outlined),
                          label: Text(
                            l10n.pick(
                              vi: 'Tìm gia phả',
                              en: 'Search genealogies',
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
              if (widget.session != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pick(
                            vi: 'Yêu cầu bạn đã gửi',
                            en: 'Your submitted requests',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_myRequestsErrorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _myRequestsErrorMessage!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ] else if (_myRequests.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.pick(
                              vi: 'Bạn chưa gửi yêu cầu tham gia nào.',
                              en: 'You have not submitted any join request yet.',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          ..._myRequests.map((request) {
                            final isCanceling =
                                _cancelingRequestId == request.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatusChip(request),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.pick(
                                        vi: 'Đã gửi: ${_formatShortDate(request.submittedAtEpochMs)}',
                                        en: 'Submitted: ${_formatShortDate(request.submittedAtEpochMs)}',
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (request.canCancel) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: isCanceling
                                              ? null
                                              : () => _cancelRequest(request),
                                          icon: isCanceling
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
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
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
                        vi: 'Chưa có kết quả phù hợp. Hãy đổi từ khóa và thử lại.',
                        en: 'No matching genealogy found. Try adjusting your search.',
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

                                if (isPendingForCurrentUser) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 18,
                                            color: theme
                                                .colorScheme
                                                .onSecondaryContainer,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.pick(
                                              vi: 'Đã gửi yêu cầu tham gia',
                                              en: 'Join request submitted',
                                            ),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.pick(
                                          vi: 'Yêu cầu đã được gửi ngày ${_formatShortDate(pendingSinceEpochMs ?? DateTime.now().millisecondsSinceEpoch)}.',
                                          en: 'Your request was submitted on ${_formatShortDate(pendingSinceEpochMs ?? DateTime.now().millisecondsSinceEpoch)}.',
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.pick(
                                          vi: 'Trong thời gian chờ duyệt, bạn chưa thể xem thông tin của họ tộc này.',
                                          en: 'While waiting for review, this clan information stays hidden.',
                                        ),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (pendingRequest != null) ...[
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: isCanceling
                                              ? null
                                              : () => _cancelRequest(
                                                  pendingRequest,
                                                ),
                                          icon: isCanceling
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
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result.genealogyName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l10n.pick(
                                              vi: 'Trưởng tộc: ${result.leaderName} · ${result.provinceCity}',
                                              en: 'Leader: ${result.leaderName} · ${result.provinceCity}',
                                            ),
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                        if (result.provinceCity
                                            .trim()
                                            .isNotEmpty)
                                          AddressDirectionIconButton(
                                            address: result.provinceCity.trim(),
                                            iconSize: 18,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      result.summary.isEmpty
                                          ? l10n.pick(
                                              vi: 'Chưa có tóm tắt cho gia phả này.',
                                              en: 'No summary available for this genealogy.',
                                            )
                                          : result.summary,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.pick(
                                        vi: '${result.memberCount} thành viên · ${result.branchCount} chi',
                                        en: '${result.memberCount} members · ${result.branchCount} branches',
                                      ),
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _openJoinRequestSheet(result),
                                      icon: const Icon(
                                        Icons.how_to_reg_outlined,
                                      ),
                                      label: Text(
                                        l10n.pick(
                                          vi: 'Gửi yêu cầu tham gia',
                                          en: 'Request to join',
                                        ),
                                      ),
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
  }
}

class _JoinRequestSheet extends StatefulWidget {
  const _JoinRequestSheet({
    required this.result,
    required this.repository,
    required this.session,
  });

  final GenealogyDiscoveryResult result;
  final GenealogyDiscoveryRepository repository;
  final AuthSession? session;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
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
                  vi: 'Yêu cầu tham gia ${widget.result.genealogyName}',
                  en: 'Join request for ${widget.result.genealogyName}',
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
