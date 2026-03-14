import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import 'event_record.dart';

class EventWorkspaceSnapshot {
  const EventWorkspaceSnapshot({
    required this.events,
    required this.members,
    required this.branches,
  });

  final List<EventRecord> events;
  final List<MemberProfile> members;
  final List<BranchProfile> branches;
}
