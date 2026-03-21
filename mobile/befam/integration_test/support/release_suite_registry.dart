import 'release_case_catalog.dart';

class ReleaseSuiteCase {
  const ReleaseSuiteCase({
    required this.suite,
    required this.testCaseId,
    required this.priority,
    required this.title,
  });

  final String suite;
  final String testCaseId;
  final String priority;
  final String title;
}

const List<ReleaseSuiteCase> automatedReleaseCases = [
  ReleaseSuiteCase(
    suite: 'Auth, Session, Identity',
    testCaseId: 'AUTH-001',
    priority: 'P0',
    title: 'Login phone OTP thành công và vào đúng member + clan context',
  ),
  ReleaseSuiteCase(
    suite: 'Auth, Session, Identity',
    testCaseId: 'AUTH-003',
    priority: 'P0',
    title: 'Child-code path resolve OTP thành công',
  ),
  ReleaseSuiteCase(
    suite: 'Auth, Session, Identity',
    testCaseId: 'AUTH-009',
    priority: 'P0',
    title: 'User chưa có clan/member không crash và có empty-state rõ ràng',
  ),
  ReleaseSuiteCase(
    suite: 'Clan Context & App Navigation',
    testCaseId: 'CTX-003',
    priority: 'P0',
    title: 'Unlinked user mở Gia phả đi đúng discovery/create-join flow',
  ),
  ReleaseSuiteCase(
    suite: 'Clan Context & App Navigation',
    testCaseId: 'CTX-007',
    priority: 'P1',
    title: 'Đổi ngôn ngữ EN/VI cập nhật labels đồng bộ',
  ),
  ReleaseSuiteCase(
    suite: 'Member, Relationship, Genealogy',
    testCaseId: 'TREE-001',
    priority: 'P0',
    title: 'Màn hình cây tải ổn định, filter/scope hoạt động',
  ),
  ReleaseSuiteCase(
    suite: 'Member, Relationship, Genealogy',
    testCaseId: 'MEM-001',
    priority: 'P0',
    title: 'Tạo thành viên bằng stepper và lưu thành công',
  ),
  ReleaseSuiteCase(
    suite: 'Events & Dual Calendar',
    testCaseId: 'EVT-002',
    priority: 'P0',
    title: 'Tạo sự kiện âm lịch giỗ kỵ có chi tiết tưởng niệm',
  ),
  ReleaseSuiteCase(
    suite: 'Notifications (Inbox/Push/Deep-link)',
    testCaseId: 'NOTIF-003',
    priority: 'P0',
    title: 'Mở notification từ inbox và mark-read đúng',
  ),
  ReleaseSuiteCase(
    suite: 'Security/Rules (Firestore + Storage)',
    testCaseId: 'RULE-001',
    priority: 'P0',
    title: 'Không truy cập chéo dữ liệu gia phả ngoài quyền',
  ),
];

final Set<String> automatedReleaseCaseIds = automatedReleaseCases
    .map((entry) => entry.testCaseId)
    .toSet();

Set<String> missingAutomatedReleaseCaseIds() {
  return automatedReleaseCaseIds.difference(releaseCatalogCaseIds);
}
