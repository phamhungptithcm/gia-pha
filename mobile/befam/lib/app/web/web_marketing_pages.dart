import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/analytics_event_names.dart';
import '../../core/services/app_environment.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/firebase_services.dart';
import '../../l10n/l10n.dart';

Future<void> _trackMarketingCtaClick({
  required String ctaType,
  required String placement,
  required String pagePath,
  required String destination,
}) async {
  try {
    await FirebaseServices.analytics.logEvent(
      name: AnalyticsEventNames.webMarketingCtaClick,
      parameters: <String, Object>{
        'cta_type': ctaType,
        'placement': placement,
        'page_path': pagePath,
        'destination': destination,
      },
    );
  } catch (error, stackTrace) {
    AppLogger.warning(
      'Web marketing analytics event failed.',
      error,
      stackTrace,
    );
  }
}

void _trackAndOpenApp(
  BuildContext context, {
  required String pagePath,
  required String placement,
}) {
  unawaited(
    _trackMarketingCtaClick(
      ctaType: 'open_app',
      placement: placement,
      pagePath: pagePath,
      destination: '/app',
    ),
  );
  context.go('/app');
}

Future<void> _trackAndOpenExternalUrl({
  required String ctaType,
  required String placement,
  required String pagePath,
  required String url,
}) async {
  await _trackMarketingCtaClick(
    ctaType: ctaType,
    placement: placement,
    pagePath: pagePath,
    destination: url,
  );
  await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
}

class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/',
      pageTitle: context.l10n.pick(
        vi: 'BeFam | Gia phả số cho dòng tộc hiện đại',
        en: 'BeFam | Digital lineage platform for modern families',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroStorySection(
              badge: l10n.webLandingBadge,
              title: context.l10n.pick(
                vi: 'Giữ cội nguồn sống trong đời sống hiện đại.',
                en: 'Keep family heritage alive in modern life.',
              ),
              subtitle: context.l10n.pick(
                vi: 'BeFam kết nối cây gia phả, lịch giỗ, quỹ họ và quy trình quản trị trong một không gian thống nhất để con cháu ở bất cứ đâu vẫn thấy mình thuộc về.',
                en: 'BeFam unifies genealogy, memorial calendars, clan funds, and governance workflows so every generation stays connected, wherever they live.',
              ),
              primaryLabel: l10n.webLandingPrimaryCta,
              secondaryLabel: l10n.webLandingSecondaryCta,
              onPrimaryPressed: () => _trackAndOpenApp(
                context,
                pagePath: '/',
                placement: 'landing_hero_primary',
              ),
              onSecondaryPressed: () => context.go('/about-us'),
              highlightTitle: context.l10n.pick(
                vi: 'Vì sao BeFam khác biệt',
                en: 'Why BeFam stands out',
              ),
              highlightDescription: context.l10n.pick(
                vi: 'Không chỉ là app vẽ cây gia phả, BeFam là nền tảng vận hành họ tộc theo dữ liệu, vai trò và quyền truy cập an toàn.',
                en: 'More than a family tree app, BeFam is an operating platform for clan governance, roles, and secure access.',
              ),
              highlights: [
                context.l10n.pick(
                  vi: 'Genealogy + vận hành họ tộc + membership an toàn trong cùng một sản phẩm.',
                  en: 'Genealogy + clan operations + secure membership in one product.',
                ),
                context.l10n.pick(
                  vi: 'Thiết kế cho dòng họ Việt: giỗ, dỗ trạp, quỹ họ, khuyến học.',
                  en: 'Built for Vietnamese family traditions: memorials, rituals, funds, and scholarships.',
                ),
                context.l10n.pick(
                  vi: 'Dễ dùng cho cả trưởng tộc, trưởng chi và thế hệ trẻ ở xa quê.',
                  en: 'Usable for clan leaders and younger generations living far from home.',
                ),
              ],
              metrics: [
                _MarketingMetric(
                  label: context.l10n.pick(
                    vi: 'Nền tảng hợp nhất',
                    en: 'Unified platform',
                  ),
                  value: context.l10n.pick(vi: '3 lớp', en: '3 layers'),
                ),
                _MarketingMetric(
                  label: context.l10n.pick(
                    vi: 'Luồng quản trị',
                    en: 'Governance workflows',
                  ),
                  value: context.l10n.pick(vi: 'Minh bạch', en: 'Transparent'),
                ),
                _MarketingMetric(
                  label: context.l10n.pick(
                    vi: 'Truy cập dữ liệu',
                    en: 'Data access',
                  ),
                  value: context.l10n.pick(vi: 'Đúng quyền', en: 'Role-safe'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionHeading(
              eyebrow: context.l10n.pick(
                vi: 'Giá trị cốt lõi',
                en: 'Core value',
              ),
              title: context.l10n.pick(
                vi: 'Một không gian chung để cả dòng tộc cùng nhìn về một hướng.',
                en: 'A shared workspace where the whole clan stays aligned.',
              ),
              description: context.l10n.pick(
                vi: 'Từ thông tin thế hệ, sự kiện đến tài chính đều có lịch sử rõ ràng, giảm bỏ sót và giảm hiểu nhầm trong quá trình điều hành.',
                en: 'From lineage records to events and finances, every action has clear history to reduce misses and misunderstandings.',
              ),
            ),
            const SizedBox(height: 16),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.account_tree_rounded,
                  title: l10n.webLandingFeatureTreeTitle,
                  description: l10n.webLandingFeatureTreeDescription,
                ),
                _FeatureItem(
                  icon: Icons.calendar_month_rounded,
                  title: l10n.webLandingFeatureEventsTitle,
                  description: l10n.webLandingFeatureEventsDescription,
                ),
                _FeatureItem(
                  icon: Icons.workspace_premium_rounded,
                  title: l10n.webLandingFeatureBillingTitle,
                  description: l10n.webLandingFeatureBillingDescription,
                ),
                _FeatureItem(
                  icon: Icons.verified_user_rounded,
                  title: context.l10n.pick(
                    vi: 'Gia nhập đúng họ tộc',
                    en: 'Secure clan membership',
                  ),
                  description: context.l10n.pick(
                    vi: 'Yêu cầu tham gia có quy trình duyệt, theo dõi trạng thái và kiểm soát quyền truy cập theo vai trò.',
                    en: 'Join requests follow an approval flow with status tracking and role-based access controls.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _JourneyTimeline(
              title: context.l10n.pick(
                vi: 'Hành trình người dùng trên BeFam',
                en: 'A typical BeFam journey',
              ),
              steps: [
                _JourneyStep(
                  index: 1,
                  title: context.l10n.pick(
                    vi: 'Xác thực và định danh',
                    en: 'Sign in and identify',
                  ),
                  description: context.l10n.pick(
                    vi: 'Đăng nhập OTP, đối soát hồ sơ, liên kết đúng thành viên.',
                    en: 'Use OTP, reconcile profile, and securely link the right member identity.',
                  ),
                ),
                _JourneyStep(
                  index: 2,
                  title: context.l10n.pick(
                    vi: 'Vận hành họ tộc',
                    en: 'Run clan operations',
                  ),
                  description: context.l10n.pick(
                    vi: 'Quản lý cây gia phả, lịch sự kiện, ngày giỗ và hoạt động nội bộ.',
                    en: 'Manage genealogy, event calendars, memorial days, and clan activities.',
                  ),
                ),
                _JourneyStep(
                  index: 3,
                  title: context.l10n.pick(
                    vi: 'Minh bạch tài chính',
                    en: 'Keep finances transparent',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi quỹ, khuyến học, giao dịch và gói dịch vụ trên cùng hệ thống.',
                    en: 'Track funds, scholarships, transactions, and subscription plans in one system.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _MarketingFaqSection(
              title: context.l10n.pick(
                vi: 'Câu hỏi thường gặp',
                en: 'Frequently asked questions',
              ),
              description: context.l10n.pick(
                vi: 'Một số câu hỏi phổ biến khi các dòng họ bắt đầu số hóa dữ liệu trên BeFam.',
                en: 'Common questions when family clans begin digitizing operations with BeFam.',
              ),
              items: [
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'BeFam có phải chỉ là app vẽ cây gia phả không?',
                    en: 'Is BeFam only a family tree drawing app?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Không. BeFam kết hợp 3 lớp: genealogy, vận hành họ tộc (sự kiện/quỹ/khuyến học), và membership access an toàn theo vai trò.',
                    en: 'No. BeFam combines three layers: genealogy, clan operations (events/funds/scholarships), and secure role-based membership access.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'Dòng họ có thành viên ở nhiều nơi có dùng được không?',
                    en: 'Can clans with members living in many locations use BeFam?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Có. BeFam được thiết kế cho bối cảnh con cháu học tập và làm việc xa quê, vẫn theo dõi lịch giỗ, sự kiện và vai vế rõ ràng.',
                    en: 'Yes. BeFam is built for distributed families so members can still track memorials, events, and lineage context clearly.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'Khi nào gói dịch vụ được kích hoạt sau thanh toán?',
                    en: 'When does a plan become active after payment?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Gói chỉ được kích hoạt sau khi hệ thống nhận callback/webhook thanh toán thành công. Trạng thái chờ hoặc thất bại sẽ không cấp quyền mới.',
                    en: 'A plan is activated only after successful callback/webhook confirmation. Pending or failed payments do not grant new entitlements.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'BeFam có hỗ trợ tiếng Việt và tiếng Anh không?',
                    en: 'Does BeFam support Vietnamese and English?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Có. BeFam hỗ trợ song ngữ Việt/Anh, giúp cả thành viên trong nước và ở nước ngoài dùng thuận tiện hơn.',
                    en: 'Yes. BeFam supports both Vietnamese and English for smoother use by local and overseas family members.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _CtaPanel(
              title: context.l10n.pick(
                vi: 'Sẵn sàng đưa dòng họ lên nền tảng số?',
                en: 'Ready to bring your clan to a digital platform?',
              ),
              description: context.l10n.pick(
                vi: 'Bắt đầu với BeFam để tổ chức dữ liệu gia phả, kết nối thế hệ và quản trị hoạt động họ tộc rõ ràng hơn mỗi ngày.',
                en: 'Start with BeFam to organize lineage data, connect generations, and run clan operations with clarity every day.',
              ),
              primaryLabel: context.l10n.pick(
                vi: 'Mở ứng dụng ngay',
                en: 'Open the app now',
              ),
              secondaryLabel: context.l10n.pick(
                vi: 'Xem trang về chúng tôi',
                en: 'Read about us',
              ),
              onPrimaryPressed: () => _trackAndOpenApp(
                context,
                pagePath: '/',
                placement: 'landing_bottom_cta_primary',
              ),
              onSecondaryPressed: () => context.go('/about-us'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebAboutUsPage extends StatelessWidget {
  const WebAboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/about-us',
      pageTitle: context.l10n.pick(
        vi: 'Về BeFam | Câu chuyện và sứ mệnh',
        en: 'About BeFam | Story and mission',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: l10n.webAboutTitle,
              subtitle: context.l10n.pick(
                vi: 'Ngày trước, con cháu thường sống gần nhau nên việc kết nối trong mỗi dịp giỗ, lễ, họp họ diễn ra tự nhiên. Hôm nay, khi các thế hệ học tập và lập nghiệp khắp nơi, điều khó nhất không phải là không muốn về, mà là không thể về cùng lúc.',
                en: 'Families once lived close together, so connection came naturally during memorial ceremonies and clan gatherings. Today, generations move across cities and countries, and the challenge is not willingness but being able to return at the same time.',
              ),
              icon: Icons.groups_2_rounded,
              badge: context.l10n.pick(
                vi: 'Câu chuyện sản phẩm',
                en: 'Product story',
              ),
            ),
            const SizedBox(height: 20),
            _QuoteCard(
              quote: context.l10n.pick(
                vi: 'BeFam ra đời để giữ mạch kết nối của cả dòng tộc trong thời đại phân tán địa lý: đúng người, đúng vai trò, đúng dữ liệu.',
                en: 'BeFam was built to keep clans connected across distance: the right person, the right role, and the right data.',
              ),
            ),
            const SizedBox(height: 20),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.favorite_rounded,
                  title: l10n.webAboutMissionTitle,
                  description: l10n.webAboutMissionDescription,
                ),
                _FeatureItem(
                  icon: Icons.visibility_rounded,
                  title: l10n.webAboutVisionTitle,
                  description: l10n.webAboutVisionDescription,
                ),
                _FeatureItem(
                  icon: Icons.security_rounded,
                  title: l10n.webAboutTrustTitle,
                  description: l10n.webAboutTrustDescription,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeading(
              eyebrow: context.l10n.pick(vi: 'Nguyên tắc', en: 'Principles'),
              title: context.l10n.pick(
                vi: 'BeFam được thiết kế để đồng hành dài hạn cùng cộng đồng họ tộc.',
                en: 'BeFam is designed for long-term clan communities.',
              ),
              description: context.l10n.pick(
                vi: 'Mọi quyết định sản phẩm đều ưu tiên tính dễ dùng, minh bạch vận hành và bảo vệ quyền riêng tư của từng thành viên.',
                en: 'Every product decision prioritizes usability, operational transparency, and member privacy.',
              ),
            ),
            const SizedBox(height: 14),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.lock_person_rounded,
                  title: context.l10n.pick(
                    vi: 'An toàn theo thiết kế',
                    en: 'Security by design',
                  ),
                  description: context.l10n.pick(
                    vi: 'Truy cập dữ liệu theo vai trò và quy trình xác thực để giảm liên kết sai hồ sơ.',
                    en: 'Role-based data access and verification flows reduce mis-linking risks.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.manage_accounts_rounded,
                  title: context.l10n.pick(
                    vi: 'Vận hành rõ trách nhiệm',
                    en: 'Clear operational ownership',
                  ),
                  description: context.l10n.pick(
                    vi: 'Owner, admin, leader, thủ quỹ và các vai trò khác có phạm vi quyền riêng, tránh chồng chéo.',
                    en: 'Owners, admins, leaders, treasurers, and other roles each have explicit permissions.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.diversity_3_rounded,
                  title: context.l10n.pick(
                    vi: 'Phù hợp đa thế hệ',
                    en: 'Multi-generation ready',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ngôn ngữ gần gũi, thao tác đơn giản để người lớn tuổi và người trẻ đều sử dụng được.',
                    en: 'Natural language and simple flows so both elder and younger members can use it comfortably.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _FounderContactCard(),
            const SizedBox(height: 24),
            _CtaPanel(
              title: context.l10n.pick(
                vi: 'Muốn xem BeFam hoạt động thực tế?',
                en: 'Want to see BeFam in action?',
              ),
              description: context.l10n.pick(
                vi: 'Mở ứng dụng để trải nghiệm luồng gia phả, sự kiện và quản trị họ tộc ngay trong một workspace thống nhất.',
                en: 'Open the app to explore genealogy, event, and governance workflows in one unified workspace.',
              ),
              primaryLabel: context.l10n.pick(
                vi: 'Mở ứng dụng',
                en: 'Open app',
              ),
              secondaryLabel: context.l10n.pick(
                vi: 'Xem thông tin sản phẩm',
                en: 'View product info',
              ),
              onPrimaryPressed: () => _trackAndOpenApp(
                context,
                pagePath: '/about-us',
                placement: 'about_bottom_cta_primary',
              ),
              onSecondaryPressed: () => context.go('/befam-info'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebBeFamInfoPage extends StatelessWidget {
  const WebBeFamInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/befam-info',
      pageTitle: context.l10n.pick(
        vi: 'Thông tin BeFam | Tính năng và khả năng',
        en: 'BeFam Information | Features and capabilities',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: l10n.webInfoTitle,
              subtitle: context.l10n.pick(
                vi: 'BeFam là nền tảng vận hành họ tộc theo hướng mobile-first: quản lý gia phả, kết nối thành viên, vận hành sự kiện, quỹ và khuyến học trên cùng một cấu trúc dữ liệu nhất quán.',
                en: 'BeFam is a mobile-first clan operations platform: manage genealogy, member access, events, funds, and scholarship workflows in one consistent data model.',
              ),
              icon: Icons.info_rounded,
              badge: context.l10n.pick(
                vi: 'Tổng quan sản phẩm',
                en: 'Product overview',
              ),
            ),
            const SizedBox(height: 20),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.hub_rounded,
                  title: l10n.webInfoGenealogyTitle,
                  description: l10n.webInfoGenealogyDescription,
                ),
                _FeatureItem(
                  icon: Icons.notifications_active_rounded,
                  title: l10n.webInfoNotificationsTitle,
                  description: l10n.webInfoNotificationsDescription,
                ),
                _FeatureItem(
                  icon: Icons.payments_rounded,
                  title: l10n.webInfoBillingTitle,
                  description: l10n.webInfoBillingDescription,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeading(
              eyebrow: context.l10n.pick(
                vi: 'Đối tượng sử dụng',
                en: 'Who uses BeFam',
              ),
              title: context.l10n.pick(
                vi: 'Một nền tảng cho cả ban điều hành và toàn bộ thành viên dòng họ.',
                en: 'One platform for clan operators and members across generations.',
              ),
              description: context.l10n.pick(
                vi: 'Từ trưởng tộc, trưởng chi, thủ quỹ đến thành viên ở xa quê đều có luồng làm việc phù hợp theo quyền và nhu cầu thực tế.',
                en: 'From clan leaders and treasurers to members living far from home, each role has a focused workflow.',
              ),
            ),
            const SizedBox(height: 14),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: context.l10n.pick(
                    vi: 'Ban điều hành họ tộc',
                    en: 'Clan governance team',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi tổng quan, phân quyền, duyệt yêu cầu và điều phối hoạt động theo chi nhánh.',
                    en: 'Track overview, manage permissions, review requests, and coordinate branch operations.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.account_balance_wallet_rounded,
                  title: context.l10n.pick(
                    vi: 'Tổ vận hành quỹ và khuyến học',
                    en: 'Fund and scholarship operators',
                  ),
                  description: context.l10n.pick(
                    vi: 'Quản lý giao dịch, hồ sơ xét duyệt và báo cáo minh bạch theo từng giai đoạn.',
                    en: 'Manage transactions, review submissions, and keep transparent reports over time.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.person_search_rounded,
                  title: context.l10n.pick(
                    vi: 'Thành viên và con cháu ở xa',
                    en: 'Members and descendants abroad',
                  ),
                  description: context.l10n.pick(
                    vi: 'Tìm đúng gia phả, gửi yêu cầu tham gia đúng quy trình và theo dõi lịch quan trọng không bị bỏ sót.',
                    en: 'Find the right clan, submit join requests safely, and keep up with important family dates.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoBulletList(
              title: l10n.webInfoHighlightsTitle,
              points: [
                l10n.webInfoHighlightsItemOne,
                l10n.webInfoHighlightsItemTwo,
                l10n.webInfoHighlightsItemThree,
                context.l10n.pick(
                  vi: 'Thanh toán và kích hoạt gói chỉ hoàn tất sau khi callback/webhook xác nhận thành công.',
                  en: 'Plan activation happens only after successful callback/webhook confirmation.',
                ),
                context.l10n.pick(
                  vi: 'Thiết kế hỗ trợ điện thoại, tablet và web để điều hành linh hoạt theo ngữ cảnh sử dụng.',
                  en: 'Designed for phone, tablet, and web so operations stay flexible in every context.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _CtaPanel(
              title: context.l10n.pick(
                vi: 'Bạn muốn dùng BeFam cho dòng họ của mình?',
                en: 'Want to use BeFam for your family clan?',
              ),
              description: context.l10n.pick(
                vi: 'Bắt đầu trải nghiệm ngay để thiết lập gia phả, mời thành viên và vận hành các hoạt động quan trọng trong một luồng thống nhất.',
                en: 'Start now to set up genealogy, invite members, and run important clan activities with one consistent flow.',
              ),
              primaryLabel: context.l10n.pick(
                vi: 'Bắt đầu với BeFam',
                en: 'Start with BeFam',
              ),
              secondaryLabel: context.l10n.pick(
                vi: 'Về chúng tôi',
                en: 'About us',
              ),
              onPrimaryPressed: () => _trackAndOpenApp(
                context,
                pagePath: '/befam-info',
                placement: 'info_bottom_cta_primary',
              ),
              onSecondaryPressed: () => context.go('/about-us'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebMarketingLayout extends StatelessWidget {
  const _WebMarketingLayout({
    required this.currentPath,
    required this.pageTitle,
    required this.child,
  });

  final String currentPath;
  final String pageTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Title(
      title: pageTitle,
      color: colorScheme.primary,
      child: Scaffold(
        body: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.44),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Positioned(
              top: -120,
              right: -80,
              child: _GlowOrb(
                size: 300,
                color: colorScheme.secondary.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              top: 220,
              left: -120,
              child: _GlowOrb(
                size: 280,
                color: colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1220),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        _TopNavigation(currentPath: currentPath),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                child,
                                const SizedBox(height: 8),
                                _WebFooter(pagePath: currentPath),
                              ],
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
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final navItems = [
      _NavItem(path: '/', label: l10n.webNavHome),
      _NavItem(path: '/about-us', label: l10n.webNavAboutUs),
      _NavItem(path: '/befam-info', label: l10n.webNavBeFamInfo),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 920;

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const _BrandMark(),
                const SizedBox(width: 12),
                Text(
                  'BeFam',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (!isCompact)
                  ...navItems.map(
                    (item) => _NavButton(
                      label: item.label,
                      isActive: currentPath == item.path,
                      onPressed: () => context.go(item.path),
                    ),
                  ),
                if (isCompact)
                  PopupMenuButton<_NavItem>(
                    tooltip: l10n.webNavMenuTooltip,
                    onSelected: (item) => context.go(item.path),
                    itemBuilder: (context) => navItems
                        .map(
                          (item) => PopupMenuItem<_NavItem>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _trackAndOpenApp(
                    context,
                    pagePath: currentPath,
                    placement: 'top_nav_open_app',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Text(
                    isCompact
                        ? context.l10n.pick(vi: 'Mở', en: 'Open')
                        : l10n.webNavOpenApp,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroStorySection extends StatelessWidget {
  const _HeroStorySection({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    required this.highlightTitle,
    required this.highlightDescription,
    required this.highlights,
    required this.metrics,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;
  final String highlightTitle;
  final String highlightDescription;
  final List<String> highlights;
  final List<_MarketingMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 980;

            final leftPane = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EyebrowChip(label: badge),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.16,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onPrimaryPressed,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: Text(primaryLabel),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSecondaryPressed,
                      icon: const Icon(Icons.explore_rounded),
                      label: Text(secondaryLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _MarketingMetricStrip(metrics: metrics),
              ],
            );

            final rightPane = Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.14),
                    colorScheme.secondary.withValues(alpha: 0.18),
                  ],
                ),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.24),
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          highlightTitle,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    highlightDescription,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...highlights.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item, style: textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [leftPane, const SizedBox(height: 16), rightPane],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: leftPane),
                const SizedBox(width: 22),
                Expanded(flex: 2, child: rightPane),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MarketingMetricStrip extends StatelessWidget {
  const _MarketingMetricStrip({required this.metrics});

  final List<_MarketingMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MarketingMetric metric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.value,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            metric.label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EyebrowChip(label: eyebrow),
        const SizedBox(height: 10),
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FeatureCardGrid extends StatelessWidget {
  const _FeatureCardGrid({required this.items});

  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1020
            ? 3
            : width >= 700
            ? 2
            : 1;
        const spacing = 14.0;
        final cardWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: _FeatureCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Icon(item.icon, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({required this.title, required this.steps});

  final String title;
  final List<_JourneyStep> steps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 860;
                if (isCompact) {
                  return Column(
                    children: [
                      for (var index = 0; index < steps.length; index++) ...[
                        _JourneyStepCard(step: steps[index]),
                        if (index < steps.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Icon(
                              Icons.south_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < steps.length; index++) ...[
                      Expanded(child: _JourneyStepCard(step: steps[index])),
                      if (index < steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 26,
                          ),
                          child: Icon(
                            Icons.east_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStepCard extends StatelessWidget {
  const _JourneyStepCard({required this.step});

  final _JourneyStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        color: Colors.white.withValues(alpha: 0.8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: colorScheme.secondaryContainer,
            ),
            child: Text(
              '${context.l10n.pick(vi: 'Bước', en: 'Step')} ${step.index}',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketingFaqSection extends StatelessWidget {
  const _MarketingFaqSection({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<_FaqItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    iconColor: colorScheme.primary,
                    collapsedIconColor: colorScheme.primary,
                    title: Text(
                      item.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.answer,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CtaPanel extends StatelessWidget {
  const _CtaPanel({
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String title;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.secondary.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onPrimaryPressed,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(primaryLabel),
              ),
              OutlinedButton.icon(
                onPressed: onSecondaryPressed,
                icon: const Icon(Icons.north_east_rounded),
                label: Text(secondaryLabel),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 16), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    _EyebrowChip(label: badge!),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: colorScheme.primary,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quote,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBulletList extends StatelessWidget {
  const _InfoBulletList({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FounderContactCard extends StatelessWidget {
  const _FounderContactCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(
                          vi: 'Thông tin liên hệ',
                          en: 'Contact information',
                        ),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pick(
                          vi: 'Hỗ trợ hợp tác, tư vấn triển khai và thông tin sản phẩm.',
                          en: 'For partnerships, onboarding consulting, and product inquiries.',
                        ),
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Phạm Hùng',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const _ContactRow(
              icon: Icons.phone_rounded,
              value: '+19452369965',
              link: 'tel:+19452369965',
            ),
            const SizedBox(height: 8),
            const _ContactRow(
              icon: Icons.location_on_rounded,
              value: 'Frisco, Texas, United States',
            ),
            const SizedBox(height: 8),
            const _ContactRow(
              icon: Icons.email_rounded,
              value: 'phamhung.pitit@gmail.com',
              link: 'mailto:phamhung.pitit@gmail.com',
            ),
            const SizedBox(height: 8),
            const _ContactRow(
              icon: Icons.facebook_rounded,
              value: 'Facebook',
              link: 'https://www.facebook.com/hawaihouu',
            ),
            const SizedBox(height: 8),
            const _ContactRow(
              icon: Icons.work_rounded,
              value: 'LinkedIn',
              link: 'https://www.linkedin.com/in/hunpham',
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value, this.link});

  final IconData icon;
  final String value;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget content = Text(value, style: textTheme.bodyLarge);
    if (link != null) {
      content = InkWell(
        onTap: () async {
          await launchUrl(Uri.parse(link!), mode: LaunchMode.platformDefault);
        },
        child: Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: content),
      ],
    );
  }
}

class _WebFooter extends StatelessWidget {
  const _WebFooter({required this.pagePath});

  final String pagePath;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final l10n = context.l10n;
    final iosStoreUrl = AppEnvironment.iosAppStoreUrl.trim();
    final androidStoreUrl = AppEnvironment.androidPlayStoreUrl.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 20),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _StoreDownloadButton(
                icon: Icons.phone_iphone_rounded,
                ctaType: 'app_store',
                placement: 'footer_app_store',
                pagePath: pagePath,
                title: l10n.pick(
                  vi: 'Tải trên App Store',
                  en: 'Download on App Store',
                ),
                subtitle: iosStoreUrl.isEmpty
                    ? l10n.pick(vi: 'Sắp mở', en: 'Coming soon')
                    : l10n.pick(vi: 'iOS app', en: 'iOS app'),
                url: iosStoreUrl,
              ),
              _StoreDownloadButton(
                icon: Icons.android_rounded,
                ctaType: 'google_play',
                placement: 'footer_google_play',
                pagePath: pagePath,
                title: l10n.pick(
                  vi: 'Tải trên Google Play',
                  en: 'Get it on Google Play',
                ),
                subtitle: androidStoreUrl.isEmpty
                    ? l10n.pick(vi: 'Sắp mở', en: 'Coming soon')
                    : l10n.pick(vi: 'Android app', en: 'Android app'),
                url: androidStoreUrl,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.pick(
              vi: 'Copyright © $year BeFam. Đã đăng ký bản quyền.',
              en: 'Copyright © $year BeFam. All rights reserved.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StoreDownloadButton extends StatelessWidget {
  const _StoreDownloadButton({
    required this.ctaType,
    required this.placement,
    required this.pagePath,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final String ctaType;
  final String placement;
  final String pagePath;
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = url.trim().isNotEmpty;

    return InkWell(
      onTap: !isEnabled
          ? null
          : () async {
              await _trackAndOpenExternalUrl(
                ctaType: ctaType,
                placement: placement,
                pagePath: pagePath,
                url: url,
              );
            },
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isEnabled
              ? Colors.white.withValues(alpha: 0.92)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(
            color: isEnabled ? colorScheme.outlineVariant : colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(onPressed: onPressed, child: Text(label)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _EyebrowChip extends StatelessWidget {
  const _EyebrowChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.secondaryContainer,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 90, spreadRadius: 30),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.primary.withValues(alpha: 0.14),
      ),
      child: Icon(Icons.family_restroom_rounded, color: colorScheme.primary),
    );
  }
}

class _NavItem {
  const _NavItem({required this.path, required this.label});

  final String path;
  final String label;
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _MarketingMetric {
  const _MarketingMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _JourneyStep {
  const _JourneyStep({
    required this.index,
    required this.title,
    required this.description,
  });

  final int index;
  final String title;
  final String description;
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
