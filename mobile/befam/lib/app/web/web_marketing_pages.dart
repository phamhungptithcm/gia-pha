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

const double _kSectionGap = 12;
const double _kBlockGap = 12;
const double _kCardGap = 10;
const double _kCardPadding = 16;
const double _kMarketingRadius = 8;
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
                vi: 'Một nơi gọn để xem gia phả, nhớ ngày giỗ và quản lý việc chung.',
                en: 'One calm place for lineage, memorial dates, and shared clan work.',
              ),
              primaryLabel: l10n.webLandingPrimaryCta,
              secondaryLabel: context.l10n.pick(vi: 'Câu chuyện', en: 'Story'),
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
                    vi: 'Nhìn nhánh họ nhanh hơn.',
                    en: 'Branches stay easy to scan.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.calendar_month_rounded,
                  title: context.l10n.pick(
                    vi: 'Rõ ngày giỗ',
                    en: 'Clear dates',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ngày quan trọng luôn đúng chỗ.',
                    en: 'Important dates stay visible.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.payments_rounded,
                  title: context.l10n.pick(vi: 'Rõ quỹ họ', en: 'Clear funds'),
                  description: context.l10n.pick(
                    vi: 'Thu chi có quyền và lịch sử.',
                    en: 'Role-aware records.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.auto_awesome_rounded,
                  title: context.l10n.pick(vi: 'Rõ quyền', en: 'Clear access'),
                  description: context.l10n.pick(
                    vi: 'Ai xem, ai sửa đều rõ.',
                    en: 'View and edit roles are clear.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kSectionGap),
            _JourneyTimeline(
              title: context.l10n.pick(
                vi: 'Dùng BeFam thế nào?',
                en: 'How BeFam fits in',
              ),
              steps: [
                _JourneyStep(
                  index: 1,
                  title: context.l10n.pick(
                    vi: 'Xác nhận đúng người',
                    en: 'Sign in and identify',
                  ),
                  description: context.l10n.pick(
                    vi: 'Đăng nhập và vào đúng gia phả của mình.',
                    en: 'Sign in and open the right family record.',
                  ),
                ),
                _JourneyStep(
                  index: 2,
                  title: context.l10n.pick(
                    vi: 'Sắp xếp việc chung',
                    en: 'Run clan operations',
                  ),
                  description: context.l10n.pick(
                    vi: 'Theo dõi ngày giỗ, họp họ và thông báo.',
                    en: 'Track memorials, events, and reminders.',
                  ),
                ),
                _JourneyStep(
                  index: 3,
                  title: context.l10n.pick(
                    vi: 'Theo dõi quỹ rõ ràng',
                    en: 'Keep finances transparent',
                  ),
                  description: context.l10n.pick(
                    vi: 'Xem thu chi và đóng góp khi cần.',
                    en: 'Review funds and contributions clearly.',
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
                vi: 'Giữ liên kết gia đình, dù mỗi người ở một nơi.',
                en: 'Keep family work together, even when everyone lives apart.',
              ),
              subtitle: context.l10n.pick(
                vi: 'BeFam gom gia phả, ngày giỗ, việc chung và hỗ trợ vào một mạch dễ theo dõi.',
                en: 'BeFam keeps lineage, memorial dates, shared work, and support in one clear flow.',
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
                    vi: 'Gia phả rời rạc, lịch giỗ dễ quên được gom lại.',
                    en: 'Lineage and memorial dates are kept together.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.visibility_rounded,
                  title: context.l10n.pick(
                    vi: 'Ưu tiên dễ theo dõi',
                    en: 'Easy to follow',
                  ),
                  description: context.l10n.pick(
                    vi: 'Vào là thấy việc chính, không cần đọc dài.',
                    en: 'The main task is visible without heavy reading.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.security_rounded,
                  title: context.l10n.pick(
                    vi: 'Rõ người, rõ việc',
                    en: 'Keep responsibility clear',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ai xem, ai sửa, ai duyệt được thể hiện rõ.',
                    en: 'View, edit, and review roles stay explicit.',
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
                vi: 'Mọi việc chính của dòng họ trong một nơi.',
                en: 'The core family-clan workflows in one place.',
              ),
              subtitle: context.l10n.pick(
                vi: 'Xem người thân, ngày giỗ, quỹ họ và quyền truy cập rõ hơn.',
                en: 'Lineage, memorials, funds, and access stay clear.',
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
                    vi: 'Cây nhà, hồ sơ và nhánh chi ở cùng một chỗ.',
                    en: 'Members, branches, and relationships together.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.notifications_active_rounded,
                  title: context.l10n.pick(
                    vi: 'Lịch và thông báo',
                    en: 'Notifications and reminders',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ngày giỗ, họp họ và mốc quan trọng.',
                    en: 'Memorials, gatherings, and key dates.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.payments_rounded,
                  title: context.l10n.pick(
                    vi: 'Quỹ và quyền dùng',
                    en: 'Plans and billing',
                  ),
                  description: context.l10n.pick(
                    vi: 'Trạng thái gói, thanh toán và quyền dùng.',
                    en: 'Plans, payments, and access status.',
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
                    vi: 'Duyệt yêu cầu và phân quyền theo từng chi.',
                    en: 'Review requests and assign branch access.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.account_balance_wallet_rounded,
                  title: context.l10n.pick(
                    vi: 'Người phụ trách quỹ',
                    en: 'Fund and scholarship operators',
                  ),
                  description: context.l10n.pick(
                    vi: 'Ghi nhận thu chi và xem lại lịch sử.',
                    en: 'Record funds and review history.',
                  ),
                ),
                _FeatureItem(
                  icon: Icons.person_search_rounded,
                  title: context.l10n.pick(
                    vi: 'Con cháu ở xa',
                    en: 'Members and descendants abroad',
                  ),
                  description: context.l10n.pick(
                    vi: 'Xem gia phả và theo dõi lịch quan trọng.',
                    en: 'View lineage and key dates from afar.',
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
        vi: 'Dữ liệu gia đình chỉ dùng cho việc vận hành BeFam.',
        en: 'Family data is used only to operate BeFam.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Tóm tắt cách BeFam thu thập, bảo vệ và phản hồi yêu cầu dữ liệu.',
        en: 'A concise summary of collection, protection, and data requests.',
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
              vi: 'BeFam có thể xử lý số điện thoại đăng nhập, hồ sơ thành viên, vai trò, sự kiện, quỹ, khuyến học và tín hiệu kỹ thuật cần cho bảo mật.',
              en: 'BeFam may process sign-in phone numbers, member profiles, roles, events, funds, scholarships, and technical security signals.',
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
              vi: 'Dữ liệu dùng để đăng nhập, hiển thị đúng quyền, vận hành gia phả, sự kiện, quỹ, khuyến học, thông báo và hỗ trợ.',
              en: 'Data supports sign-in, permissions, lineage, events, funds, scholarships, notifications, and support.',
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
              vi: 'BeFam chỉ chia sẻ dữ liệu với hạ tầng cần thiết như Firebase, Google Cloud, kho ứng dụng, xác thực hoặc thanh toán. Quyền xem trong app theo vai trò.',
              en: 'BeFam shares data only with required infrastructure, app stores, verification, or payment providers. In-app access is role-based.',
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
              vi: 'Cần cập nhật, phản hồi hoặc yêu cầu dữ liệu? Gửi email hỗ trợ chính thức để được hướng dẫn.',
              en: 'For updates, feedback, or data requests, contact official support by email.',
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
        vi: 'Dùng BeFam đúng người, đúng quyền, đúng bối cảnh.',
        en: 'Use BeFam with the right person, role, and context.',
      ),
      subtitle: context.l10n.pick(
        vi: 'Người dùng cần cung cấp thông tin phù hợp và không ảnh hưởng xấu đến thành viên khác.',
        en: 'Users should provide appropriate information and avoid harming other members.',
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
              vi: 'BeFam hỗ trợ gia phả, thành viên, sự kiện, quỹ và khuyến học. Không dùng để mạo danh, truy cập sai quyền hoặc đăng nội dung trái pháp luật.',
              en: 'BeFam supports lineage, members, events, funds, and scholarships. Do not impersonate, over-access, or submit unlawful content.',
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
              vi: 'Mỗi tài khoản phải gắn với đúng người, hồ sơ và vai trò. Người dùng chịu trách nhiệm với thao tác của mình.',
              en: 'Each account must match the right person, profile, and role. Users are responsible for their actions.',
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
              vi: 'Không mạo danh, vượt quyền, đăng nội dung sai lệch hoặc gây hại cho thành viên và hoạt động chung.',
              en: 'Do not impersonate, exceed permissions, mislead, or harm members and shared operations.',
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
              vi: 'Một số tính năng gắn với gói hoặc thanh toán. Quyền dùng chỉ mở khi hệ thống hoặc kho ứng dụng xác nhận thành công.',
              en: 'Some features depend on plans or payments. Access opens only after system or store confirmation.',
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
        vi: 'Bạn có thể yêu cầu xóa tài khoản BeFam qua email.',
        en: 'You can request BeFam account deletion by email.',
      ),
      subtitle: context.l10n.pick(
        vi: 'BeFam sẽ xác minh thông tin cần thiết trước khi xử lý.',
        en: 'BeFam verifies the required details before processing.',
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
              vi: 'Gửi email hỗ trợ với số điện thoại đăng nhập, họ tên và thông tin cần để xác minh chủ tài khoản.',
              en: 'Email support with your sign-in phone number, full name, and details needed for ownership verification.',
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
              vi: 'BeFam có thể xác minh số điện thoại, họ tên và chi tiết liên quan để bảo đảm yêu cầu hợp lệ.',
              en: 'BeFam may verify phone number, name, and related details to confirm the request is valid.',
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
              vi: 'Khi yêu cầu hợp lệ, BeFam sẽ xóa hoặc vô hiệu hóa tài khoản theo chính sách, trừ dữ liệu cần giữ để đối soát hoặc tuân thủ pháp lý.',
              en: 'After validation, BeFam deletes or deactivates the account under policy, except data retained for reconciliation or legal reasons.',
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
              vi: 'BeFam phản hồi tiến độ qua email sau khi tiếp nhận và xác minh thông tin.',
              en: 'BeFam responds by email after receiving and verifying the request.',
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
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sectionColumns = constraints.maxWidth >= 900 ? 2 : 1;
            const spacing = _kCardGap;
            final sectionWidth =
                ((constraints.maxWidth - (spacing * (sectionColumns - 1)))
                            .clamp(0.0, double.infinity) /
                        sectionColumns)
                    .toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCard(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                  badge: eyebrow,
                ),
                const SizedBox(height: _kCardGap),
                _LegalFactGrid(facts: facts),
                const SizedBox(height: _kCardGap),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final section in sections)
                      SizedBox(
                        width: sectionWidth,
                        child: _LegalSectionCard(section: section),
                      ),
                  ],
                ),
              ],
            );
          },
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
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          const SizedBox(height: 10),
          ...[
            for (final paragraph in section.paragraphs) ...[
              Text(
                paragraph,
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.48,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
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
        const spacing = 10.0;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kMarketingRadius),
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
          const SizedBox(height: 6),
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
                          _TopNavigation(
                            currentPath: widget.currentPath,
                            isScrolled: _isScrolled,
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
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _WebFooter(pagePath: widget.currentPath),
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
                    const SizedBox(height: 12),
                    SizedBox(height: 236, child: const _LandingHeroArtwork()),
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
                        height: 278,
                        child: const _LandingHeroArtwork(),
                      ),
                    ),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heroRow,
              const SizedBox(height: 12),
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
    final isPhone = MediaQuery.sizeOf(context).width < 560;

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
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            title,
            style: textTheme.headlineLarge?.copyWith(
              fontSize: isPhone ? 40 : 52,
              fontWeight: FontWeight.w900,
              color: _kLandingInk,
              height: 1.04,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            subtitle,
            style: textTheme.titleMedium?.copyWith(
              color: _kLandingMuted,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        const spacing = 10.0;
        final itemHeight = width >= 1120
            ? 130.0
            : width >= 720
            ? 136.0
            : 118.0;
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
      padding: const EdgeInsets.all(14),
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
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _kLandingInk,
                    height: 1.08,
                    letterSpacing: 0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _kLandingMuted,
                    height: 1.32,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
      width: 76,
      height: 76,
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
          size: 36,
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
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;
          final isPhone = constraints.maxWidth < 560;

          final leftPane = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StaticHeroKicker(label: badge),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPhone ? constraints.maxWidth : 650,
                ),
                child: Text(
                  title,
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: isPhone
                        ? 34
                        : isCompact
                        ? 40
                        : 52,
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
                  maxLines: isPhone ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 18),
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
                ? 284
                : isCompact
                ? 260
                : 292,
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
            horizontal: isCompact ? 12 : 14,
            vertical: isCompact ? 4 : 6,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            ),
            child: Icon(item.icon, color: colorScheme.primary, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.22,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            ),
            child: Icon(item.icon, color: colorScheme.primary, size: 19),
          ),
          const SizedBox(width: 10),
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
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 8),
          Text(
            step.title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.24,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.34,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
        borderRadius: BorderRadius.circular(_kMarketingRadius),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_kCardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24),
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
                    height: 1.12,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
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
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final intro = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
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
                        height: 1.12,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.pick(
                        vi: 'Cần hỗ trợ hoặc góp ý? Chọn kênh phù hợp bên dưới.',
                        en: 'Need support or feedback? Use the channel that fits.',
                      ),
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ContactActionCard(
                icon: Icons.mail_outline_rounded,
                title: l10n.pick(vi: 'Email', en: 'Email'),
                href:
                    'mailto:$_kSupportEmail?subject=BeFam%20Support%20Request',
              ),
              _ContactActionCard(
                icon: Icons.description_outlined,
                title: l10n.pick(vi: 'Góp ý', en: 'Feedback'),
                href: _kFeedbackFormUrl,
              ),
              _ContactActionCard(
                icon: Icons.facebook_rounded,
                title: l10n.pick(vi: 'Fanpage', en: 'Fanpage'),
                href: _kFanpageUrl,
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 10), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: intro),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ContactActionCard extends StatelessWidget {
  const _ContactActionCard({
    required this.icon,
    required this.title,
    required this.href,
  });

  final IconData icon;
  final String title;
  final String href;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => launchUrl(Uri.parse(href), mode: LaunchMode.platformDefault),
      borderRadius: BorderRadius.circular(_kMarketingRadius),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kMarketingRadius),
          color: Colors.white.withValues(alpha: 0.76),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final brand = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandMark(),
            const SizedBox(width: 10),
            Text(
              'BeFam',
              style: theme.textTheme.titleLarge?.copyWith(
                color: _kLandingInk,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        );

        final links = Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _FooterLinkButton(
              label: l10n.pick(vi: 'Riêng tư', en: 'Privacy'),
              onPressed: () => context.go('/privacy'),
            ),
            _FooterLinkButton(
              label: l10n.pick(vi: 'Điều khoản', en: 'Terms'),
              onPressed: () => context.go('/terms'),
            ),
            _FooterLinkButton(
              label: l10n.pick(vi: 'Xóa tài khoản', en: 'Delete account'),
              onPressed: () => context.go('/account-deletion'),
            ),
            _FooterLinkButton(
              label: l10n.pick(vi: 'Hỗ trợ', en: 'Support'),
              onPressed: () => launchUrl(
                Uri.parse(
                  'mailto:$_kSupportEmail?subject=BeFam%20Support%20Request',
                ),
                mode: LaunchMode.platformDefault,
              ),
            ),
          ],
        );

        final copyright = Text(
          '© $year BeFam',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _kLandingMuted,
            fontWeight: FontWeight.w700,
          ),
        );

        final openButton = FilledButton.icon(
          onPressed: () => _trackAndOpenApp(
            context,
            pagePath: pagePath,
            placement: 'footer_open_app',
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: Text(l10n.pick(vi: 'Mở', en: 'Open')),
          style: FilledButton.styleFrom(
            backgroundColor: _kLandingInk,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kMarketingRadius),
            color: Colors.white.withValues(alpha: 0.9),
            border: Border.all(color: _kLandingLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        brand,
                        const Spacer(),
                        copyright,
                        const SizedBox(width: 8),
                        openButton,
                      ],
                    ),
                    const SizedBox(height: 6),
                    links,
                  ],
                )
              : Row(
                  children: [
                    brand,
                    const SizedBox(width: 14),
                    copyright,
                    const Spacer(),
                    links,
                    const SizedBox(width: 10),
                    openButton,
                  ],
                ),
        );
      },
    );
  }
}

class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _kLandingMuted,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
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
