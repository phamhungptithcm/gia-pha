import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/analytics_event_names.dart';
import '../../core/services/app_environment.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/firebase_services.dart';
import '../../l10n/l10n.dart';

const double _kSectionGap = 32;
const double _kBlockGap = 20;
const double _kCardGap = 16;
const double _kCardPadding = 22;
const String _kSupportEmail = 'support@hunpeo.vn';

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
        padding: const EdgeInsets.only(top: 26, bottom: 44),
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
                vi: 'BeFam kết nối cây gia phả, lịch giỗ, quỹ họ và các việc chung của dòng tộc trong một không gian thống nhất, để con cháu ở đâu cũng thấy gần nhau.',
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
                vi: 'BeFam không chỉ để xem cây gia phả. Đây là không gian chung để cả dòng họ vận hành công việc, phân quyền rõ ràng và bảo vệ dữ liệu an toàn.',
                en: 'More than a family tree app, BeFam is an operating platform for clan governance, roles, and secure access.',
              ),
              highlights: [
                context.l10n.pick(
                  vi: 'Gia phả, vận hành họ tộc và quản lý thành viên nằm trong cùng một hệ thống.',
                  en: 'Genealogy + clan operations + secure membership in one product.',
                ),
                context.l10n.pick(
                  vi: 'Thiết kế theo bối cảnh dòng họ Việt: giỗ chạp, họp họ, quỹ họ, khuyến học.',
                  en: 'Built for Vietnamese family traditions: memorials, rituals, funds, and scholarships.',
                ),
                context.l10n.pick(
                  vi: 'Thân thiện với cả trưởng tộc, trưởng chi và thế hệ trẻ ở xa quê.',
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
            const SizedBox(height: _kSectionGap),
            _SectionHeading(
              eyebrow: context.l10n.pick(
                vi: 'Giá trị cốt lõi',
                en: 'Core value',
              ),
              title: context.l10n.pick(
                vi: 'Một không gian chung để dòng tộc cùng nhìn về một hướng.',
                en: 'A shared workspace where the whole clan stays aligned.',
              ),
              description: context.l10n.pick(
                vi: 'Thông tin thế hệ, sự kiện và tài chính đều có lịch sử rõ ràng, giúp giảm bỏ sót và hạn chế hiểu nhầm khi phối hợp.',
                en: 'From lineage records to events and finances, every action has clear history to reduce misses and misunderstandings.',
              ),
            ),
            const SizedBox(height: _kCardGap),
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
            const SizedBox(height: _kSectionGap),
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
                    vi: 'Đăng nhập bằng OTP, đối chiếu hồ sơ và gắn đúng thành viên.',
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
                    vi: 'Quản lý cây gia phả, lịch sự kiện, ngày giỗ và các việc chung theo từng chi.',
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
                    vi: 'Theo dõi quỹ, khuyến học, giao dịch và gói dịch vụ trong một luồng rõ ràng.',
                    en: 'Track funds, scholarships, transactions, and subscription plans in one system.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kSectionGap),
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
                    vi: 'Không. BeFam gồm 3 lớp: gia phả, vận hành họ tộc (sự kiện/quỹ/khuyến học) và quản lý truy cập theo vai trò.',
                    en: 'No. BeFam combines three layers: genealogy, clan operations (events/funds/scholarships), and secure role-based membership access.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'Dòng họ có thành viên ở nhiều nơi có dùng được không?',
                    en: 'Can clans with members living in many locations use BeFam?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Có. BeFam phù hợp khi con cháu học tập, làm việc xa quê nhưng vẫn cần theo dõi lịch giỗ, sự kiện và vai vế rõ ràng.',
                    en: 'Yes. BeFam is built for distributed families so members can still track memorials, events, and lineage context clearly.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'Khi nào gói dịch vụ được kích hoạt sau thanh toán?',
                    en: 'When does a plan become active after payment?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Gói chỉ được kích hoạt khi hệ thống xác nhận thanh toán thành công từ cổng thanh toán hoặc kho ứng dụng.',
                    en: 'A plan is activated only after successful callback/webhook confirmation. Pending or failed payments do not grant new entitlements.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'BeFam có hỗ trợ tiếng Việt và tiếng Anh không?',
                    en: 'Does BeFam support Vietnamese and English?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Có. BeFam hỗ trợ tiếng Việt và tiếng Anh để cả thành viên trong nước lẫn ở nước ngoài đều dễ dùng.',
                    en: 'Yes. BeFam supports both Vietnamese and English for smoother use by local and overseas family members.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kSectionGap),
            _CtaPanel(
              title: context.l10n.pick(
                vi: 'Sẵn sàng đưa dòng họ lên nền tảng số?',
                en: 'Ready to bring your clan to a digital platform?',
              ),
              description: context.l10n.pick(
                vi: 'Bắt đầu với BeFam để sắp xếp gia phả, kết nối thế hệ và quản lý hoạt động họ tộc gọn gàng hơn mỗi ngày.',
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
        padding: const EdgeInsets.only(top: 20, bottom: 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: l10n.webAboutTitle,
              subtitle: context.l10n.pick(
                vi: 'Trước đây, con cháu thường sống gần nhau nên chuyện giỗ lễ, họp họ diễn ra rất tự nhiên. Khi các thế hệ học tập và lập nghiệp ở nhiều nơi, điều khó nhất không phải là không muốn về, mà là khó về cùng lúc.',
                en: 'Families once lived close together, so connection came naturally during memorial ceremonies and clan gatherings. Today, generations move across cities and countries, and the challenge is not willingness but being able to return at the same time.',
              ),
              icon: Icons.groups_2_rounded,
              badge: context.l10n.pick(
                vi: 'Câu chuyện sản phẩm',
                en: 'Product story',
              ),
            ),
            const SizedBox(height: _kBlockGap),
            _QuoteCard(
              quote: context.l10n.pick(
                vi: 'BeFam được tạo ra để giữ nhịp kết nối của dòng tộc trong bối cảnh phân tán địa lý: đúng người, đúng vai trò, đúng dữ liệu.',
                en: 'BeFam was built to keep clans connected across distance: the right person, the right role, and the right data.',
              ),
            ),
            const SizedBox(height: _kBlockGap),
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
            const SizedBox(height: _kBlockGap),
            _SectionHeading(
              eyebrow: context.l10n.pick(vi: 'Nguyên tắc', en: 'Principles'),
              title: context.l10n.pick(
                vi: 'BeFam được thiết kế để đồng hành lâu dài cùng cộng đồng họ tộc.',
                en: 'BeFam is designed for long-term clan communities.',
              ),
              description: context.l10n.pick(
                vi: 'Mỗi quyết định sản phẩm đều ưu tiên dễ dùng, minh bạch và tôn trọng quyền riêng tư của từng thành viên.',
                en: 'Every product decision prioritizes usability, operational transparency, and member privacy.',
              ),
            ),
            const SizedBox(height: _kCardGap),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.lock_person_rounded,
                  title: context.l10n.pick(
                    vi: 'An toàn theo thiết kế',
                    en: 'Security by design',
                  ),
                  description: context.l10n.pick(
                    vi: 'Truy cập theo vai trò và quy trình xác thực rõ ràng để giảm liên kết nhầm hồ sơ.',
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
                    vi: 'Ban quản trị, trưởng chi, thủ quỹ... đều có phạm vi trách nhiệm rõ ràng, hạn chế chồng chéo.',
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
                    vi: 'Ngôn ngữ gần gũi, thao tác trực quan để cả người lớn tuổi và người trẻ đều dùng thuận tiện.',
                    en: 'Natural language and simple flows so both elder and younger members can use it comfortably.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kBlockGap),
            const _HunpeoLabsContactCard(),
            const SizedBox(height: _kSectionGap),
            _CtaPanel(
              title: context.l10n.pick(
                vi: 'Muốn xem BeFam hoạt động thực tế?',
                en: 'Want to see BeFam in action?',
              ),
              description: context.l10n.pick(
                vi: 'Mở ứng dụng để trải nghiệm luồng gia phả, sự kiện và quản trị họ tộc trong một không gian thống nhất.',
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
        padding: const EdgeInsets.only(top: 20, bottom: 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: l10n.webInfoTitle,
              subtitle: context.l10n.pick(
                vi: 'BeFam là nền tảng ưu tiên thiết bị di động, giúp quản lý gia phả, thành viên, sự kiện, quỹ và khuyến học trên cùng một nguồn dữ liệu thống nhất.',
                en: 'BeFam is a mobile-first clan operations platform: manage genealogy, member access, events, funds, and scholarship workflows in one consistent data model.',
              ),
              icon: Icons.info_rounded,
              badge: context.l10n.pick(
                vi: 'Tổng quan sản phẩm',
                en: 'Product overview',
              ),
            ),
            const SizedBox(height: _kBlockGap),
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
            const SizedBox(height: _kBlockGap),
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
            const SizedBox(height: _kCardGap),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: context.l10n.pick(
                    vi: 'Ban điều hành họ tộc',
                    en: 'Clan governance team',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi tổng quan, phân quyền, duyệt yêu cầu và điều phối hoạt động theo từng chi.',
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
                    vi: 'Tìm đúng gia phả, gửi yêu cầu tham gia đúng quy trình và theo dõi các lịch quan trọng.',
                    en: 'Find the right clan, submit join requests safely, and keep up with important family dates.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kBlockGap),
            _InfoBulletList(
              title: l10n.webInfoHighlightsTitle,
              points: [
                l10n.webInfoHighlightsItemOne,
                l10n.webInfoHighlightsItemTwo,
                l10n.webInfoHighlightsItemThree,
                context.l10n.pick(
                  vi: 'Thanh toán và kích hoạt gói chỉ hoàn tất khi hệ thống nhận xác nhận giao dịch thành công.',
                  en: 'Plan activation happens only after successful callback/webhook confirmation.',
                ),
                context.l10n.pick(
                  vi: 'Thiết kế hỗ trợ điện thoại, máy tính bảng và web để điều hành linh hoạt theo từng ngữ cảnh.',
                  en: 'Designed for phone, tablet, and web so operations stay flexible in every context.',
                ),
              ],
            ),
            const SizedBox(height: _kSectionGap),
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

class WebPrivacyPolicyPage extends StatelessWidget {
  const WebPrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalContentPage(
      currentPath: '/privacy',
      pageTitle: context.l10n.pick(
        vi: 'Chính sách quyền riêng tư | BeFam',
        en: 'Privacy Policy | BeFam',
      ),
      eyebrow: context.l10n.pick(vi: 'Quyền riêng tư', en: 'Privacy'),
      title: context.l10n.pick(
        vi: 'BeFam tôn trọng dữ liệu của từng thành viên dòng họ.',
        en: 'BeFam respects each member’s family data.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Trang này tóm tắt cách BeFam thu thập, sử dụng, bảo vệ và phản hồi yêu cầu liên quan đến dữ liệu cá nhân.',
        en: 'This page summarizes how BeFam collects, uses, protects, and responds to requests about personal data.',
      ),
      sections: [
        _LegalSection(
          title: context.l10n.pick(
            vi: '1. Dữ liệu BeFam thu thập',
            en: '1. Data BeFam collects',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam có thể xử lý số điện thoại, hồ sơ thành viên, vai trò trong gia phả, nội dung do người dùng nhập, giao dịch quỹ, hồ sơ khuyến học và các tín hiệu kỹ thuật phục vụ đăng nhập, bảo mật và vận hành.',
              en: 'BeFam may process phone numbers, member profiles, genealogy roles, user-entered content, fund transactions, scholarship submissions, and technical signals needed for sign-in, security, and operations.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '2. Mục đích sử dụng',
            en: '2. Why we use this data',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Dữ liệu được dùng để xác thực tài khoản, hiển thị gia phả đúng quyền, vận hành lịch sự kiện, quỹ, khuyến học, gửi thông báo quan trọng và hỗ trợ người dùng khi có sự cố.',
              en: 'Data is used to authenticate accounts, show the correct family records with proper permissions, run event, fund, and scholarship workflows, send important notifications, and support users when issues happen.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '3. Chia sẻ và bảo vệ dữ liệu',
            en: '3. Sharing and protecting data',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam chỉ chia sẻ dữ liệu với hạ tầng và dịch vụ vận hành cần thiết như Firebase, Google Cloud, Apple App Store, Google Play hoặc các đối tác xác thực/thanh toán liên quan đến tính năng đang dùng. Quyền truy cập trong app được kiểm soát theo vai trò.',
              en: 'BeFam only shares data with required operating infrastructure and services such as Firebase, Google Cloud, Apple App Store, Google Play, or relevant verification and payment providers used by the feature. In-app access is controlled by role.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '4. Liên hệ về dữ liệu',
            en: '4. Contact about your data',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Nếu bạn cần cập nhật, phản hồi hoặc yêu cầu xử lý dữ liệu liên quan đến tài khoản BeFam, hãy liên hệ đội ngũ hỗ trợ qua email bên dưới.',
              en: 'If you need to update, question, or request handling of data related to your BeFam account, contact the support team using the email below.',
            ),
          ],
          actions: [
            _LegalAction(
              label: _kSupportEmail,
              href: 'mailto:$_kSupportEmail?subject=BeFam%20Privacy%20Request',
            ),
          ],
        ),
      ],
    );
  }
}

class WebTermsPage extends StatelessWidget {
  const WebTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalContentPage(
      currentPath: '/terms',
      pageTitle: context.l10n.pick(
        vi: 'Điều khoản sử dụng | BeFam',
        en: 'Terms of Use | BeFam',
      ),
      eyebrow: context.l10n.pick(vi: 'Điều khoản', en: 'Terms'),
      title: context.l10n.pick(
        vi: 'BeFam được dùng để vận hành gia phả và hoạt động dòng họ một cách tôn trọng và minh bạch.',
        en: 'BeFam is intended for respectful and transparent family-clan operations.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Khi dùng BeFam, người dùng cần bảo đảm thông tin cung cấp là phù hợp, đúng quyền và không gây ảnh hưởng đến thành viên khác trong dòng họ.',
        en: 'When using BeFam, users are expected to provide appropriate information, act within their permissions, and avoid harming other family members.',
      ),
      sections: [
        _LegalSection(
          title: context.l10n.pick(
            vi: '1. Phạm vi sử dụng',
            en: '1. Intended use',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam hỗ trợ lưu trữ gia phả, quản lý thành viên, sự kiện, quỹ, khuyến học và các hoạt động liên quan đến vận hành họ tộc. Người dùng không được dùng BeFam để mạo danh, truy cập sai quyền hoặc đưa nội dung trái pháp luật.',
              en: 'BeFam supports genealogy records, member management, events, funds, scholarships, and related clan operations. Users must not use BeFam to impersonate others, access data outside their permissions, or submit unlawful content.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '2. Trách nhiệm tài khoản',
            en: '2. Account responsibility',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Mỗi tài khoản phải được dùng đúng người, đúng hồ sơ và đúng vai trò. Người dùng chịu trách nhiệm với thao tác của mình trên hệ thống, bao gồm yêu cầu tham gia, quản trị dữ liệu, giao dịch và cập nhật thông tin.',
              en: 'Each account must be used by the right person, profile, and role. Users are responsible for their actions in the system, including join requests, data administration, transactions, and profile updates.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '3. Dịch vụ trả phí và thông báo',
            en: '3. Paid services and notifications',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Một số tính năng có thể đi kèm gói dịch vụ hoặc nhắc việc qua thông báo. Quyền sử dụng chỉ được kích hoạt khi thanh toán hoặc xác minh hoàn tất theo chính sách của hệ thống và kho ứng dụng.',
              en: 'Some features may depend on subscriptions or reminder notifications. Access is activated only after payment or verification completes according to system and store policies.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '4. Hỗ trợ và phản hồi',
            en: '4. Support and feedback',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Nếu cần hỗ trợ về điều khoản, quyền sử dụng hoặc tranh chấp liên quan đến tài khoản BeFam, vui lòng liên hệ đội ngũ hỗ trợ.',
              en: 'If you need help with terms, access rights, or account-related disputes in BeFam, please contact support.',
            ),
          ],
          actions: [
            _LegalAction(
              label: _kSupportEmail,
              href: 'mailto:$_kSupportEmail?subject=BeFam%20Terms%20Question',
            ),
          ],
        ),
      ],
    );
  }
}

class WebAccountDeletionPage extends StatelessWidget {
  const WebAccountDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalContentPage(
      currentPath: '/account-deletion',
      pageTitle: context.l10n.pick(
        vi: 'Yêu cầu xóa tài khoản | BeFam',
        en: 'Account Deletion Request | BeFam',
      ),
      eyebrow: context.l10n.pick(
        vi: 'Xóa tài khoản',
        en: 'Account deletion',
      ),
      title: context.l10n.pick(
        vi: 'Bạn có thể gửi yêu cầu xóa tài khoản BeFam mà không cần đăng nhập.',
        en: 'You can request deletion of your BeFam account without signing in.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Đội ngũ BeFam sẽ tiếp nhận yêu cầu, xác minh thông tin cần thiết và phản hồi tiến độ qua email hỗ trợ.',
        en: 'The BeFam team will receive the request, verify the necessary details, and respond with next steps through support.',
      ),
      sections: [
        _LegalSection(
          title: context.l10n.pick(
            vi: '1. Cách gửi yêu cầu',
            en: '1. How to submit a request',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Gửi email tới đội ngũ hỗ trợ với tiêu đề “Yêu cầu xóa tài khoản BeFam” và cung cấp số điện thoại đăng nhập, họ tên, cùng thông tin nhận diện cần thiết để xác minh.',
              en: 'Send an email to support with the subject “BeFam account deletion request” and include the sign-in phone number, full name, and the identity details needed for verification.',
            ),
          ],
          actions: [
            _LegalAction(
              label: context.l10n.pick(
                vi: 'Gửi yêu cầu qua email',
                en: 'Send request by email',
              ),
              href:
                  'mailto:$_kSupportEmail?subject=BeFam%20Account%20Deletion%20Request',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '2. Dữ liệu sẽ được xử lý',
            en: '2. What data will be handled',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Khi yêu cầu được xác nhận, BeFam sẽ xử lý việc xóa hoặc vô hiệu hóa tài khoản và các dữ liệu liên quan theo chính sách vận hành hiện hành, ngoại trừ phần dữ liệu cần lưu giữ theo nghĩa vụ pháp lý hoặc phục vụ đối soát hệ thống.',
              en: 'Once the request is confirmed, BeFam will process deletion or deactivation of the account and related data according to current operating policy, except data that must be retained for legal or system-reconciliation reasons.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '3. Thời gian phản hồi',
            en: '3. Response time',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam sẽ phản hồi yêu cầu qua email hỗ trợ sau khi tiếp nhận và xác minh thông tin. Trong giai đoạn đầu vận hành, thời gian xử lý có thể thay đổi theo khối lượng yêu cầu thực tế.',
              en: 'BeFam will respond by email after receiving and verifying the request. In the early operating phase, handling time may vary depending on request volume.',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalContentPage extends StatelessWidget {
  const _LegalContentPage({
    required this.currentPath,
    required this.pageTitle,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  final String currentPath;
  final String pageTitle;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return _WebMarketingLayout(
      currentPath: currentPath,
      pageTitle: pageTitle,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: title,
              subtitle: subtitle,
              icon: Icons.verified_user_rounded,
              badge: eyebrow,
            ),
            const SizedBox(height: _kBlockGap),
            ...[
              for (final section in sections) ...[
                _LegalSectionCard(section: section),
                const SizedBox(height: _kCardGap),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.title,
    required this.paragraphs,
    this.actions = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<_LegalAction> actions;
}

class _LegalAction {
  const _LegalAction({required this.label, required this.href});

  final String label;
  final String href;
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            ...[
              for (final paragraph in section.paragraphs) ...[
                Text(
                  paragraph,
                  style: textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (section.actions.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final action in section.actions)
                    OutlinedButton(
                      onPressed: () => launchUrl(
                        Uri.parse(action.href),
                        mode: LaunchMode.platformDefault,
                      ),
                      child: Text(action.label),
                    ),
                ],
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
                      horizontal: 22,
                      vertical: 14,
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const _BrandMark(),
                const SizedBox(width: 12),
                Text(
                  'BeFam',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
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
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
        padding: const EdgeInsets.all(28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 980;

            final leftPane = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EyebrowChip(label: badge),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.52,
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
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
                            letterSpacing: -0.2,
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
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...highlights.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
                            child: Text(
                              item,
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                              ),
                            ),
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
                children: [leftPane, const SizedBox(height: 20), rightPane],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: leftPane),
                const SizedBox(width: 24),
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
        const spacing = 12.0;
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
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
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
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.2,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Text(
            description,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
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
        const spacing = 16.0;
        final minCardHeight = width >= 1020
            ? 236.0
            : width >= 700
            ? 248.0
            : 0.0;
        final rowCount = (items.length / columns).ceil();

        return Column(
          children: [
            for (var row = 0; row < rowCount; row++) ...[
              if (row > 0) const SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: spacing),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final index = (row * columns) + column;
                            if (index >= items.length) {
                              return const SizedBox.shrink();
                            }
                            return _FeatureCard(
                              item: items[index],
                              minHeight: minCardHeight,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, required this.minHeight});

  final _FeatureItem item;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        constraints: minHeight <= 0
            ? const BoxConstraints()
            : BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(_kCardPadding),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.24,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
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
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.22,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(16),
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
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.24,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.48,
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
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                    iconColor: colorScheme.primary,
                    collapsedIconColor: colorScheme.primary,
                    title: Text(
                      item.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        letterSpacing: -0.15,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.answer,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.52,
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
      padding: const EdgeInsets.all(24),
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
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
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
        padding: const EdgeInsets.all(_kCardPadding),
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
                      height: 1.2,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
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
      padding: const EdgeInsets.all(_kCardPadding),
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
                letterSpacing: -0.1,
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
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.22,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            ...points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                          height: 1.5,
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

class _HunpeoLabsContactCard extends StatelessWidget {
  const _HunpeoLabsContactCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
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
                    Icons.support_agent_rounded,
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
                          vi: 'Kết nối với Hunpeo Labs',
                          en: 'Connect with Hunpeo Labs',
                        ),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pick(
                          vi: 'Đội ngũ Hunpeo Labs tiếp nhận hợp tác, góp ý sản phẩm và phản ánh trải nghiệm người dùng.',
                          en: 'Hunpeo Labs handles partnerships, product feedback, and user experience reports.',
                        ),
                        style: textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Hunpeo Labs',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.business_rounded,
              value: l10n.pick(
                vi: 'Đơn vị vận hành và phát triển sản phẩm BeFam.',
                en: 'Product operator and developer of BeFam.',
              ),
            ),
            const SizedBox(height: 8),
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              value: l10n.pick(
                vi: 'Email hỗ trợ: $_kSupportEmail',
                en: 'Support email: $_kSupportEmail',
              ),
              link: 'mailto:$_kSupportEmail',
            ),
            const SizedBox(height: 8),
            _ContactRow(
              icon: Icons.schedule_rounded,
              value: l10n.pick(
                vi: 'Google Form phản ánh và Fanpage BeFam đang được chuẩn bị.',
                en: 'Google Form feedback and BeFam Fanpage are being prepared.',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ContactChannelChip(
                  icon: Icons.description_rounded,
                  label: l10n.pick(
                    vi: 'Google Form phản ánh',
                    en: 'Feedback Google Form',
                  ),
                ),
                _ContactChannelChip(
                  icon: Icons.facebook_rounded,
                  label: l10n.pick(vi: 'Fanpage BeFam', en: 'BeFam Fanpage'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactChannelChip extends StatelessWidget {
  const _ContactChannelChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.pick(vi: 'Sắp cập nhật', en: 'Coming soon'),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

    Widget content = Text(
      value,
      style: textTheme.bodyLarge?.copyWith(height: 1.5),
    );
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
            height: 1.5,
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
      padding: const EdgeInsets.only(top: 10, bottom: 22),
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _FooterLinkButton(
                label: l10n.pick(
                  vi: 'Chính sách quyền riêng tư',
                  en: 'Privacy policy',
                ),
                onPressed: () => context.go('/privacy'),
              ),
              _FooterLinkButton(
                label: l10n.pick(
                  vi: 'Điều khoản sử dụng',
                  en: 'Terms of use',
                ),
                onPressed: () => context.go('/terms'),
              ),
              _FooterLinkButton(
                label: l10n.pick(
                  vi: 'Yêu cầu xóa tài khoản',
                  en: 'Account deletion',
                ),
                onPressed: () => context.go('/account-deletion'),
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

class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
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
                    height: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
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
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);
    if (isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: onPressed,
          child: Text(label, style: textStyle),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: onPressed,
        child: Text(label, style: textStyle),
      ),
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
          letterSpacing: 0.1,
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
