import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/discovery/models/genealogy_discovery_result.dart';
import 'package:befam/features/discovery/models/join_request_draft.dart';
import 'package:befam/features/discovery/models/join_request_review_item.dart';
import 'package:befam/features/discovery/models/my_join_request_item.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_repository.dart';

class DebugGenealogyDiscoveryRepository
    implements GenealogyDiscoveryRepository {
  DebugGenealogyDiscoveryRepository._({
    required List<GenealogyDiscoveryResult> discovery,
    required List<JoinRequestReviewItem> joinRequests,
  }) : _discovery = List<GenealogyDiscoveryResult>.unmodifiable(discovery),
       _joinRequests = List<JoinRequestReviewItem>.of(joinRequests) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var index = 0; index < _joinRequests.length; index += 1) {
      final requestId = _joinRequests[index].id;
      _submittedAtByRequestId[requestId] = now - (index * 60000);
    }
  }

  factory DebugGenealogyDiscoveryRepository.seeded() {
    return DebugGenealogyDiscoveryRepository._(
      discovery: const [
        GenealogyDiscoveryResult(
          id: 'clan_demo_001',
          clanId: 'clan_demo_001',
          genealogyName: 'Nguyễn tộc miền Trung',
          leaderName: 'Nguyễn Minh',
          provinceCity: 'Đà Nẵng',
          summary: 'Gia phả mẫu với dữ liệu nhiều thế hệ để kiểm thử UI.',
          memberCount: 34,
          branchCount: 6,
        ),
        GenealogyDiscoveryResult(
          id: 'clan_demo_002',
          clanId: 'clan_demo_002',
          genealogyName: 'Trần tộc Quảng Nam',
          leaderName: 'Trần Văn Long',
          provinceCity: 'Quảng Nam',
          summary: 'Nhánh gia phả tập trung theo từng chi vùng duyên hải.',
          memberCount: 21,
          branchCount: 4,
        ),
      ],
      joinRequests: const [],
    );
  }

  final List<GenealogyDiscoveryResult> _discovery;
  final List<JoinRequestReviewItem> _joinRequests;
  final Map<String, int> _submittedAtByRequestId = <String, int>{};

  @override
  bool get isSandbox => true;

  @override
  Future<List<GenealogyDiscoveryResult>> search({
    String? query,
    String? leaderQuery,
    String? locationQuery,
    int limit = 20,
  }) async {
    final normalizedQuery = (query ?? '').trim().toLowerCase();
    final normalizedLeader = (leaderQuery ?? '').trim().toLowerCase();
    final normalizedLocation = (locationQuery ?? '').trim().toLowerCase();
    return _discovery
        .where((entry) {
          final name = entry.genealogyName.toLowerCase();
          final leader = entry.leaderName.toLowerCase();
          final location = entry.provinceCity.toLowerCase();
          if (normalizedLeader.isNotEmpty &&
              !leader.contains(normalizedLeader)) {
            return false;
          }
          if (normalizedLocation.isNotEmpty &&
              !location.contains(normalizedLocation)) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return name.contains(normalizedQuery) ||
              leader.contains(normalizedQuery) ||
              location.contains(normalizedQuery);
        })
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> submitJoinRequest({required JoinRequestDraft draft}) async {
    final requestId = 'join_debug_${_joinRequests.length + 1}';
    _joinRequests.add(
      JoinRequestReviewItem(
        id: requestId,
        clanId: draft.clanId,
        status: 'pending',
        applicantName: draft.applicantName.trim(),
        relationshipToFamily: draft.relationshipToFamily.trim(),
        contactInfo: draft.contactInfo.trim(),
        message: draft.message?.trim(),
      ),
    );
    _submittedAtByRequestId[requestId] = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<List<MyJoinRequestItem>> loadMyJoinRequests({
    required AuthSession session,
  }) async {
    final items = _joinRequests
        .map(
          (request) => MyJoinRequestItem(
            id: request.id,
            clanId: request.clanId,
            status: request.status.trim().toLowerCase(),
            submittedAtEpochMs:
                _submittedAtByRequestId[request.id] ??
                DateTime.now().millisecondsSinceEpoch,
            canCancel: request.status.trim().toLowerCase() == 'pending',
          ),
        )
        .toList(growable: false);
    items.sort(
      (left, right) =>
          right.submittedAtEpochMs.compareTo(left.submittedAtEpochMs),
    );
    return items;
  }

  @override
  Future<void> cancelJoinRequest({
    required AuthSession session,
    required String requestId,
  }) async {
    final index = _joinRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) {
      return;
    }
    final existing = _joinRequests[index];
    if (existing.status.trim().toLowerCase() != 'pending') {
      return;
    }
    _joinRequests[index] = JoinRequestReviewItem(
      id: existing.id,
      clanId: existing.clanId,
      status: 'canceled',
      applicantName: existing.applicantName,
      relationshipToFamily: existing.relationshipToFamily,
      contactInfo: existing.contactInfo,
      message: existing.message,
    );
  }

  @override
  Future<List<JoinRequestReviewItem>> loadPendingJoinRequests({
    required AuthSession session,
  }) async {
    if (session.accessMode != AuthMemberAccessMode.claimed ||
        (session.clanId ?? '').trim().isEmpty) {
      return const [];
    }
    final clanId = session.clanId!.trim();
    return _joinRequests
        .where(
          (request) => request.clanId == clanId && request.status == 'pending',
        )
        .toList(growable: false);
  }

  @override
  Future<void> reviewJoinRequest({
    required AuthSession session,
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    final index = _joinRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) {
      return;
    }
    final existing = _joinRequests[index];
    _joinRequests[index] = JoinRequestReviewItem(
      id: existing.id,
      clanId: existing.clanId,
      status: approve ? 'approved' : 'rejected',
      applicantName: existing.applicantName,
      relationshipToFamily: existing.relationshipToFamily,
      contactInfo: existing.contactInfo,
      message: (note ?? existing.message)?.trim(),
    );
  }
}
