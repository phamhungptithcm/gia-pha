import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../models/onboarding_models.dart';
import 'onboarding_remote_config_service.dart';

class OnboardingCatalogSnapshot {
  const OnboardingCatalogSnapshot({
    required this.settings,
    required this.flows,
  });

  final OnboardingRemoteSettings settings;
  final List<OnboardingFlow> flows;
}

abstract class OnboardingCatalogRepository {
  Future<OnboardingCatalogSnapshot> load({
    required AuthSession session,
    required OnboardingTrigger trigger,
  });
}

class DisabledOnboardingCatalogRepository
    implements OnboardingCatalogRepository {
  const DisabledOnboardingCatalogRepository();

  static const OnboardingRemoteSettings _disabledSettings =
      OnboardingRemoteSettings(
        enabled: false,
        firestoreCatalogEnabled: false,
        catalogCollection: 'onboardingFlows',
        rolloutPercent: 0,
        shellNavigationEnabled: false,
        memberWorkspaceEnabled: false,
        genealogyWorkspaceEnabled: false,
        genealogyDiscoveryEnabled: false,
        clanDetailEnabled: false,
      );

  @override
  Future<OnboardingCatalogSnapshot> load({
    required AuthSession session,
    required OnboardingTrigger trigger,
  }) async {
    return const OnboardingCatalogSnapshot(
      settings: _disabledSettings,
      flows: <OnboardingFlow>[],
    );
  }
}

class FirebaseOnboardingCatalogRepository
    implements OnboardingCatalogRepository {
  FirebaseOnboardingCatalogRepository({
    FirebaseFirestore? firestore,
    OnboardingRemoteConfigService? remoteConfigService,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _remoteConfigService =
           remoteConfigService ?? createDefaultOnboardingRemoteConfigService();

  final FirebaseFirestore _firestore;
  final OnboardingRemoteConfigService _remoteConfigService;

  @override
  Future<OnboardingCatalogSnapshot> load({
    required AuthSession session,
    required OnboardingTrigger trigger,
  }) async {
    final settings = await _remoteConfigService.load();
    if (!settings.enabled ||
        !settings.isTriggerEnabled(trigger.id) ||
        !settings.includesUser(session.uid)) {
      return OnboardingCatalogSnapshot(settings: settings, flows: const []);
    }

    List<OnboardingFlow> flows = const <OnboardingFlow>[];
    if (settings.firestoreCatalogEnabled) {
      flows = await _loadRemoteFlows(
        collection: settings.catalogCollection,
        triggerId: trigger.id,
      );
    }
    if (flows.isEmpty) {
      flows = _fallbackFlowsFor(trigger.id);
    }

    flows =
        flows
            .where((flow) => flow.enabled && flow.steps.isNotEmpty)
            .where((flow) => flow.supportsCurrentPlatform())
            .toList(growable: false)
          ..sort((left, right) => left.priority.compareTo(right.priority));

    return OnboardingCatalogSnapshot(settings: settings, flows: flows);
  }

  Future<List<OnboardingFlow>> _loadRemoteFlows({
    required String collection,
    required String triggerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collection)
          .where('triggerId', isEqualTo: triggerId)
          .get();
      if (snapshot.docs.isEmpty) {
        return const <OnboardingFlow>[];
      }

      return snapshot.docs
          .map((doc) => doc.data())
          .map(OnboardingFlow.fromJson)
          .where((flow) => flow.id.isNotEmpty)
          .toList(growable: false);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to load onboarding catalog from Firestore. Falling back to local catalog.',
        error,
        stackTrace,
      );
      return const <OnboardingFlow>[];
    }
  }

  List<OnboardingFlow> _fallbackFlowsFor(String triggerId) {
    return switch (triggerId) {
      'app_shell_home' => const <OnboardingFlow>[_shellNavigationFlow],
      'member_workspace_opened' => const <OnboardingFlow>[_memberAddFlow],
      'genealogy_workspace_opened' => const <OnboardingFlow>[_genealogyFlow],
      'genealogy_discovery_opened' => const <OnboardingFlow>[
        _genealogyDiscoveryFlow,
      ],
      'clan_detail_opened' => const <OnboardingFlow>[_clanDetailFlow],
      _ => const <OnboardingFlow>[],
    };
  }
}

const OnboardingFlow _shellNavigationFlow = OnboardingFlow(
  id: 'shell_navigation',
  triggerId: 'app_shell_home',
  version: 1,
  priority: 10,
  maxDisplays: 2,
  cooldown: Duration(hours: 24),
  steps: <OnboardingStep>[
    OnboardingStep(
      id: 'tree_tab',
      anchorId: 'shell.destination.tree',
      title: OnboardingLocalizedText(
        vi: 'Bắt đầu từ cây gia phả',
        en: 'Start with the family tree',
      ),
      body: OnboardingLocalizedText(
        vi: 'Mở sơ đồ gia phả để xem các thế hệ, nhánh họ và quan hệ chính trong cùng một chỗ.',
        en: 'Open the tree to explore generations, branches, and core relationships in one place.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
    OnboardingStep(
      id: 'events_tab',
      anchorId: 'shell.destination.events',
      title: OnboardingLocalizedText(
        vi: 'Theo dõi ngày giỗ và lịch họ tộc',
        en: 'Track memorial days and clan events',
      ),
      body: OnboardingLocalizedText(
        vi: 'Lịch sự kiện giúp bạn quản lý giỗ chạp, họp họ và nhắc việc theo từng gia phả.',
        en: 'The calendar keeps memorials, gatherings, and reminders organized for each clan.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
    OnboardingStep(
      id: 'profile_tab',
      anchorId: 'shell.destination.profile',
      title: OnboardingLocalizedText(
        vi: 'Thiết lập hồ sơ và quyền truy cập',
        en: 'Set up your profile and access',
      ),
      body: OnboardingLocalizedText(
        vi: 'Vào hồ sơ để hoàn thiện thông tin cá nhân, thông báo và các cài đặt liên quan đến tài khoản.',
        en: 'Use Profile to finish account details, notification preferences, and personal settings.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
  ],
);

const OnboardingFlow _memberAddFlow = OnboardingFlow(
  id: 'member_add',
  triggerId: 'member_workspace_opened',
  version: 1,
  priority: 20,
  maxDisplays: 3,
  cooldown: Duration(hours: 12),
  steps: <OnboardingStep>[
    OnboardingStep(
      id: 'member_add_fab',
      anchorId: 'member.add_fab',
      title: OnboardingLocalizedText(
        vi: 'Thêm thành viên mới',
        en: 'Add a new member',
      ),
      body: OnboardingLocalizedText(
        vi: 'Bắt đầu từ nút này để tạo hồ sơ mới. BeFam sẽ cho phép tra cứu số điện thoại trước rồi tự điền dữ liệu khi có thể.',
        en: 'Start here to create a profile. BeFam can check the phone number first and prefill known data when available.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
  ],
);

const OnboardingFlow _genealogyFlow = OnboardingFlow(
  id: 'genealogy_workspace',
  triggerId: 'genealogy_workspace_opened',
  version: 1,
  priority: 30,
  maxDisplays: 2,
  cooldown: Duration(hours: 24),
  steps: <OnboardingStep>[
    OnboardingStep(
      id: 'main_add_fab',
      anchorId: 'genealogy.main_add_fab',
      title: OnboardingLocalizedText(
        vi: 'Mở trung tâm thao tác nhanh',
        en: 'Open the quick action hub',
      ),
      body: OnboardingLocalizedText(
        vi: 'Từ nút này bạn có thể mở các thao tác tạo gia phả, thêm nhánh hoặc thêm thành viên theo đúng quyền hiện có.',
        en: 'Use this button to open the actions your role allows, such as adding a genealogy, branch, or member.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
    OnboardingStep(
      id: 'zoom_in',
      anchorId: 'genealogy.zoom_in',
      title: OnboardingLocalizedText(
        vi: 'Phóng to để đọc quan hệ dễ hơn',
        en: 'Zoom in for easier reading',
      ),
      body: OnboardingLocalizedText(
        vi: 'Khi sơ đồ dày đặc, dùng điều khiển này để phóng to nhanh rồi chạm vào từng thành viên để xem chi tiết.',
        en: 'When the tree gets dense, use this control to zoom in quickly and inspect each member in detail.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
  ],
);

const OnboardingFlow _genealogyDiscoveryFlow = OnboardingFlow(
  id: 'genealogy_discovery',
  triggerId: 'genealogy_discovery_opened',
  version: 1,
  priority: 40,
  maxDisplays: 2,
  cooldown: Duration(hours: 24),
  steps: <OnboardingStep>[
    OnboardingStep(
      id: 'query_input',
      anchorId: 'discovery.query_input',
      title: OnboardingLocalizedText(
        vi: 'Tìm gia phả theo tên hoặc từ khóa',
        en: 'Search by name or keyword',
      ),
      body: OnboardingLocalizedText(
        vi: 'Nhập họ tộc, trưởng tộc hoặc một từ khóa nhận diện để thu hẹp danh sách nhanh hơn.',
        en: 'Enter a family name, leader, or identifying keyword to narrow the list faster.',
      ),
      placement: OnboardingTooltipPlacement.below,
    ),
    OnboardingStep(
      id: 'search_button',
      anchorId: 'discovery.search_button',
      title: OnboardingLocalizedText(
        vi: 'Chạy tìm kiếm và xem kết quả',
        en: 'Run the search and review results',
      ),
      body: OnboardingLocalizedText(
        vi: 'Sau khi lọc, danh sách bên dưới sẽ cho phép bạn gửi yêu cầu tham gia đúng gia phả.',
        en: 'After filtering, the list below lets you request access to the right genealogy.',
      ),
      placement: OnboardingTooltipPlacement.below,
    ),
  ],
);

const OnboardingFlow _clanDetailFlow = OnboardingFlow(
  id: 'clan_detail',
  triggerId: 'clan_detail_opened',
  version: 1,
  priority: 50,
  maxDisplays: 2,
  cooldown: Duration(hours: 24),
  steps: <OnboardingStep>[
    OnboardingStep(
      id: 'clan_edit_fab',
      anchorId: 'clan.edit_fab',
      title: OnboardingLocalizedText(
        vi: 'Chỉnh sửa cấu hình gia phả',
        en: 'Edit clan configuration',
      ),
      body: OnboardingLocalizedText(
        vi: 'Dùng nút này để cập nhật thông tin gốc của gia phả như tên, slug, người khai sáng và mô tả.',
        en: 'Use this button to update the clan identity, slug, founder, and description.',
      ),
      placement: OnboardingTooltipPlacement.above,
    ),
    OnboardingStep(
      id: 'branch_section',
      anchorId: 'clan.branch_section',
      title: OnboardingLocalizedText(
        vi: 'Quản lý các nhánh trong cùng một nơi',
        en: 'Manage branches from one place',
      ),
      body: OnboardingLocalizedText(
        vi: 'Khu vực này là nơi thêm nhánh mới, xem nhanh người phụ trách và mở danh sách chi đầy đủ.',
        en: 'This section is where you add branches, review leaders, and open the full branch list.',
      ),
      placement: OnboardingTooltipPlacement.below,
    ),
  ],
);

OnboardingCatalogRepository createDefaultOnboardingCatalogRepository() {
  return FirebaseOnboardingCatalogRepository();
}
