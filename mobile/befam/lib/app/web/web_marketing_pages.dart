import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/analytics_event_names.dart';
import '../../core/services/app_environment.dart';
import '../../core/services/app_locale_controller.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/firebase_services.dart';
import '../../core/widgets/app_locale_scope.dart';
import '../../core/widgets/app_workspace_chrome.dart';
import '../../l10n/l10n.dart';
import 'widgets/marketing_ad_slot.dart';

const double _kSectionGap = 18;
const double _kBlockGap = 16;
const double _kCardGap = 12;
const double _kCardPadding = 20;
const double _kMarketingRadius = 8;
const double _kAppSurfaceRadius = 18;
const Color _kLandingLine = Color(0xFFDCE4F2);
const Color _kLandingInk = Color(0xFF0F172A);
const Color _kLandingMuted = Color(0xFF526076);
const Color _kLandingAqua = Color(0xFFE4EAFF);
const Color _kLandingMint = Color(0xFFE4F8EF);
const Color _kLandingCoral = Color(0xFFF0EAFF);
const Color _kLandingGold = Color(0xFFFFF4D8);
const String _kSupportEmail = 'hunpeo97@gmail.com';
const String _kFeedbackFormUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLSfMvozcjAeBM4Ln2Ncwr2sTY6RUgwQtdpgefqG8_qeWzcpTBA/viewform?usp=header';
const String _kFanpageUrl =
    'https://www.facebook.com/profile.php?id=61579548848441';

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

Widget _buildMarketingInlineAdForPath(String currentPath) {
  if (AppEnvironment.adSenseMarketingInlineSlotId.trim().isEmpty) {
    return const SizedBox.shrink();
  }

  final pageType = switch (currentPath) {
    '/' => 'landing_home',
    '/about-us' => 'landing_about',
    '/befam-info' => 'landing_info',
    _ => '',
  };

  if (pageType.isEmpty) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: MarketingInlineAdSlot(pageType: pageType),
  );
}

class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/',
      pageTitle: context.l10n.pick(
        vi: 'BeFam | Gia phả sống cho dòng họ Việt',
        en: 'BeFam | Living family memory',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LandingHeroSection(
              badge: context.l10n.pick(
                vi: 'Dòng họ / Gia phả số',
                en: 'Family / Living lineage',
              ),
              title: context.l10n.pick(
                vi: 'Gia phả sống. BeFam giữ ký ức.',
                en: 'Living lineage. BeFam keeps the memory.',
              ),
              subtitle: context.l10n.pick(
                vi: 'Một nơi gọn để lưu người thân, ngày giỗ, sự kiện và quỹ họ. Rõ ràng cho hôm nay, dễ trao lại mai sau.',
                en: 'One calm place for relatives, memorial days, events, and clan funds.',
              ),
              primaryLabel: l10n.webLandingPrimaryCta,
              secondaryLabel: context.l10n.pick(
                vi: 'Xem câu chuyện BeFam',
                en: 'Read the BeFam story',
              ),
              onPrimaryPressed: () => _trackAndOpenApp(
                context,
                pagePath: '/',
                placement: 'landing_hero_primary',
              ),
              onSecondaryPressed: () => context.go('/about-us'),
              quickCards: [
                _FeatureItem(
                  icon: Icons.account_tree_rounded,
                  title: context.l10n.pick(
                    vi: 'Rõ quan hệ',
                    en: 'Clear lineage',
                  ),
                  description: context.l10n.pick(
                    vi: 'Thế hệ và nhánh họ dễ nhìn hơn.',
                    en: 'See branches and generations faster.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.calendar_month_rounded,
                  title: context.l10n.pick(
                    vi: 'Rõ ngày giỗ',
                    en: 'Clear dates',
                  ),
                  description: context.l10n.pick(
                    vi: 'Việc cần nhớ nằm đúng chỗ.',
                    en: 'Important days stay visible.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.payments_rounded,
                  title: context.l10n.pick(vi: 'Rõ quỹ họ', en: 'Clear funds'),
                  description: context.l10n.pick(
                    vi: 'Thu chi theo quyền và lịch sử.',
                    en: 'Role-aware records and history.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.auto_awesome_rounded,
                  title: context.l10n.pick(
                    vi: 'Rõ việc chung',
                    en: 'Clear work',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ít chữ hơn, tập trung hơn.',
                    en: 'Less copy, more focus.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kSectionGap),
            _JourneyTimeline(
              title: context.l10n.pick(
                vi: 'Bắt đầu với BeFam trong 3 bước',
                en: 'A typical BeFam journey',
              ),
              steps: [
                _JourneyStep(
                  index: 1,
                  title: context.l10n.pick(
                    vi: 'Xác nhận đúng người',
                    en: 'Sign in and identify',
                  ),
                  description: context.l10n.pick(
                    vi: 'Đăng nhập, đối chiếu hồ sơ và vào đúng gia phả của mình.',
                    en: 'Use OTP, reconcile profile, and securely link the right member identity.',
                  ),
                ),
                _JourneyStep(
                  index: 2,
                  title: context.l10n.pick(
                    vi: 'Sắp xếp việc chung',
                    en: 'Run clan operations',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi ngày giỗ, họp họ, thông báo và các đầu việc của dòng họ.',
                    en: 'Manage genealogy, event calendars, memorial days, and clan activities.',
                  ),
                ),
                _JourneyStep(
                  index: 3,
                  title: context.l10n.pick(
                    vi: 'Theo dõi quỹ rõ ràng',
                    en: 'Keep finances transparent',
                  ),
                  description: context.l10n.pick(
                    vi: 'Thu chi, đóng góp và các khoản hỗ trợ đều dễ xem lại khi cần.',
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
                vi: 'Những điều mọi người thường hỏi khi bắt đầu dùng BeFam.',
                en: 'Common questions when family clans begin digitizing operations with BeFam.',
              ),
              items: [
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'BeFam có chỉ để làm gia phả không?',
                    en: 'Is BeFam only a family tree drawing app?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Không. Ngoài gia phả, BeFam còn hỗ trợ theo dõi việc chung, quỹ họ và quyền truy cập theo vai trò.',
                    en: 'No. BeFam combines three layers: genealogy, clan operations (events/funds/scholarships), and secure role-based membership access.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'Nhà có người ở nhiều nơi thì dùng được không?',
                    en: 'Can clans with members living in many locations use BeFam?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Có. BeFam khá hợp khi con cháu sống xa quê nhưng vẫn muốn theo dõi ngày giỗ, việc chung và thông tin dòng họ.',
                    en: 'Yes. BeFam is built for distributed families so members can still track memorials, events, and lineage context clearly.',
                  ),
                ),
                _FaqItem(
                  question: context.l10n.pick(
                    vi: 'Thanh toán xong thì khi nào gói được mở?',
                    en: 'When does a plan become active after payment?',
                  ),
                  answer: context.l10n.pick(
                    vi: 'Gói sẽ được mở khi hệ thống nhận xác nhận thanh toán thành công từ cổng thanh toán hoặc kho ứng dụng.',
                    en: 'A plan is activated only after successful callback/webhook confirmation. Pending or failed payments do not grant new entitlements.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kSectionGap),
            _CtaPanel(
              title: context.l10n.pick(
                vi: 'Muốn bắt đầu cho dòng họ mình?',
                en: 'Ready to bring your clan to a digital platform?',
              ),
              description: context.l10n.pick(
                vi: 'Mở BeFam để bắt đầu sắp xếp gia phả, thông tin thành viên và việc chung cho gọn hơn.',
                en: 'Start with BeFam to organize lineage data, connect generations, and run clan operations with clarity every day.',
              ),
              primaryLabel: context.l10n.pick(
                vi: 'Mở ứng dụng',
                en: 'Open the app now',
              ),
              secondaryLabel: context.l10n.pick(
                vi: 'Xem về BeFam',
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
    return _WebMarketingLayout(
      currentPath: '/about-us',
      pageTitle: context.l10n.pick(
        vi: 'Về BeFam | Câu chuyện, sứ mệnh và Hunpeo Labs',
        en: 'About BeFam | Story and mission',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroStorySection(
              badge: context.l10n.pick(
                vi: 'Câu chuyện BeFam',
                en: 'The BeFam story',
              ),
              title: context.l10n.pick(
                vi: 'BeFam được làm ra để người trong họ vẫn giữ nhịp với nhau, dù sống ở đâu.',
                en: 'We built BeFam so family clans can stay close even when life spreads across many places.',
              ),
              subtitle: context.l10n.pick(
                vi: 'Khi con cháu đi học, đi làm xa, chuyện gia phả, ngày giỗ và việc chung dễ bị rời rạc. BeFam gom những việc đó về một chỗ để cả nhà dễ theo dõi hơn.',
                en: 'As generations study, work, and settle far from home, memorial rituals, communication, and clan operations become harder to coordinate. BeFam brings those workflows back together in one clear and approachable space.',
              ),
              primaryLabel: context.l10n.pick(
                vi: 'Xem BeFam có gì',
                en: 'View BeFam info',
              ),
              onPrimaryPressed: () => context.go('/befam-info'),
              secondaryLabel: null,
              onSecondaryPressed: null,
              focusTags: const [],
            ),
            const SizedBox(height: _kCardGap),
            _CompactFeatureList(
              items: [
                _FeatureItem(
                  icon: Icons.favorite_rounded,
                  title: context.l10n.pick(
                    vi: 'Làm từ việc thật',
                    en: 'Built from a real need',
                  ),
                  description: context.l10n.pick(
                    vi: 'Bắt đầu từ những việc gia đình hay gặp: gia phả rời rạc, lịch giỗ dễ quên, thông tin khó nối lại.',
                    en: 'Help each clan keep genealogy and shared work in one easier place.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.visibility_rounded,
                  title: context.l10n.pick(
                    vi: 'Ưu tiên dễ theo dõi',
                    en: 'Easy to follow',
                  ),
                  description: context.l10n.pick(
                    vi: 'Vào là hiểu mình cần xem gì, làm gì, kể cả với người không quen công nghệ.',
                    en: 'Become a trusted product for clans who want long-term connection.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.security_rounded,
                  title: context.l10n.pick(
                    vi: 'Rõ người, rõ việc',
                    en: 'Keep responsibility clear',
                  ),
                  description: context.l10n.pick(
                    vi: 'Vai trò, quyền truy cập và các bước xử lý cần nhìn ra ngay để đỡ nhầm lẫn.',
                    en: 'Keep the product clear, approachable, and respectful of member data.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kBlockGap),
            const _HunpeoLabsContactCard(),
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
    return _WebMarketingLayout(
      currentPath: '/befam-info',
      pageTitle: context.l10n.pick(
        vi: 'Thông tin BeFam | Tính năng, đối tượng dùng và nền tảng',
        en: 'BeFam Information | Features and capabilities',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroStorySection(
              badge: context.l10n.pick(
                vi: 'BeFam có gì?',
                en: 'Product overview',
              ),
              title: context.l10n.pick(
                vi: 'BeFam gom gia phả, lịch chung và quyền truy cập về một nơi.',
                en: 'One platform where genealogy, membership, and clan operations live in one clear system.',
              ),
              subtitle: context.l10n.pick(
                vi: 'Nếu đang tìm một chỗ để theo dõi gia phả và việc chung của dòng họ, đây là những phần bạn sẽ dùng nhiều nhất.',
                en: 'BeFam is mobile-first and works across web and tablet, giving clan operators and family members a shared source of truth.',
              ),
              primaryLabel: context.l10n.pick(
                vi: 'Mở ứng dụng',
                en: 'Start with BeFam',
              ),
              secondaryLabel: null,
              onPrimaryPressed: () => _trackAndOpenApp(
                context,
                pagePath: '/befam-info',
                placement: 'info_hero_primary',
              ),
              onSecondaryPressed: null,
              focusTags: const [],
            ),
            const SizedBox(height: _kCardGap),
            _FeatureCardGrid(
              items: [
                _FeatureItem(
                  icon: Icons.hub_rounded,
                  title: context.l10n.pick(
                    vi: 'Gia phả',
                    en: 'Genealogy workspace',
                  ),
                  description: context.l10n.pick(
                    vi: 'Xem cây gia phả, hồ sơ thành viên và các nhánh chi trong cùng một nơi.',
                    en: 'Track members, branches, and relationships in one shared structure.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.notifications_active_rounded,
                  title: context.l10n.pick(
                    vi: 'Lịch và thông báo',
                    en: 'Notifications and reminders',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi ngày giỗ, họp họ và các mốc quan trọng.',
                    en: 'Receive reminders for events and important family dates.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.payments_rounded,
                  title: context.l10n.pick(
                    vi: 'Quỹ và quyền dùng',
                    en: 'Plans and billing',
                  ),
                  description: context.l10n.pick(
                    vi: 'Xem trạng thái gói, thanh toán và quyền truy cập rõ ràng hơn.',
                    en: 'Manage access, billing status, and payments clearly.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kBlockGap),
            _CompactFeatureList(
              items: [
                _FeatureItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: context.l10n.pick(
                    vi: 'Ban điều hành họ tộc',
                    en: 'Clan governance team',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi tổng quan, duyệt yêu cầu và phân quyền theo từng chi.',
                    en: 'Track overview, manage permissions, review requests, and coordinate branch operations.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.account_balance_wallet_rounded,
                  title: context.l10n.pick(
                    vi: 'Người phụ trách quỹ',
                    en: 'Fund and scholarship operators',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ghi nhận thu chi, xét duyệt hồ sơ và theo dõi báo cáo minh bạch.',
                    en: 'Manage transactions, review submissions, and keep transparent reports over time.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.person_search_rounded,
                  title: context.l10n.pick(
                    vi: 'Con cháu ở xa',
                    en: 'Members and descendants abroad',
                  ),
                  description: context.l10n.pick(
                    vi: 'Xem gia phả, gửi yêu cầu tham gia và theo dõi lịch quan trọng.',
                    en: 'Find the right clan, submit join requests safely, and keep up with important family dates.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kBlockGap),
            _InfoBulletList(
              title: context.l10n.pick(
                vi: 'Một vài điều nên biết',
                en: 'Platform highlights',
              ),
              points: [
                context.l10n.pick(
                  vi: 'Dùng được trên điện thoại, máy tính bảng và web.',
                  en: 'Works across phone, tablet, and web for more flexible operations.',
                ),
                context.l10n.pick(
                  vi: 'Có tiếng Việt và tiếng Anh để thành viên ở nhiều nơi vẫn dễ theo dõi.',
                  en: 'Supports Vietnamese and English for members across locations.',
                ),
                context.l10n.pick(
                  vi: 'Quyền sử dụng chỉ mở khi hệ thống xác nhận thanh toán thành công.',
                  en: 'Access is granted only after the system confirms successful payment.',
                ),
              ],
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
      icon: Icons.privacy_tip_rounded,
      eyebrow: context.l10n.pick(vi: 'Quyền riêng tư', en: 'Privacy'),
      title: context.l10n.pick(
        vi: 'BeFam tôn trọng dữ liệu của từng thành viên và xử lý thông tin theo đúng mục đích vận hành.',
        en: 'BeFam respects each member’s family data.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Trang này tóm tắt cách BeFam thu thập, sử dụng, bảo vệ và phản hồi các yêu cầu liên quan đến dữ liệu cá nhân trong quá trình vận hành sản phẩm.',
        en: 'This page summarizes how BeFam collects, uses, protects, and responds to requests about personal data.',
      ),
      facts: [
        _LegalFact(
          title: context.l10n.pick(vi: 'Kênh hỗ trợ', en: 'Support channel'),
          description: _kSupportEmail,
        ),
        _LegalFact(
          title: context.l10n.pick(vi: 'Phạm vi xử lý', en: 'Scope'),
          description: context.l10n.pick(
            vi: 'Theo vai trò và nhu cầu vận hành',
            en: 'Role-based and operationally scoped',
          ),
        ),
        _LegalFact(
          title: context.l10n.pick(vi: 'Yêu cầu dữ liệu', en: 'Data requests'),
          description: context.l10n.pick(
            vi: 'Có thể gửi qua email hỗ trợ',
            en: 'Can be submitted via support email',
          ),
        ),
      ],
      sections: [
        _LegalSection(
          title: context.l10n.pick(
            vi: '1. Thông tin BeFam có thể xử lý',
            en: '1. Data BeFam collects',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam có thể xử lý số điện thoại đăng nhập, hồ sơ thành viên, vai trò trong gia phả, nội dung do người dùng nhập, dữ liệu sự kiện, giao dịch quỹ, hồ sơ khuyến học và một số tín hiệu kỹ thuật cần cho đăng nhập, bảo mật và vận hành dịch vụ.',
              en: 'BeFam may process phone numbers, member profiles, genealogy roles, user-entered content, fund transactions, scholarship submissions, and technical signals needed for sign-in, security, and operations.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '2. Mục đích sử dụng dữ liệu',
            en: '2. Why we use this data',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Dữ liệu được dùng để xác thực tài khoản, hiển thị đúng thông tin theo vai trò, vận hành các tính năng gia phả, sự kiện, quỹ, khuyến học, gửi thông báo cần thiết và hỗ trợ người dùng khi phát sinh vấn đề.',
              en: 'Data is used to authenticate accounts, show the correct family records with proper permissions, run event, fund, and scholarship workflows, send important notifications, and support users when issues happen.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '3. Bảo vệ và chia sẻ có kiểm soát',
            en: '3. Sharing and protecting data',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam chỉ chia sẻ dữ liệu với hạ tầng và dịch vụ vận hành cần thiết như Firebase, Google Cloud, Apple App Store, Google Play hoặc các đối tác xác thực và thanh toán liên quan đến tính năng mà người dùng đang sử dụng. Quyền truy cập trong ứng dụng được kiểm soát theo vai trò.',
              en: 'BeFam only shares data with required operating infrastructure and services such as Firebase, Google Cloud, Apple App Store, Google Play, or relevant verification and payment providers used by the feature. In-app access is controlled by role.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '4. Quyền yêu cầu và liên hệ',
            en: '4. Contact about your data',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Nếu bạn cần cập nhật thông tin, phản hồi hoặc yêu cầu liên quan đến dữ liệu của tài khoản BeFam, vui lòng liên hệ đội ngũ hỗ trợ qua email chính thức bên dưới để được tiếp nhận và hướng dẫn.',
              en: 'If you need to update, question, or request handling of data related to your BeFam account, contact the support team using the email below.',
            ),
          ],
          actions: [
            _LegalAction(
              label: context.l10n.pick(
                vi: 'Liên hệ email hỗ trợ',
                en: 'Contact support by email',
              ),
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
      icon: Icons.gavel_rounded,
      eyebrow: context.l10n.pick(vi: 'Điều khoản', en: 'Terms'),
      title: context.l10n.pick(
        vi: 'BeFam được thiết kế cho việc vận hành gia phả và hoạt động dòng họ theo cách tôn trọng, rõ ràng và đúng quyền.',
        en: 'BeFam is intended for respectful and transparent family-clan operations.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Khi sử dụng BeFam, người dùng cần cung cấp thông tin phù hợp, thao tác đúng quyền và không gây ảnh hưởng tiêu cực đến các thành viên khác trong dòng họ.',
        en: 'When using BeFam, users are expected to provide appropriate information, act within their permissions, and avoid harming other family members.',
      ),
      facts: [
        _LegalFact(
          title: context.l10n.pick(
            vi: 'Nguyên tắc sử dụng',
            en: 'Use principle',
          ),
          description: context.l10n.pick(
            vi: 'Đúng người, đúng quyền, đúng bối cảnh',
            en: 'Right person, right role, right context',
          ),
        ),
        _LegalFact(
          title: context.l10n.pick(vi: 'Trách nhiệm', en: 'Responsibility'),
          description: context.l10n.pick(
            vi: 'Giữ an toàn tài khoản và thông tin',
            en: 'Keep account and information secure',
          ),
        ),
        _LegalFact(
          title: context.l10n.pick(vi: 'Hỗ trợ', en: 'Support'),
          description: _kSupportEmail,
        ),
      ],
      sections: [
        _LegalSection(
          title: context.l10n.pick(
            vi: '1. Phạm vi sử dụng phù hợp',
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
              vi: 'Mỗi tài khoản phải được sử dụng bởi đúng người, đúng hồ sơ và đúng vai trò. Người dùng chịu trách nhiệm với các thao tác của mình trên hệ thống, bao gồm yêu cầu tham gia, cập nhật hồ sơ, quản trị dữ liệu, giao dịch và các hành động vận hành liên quan.',
              en: 'Each account must be used by the right person, profile, and role. Users are responsible for their actions in the system, including join requests, data administration, transactions, and profile updates.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '3. Nội dung và hành vi không phù hợp',
            en: '3. Inappropriate content and behavior',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Người dùng không được mạo danh, truy cập dữ liệu vượt quá quyền được cấp, đăng tải nội dung sai lệch hoặc sử dụng BeFam theo cách gây tổn hại tới thành viên khác hay hoạt động chung của dòng họ.',
              en: 'Users must not impersonate others, access data beyond their granted permissions, upload misleading content, or use BeFam in ways that harm other members or shared clan operations.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '4. Gói dịch vụ và hỗ trợ',
            en: '4. Paid services and support',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Một số tính năng có thể gắn với gói dịch vụ, thanh toán hoặc nhắc việc. Quyền sử dụng chỉ được kích hoạt khi hệ thống hoặc kho ứng dụng xác nhận thành công. Nếu cần hỗ trợ về điều khoản, quyền sử dụng hoặc tranh chấp liên quan đến tài khoản, vui lòng liên hệ email hỗ trợ chính thức.',
              en: 'If you need help with terms, access rights, or account-related disputes in BeFam, please contact support.',
            ),
          ],
          actions: [
            _LegalAction(
              label: context.l10n.pick(
                vi: 'Liên hệ email hỗ trợ',
                en: 'Contact support by email',
              ),
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
      icon: Icons.delete_sweep_rounded,
      eyebrow: context.l10n.pick(vi: 'Xóa tài khoản', en: 'Account deletion'),
      title: context.l10n.pick(
        vi: 'Bạn có thể gửi yêu cầu xóa tài khoản BeFam mà không cần đăng nhập.',
        en: 'You can request deletion of your BeFam account without signing in.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Đội ngũ BeFam sẽ tiếp nhận yêu cầu, xác minh thông tin cần thiết và phản hồi tiến độ qua email hỗ trợ.',
        en: 'The BeFam team will receive the request, verify the necessary details, and respond with next steps through support.',
      ),
      facts: [
        _LegalFact(
          title: context.l10n.pick(vi: 'Đăng nhập', en: 'Sign-in'),
          description: context.l10n.pick(
            vi: 'Không bắt buộc để gửi yêu cầu',
            en: 'Not required to submit a request',
          ),
        ),
        _LegalFact(
          title: context.l10n.pick(vi: 'Xác minh', en: 'Verification'),
          description: context.l10n.pick(
            vi: 'Cần trước khi xử lý xóa',
            en: 'Required before deletion is processed',
          ),
        ),
        _LegalFact(
          title: context.l10n.pick(vi: 'Kênh phản hồi', en: 'Response channel'),
          description: _kSupportEmail,
        ),
      ],
      sections: [
        _LegalSection(
          title: context.l10n.pick(
            vi: '1. Cách gửi yêu cầu',
            en: '1. How to submit a request',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Gửi email tới đội ngũ hỗ trợ với tiêu đề “Yêu cầu xóa tài khoản BeFam”, kèm số điện thoại đăng nhập, họ tên và các thông tin nhận diện cần thiết để đội ngũ BeFam xác minh chủ tài khoản.',
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
            vi: '2. Những gì BeFam sẽ xác minh',
            en: '2. What BeFam will verify',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Trước khi xử lý xóa, BeFam có thể xác minh số điện thoại đăng nhập, họ tên và một số chi tiết liên quan để bảo đảm yêu cầu đến từ đúng chủ tài khoản hoặc người có quyền đại diện hợp lệ.',
              en: 'Before processing deletion, BeFam may verify the sign-in phone number, full name, and relevant details to ensure the request comes from the rightful account holder or a valid representative.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '3. Cách dữ liệu được xử lý',
            en: '3. How data is handled',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'Khi yêu cầu được xác nhận, BeFam sẽ xử lý việc xóa hoặc vô hiệu hóa tài khoản và dữ liệu liên quan theo chính sách vận hành hiện hành, ngoại trừ phần dữ liệu cần được lưu giữ do nghĩa vụ pháp lý hoặc phục vụ đối soát hệ thống.',
              en: 'Once the request is confirmed, BeFam will process deletion or deactivation of the account and related data according to current operating policy, except data that must be retained for legal or system-reconciliation reasons.',
            ),
          ],
        ),
        _LegalSection(
          title: context.l10n.pick(
            vi: '4. Phản hồi kết quả',
            en: '4. Response and completion',
          ),
          paragraphs: [
            context.l10n.pick(
              vi: 'BeFam sẽ phản hồi tiến độ qua email hỗ trợ sau khi tiếp nhận và xác minh thông tin. Thời gian xử lý có thể thay đổi theo khối lượng yêu cầu thực tế, nhưng đội ngũ sẽ cố gắng cập nhật kết quả sớm nhất có thể.',
              en: 'BeFam will respond with progress by email after receiving and verifying the request. Processing time may vary based on request volume, but the team will aim to keep you updated as early as possible.',
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
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.facts,
    required this.sections,
  });

  final String currentPath;
  final String pageTitle;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<_LegalFact> facts;
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
              icon: icon,
              badge: eyebrow,
            ),
            const SizedBox(height: _kBlockGap),
            _LegalFactGrid(facts: facts),
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

class _LegalFact {
  const _LegalFact({required this.title, required this.description});

  final String title;
  final String description;
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kAppSurfaceRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Text(
              section.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...[
            for (final paragraph in section.paragraphs) ...[
              Text(
                paragraph,
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (section.actions.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in section.actions)
                  FilledButton.tonalIcon(
                    onPressed: () => launchUrl(
                      Uri.parse(action.href),
                      mode: LaunchMode.platformDefault,
                    ),
                    icon: Icon(
                      action.href.startsWith('mailto:')
                          ? Icons.mail_outline_rounded
                          : Icons.open_in_new_rounded,
                    ),
                    label: Text(action.label),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegalFactGrid extends StatelessWidget {
  const _LegalFactGrid({required this.facts});

  final List<_LegalFact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1020
            ? 3
            : width >= 680
            ? 2
            : 1;
        const spacing = 14.0;
        final itemWidth =
            ((width - (spacing * (columns - 1))).clamp(0.0, double.infinity) /
                    columns)
                .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final fact in facts)
              SizedBox(
                width: itemWidth,
                child: _LegalFactCard(fact: fact),
              ),
          ],
        );
      },
    );
  }
}

class _LegalFactCard extends StatelessWidget {
  const _LegalFactCard({required this.fact});

  final _LegalFact fact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.7),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fact.title,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fact.description,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebMarketingLayout extends StatefulWidget {
  const _WebMarketingLayout({
    required this.currentPath,
    required this.pageTitle,
    required this.child,
  });

  final String currentPath;
  final String pageTitle;
  final Widget child;

  @override
  State<_WebMarketingLayout> createState() => _WebMarketingLayoutState();
}

class _WebMarketingLayoutState extends State<_WebMarketingLayout> {
  late final ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    final nextIsScrolled = _scrollController.hasClients
        ? _scrollController.offset > 12
        : false;
    if (nextIsScrolled == _isScrolled) {
      return;
    }
    setState(() => _isScrolled = nextIsScrolled);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inlineAd = _buildMarketingInlineAdForPath(widget.currentPath);
    return Title(
      title: widget.pageTitle,
      color: _kLandingInk,
      child: Scaffold(
        body: AppLineageBackdrop(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shellWidth = constraints.maxWidth > 1220
                    ? 1220.0
                    : constraints.maxWidth;
                final horizontalPadding = shellWidth < 560 ? 14.0 : 22.0;

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: shellWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          AnimatedPadding(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(top: _isScrolled ? 0 : 8),
                            child: _TopNavigation(
                              currentPath: widget.currentPath,
                              isScrolled: _isScrolled,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  widget.child,
                                  inlineAd,
                                  const SizedBox(height: 8),
                                  _WebFooter(pagePath: widget.currentPath),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({required this.currentPath, required this.isScrolled});

  final String currentPath;
  final bool isScrolled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final localeController = AppLocaleScope.maybeOf(context);
    final navItems = [
      _NavItem(
        path: '/befam-info',
        label: l10n.pick(vi: 'Gia phả', en: 'Lineage'),
      ),
      _NavItem(
        path: '/befam-info',
        label: l10n.pick(vi: 'Giỗ lễ', en: 'Memorials'),
      ),
      _NavItem(
        path: '/befam-info',
        label: l10n.pick(vi: 'Quỹ họ', en: 'Funds'),
      ),
      _NavItem(
        path: '/privacy',
        label: l10n.pick(vi: 'Bảo mật', en: 'Trust'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 900;
        final isPhone = width < 560;
        final showBrandSubtitle = width >= 1180;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: isScrolled ? 0.9 : 0.78),
            border: Border.all(color: _kLandingLine),
            boxShadow: [
              BoxShadow(
                color: Color(isScrolled ? 0x1F0F172A : 0x140F172A),
                blurRadius: isScrolled ? 28 : 24,
                offset: Offset(0, isScrolled ? 14 : 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 10 : 18,
              vertical: isPhone ? 10 : 12,
            ),
            child: Row(
              children: [
                const _BrandMark(),
                SizedBox(width: isPhone ? 10 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BeFam',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    if (showBrandSubtitle)
                      Text(
                        context.l10n.pick(
                          vi: 'Gia phả sống cho dòng họ Việt',
                          en: 'Living lineage for families',
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: _kLandingMuted,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (!isCompact)
                  ...navItems.map(
                    (item) => _NavButton(
                      label: item.label,
                      isActive:
                          (currentPath == '/befam-info' &&
                              item == navItems.first) ||
                          (currentPath == item.path &&
                              currentPath != '/befam-info'),
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
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                SizedBox(width: isPhone ? 4 : 8),
                if (!isPhone) ...[
                  _MarketingLanguageSwitch(
                    controller: localeController,
                    compact: isCompact,
                  ),
                  const SizedBox(width: 10),
                ],
                if (!isCompact) ...[
                  TextButton(
                    onPressed: () => _trackAndOpenApp(
                      context,
                      pagePath: currentPath,
                      placement: 'top_nav_sign_in',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _kLandingMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      l10n.pick(vi: 'Đăng nhập', en: 'Sign in').toUpperCase(),
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                FilledButton(
                  onPressed: () => _trackAndOpenApp(
                    context,
                    pagePath: currentPath,
                    placement: 'top_nav_open_app',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kLandingInk,
                    foregroundColor: Colors.white,
                    minimumSize: Size(isPhone ? 42 : 0, isPhone ? 42 : 46),
                    padding: EdgeInsets.symmetric(horizontal: isPhone ? 0 : 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: isPhone
                      ? const Icon(Icons.arrow_forward_rounded, size: 18)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCompact
                                  ? context.l10n.pick(vi: 'Mở', en: 'Open')
                                  : l10n.webNavOpenApp,
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
                if (isCompact && !isPhone) const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LandingHeroSection extends StatelessWidget {
  const _LandingHeroSection({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    required this.quickCards,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;
  final List<_FeatureItem> quickCards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;

          final heroRow = isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LandingHeroContent(
                      badge: badge,
                      title: title,
                      subtitle: subtitle,
                      primaryLabel: primaryLabel,
                      secondaryLabel: secondaryLabel,
                      onPrimaryPressed: onPrimaryPressed,
                      onSecondaryPressed: onSecondaryPressed,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(height: 272, child: const _LandingHeroArtwork()),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _LandingHeroContent(
                        badge: badge,
                        title: title,
                        subtitle: subtitle,
                        primaryLabel: primaryLabel,
                        secondaryLabel: secondaryLabel,
                        onPrimaryPressed: onPrimaryPressed,
                        onSecondaryPressed: onSecondaryPressed,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      flex: 9,
                      child: SizedBox(
                        height: 308,
                        child: const _LandingHeroArtwork(),
                      ),
                    ),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heroRow,
              const SizedBox(height: 18),
              _LandingQuickCardGrid(items: quickCards),
            ],
          );
        },
      ),
    );
  }
}

class _LandingHeroContent extends StatelessWidget {
  const _LandingHeroContent({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white.withValues(alpha: 0.88),
            border: Border.all(color: _kLandingLine),
          ),
          child: Text(
            badge,
            style: textTheme.labelLarge?.copyWith(
              color: _kLandingInk,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(
            title,
            style: textTheme.headlineLarge?.copyWith(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: _kLandingInk,
              height: 1.04,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            style: textTheme.titleMedium?.copyWith(
              color: _kLandingMuted,
              height: 1.48,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPrimaryPressed,
              icon: const Icon(Icons.arrow_outward_rounded),
              label: Text(primaryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: _kLandingInk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onSecondaryPressed,
              icon: const Icon(Icons.chevron_right_rounded),
              label: Text(secondaryLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kLandingInk,
                side: const BorderSide(color: _kLandingLine),
                backgroundColor: Colors.white.withValues(alpha: 0.72),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LandingQuickCardGrid extends StatelessWidget {
  const _LandingQuickCardGrid({required this.items});

  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120
            ? 4
            : width >= 720
            ? 2
            : 1;
        const spacing = 14.0;
        final itemHeight = width >= 1120
            ? 196.0
            : width >= 720
            ? 180.0
            : 168.0;
        final itemWidth =
            ((width - (spacing * (columns - 1))).clamp(0.0, double.infinity) /
                    columns)
                .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _LandingQuickCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _LandingQuickCard extends StatelessWidget {
  const _LandingQuickCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final artworkColor = switch (item.icon) {
      Icons.account_tree_rounded => _kLandingMint,
      Icons.calendar_month_rounded => _kLandingCoral,
      Icons.payments_rounded => _kLandingAqua,
      _ => _kLandingGold,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: _kLandingLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _kLandingInk,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: _kLandingMuted,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _LandingCardIllustration(
            icon: item.icon,
            backgroundColor: artworkColor,
          ),
        ],
      ),
    );
  }
}

class _LandingCardIllustration extends StatelessWidget {
  const _LandingCardIllustration({
    required this.icon,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      height: 122,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, Colors.white.withValues(alpha: 0.82)],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 58,
          color: _kLandingInk.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _LandingHeroArtwork extends StatelessWidget {
  const _LandingHeroArtwork();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = [
      (
        eyebrow: context.l10n.pick(vi: 'Gia phả', en: 'Lineage'),
        label: context.l10n.pick(
          vi: 'Thế hệ và quan hệ',
          en: 'Generations and relationships',
        ),
      ),
      (
        eyebrow: context.l10n.pick(vi: 'Ngày giỗ', en: 'Memorials'),
        label: context.l10n.pick(vi: 'Lịch âm dương', en: 'Lunar calendar'),
      ),
      (
        eyebrow: context.l10n.pick(vi: 'Thành viên', en: 'Members'),
        label: context.l10n.pick(
          vi: 'Quyền theo vai trò',
          en: 'Role-based access',
        ),
      ),
      (
        eyebrow: context.l10n.pick(vi: 'Quỹ họ', en: 'Clan funds'),
        label: context.l10n.pick(
          vi: 'Thu chi minh bạch',
          en: 'Transparent records',
        ),
      ),
    ];
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    if (isPhone) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(color: _kLandingLine),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: AppLineageGridOverlay(opacity: 0.7, spacing: 28),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: _LineageSignalChip(
                            eyebrow: items[index].eyebrow,
                            label: items[index].label,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      if (index < items.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(color: _kLandingLine),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: AppLineageGridOverlay(opacity: 0.9, spacing: 28),
            ),
            const Positioned(
              left: 24,
              top: 22,
              child: _LineageSignalChip(
                eyebrow: 'Gia phả',
                label: 'Thế hệ và quan hệ',
              ),
            ),
            const Positioned(
              right: 22,
              top: 42,
              child: _LineageSignalChip(
                eyebrow: 'Ngày giỗ',
                label: 'Lịch âm dương',
              ),
            ),
            const Positioned(
              left: 42,
              bottom: 34,
              child: _LineageSignalChip(
                eyebrow: 'Thành viên',
                label: 'Quyền theo vai trò',
              ),
            ),
            const Positioned(
              right: 36,
              bottom: 22,
              child: _LineageSignalChip(
                eyebrow: 'Quỹ họ',
                label: 'Thu chi minh bạch',
              ),
            ),
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.92),
                  border: Border.all(
                    color: colorScheme.secondary.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'BeFam\nrõ người\nrõ việc',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: _kLandingInk,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                      letterSpacing: 0,
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

class _LineageSignalChip extends StatelessWidget {
  const _LineageSignalChip({
    required this.eyebrow,
    required this.label,
    this.width = 150,
  });

  final String eyebrow;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: _kLandingLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow,
            style: textTheme.labelSmall?.copyWith(
              color: _kLandingMuted,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: _kLandingInk,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStorySection extends StatelessWidget {
  const _HeroStorySection({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.focusTags,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final List<String> focusTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;
          final isPhone = constraints.maxWidth < 560;

          final leftPane = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StaticHeroKicker(label: badge),
              const SizedBox(height: 26),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPhone ? constraints.maxWidth : 650,
                ),
                child: Text(
                  title,
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: isPhone
                        ? 36
                        : isCompact
                        ? 42
                        : 64,
                    fontWeight: FontWeight.w900,
                    color: _kLandingInk,
                    height: 1.04,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPhone ? constraints.maxWidth : 620,
                ),
                child: Text(
                  subtitle,
                  style: textTheme.titleLarge?.copyWith(
                    color: _kLandingMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.48,
                    fontSize: isPhone ? 17 : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onPrimaryPressed,
                    icon: const Icon(Icons.square_rounded, size: 10),
                    label: Text(primaryLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kLandingInk,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (secondaryLabel != null && onSecondaryPressed != null)
                    OutlinedButton.icon(
                      onPressed: onSecondaryPressed,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: Text(secondaryLabel!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kLandingInk,
                        side: const BorderSide(color: _kLandingLine),
                        backgroundColor: Colors.white.withValues(alpha: 0.72),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              if (focusTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in focusTags) _FocusTag(label: tag),
                  ],
                ),
              ],
            ],
          );

          final rightPane = SizedBox(
            height: isPhone
                ? 330
                : isCompact
                ? 292
                : 430,
            child: const _LandingHeroArtwork(),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [leftPane, const SizedBox(height: 16), rightPane],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 6, child: leftPane),
              const SizedBox(width: 36),
              Expanded(flex: 5, child: rightPane),
            ],
          );
        },
      ),
    );
  }
}

class _StaticHeroKicker extends StatelessWidget {
  const _StaticHeroKicker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF32C475),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF8AA096),
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FocusTag extends StatelessWidget {
  const _FocusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: _kLandingLine),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _kLandingInk,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FeatureCardGrid extends StatelessWidget {
  const _FeatureCardGrid({required this.items});

  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 900;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kMarketingRadius),
            color: Colors.white.withValues(alpha: 0.84),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 18,
            vertical: isCompact ? 6 : 8,
          ),
          child: isCompact
              ? Column(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      _FeatureCard(
                        item: items[index],
                        showTrailingDivider: false,
                        showBottomDivider: index < items.length - 1,
                      ),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Expanded(
                          child: _FeatureCard(
                            item: items[index],
                            showTrailingDivider: index < items.length - 1,
                            showBottomDivider: false,
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.item,
    required this.showTrailingDivider,
    required this.showBottomDivider,
  });

  final _FeatureItem item;
  final bool showTrailingDivider;
  final bool showBottomDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: showTrailingDivider
              ? BorderSide(color: colorScheme.outlineVariant)
              : BorderSide.none,
          bottom: showBottomDivider
              ? BorderSide(color: colorScheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            ),
            child: Icon(item.icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.22,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactFeatureList extends StatelessWidget {
  const _CompactFeatureList({required this.items});

  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _CompactFeatureRow(
              item: items[index],
              showDivider: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _CompactFeatureRow extends StatelessWidget {
  const _CompactFeatureRow({required this.item, required this.showDivider});

  final _FeatureItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: showDivider
              ? BorderSide(color: colorScheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            ),
            child: Icon(item.icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                letterSpacing: 0,
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
        borderRadius: BorderRadius.circular(_kMarketingRadius),
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
              letterSpacing: 0,
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
                letterSpacing: 0,
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
                    borderRadius: BorderRadius.circular(_kMarketingRadius),
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
                        letterSpacing: 0,
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
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final String title;
  final String description;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.62),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
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
                icon: const Icon(Icons.arrow_outward_rounded),
                label: Text(primaryLabel),
              ),
              if (secondaryLabel != null && onSecondaryPressed != null)
                OutlinedButton.icon(
                  onPressed: onSecondaryPressed,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(secondaryLabel!),
                ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 12), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kAppSurfaceRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_kCardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) ...[
                  _EyebrowChip(label: badge!),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.56,
                    ),
                  ),
                ),
              ],
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.22,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HunpeoLabsContactCard extends StatelessWidget {
  const _HunpeoLabsContactCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
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
                        height: 1.18,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.pick(
                        vi: 'Hunpeo Labs là đơn vị vận hành BeFam. Nếu bạn cần hỗ trợ, góp ý hoặc phản ánh trải nghiệm, có thể liên hệ theo các kênh dưới đây.',
                        en: 'Hunpeo Labs operates and develops BeFam, handling partnerships, product feedback, and user-experience reports through a single contact flow.',
                      ),
                      style: textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 980
                  ? 3
                  : width >= 660
                  ? 2
                  : 1;
              const spacing = 14.0;
              final itemWidth =
                  ((width - (spacing * (columns - 1))).clamp(
                            0.0,
                            double.infinity,
                          ) /
                          columns)
                      .toDouble();

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ContactActionCard(
                      icon: Icons.mail_outline_rounded,
                      title: l10n.pick(vi: 'Email hỗ trợ', en: 'Support email'),
                      value: _kSupportEmail,
                      description: l10n.pick(
                        vi: 'Dùng cho hỗ trợ tài khoản và các vấn đề cần phản hồi trực tiếp.',
                        en: 'Primary channel for account support, access issues, and operational questions.',
                      ),
                      href:
                          'mailto:$_kSupportEmail?subject=BeFam%20Support%20Request',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ContactActionCard(
                      icon: Icons.description_outlined,
                      title: l10n.pick(
                        vi: 'Google Form phản ánh',
                        en: 'Feedback Google Form',
                      ),
                      value: l10n.pick(
                        vi: 'Gửi góp ý hoặc phản ánh',
                        en: 'Send feedback or report',
                      ),
                      description: l10n.pick(
                        vi: 'Dùng khi bạn muốn góp ý, báo lỗi hoặc phản ánh trải nghiệm.',
                        en: 'Submit product feedback, bug reports, and improvement suggestions.',
                      ),
                      href: _kFeedbackFormUrl,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ContactActionCard(
                      icon: Icons.facebook_rounded,
                      title: l10n.pick(
                        vi: 'Fanpage BeFam',
                        en: 'BeFam Fanpage',
                      ),
                      value: l10n.pick(
                        vi: 'Theo dõi cập nhật cộng đồng',
                        en: 'Follow community updates',
                      ),
                      description: l10n.pick(
                        vi: 'Xem thông báo mới và các cập nhật từ BeFam.',
                        en: 'Follow announcements, new content, and BeFam community updates.',
                      ),
                      href: _kFanpageUrl,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContactActionCard extends StatelessWidget {
  const _ContactActionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.href,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;
  final String href;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => launchUrl(Uri.parse(href), mode: LaunchMode.platformDefault),
      borderRadius: BorderRadius.circular(_kMarketingRadius),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kMarketingRadius),
          color: Colors.white.withValues(alpha: 0.76),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 22, color: colorScheme.primary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.52,
              ),
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final iosStoreUrl = AppEnvironment.iosAppStoreUrl.trim();
    final androidStoreUrl = AppEnvironment.androidPlayStoreUrl.trim();
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: _kLandingLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 940;
              final brandBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _BrandMark(),
                      const SizedBox(width: 12),
                      Text(
                        'BeFam',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _kLandingInk,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      l10n.pick(
                        vi: 'Nền tảng gia phả số giúp dòng tộc giữ kết nối, vận hành rõ ràng và minh bạch hơn trong đời sống hiện đại.',
                        en: 'A digital lineage platform helping family clans stay connected and operate with more clarity in modern life.',
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _kLandingMuted,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FooterSupportBadge(
                    label: l10n.pick(
                      vi: 'Hỗ trợ chính thức',
                      en: 'Official support',
                    ),
                    value: _kSupportEmail,
                    href:
                        'mailto:$_kSupportEmail?subject=BeFam%20Support%20Request',
                  ),
                ],
              );

              final storeBlock = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StoreDownloadButton(
                    ctaType: 'app_store',
                    placement: 'footer_app_store',
                    pagePath: pagePath,
                    title: l10n.pick(
                      vi: 'Tải trên App Store',
                      en: 'Download on App Store',
                    ),
                    subtitle: l10n.pick(vi: 'Ứng dụng iPhone', en: 'iOS app'),
                    url: iosStoreUrl,
                  ),
                  _StoreDownloadButton(
                    ctaType: 'google_play',
                    placement: 'footer_google_play',
                    pagePath: pagePath,
                    title: l10n.pick(
                      vi: 'Tải trên Google Play',
                      en: 'Get it on Google Play',
                    ),
                    subtitle: l10n.pick(
                      vi: 'Ứng dụng Android',
                      en: 'Android app',
                    ),
                    url: androidStoreUrl,
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brandBlock,
                    const SizedBox(height: 14),
                    storeBlock,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: brandBlock),
                  const SizedBox(width: 16),
                  Flexible(child: storeBlock),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(color: _kLandingLine, height: 1),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final links = Wrap(
                spacing: 10,
                runSpacing: 10,
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
              );

              final copyright = Text(
                context.l10n.pick(
                  vi: 'Copyright © $year BeFam. Đã đăng ký bản quyền.',
                  en: 'Copyright © $year BeFam. All rights reserved.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _kLandingMuted,
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [links, const SizedBox(height: 14), copyright],
                );
              }

              return Row(
                children: [
                  Expanded(child: links),
                  const SizedBox(width: 12),
                  copyright,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FooterSupportBadge extends StatelessWidget {
  const _FooterSupportBadge({
    required this.label,
    required this.value,
    required this.href,
  });

  final String label;
  final String value;
  final String href;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => launchUrl(Uri.parse(href), mode: LaunchMode.platformDefault),
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.78),
          border: Border.all(color: _kLandingLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              color: _kLandingInk,
              size: 18,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: _kLandingMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    color: _kLandingInk,
                    fontWeight: FontWeight.w700,
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

class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kLandingInk,
        side: const BorderSide(color: _kLandingLine),
        backgroundColor: Colors.white.withValues(alpha: 0.68),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        minimumSize: Size.zero,
      ),
      child: Text(label),
    );
  }
}

class _MarketingLanguageSwitch extends StatelessWidget {
  const _MarketingLanguageSwitch({
    required this.controller,
    this.compact = false,
  });

  final AppLocaleController? controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final selectedLanguageCode = controller!.locale.languageCode.toLowerCase();
    final options = [
      (
        code: 'vi',
        short: 'VI',
        label: l10n.pick(vi: 'Tiếng Việt', en: 'Vietnamese'),
      ),
      (
        code: 'en',
        short: 'EN',
        label: l10n.pick(vi: 'Tiếng Anh', en: 'English'),
      ),
    ];

    Future<void> selectLanguage(String code) async {
      await controller!.updateLanguageCode(code);
    }

    final current = options.firstWhere(
      (option) => option.code == selectedLanguageCode,
      orElse: () => options.first,
    );
    final textTheme = Theme.of(context).textTheme;
    final pillPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 9);

    return PopupMenuButton<String>(
      tooltip: l10n.pick(vi: 'Đổi ngôn ngữ', en: 'Change language'),
      onSelected: (languageCode) => unawaited(selectLanguage(languageCode)),
      offset: const Offset(0, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option.code,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _kLandingInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selectedLanguageCode == option.code)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: _kLandingInk,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: pillPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.72),
          border: Border.all(color: _kLandingLine),
          boxShadow: compact
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: compact ? 16 : 18,
              color: _kLandingMuted,
            ),
            const SizedBox(width: 8),
            Text(
              current.short,
              style: textTheme.labelLarge?.copyWith(
                color: _kLandingInk,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: compact ? 18 : 20,
              color: _kLandingMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreDownloadButton extends StatelessWidget {
  const _StoreDownloadButton({
    required this.ctaType,
    required this.placement,
    required this.pagePath,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final String ctaType;
  final String placement;
  final String pagePath;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStoreUrl = url.trim().isNotEmpty;

    Future<void> handleTap() async {
      if (hasStoreUrl) {
        await _trackAndOpenExternalUrl(
          ctaType: ctaType,
          placement: placement,
          pagePath: pagePath,
          url: url,
        );
        return;
      }

      _trackAndOpenApp(
        context,
        pagePath: pagePath,
        placement: '${placement}_fallback_open_app',
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF020304), Color(0xFF0B0F12)],
            ),
            border: Border.all(color: const Color(0xFF1F262C)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 264, maxWidth: 320),
            child: Row(
              children: [
                _StoreBrandTile(ctaType: ctaType, isEnabled: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFC3CDD5),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  hasStoreUrl
                      ? Icons.arrow_outward_rounded
                      : Icons.smartphone_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreBrandTile extends StatelessWidget {
  const _StoreBrandTile({required this.ctaType, required this.isEnabled});

  final String ctaType;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    if (ctaType == 'app_store') {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF0EA5E9)],
          ),
        ),
        child: CustomPaint(painter: _AppStoreGlyphPainter()),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(11),
        child: CustomPaint(painter: _GooglePlayGlyphPainter()),
      ),
    );
  }
}

class _AppStoreGlyphPainter extends CustomPainter {
  const _AppStoreGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.2),
      Offset(size.width * 0.18, size.height * 0.72),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, size.height * 0.2),
      Offset(size.width * 0.82, size.height * 0.72),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.6),
      Offset(size.width * 0.72, size.height * 0.6),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GooglePlayGlyphPainter extends CustomPainter {
  const _GooglePlayGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = const Color(0xFF3B82F6);
    final green = Paint()..color = const Color(0xFF34D399);
    final yellow = Paint()..color = const Color(0xFFFBBF24);
    final red = Paint()..color = const Color(0xFFF87171);

    final left = Offset(size.width * 0.18, size.height * 0.12);
    final right = Offset(size.width * 0.86, size.height * 0.5);
    final bottom = Offset(size.width * 0.18, size.height * 0.88);
    final center = Offset(size.width * 0.46, size.height * 0.5);

    final bluePath = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(size.width * 0.3, size.height * 0.62)
      ..close();

    final greenPath = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(size.width * 0.3, size.height * 0.38)
      ..lineTo(size.width * 0.3, size.height * 0.62)
      ..lineTo(bottom.dx, bottom.dy)
      ..close();

    final yellowPath = Path()
      ..moveTo(size.width * 0.3, size.height * 0.38)
      ..lineTo(right.dx, right.dy)
      ..lineTo(center.dx, center.dy)
      ..close();

    final redPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(size.width * 0.3, size.height * 0.62)
      ..close();

    canvas.drawPath(greenPath, green);
    canvas.drawPath(bluePath, blue);
    canvas.drawPath(yellowPath, yellow);
    canvas.drawPath(redPath, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w900,
      color: isActive ? const Color(0xFF3155FF) : _kLandingMuted,
      letterSpacing: 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isActive ? const Color(0xFF3155FF) : _kLandingMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(label.toUpperCase(), style: textStyle),
      ),
    );
  }
}

class _EyebrowChip extends StatelessWidget {
  const _EyebrowChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _kLandingGold,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _kLandingInk,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _kLandingInk,
        border: Border.all(color: const Color(0x383155FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x263155FF),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -5,
              top: -5,
              child: Transform.rotate(
                angle: 0.314,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3155FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -4,
              bottom: -4,
              child: Transform.rotate(
                angle: 0.314,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE34CFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'BF',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
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
