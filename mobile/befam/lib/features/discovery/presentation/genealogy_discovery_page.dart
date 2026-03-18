import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/genealogy_discovery_result.dart';
import '../models/join_request_draft.dart';
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

  bool _isLoading = false;
  bool _isOpeningAddAction = false;
  String? _errorMessage;
  List<GenealogyDiscoveryResult> _results = const [];

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.repository.search(
        query: _queryController.text,
        leaderQuery: _leaderController.text,
        locationQuery: _locationController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = items;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = context.l10n.pick(
          vi: 'Không thể tải danh sách gia phả công khai. Vui lòng thử lại.',
          en: 'Could not load public genealogy list. Please try again.',
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

  Future<void> _openJoinRequestSheet(GenealogyDiscoveryResult result) async {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

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
                            Text(
                              result.genealogyName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.pick(
                                vi: 'Trưởng tộc: ${result.leaderName} · ${result.provinceCity}',
                                en: 'Leader: ${result.leaderName} · ${result.provinceCity}',
                              ),
                              style: theme.textTheme.bodyMedium,
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
                              onPressed: () => _openJoinRequestSheet(result),
                              icon: const Icon(Icons.how_to_reg_outlined),
                              label: Text(
                                l10n.pick(
                                  vi: 'Gửi yêu cầu tham gia',
                                  en: 'Request to join',
                                ),
                              ),
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
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
                    vi: 'Quan hệ với dòng tộc',
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
