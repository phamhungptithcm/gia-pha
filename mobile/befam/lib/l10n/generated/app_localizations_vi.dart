// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'BeFam';

  @override
  String get authSignInNeedsAttention => 'Đăng nhập cần được kiểm tra';

  @override
  String get authLoadingTitle => 'Đang chuẩn bị phiên BeFam của bạn';

  @override
  String get authLoadingReadyDescription =>
      'Firebase đã sẵn sàng. BeFam đang khôi phục phiên đăng nhập gần nhất.';

  @override
  String get authLoadingPendingDescription =>
      'BeFam vẫn đang kiểm tra trạng thái Firebase trên thiết bị này.';

  @override
  String get authFirebaseReadyChip => 'Firebase sẵn sàng';

  @override
  String get authBootstrapPendingChip => 'Khởi tạo đang chờ';

  @override
  String get authLiveFirebaseChip => 'Xác thực Firebase thật';

  @override
  String get authHeroTitle => 'Xác thực là cột mốc tiếp theo của BeFam.';

  @override
  String get authHeroLiveDescription =>
      'Bản dựng này dùng luồng xác thực Firebase thật cho xác minh số điện thoại và khôi phục phiên.';

  @override
  String get authMethodPhoneTitle => 'Tiếp tục bằng số điện thoại';

  @override
  String get authMethodPhoneDescription =>
      'Dùng số điện thoại của bạn để nhận OTP và khôi phục danh tính BeFam.';

  @override
  String get authMethodPhoneButton => 'Dùng số điện thoại';

  @override
  String get authMethodChildTitle => 'Tiếp tục bằng mã trẻ em';

  @override
  String get authMethodChildDescription =>
      'Bắt đầu từ mã trẻ em, xác định số điện thoại phụ huynh liên kết và xác minh quyền truy cập bằng OTP.';

  @override
  String get authMethodChildButton => 'Dùng mã trẻ em';

  @override
  String get authBootstrapNoteTitle => 'Ghi chú khởi tạo hiện tại';

  @override
  String get authBootstrapNoteReadyLive =>
      'Firebase đã sẵn sàng và ứng dụng sẽ thử xác thực số điện thoại thật.';

  @override
  String get authPhoneHelperLive =>
      'Dùng số Việt Nam nội địa hoặc định dạng quốc tế đầy đủ. BeFam chỉ dùng số này để xác thực an toàn.';

  @override
  String get authPhoneTitle => 'Xác minh số điện thoại';

  @override
  String get authPhoneDescription =>
      'Nhập số điện thoại theo định dạng Việt Nam hoặc E.164 đầy đủ. BeFam sẽ gửi OTP đến số này.';

  @override
  String get authPhoneLabel => 'Số điện thoại';

  @override
  String get authPhoneHint => '0901234567 hoặc +84901234567';

  @override
  String get authPhoneDemoButton => 'Dùng số demo 0901234567';

  @override
  String get authSendOtp => 'Gửi OTP';

  @override
  String get authSendingOtp => 'Đang gửi OTP...';

  @override
  String get authChildTitle => 'Truy cập bằng mã trẻ em';

  @override
  String get authChildDescription =>
      'Nhập mã trẻ em của gia đình. BeFam sẽ xác định số điện thoại phụ huynh liên kết và gửi OTP xác minh.';

  @override
  String get authChildLabel => 'Mã trẻ em';

  @override
  String get authChildHint => 'BEFAM-CHILD-001';

  @override
  String get authChildHelper =>
      'Dùng mã truy cập trẻ em do quản trị viên gia đình cung cấp.';

  @override
  String get authChildQuickTesting => 'Mã dùng nhanh để kiểm thử cục bộ';

  @override
  String get authContinue => 'Tiếp tục';

  @override
  String get authResolvingParentPhone => 'Đang xác định số phụ huynh...';

  @override
  String get authOtpMissingTitle => 'Xác minh OTP';

  @override
  String get authOtpMissingDescription =>
      'Hãy yêu cầu mã mới trước khi thử xác minh quyền truy cập.';

  @override
  String get authOtpTitle => 'Xác minh OTP';

  @override
  String authOtpDescription(Object maskedDestination) {
    return 'Nhập mã gồm 6 chữ số đã gửi đến $maskedDestination.';
  }

  @override
  String authOtpChildIdentifier(Object childIdentifier) {
    return 'Mã trẻ em: $childIdentifier';
  }

  @override
  String get authContinueNow => 'Tiếp tục ngay';

  @override
  String get authVerifyingOtp => 'Đang xác minh OTP...';

  @override
  String authResendIn(int seconds) {
    return 'Gửi lại sau $seconds giây';
  }

  @override
  String get authResendOtp => 'Gửi lại OTP';

  @override
  String get authOtpHelpText =>
      'Nhập hoặc dán mã. BeFam sẽ tự tiếp tục ngay sau chữ số thứ sáu.';

  @override
  String get authQuickBenefitsTitle => 'Chọn cách vào BeFam dễ nhất';

  @override
  String get authQuickBenefitsDescription =>
      'BeFam giữ luồng đăng nhập ngắn gọn, hướng dẫn từng bước và tự tiếp tục khi OTP hoàn tất.';

  @override
  String get authQuickBenefitAutoContinue => 'OTP 6 số tự tiếp tục';

  @override
  String get authQuickBenefitMultipleAccess =>
      'Hỗ trợ số điện thoại và mã trẻ em';

  @override
  String get authQuickBenefitLive => 'Xác minh Firebase thật';

  @override
  String get authBack => 'Quay lại';

  @override
  String get authEntryMethodPhoneSummary => 'Đăng nhập bằng điện thoại';

  @override
  String get authEntryMethodChildSummary => 'Truy cập bằng mã trẻ em';

  @override
  String get authEntryMethodPhoneInline => 'số điện thoại';

  @override
  String get authEntryMethodChildInline => 'mã trẻ em';

  @override
  String get shellHomeLabel => 'Nhà';

  @override
  String get shellHomeTitle => 'Trang tổng quan';

  @override
  String get shellTreeLabel => 'Gia phả';

  @override
  String get shellTreeTitle => 'Cây gia phả';

  @override
  String get shellEventsLabel => 'Sự kiện';

  @override
  String get shellEventsTitle => 'Sự kiện';

  @override
  String get shellProfileLabel => 'Hồ sơ';

  @override
  String get shellProfileTitle => 'Hồ sơ';

  @override
  String get shellTreeWorkspaceTitle => 'Không gian gia phả';

  @override
  String get shellTreeWorkspaceDescription =>
      'Khung ứng dụng đã sẵn sàng cho trải nghiệm cây gia phả theo nhánh và công việc dựng cây lớn.';

  @override
  String get genealogyWorkspaceTitle => 'Không gian cây gia phả';

  @override
  String get genealogyWorkspaceDescription =>
      'Xem cây gia phả theo phạm vi cả họ hoặc chi hiện tại.';

  @override
  String get genealogyScopeClan => 'Phạm vi cả họ';

  @override
  String get genealogyScopeBranch => 'Chi hiện tại';

  @override
  String get genealogyRefreshAction => 'Tải lại dữ liệu cây';

  @override
  String get genealogyLoadFailed => 'Không thể tải không gian gia phả lúc này.';

  @override
  String get genealogyFromCache => 'Đang dùng dữ liệu cache';

  @override
  String get genealogyLiveData => 'Ảnh chụp mới nhất';

  @override
  String get genealogySummaryMembers => 'Thành viên';

  @override
  String get genealogySummaryRelationships => 'Quan hệ';

  @override
  String get genealogySummaryRoots => 'Điểm vào gốc';

  @override
  String get genealogySummaryScope => 'Phạm vi';

  @override
  String get genealogyFocusMemberTitle => 'Thành viên trọng tâm';

  @override
  String get genealogyAncestryPathTitle => 'Chuỗi tổ tiên';

  @override
  String get genealogyRootEntriesTitle => 'Điểm vào gốc của cây';

  @override
  String get genealogyNoRootEntries => 'Chưa có điểm vào gốc cho phạm vi này.';

  @override
  String get genealogyMemberStructureTitle => 'Xem trước cấu trúc';

  @override
  String get genealogyEmptyStateTitle =>
      'Chưa có thành viên nào trong phạm vi này.';

  @override
  String get genealogyEmptyStateDescription =>
      'Hãy thêm thành viên đầu tiên hoặc đổi phạm vi để bắt đầu.';

  @override
  String get genealogyGenerationLabel => 'Đời';

  @override
  String get genealogyParentCountLabel => 'Cha mẹ';

  @override
  String get genealogyChildCountLabel => 'Con';

  @override
  String get genealogySpouseCountLabel => 'Phối ngẫu';

  @override
  String get genealogySiblingCountLabel => 'Anh chị em';

  @override
  String get genealogyDescendantCountLabel => 'Hậu duệ';

  @override
  String get genealogyMemberStatusLabel => 'Tình trạng';

  @override
  String get genealogyMemberAliveStatus => 'Còn sống';

  @override
  String get genealogyMemberDeceasedStatus => 'Đã mất';

  @override
  String get genealogyViewMemberInfoAction => 'Xem thông tin thành viên';

  @override
  String genealogyMetricNodes(int count) {
    return 'Nút: $count';
  }

  @override
  String genealogyMetricEdges(int count) {
    return 'Liên kết: $count';
  }

  @override
  String genealogyMetricLayout(int millis) {
    return 'Bố cục: ${millis}ms';
  }

  @override
  String genealogyMetricAverage(int millis) {
    return 'TB: ${millis}ms';
  }

  @override
  String genealogyMetricPeak(int millis) {
    return 'Đỉnh: ${millis}ms';
  }

  @override
  String get genealogyRootReasonCurrentMember => 'Thành viên hiện tại';

  @override
  String get genealogyRootReasonClanRoot => 'Gốc của họ';

  @override
  String get genealogyRootReasonScopeRoot => 'Gốc của phạm vi';

  @override
  String get genealogyRootReasonBranchLeader => 'Trưởng chi';

  @override
  String get genealogyRootReasonBranchViceLeader => 'Phó chi';

  @override
  String get shellEventsWorkspaceTitle => 'Không gian sự kiện';

  @override
  String get shellEventsWorkspaceDescription =>
      'Lịch họ tộc, ngày giỗ và lời nhắc sẽ được triển khai tại đây tiếp theo.';

  @override
  String get shellProfileWorkspaceTitle => 'Không gian hồ sơ';

  @override
  String get shellProfileWorkspaceDescription =>
      'Thông tin thành viên, cài đặt và bối cảnh gia đình sẽ phát triển từ phần giữ chỗ này.';

  @override
  String get profileRefreshAction => 'Tải lại hồ sơ';

  @override
  String get profileOpenSettingsAction => 'Mở cài đặt';

  @override
  String get profileNoContextTitle => 'Thiếu ngữ cảnh thành viên';

  @override
  String get profileNoContextDescription =>
      'Hãy liên kết tài khoản với hồ sơ thành viên trước khi quản lý cài đặt cá nhân.';

  @override
  String get profileUpdateSuccess => 'Đã cập nhật hồ sơ thành công.';

  @override
  String get profileUpdateErrorTitle => 'Không thể cập nhật hồ sơ';

  @override
  String get profileDetailsSectionTitle => 'Chi tiết hồ sơ';

  @override
  String get profileAccountSectionTitle => 'Tài khoản';

  @override
  String get profileLogoutDialogTitle => 'Đăng xuất?';

  @override
  String get profileLogoutDialogDescription =>
      'Bạn có thể đăng nhập lại bất cứ lúc nào bằng tài khoản đã liên kết.';

  @override
  String get profileSettingsLogoutDescription =>
      'Xác nhận này giúp tránh đăng xuất nhầm khi bạn đang điều chỉnh cài đặt.';

  @override
  String get profileCancelAction => 'Hủy';

  @override
  String get profileSettingsTitle => 'Cài đặt';

  @override
  String get profileSettingsOverviewTitle => 'Tổng quan cài đặt';

  @override
  String get profileSettingsOverviewDescription =>
      'Quản lý ngôn ngữ hiển thị, tùy chọn thông báo và phiên làm việc của bạn trong BeFam.';

  @override
  String get profileLanguageSectionTitle => 'Ngôn ngữ';

  @override
  String get profileLanguageSectionDescription =>
      'Chọn ngôn ngữ hiển thị cho toàn bộ ứng dụng.';

  @override
  String get profileLanguageVietnamese => 'Tiếng Việt';

  @override
  String get profileLanguageVietnameseSubtitle =>
      'Mặc định cho người dùng tại Việt Nam';

  @override
  String get profileLanguageEnglish => 'Tiếng Anh';

  @override
  String get profileLanguageEnglishSubtitle =>
      'Hiển thị tiếng Anh trên toàn bộ ứng dụng';

  @override
  String get profileSecuritySectionTitle => 'Riêng tư và bảo mật';

  @override
  String get profileSecurityPlaceholderTitle =>
      'Cài đặt bảo mật đang được hoàn thiện';

  @override
  String get profileSecurityPlaceholderDescription =>
      'Các tùy chọn đăng nhập nâng cao và kiểm soát phiên sẽ được bổ sung ở đợt phát hành tiếp theo.';

  @override
  String get profileSessionSectionTitle => 'Phiên đăng nhập';

  @override
  String get profileNotificationFundAlerts => 'Thông báo giao dịch quỹ';

  @override
  String get profileEditSheetTitle => 'Chỉnh sửa hồ sơ';

  @override
  String get profileEditSheetDescription =>
      'Cập nhật thông tin thành viên và liên kết liên hệ để hồ sơ luôn đầy đủ, dễ dùng.';

  @override
  String get profileSaveErrorTitle => 'Không thể lưu hồ sơ';

  @override
  String get profileFacebookUrlLabel => 'Liên kết Facebook';

  @override
  String get profileZaloUrlLabel => 'Liên kết Zalo';

  @override
  String get profileLinkedinUrlLabel => 'Liên kết LinkedIn';

  @override
  String get profileSavingAction => 'Đang lưu...';

  @override
  String get shellMoreActions => 'Thao tác khác';

  @override
  String get shellLogout => 'Đăng xuất';

  @override
  String shellWelcomeBack(Object displayName) {
    return 'Chào mừng trở lại, $displayName.';
  }

  @override
  String get shellBootstrapNeedsCloud =>
      'Khung khởi tạo đã sẵn sàng, nhưng Firebase vẫn cần hoàn tất cấu hình đám mây.';

  @override
  String shellSignedInMethod(Object method) {
    return 'Bạn đã đăng nhập bằng $method, và khung BeFam đã sẵn sàng cho các nhóm tính năng tiếp theo.';
  }

  @override
  String get shellCloudSetupNeeded =>
      'Nền tảng di động đã sẵn sàng cục bộ. Cloud Firestore vẫn cần được bật để hoàn tất triển khai backend.';

  @override
  String get shellTagFreezedJson => 'Freezed + JSON';

  @override
  String get shellTagFirebaseCore => 'Firebase cốt lõi';

  @override
  String get shellTagAuthSessionLive => 'Phiên xác thực đang hoạt động';

  @override
  String get shellTagCrashlyticsEnabled => 'Crashlytics đã bật';

  @override
  String get shellTagLocalLoggerActive => 'Logger cục bộ đang hoạt động';

  @override
  String get shellTagShellPlaceholders => 'Các phần giữ chỗ';

  @override
  String get shellPriorityWorkspaces => 'Không gian ưu tiên';

  @override
  String get shellPriorityWorkspacesDescription =>
      'Các phần giữ chỗ này khớp với những bề mặt sản phẩm đầu tiên trong kế hoạch triển khai.';

  @override
  String get shellSignedInContext => 'Ngữ cảnh đã đăng nhập';

  @override
  String get shellFieldDisplayName => 'Tên hiển thị';

  @override
  String get shellFieldLoginMethod => 'Phương thức đăng nhập';

  @override
  String get shellFieldPhone => 'Số điện thoại';

  @override
  String get shellFieldChildId => 'Mã trẻ em';

  @override
  String get shellFieldMemberId => 'Mã thành viên';

  @override
  String get shellFieldClanId => 'Mã họ tộc';

  @override
  String get shellFieldBranchId => 'Mã chi';

  @override
  String get shellFieldPrimaryRole => 'Vai trò chính';

  @override
  String get shellFieldAccessMode => 'Chế độ truy cập';

  @override
  String get shellFieldSessionType => 'Loại phiên';

  @override
  String get shellAccessModeUnlinked => 'Đăng nhập chưa liên kết hồ sơ';

  @override
  String get shellAccessModeClaimed => 'Phiên thành viên đã liên kết';

  @override
  String get shellAccessModeChild => 'Phiên truy cập trẻ em';

  @override
  String get shellSessionTypeFirebase => 'Phiên xác thực Firebase';

  @override
  String get shellFieldFirebaseProject => 'Dự án Firebase';

  @override
  String get shellFieldStorageBucket => 'Kho lưu trữ';

  @override
  String get shellFieldCrashHandling => 'Xử lý lỗi';

  @override
  String get shellCrashHandlingRelease =>
      'Crashlytics ghi nhận lỗi trên bản phát hành.';

  @override
  String get shellCrashHandlingLocal =>
      'Logger hoạt động cục bộ và Crashlytics tắt ngoài bản phát hành.';

  @override
  String get shellFieldCoreServices => 'Dịch vụ cốt lõi';

  @override
  String get shellCoreServicesWaiting =>
      'Liên kết Firebase cốt lõi đang chờ khởi tạo.';

  @override
  String get shellFieldStartupNote => 'Ghi chú khởi động';

  @override
  String get shellMemberAccessClaimedTitle =>
      'Hồ sơ thành viên đã được liên kết';

  @override
  String get shellMemberAccessClaimedDescription =>
      'Phiên này đã gắn với một hồ sơ thành viên BeFam, và auth UID cũng đã được liên kết để truy cập trực tiếp hồ sơ đó.';

  @override
  String get shellMemberAccessChildTitle =>
      'Truy cập trẻ em đã được xác minh qua OTP phụ huynh';

  @override
  String get shellMemberAccessChildDescription =>
      'Phiên này dùng OTP phụ huynh để mở ngữ cảnh thành viên của trẻ. Hồ sơ trẻ có thể được truy cập mà không liên kết vĩnh viễn auth UID.';

  @override
  String get shellMemberAccessUnlinkedTitle =>
      'Đã đăng nhập nhưng chưa liên kết được hồ sơ thành viên';

  @override
  String get shellMemberAccessUnlinkedDescription =>
      'Phiên số điện thoại đã được xác minh, nhưng BeFam chưa ghép được số này với hồ sơ thành viên có thể nhận. Quyền truy cập theo họ tộc vẫn bị giới hạn cho tới khi hồ sơ được liên kết.';

  @override
  String get shellShortcutStatusLive => 'Đang dùng';

  @override
  String get shellShortcutStatusBootstrap => 'Khởi tạo';

  @override
  String get shellShortcutStatusPlanned => 'Đã lên kế hoạch';

  @override
  String get shellReadinessReady => 'Firebase sẵn sàng';

  @override
  String get shellReadinessPending => 'Cấu hình đám mây đang chờ';

  @override
  String get shortcutTitleTree => 'Cây gia phả';

  @override
  String get shortcutDescriptionTree =>
      'Bắt đầu trải nghiệm gia phả với điều hướng theo nhánh.';

  @override
  String get shortcutTitleClan => 'Họ tộc';

  @override
  String get shortcutDescriptionClan =>
      'Thiết lập hồ sơ họ tộc, ban điều hành chi và không gian quản trị đầu tiên.';

  @override
  String get shortcutTitleMembers => 'Thành viên';

  @override
  String get shortcutDescriptionMembers =>
      'Xem hồ sơ thành viên, nhận hồ sơ và chuẩn bị những luồng dữ liệu đầu tiên.';

  @override
  String get shortcutTitleEvents => 'Sự kiện';

  @override
  String get shortcutDescriptionEvents =>
      'Lên kế hoạch sự kiện họ tộc, ngày giỗ và lời nhắc trong lịch dùng chung.';

  @override
  String get shortcutTitleFunds => 'Quỹ';

  @override
  String get shortcutDescriptionFunds =>
      'Theo dõi quỹ đóng góp, lịch sử giao dịch và số dư minh bạch.';

  @override
  String get shortcutTitleScholarship => 'Khuyến học';

  @override
  String get shortcutDescriptionScholarship =>
      'Ghi nhận thành tích học tập và sau này liên kết phần thưởng với các nhánh gia đình.';

  @override
  String get shortcutTitleProfile => 'Hồ sơ';

  @override
  String get shortcutDescriptionProfile =>
      'Dành sẵn không gian cá nhân cho cài đặt thành viên, người giám hộ và ngữ cảnh.';

  @override
  String get roleSuperAdmin => 'Siêu quản trị';

  @override
  String get roleClanAdmin => 'Quản trị họ tộc';

  @override
  String get roleBranchAdmin => 'Quản trị chi';

  @override
  String get roleMember => 'Thành viên';

  @override
  String get roleUnknown => 'Chưa xác định';

  @override
  String get clanDetailTitle => 'Quản lý họ tộc';

  @override
  String get clanRefreshAction => 'Tải lại';

  @override
  String get clanSaveSuccess => 'Đã lưu hồ sơ họ tộc.';

  @override
  String get clanBranchSaveSuccess => 'Đã lưu thông tin chi.';

  @override
  String get clanNoContextTitle => 'Tài khoản này chưa có ngữ cảnh họ tộc';

  @override
  String get clanNoContextDescription =>
      'Hãy liên kết tài khoản với một hồ sơ thành viên hoặc hoàn tất quy trình nhận hồ sơ trước khi quản lý họ tộc.';

  @override
  String get clanCreateFirstTitle => 'Khởi tạo hồ sơ họ tộc';

  @override
  String get clanCreateFirstDescription =>
      'Tạo hồ sơ họ tộc để bắt đầu quản lý chi và thành viên.';

  @override
  String get clanPermissionEditor => 'Có quyền quản trị';

  @override
  String get clanPermissionViewer => 'Chỉ xem';

  @override
  String get clanSandboxSourceChip => 'Dữ liệu sandbox cục bộ';

  @override
  String get clanLiveSourceChip => 'Dữ liệu Firestore trực tiếp';

  @override
  String get clanLoadErrorTitle => 'Không thể tải không gian họ tộc';

  @override
  String get clanPermissionDeniedDescription =>
      'Phiên hiện tại không có quyền lưu thay đổi trong cài đặt họ tộc hoặc danh sách chi.';

  @override
  String get clanLoadErrorDescription =>
      'Có lỗi xảy ra khi tải dữ liệu họ tộc. Hãy thử tải lại hoặc kiểm tra cấu hình Firebase.';

  @override
  String get clanReadOnlyTitle => 'Bạn đang ở chế độ chỉ xem';

  @override
  String get clanReadOnlyDescription =>
      'Phiên này vẫn xem được thông tin họ tộc, nhưng chỉ quản trị họ tộc hoặc quản trị chi đã liên kết mới có thể thay đổi cài đặt.';

  @override
  String get clanStatBranches => 'Số chi';

  @override
  String get clanStatMembers => 'Số thành viên';

  @override
  String get clanStatYourRole => 'Vai trò của bạn';

  @override
  String get clanProfileSectionTitle => 'Hồ sơ họ tộc';

  @override
  String get clanCreateAction => 'Tạo hồ sơ';

  @override
  String get clanEditAction => 'Sửa hồ sơ';

  @override
  String get clanProfileEmptyTitle => 'Chưa có hồ sơ họ tộc';

  @override
  String get clanProfileEmptyDescription =>
      'Bắt đầu với tên họ tộc, người khai sáng và mô tả ngắn.';

  @override
  String get clanFieldName => 'Tên họ tộc';

  @override
  String get clanFieldSlug => 'Slug';

  @override
  String get clanFieldCountry => 'Quốc gia';

  @override
  String get clanFieldFounder => 'Người khai sáng';

  @override
  String get clanFieldDescription => 'Mô tả';

  @override
  String get clanFieldLogoUrl => 'Đường dẫn logo';

  @override
  String get clanFieldUnset => 'Chưa thiết lập';

  @override
  String get clanBranchSectionTitle => 'Các chi';

  @override
  String get clanAddBranchAction => 'Thêm chi';

  @override
  String get clanOpenBranchListAction => 'Mở danh sách chi';

  @override
  String get clanBranchEmptyTitle => 'Chưa có chi nào';

  @override
  String get clanBranchEmptyDescription =>
      'Tạo chi đầu tiên để phân quyền và quản lý thành viên.';

  @override
  String get clanBranchCodeLabel => 'Mã chi';

  @override
  String get clanLeaderLabel => 'Trưởng chi';

  @override
  String get clanViceLeaderLabel => 'Phó chi';

  @override
  String get clanGenerationHintLabel => 'Gợi ý đời';

  @override
  String get clanEditBranchAction => 'Sửa chi';

  @override
  String get clanEditorTitle => 'Biên tập hồ sơ họ tộc';

  @override
  String get clanEditorDescription =>
      'Thông tin này xuất hiện như lớp định danh chung cho toàn bộ ứng dụng và giúp đội vận hành thống nhất tên gọi, quốc gia, người khai sáng và mô tả nền.';

  @override
  String get clanFieldNameHint => 'Ví dụ: Họ Nguyễn Văn';

  @override
  String get clanFieldSlugHint => 'ví dụ: ho-nguyen-van';

  @override
  String get clanFieldSlugHelper =>
      'Nếu bỏ trống, BeFam sẽ tự tạo slug từ tên họ tộc.';

  @override
  String get clanValidationNameRequired => 'Hãy nhập tên họ tộc.';

  @override
  String get clanValidationCountryRequired => 'Hãy nhập mã quốc gia hợp lệ.';

  @override
  String get clanFieldFounderHint => 'Ví dụ: Nguyễn Văn Thủy Tổ';

  @override
  String get clanFieldDescriptionHint =>
      'Tóm tắt nguồn gốc, phạm vi, hoặc ghi chú quản trị quan trọng của họ tộc.';

  @override
  String get clanSaveAction => 'Lưu thay đổi';

  @override
  String get clanBranchEditorTitle => 'Biên tập chi';

  @override
  String get clanBranchEditorDescription =>
      'Cập nhật chi, người phụ trách và gợi ý đời.';

  @override
  String get clanBranchNameLabel => 'Tên chi';

  @override
  String get clanBranchNameHint => 'Ví dụ: Chi Trưởng';

  @override
  String get clanBranchCodeHint => 'Ví dụ: CT01';

  @override
  String get clanValidationBranchNameRequired => 'Hãy nhập tên chi.';

  @override
  String get clanValidationBranchCodeRequired => 'Hãy nhập mã chi.';

  @override
  String get clanValidationGenerationRequired =>
      'Hãy nhập gợi ý đời lớn hơn 0.';

  @override
  String get clanNoLeaderOption => 'Chưa gán trưởng chi';

  @override
  String get clanNoViceLeaderOption => 'Chưa gán phó chi';

  @override
  String get clanValidationViceDistinct =>
      'Trưởng chi và phó chi phải là hai người khác nhau.';

  @override
  String get clanBranchListTitle => 'Danh sách chi';

  @override
  String get memberWorkspaceTitle => 'Hồ sơ thành viên';

  @override
  String get memberRefreshAction => 'Tải lại';

  @override
  String get memberNoContextTitle =>
      'Tài khoản này chưa có ngữ cảnh thành viên';

  @override
  String get memberNoContextDescription =>
      'Liên kết tài khoản với hồ sơ thành viên để quản lý danh sách.';

  @override
  String get memberWorkspaceHeroTitle => 'Quản lý hồ sơ thành viên của họ tộc';

  @override
  String get memberWorkspaceHeroDescription =>
      'Quản lý hồ sơ thành viên theo chi và đời.';

  @override
  String get memberReadOnlyTitle => 'Bạn đang ở chế độ chỉ xem';

  @override
  String get memberReadOnlyDescription =>
      'Phiên này chỉ có quyền xem. Chỉ quản trị họ tộc hoặc quản trị chi mới thêm thành viên.';

  @override
  String get memberLoadErrorTitle => 'Không thể tải không gian thành viên';

  @override
  String get memberLoadErrorDescription =>
      'Không thể tải hồ sơ thành viên. Hãy thử lại.';

  @override
  String get memberStatCount => 'Tổng hồ sơ';

  @override
  String get memberStatVisible => 'Đang hiển thị';

  @override
  String get memberStatRole => 'Vai trò của bạn';

  @override
  String get memberOwnProfileTitle => 'Hồ sơ của bạn';

  @override
  String get memberEditOwnProfileAction => 'Sửa hồ sơ của tôi';

  @override
  String get memberFilterSectionTitle => 'Tìm kiếm và lọc';

  @override
  String get memberListSectionTitle => 'Danh sách thành viên';

  @override
  String get memberAddAction => 'Thêm thành viên';

  @override
  String get memberListEmptyTitle => 'Chưa có hồ sơ phù hợp';

  @override
  String get memberListEmptyDescription =>
      'Chưa có hồ sơ phù hợp. Hãy tạo mới hoặc đổi bộ lọc.';

  @override
  String get memberSaveSuccess => 'Đã lưu hồ sơ thành viên.';

  @override
  String get memberAvatarUploadSuccess => 'Đã tải avatar lên thành công.';

  @override
  String get memberDetailTitle => 'Chi tiết thành viên';

  @override
  String get memberUploadAvatarAction => 'Tải ảnh đại diện';

  @override
  String get memberEditAction => 'Chỉnh sửa';

  @override
  String get memberNotFoundTitle => 'Không tìm thấy thành viên';

  @override
  String get memberNotFoundDescription =>
      'Hồ sơ thành viên này không còn khả dụng trong ngữ cảnh hiện tại.';

  @override
  String get memberDetailNoNickname => 'Chưa có biệt danh';

  @override
  String get memberGenerationLabel => 'Đời';

  @override
  String get memberDetailSummaryTitle => 'Thông tin cơ bản';

  @override
  String get memberFullNameLabel => 'Họ và tên';

  @override
  String get memberNicknameLabel => 'Biệt danh';

  @override
  String get memberFieldUnset => 'Chưa thiết lập';

  @override
  String get memberPhoneLabel => 'Số điện thoại';

  @override
  String get memberEmailLabel => 'Email';

  @override
  String get memberGenderLabel => 'Giới tính';

  @override
  String get memberBirthDateLabel => 'Ngày sinh';

  @override
  String get memberDeathDateLabel => 'Ngày mất';

  @override
  String get memberJobTitleLabel => 'Nghề nghiệp';

  @override
  String get memberAddressLabel => 'Địa chỉ';

  @override
  String get memberBioLabel => 'Tiểu sử ngắn';

  @override
  String get memberSocialLinksTitle => 'Liên kết mạng xã hội';

  @override
  String get memberSocialLinksEmptyTitle => 'Chưa có liên kết mạng xã hội';

  @override
  String get memberSocialLinksEmptyDescription =>
      'Thêm Facebook, Zalo hoặc LinkedIn để hồ sơ dễ liên hệ hơn.';

  @override
  String get memberAvatarHint =>
      'Ảnh đại diện sẽ được lưu vào Firebase Storage và dùng cho các màn hình hồ sơ sau này.';

  @override
  String get memberAddSheetTitle => 'Thêm thành viên';

  @override
  String get memberEditSheetTitle => 'Chỉnh sửa thành viên';

  @override
  String get memberEditorDescription =>
      'Điền thông tin chính để tạo hồ sơ thành viên.';

  @override
  String get memberSaveErrorTitle => 'Không thể lưu hồ sơ thành viên';

  @override
  String get memberFullNameHint => 'Ví dụ: Nguyễn Văn Minh';

  @override
  String get memberValidationNameRequired => 'Hãy nhập họ và tên thành viên.';

  @override
  String get memberNicknameHint => 'Ví dụ: Minh';

  @override
  String get memberBranchLabel => 'Chi';

  @override
  String get memberValidationBranchRequired => 'Hãy chọn chi cho thành viên.';

  @override
  String get memberGenderUnspecified => 'Chưa xác định';

  @override
  String get memberGenderMale => 'Nam';

  @override
  String get memberGenderFemale => 'Nữ';

  @override
  String get memberGenderOther => 'Khác';

  @override
  String get memberValidationGenerationRequired => 'Hãy nhập đời lớn hơn 0.';

  @override
  String get memberValidationDateInvalid =>
      'Hãy nhập ngày theo định dạng YYYY-MM-DD hợp lệ.';

  @override
  String get memberPhoneHint => '0901234567 hoặc +84901234567';

  @override
  String get memberValidationPhoneInvalid => 'Hãy nhập số điện thoại hợp lệ.';

  @override
  String get memberJobTitleHint => 'Ví dụ: Kỹ sư, giáo viên, quản lý';

  @override
  String get memberAddressHint => 'Ví dụ: Đà Nẵng, Việt Nam';

  @override
  String get memberSaveAction => 'Lưu hồ sơ';

  @override
  String get memberSearchLabel => 'Tìm thành viên';

  @override
  String get memberSearchHint => 'Nhập tên, biệt danh hoặc số điện thoại';

  @override
  String get memberFilterBranchLabel => 'Lọc theo chi';

  @override
  String get memberFilterAllBranches => 'Tất cả chi';

  @override
  String get memberFilterGenerationLabel => 'Lọc theo đời';

  @override
  String get memberFilterAllGenerations => 'Tất cả đời';

  @override
  String get memberClearFiltersAction => 'Xóa bộ lọc';

  @override
  String get memberPhoneMissing => 'Chưa có số điện thoại';

  @override
  String get memberPermissionEditor => 'Có quyền chỉnh sửa';

  @override
  String get memberPermissionViewer => 'Chỉ xem';

  @override
  String get memberSandboxChip => 'Dữ liệu sandbox cục bộ';

  @override
  String get memberLiveChip => 'Dữ liệu Firestore trực tiếp';

  @override
  String get memberDuplicatePhoneError =>
      'Số điện thoại này đã thuộc về một hồ sơ thành viên khác.';

  @override
  String get memberPlanLimitExceededError =>
      'Gói hiện tại đã đạt giới hạn thành viên. Vui lòng nâng cấp gói để thêm thành viên mới.';

  @override
  String get memberPermissionDeniedError =>
      'Phiên hiện tại không có quyền thay đổi hồ sơ thành viên này.';

  @override
  String get memberAvatarUploadError =>
      'BeFam chưa thể tải ảnh đại diện lên lúc này.';

  @override
  String get relationshipInspectorTitle => 'Quan hệ gia đình';

  @override
  String get relationshipInspectorDescription =>
      'Kiểm tra các liên kết cha mẹ, con cái và hôn phối của hồ sơ này. Những thay đổi nhạy cảm chỉ dành cho quản trị đã liên kết.';

  @override
  String get relationshipRefreshAction => 'Tải lại quan hệ';

  @override
  String get relationshipAddParentAction => 'Thêm cha hoặc mẹ';

  @override
  String get relationshipAddChildAction => 'Thêm con';

  @override
  String get relationshipAddSpouseAction => 'Thêm hôn phối';

  @override
  String get relationshipParentsTitle => 'Cha mẹ';

  @override
  String get relationshipChildrenTitle => 'Con cái';

  @override
  String get relationshipSpousesTitle => 'Hôn phối';

  @override
  String get relationshipNoParents => 'Chưa có liên kết cha mẹ.';

  @override
  String get relationshipNoChildren => 'Chưa có liên kết con cái.';

  @override
  String get relationshipNoSpouses => 'Chưa có liên kết hôn phối.';

  @override
  String get relationshipCanonicalEdgeTitle => 'Cạnh quan hệ chuẩn';

  @override
  String get relationshipNoEdges => 'Chưa có cạnh quan hệ nào cho hồ sơ này.';

  @override
  String get relationshipEdgeParentChild => 'Cha mẹ -> con';

  @override
  String get relationshipEdgeSpouse => 'Hôn phối';

  @override
  String get relationshipSourceLabel => 'Nguồn';

  @override
  String get relationshipErrorTitle => 'Không thể cập nhật quan hệ';

  @override
  String get relationshipErrorDuplicateSpouse =>
      'Hai thành viên này đã có liên kết hôn phối.';

  @override
  String get relationshipErrorDuplicateParentChild =>
      'Liên kết cha mẹ - con cái này đã tồn tại.';

  @override
  String get relationshipErrorCycle =>
      'Liên kết cha mẹ - con cái này sẽ tạo chu trình không hợp lệ.';

  @override
  String get relationshipErrorPermissionDenied =>
      'Phiên hiện tại không có quyền thay đổi quan hệ nhạy cảm này.';

  @override
  String get relationshipErrorMemberNotFound =>
      'Không tìm thấy hồ sơ thành viên phù hợp để tạo quan hệ.';

  @override
  String get relationshipErrorSameMember =>
      'Không thể tạo quan hệ với chính cùng một thành viên.';

  @override
  String get relationshipPickParentTitle => 'Chọn cha hoặc mẹ';

  @override
  String get relationshipPickChildTitle => 'Chọn thành viên làm con';

  @override
  String get relationshipPickSpouseTitle => 'Chọn hôn phối';

  @override
  String get relationshipNoCandidates =>
      'Không còn ứng viên phù hợp cho thao tác này.';

  @override
  String get relationshipParentAddedSuccess => 'Đã thêm liên kết cha mẹ.';

  @override
  String get relationshipChildAddedSuccess => 'Đã thêm liên kết con cái.';

  @override
  String get relationshipSpouseAddedSuccess => 'Đã thêm liên kết hôn phối.';

  @override
  String get notificationForegroundEvent => 'Có cập nhật sự kiện mới.';

  @override
  String get notificationForegroundScholarship => 'Có cập nhật khuyến học mới.';

  @override
  String get notificationForegroundGeneral => 'Có thông báo mới.';

  @override
  String get notificationOpenedEvent => 'Đã mở thông báo sự kiện.';

  @override
  String get notificationOpenedScholarship => 'Đã mở thông báo khuyến học.';

  @override
  String get notificationOpenedGeneral => 'Đã mở một thông báo.';

  @override
  String get notificationInboxHeroTitle => 'Hộp thư thông báo';

  @override
  String get notificationInboxHeroDescription =>
      'Xem các cập nhật mới nhất về sự kiện và khuyến học gửi đến hồ sơ thành viên của bạn.';

  @override
  String notificationInboxUnreadCount(int count) {
    return '$count chưa đọc';
  }

  @override
  String get notificationInboxAllRead => 'Bạn đã xem hết thông báo';

  @override
  String get notificationInboxSourceSandbox => 'Dữ liệu sandbox cục bộ';

  @override
  String get notificationInboxSourceLive => 'Dữ liệu Firestore trực tiếp';

  @override
  String get notificationInboxNoContextTitle => 'Chưa thể mở hộp thư thông báo';

  @override
  String get notificationInboxNoContextDescription =>
      'Phiên hiện tại chưa liên kết với hồ sơ thành viên nên chưa có hộp thư để hiển thị.';

  @override
  String get notificationInboxLoadErrorTitle => 'Không thể tải thông báo';

  @override
  String get notificationInboxLoadErrorDescription =>
      'Hãy kéo để tải lại hoặc thử lại ngay. Nếu lỗi tiếp tục, hãy kiểm tra kết nối Firebase và quyền truy cập.';

  @override
  String get notificationInboxRetryAction => 'Thử lại';

  @override
  String get notificationInboxEmptyTitle => 'Chưa có thông báo nào';

  @override
  String get notificationInboxEmptyDescription =>
      'Khi có cập nhật sự kiện hoặc khuyến học, thông báo sẽ xuất hiện tại đây.';

  @override
  String get notificationInboxUnreadChip => 'Chưa đọc';

  @override
  String get notificationInboxReadChip => 'Đã đọc';

  @override
  String get notificationInboxTargetEvent => 'Sự kiện';

  @override
  String get notificationInboxTargetScholarship => 'Khuyến học';

  @override
  String get notificationInboxTargetGeneric => 'Chung';

  @override
  String get notificationInboxTargetUnknown => 'Cập nhật';

  @override
  String get notificationInboxFallbackTitle => 'Cập nhật thông báo';

  @override
  String get notificationInboxFallbackBody =>
      'Mở thông báo này để xem thêm chi tiết.';

  @override
  String get notificationInboxOpenAction => 'Mở';

  @override
  String get notificationInboxMarkReadAction => 'Đánh dấu đã đọc';

  @override
  String get notificationInboxMarkReadFailed =>
      'Chưa thể đánh dấu thông báo này là đã đọc lúc này.';

  @override
  String get notificationInboxLoadMoreAction => 'Tải thêm thông báo';

  @override
  String get notificationInboxPaginationDone => 'Không còn thông báo nào khác.';

  @override
  String get notificationTargetEventTitle => 'Thông báo sự kiện';

  @override
  String get notificationTargetEventDescription =>
      'Điểm đích này xác nhận luồng deep-link đã điều hướng đến phần sự kiện.';

  @override
  String get notificationTargetScholarshipTitle => 'Thông báo khuyến học';

  @override
  String get notificationTargetScholarshipDescription =>
      'Điểm đích này xác nhận luồng deep-link đã điều hướng đến kết quả khuyến học.';

  @override
  String get notificationTargetUnknownTitle => 'Điểm đích thông báo';

  @override
  String get notificationTargetUnknownDescription =>
      'Thông báo này chưa có điểm đích được hỗ trợ.';

  @override
  String get notificationTargetReferenceLabel => 'Mã tham chiếu';

  @override
  String get notificationTargetPayloadTitleLabel => 'Tiêu đề thông báo';

  @override
  String get notificationTargetPayloadBodyLabel => 'Nội dung thông báo';

  @override
  String get notificationTargetUnknownReference => 'Không có';

  @override
  String get notificationSettingsTitle => 'Cài đặt thông báo';

  @override
  String get notificationSettingsDescription =>
      'Quản lý lời nhắc và loại thông báo bạn muốn nhận trên thiết bị này.';

  @override
  String get notificationSettingsPushChannel => 'Thông báo đẩy (khuyên dùng)';

  @override
  String get notificationSettingsEmailChannel => 'Thông báo qua email';

  @override
  String get notificationSettingsSmsOtpOnlyNote =>
      'SMS chỉ dùng cho xác minh OTP.';

  @override
  String get notificationSettingsEventUpdates =>
      'Nhắc lịch và cập nhật sự kiện';

  @override
  String get notificationSettingsScholarshipUpdates =>
      'Kết quả và cập nhật duyệt khuyến học';

  @override
  String get notificationSettingsGeneralUpdates => 'Thông báo chung của họ tộc';

  @override
  String get notificationSettingsQuietHours => 'Chế độ giờ yên lặng';

  @override
  String get notificationSettingsPlaceholderNote =>
      'Thay đổi sẽ được lưu vào cài đặt hồ sơ và áp dụng cho phiên sử dụng tiếp theo.';

  @override
  String get authIssueRestoreSessionFailed =>
      'BeFam chưa thể khôi phục phiên đăng nhập trước đó.';

  @override
  String get authIssueRequestOtpBeforeVerify =>
      'Hãy yêu cầu OTP trước khi thử xác minh.';

  @override
  String get authIssueOtpMustBeSixDigits =>
      'Hãy nhập OTP gồm 6 chữ số để tiếp tục.';

  @override
  String get authIssuePhoneRequired => 'Hãy nhập số điện thoại để tiếp tục.';

  @override
  String get authIssuePhoneInvalidFormat =>
      'Hãy nhập số điện thoại hợp lệ với mã quốc gia hoặc định dạng Việt Nam.';

  @override
  String get authIssueChildIdentifierRequired =>
      'Hãy nhập mã trẻ em để tiếp tục.';

  @override
  String get authIssueChildIdentifierInvalid =>
      'Hãy nhập mã trẻ em hợp lệ có ít nhất 4 ký tự.';

  @override
  String get authIssueInvalidPhoneNumber =>
      'Số điện thoại chưa hợp lệ. Hãy kiểm tra lại và thử lại.';

  @override
  String get authIssueInvalidVerificationCode =>
      'Mã xác minh chưa khớp. Hãy kiểm tra OTP và thử lại.';

  @override
  String get authIssueSessionExpired =>
      'Phiên xác minh đã hết hạn. Hãy yêu cầu OTP mới để tiếp tục.';

  @override
  String get authIssueNetworkRequestFailed =>
      'Kết nối mạng thất bại. Hãy kiểm tra internet và thử lại.';

  @override
  String get authIssueTooManyRequests =>
      'Có quá nhiều lần thử xác thực. Hãy chờ một chút rồi thử lại.';

  @override
  String get authIssueQuotaExceeded =>
      'Hạn mức OTP tạm thời đã đạt. Hãy thử lại sau.';

  @override
  String get authIssueUserNotFound =>
      'BeFam chưa tìm thấy hồ sơ gia đình phù hợp với thông tin này.';

  @override
  String get authIssueChildAccessNotReady =>
      'Mã trẻ em này đã tồn tại nhưng chưa được liên kết đầy đủ với luồng OTP phụ huynh.';

  @override
  String get authIssueMemberAlreadyLinked =>
      'Hồ sơ thành viên này đã được liên kết với một tài khoản khác.';

  @override
  String get authIssueMemberClaimConflict =>
      'Có nhiều hơn một hồ sơ thành viên dùng cùng số điện thoại này. Hãy liên hệ quản trị viên họ tộc.';

  @override
  String get authIssueParentVerificationMismatch =>
      'Số điện thoại đã xác minh không khớp với số phụ huynh liên kết với mã truy cập trẻ em đó.';

  @override
  String get authIssueOperationNotAllowed =>
      'Phương thức đăng nhập này chưa được bật cho dự án Firebase hiện tại.';

  @override
  String get authIssueWebDomainNotAuthorized =>
      'Tên miền hiện tại chưa được bật trong Firebase Authentication. Hãy thêm tên miền này vào danh sách Authorized domains.';

  @override
  String get authIssueRecaptchaVerificationFailed =>
      'Xác minh reCAPTCHA chưa thành công. Hãy tải lại trang và thử lại.';

  @override
  String get authIssueAuthUnavailable => 'Hiện chưa thể hoàn tất xác thực.';

  @override
  String get authIssuePreparationFailed =>
      'Có lỗi xảy ra khi chuẩn bị đăng nhập. Hãy thử lại.';

  @override
  String get eventWorkspaceTitle => 'Không gian sự kiện';

  @override
  String get eventRefreshAction => 'Tải lại sự kiện';

  @override
  String get eventCreateAction => 'Tạo sự kiện';

  @override
  String get eventSaveSuccess => 'Đã lưu sự kiện thành công.';

  @override
  String get eventNoContextTitle => 'Cần ngữ cảnh họ tộc';

  @override
  String get eventNoContextDescription =>
      'Hãy đăng nhập bằng hồ sơ đã liên kết họ tộc để xem và quản lý sự kiện.';

  @override
  String get eventHeroTitle => 'Lịch chung họ tộc';

  @override
  String get eventHeroDescription =>
      'Theo dõi lễ nghi, ngày giỗ và lời nhắc trong một nơi.';

  @override
  String get eventReadOnlyTitle => 'Chỉ có quyền xem';

  @override
  String get eventReadOnlyDescription =>
      'Tài khoản này chỉ xem được sự kiện, chưa thể tạo hoặc chỉnh sửa.';

  @override
  String get eventLoadErrorTitle => 'Không thể tải sự kiện';

  @override
  String get eventLoadErrorDescription =>
      'Hãy thử tải lại. Nếu lỗi còn tiếp diễn, kiểm tra mạng và quyền truy cập.';

  @override
  String get eventStatTotal => 'Tổng sự kiện';

  @override
  String get eventStatUpcoming => 'Sắp diễn ra';

  @override
  String get eventStatMemorial => 'Sự kiện giỗ';

  @override
  String get eventMemorialChecklistSectionTitle => 'Danh sách giỗ kỵ';

  @override
  String get eventMemorialChecklistSectionDescription =>
      'Đối chiếu ngày mất với sự kiện giỗ để tránh thiếu sót.';

  @override
  String eventMemorialChecklistConfiguredCount(int count) {
    return 'Đã thiết lập: $count';
  }

  @override
  String eventMemorialChecklistMissingCount(int count) {
    return 'Chưa thiết lập: $count';
  }

  @override
  String eventMemorialChecklistMismatchCount(int count) {
    return 'Cần kiểm tra ngày: $count';
  }

  @override
  String get eventMemorialChecklistEmptyTitle => 'Chưa có dữ liệu giỗ kỵ';

  @override
  String get eventMemorialChecklistEmptyDescription =>
      'Khi thành viên có ngày mất, danh sách giỗ kỵ sẽ hiển thị tại đây.';

  @override
  String get eventMemorialChecklistMissingChip => 'Chưa thiết lập';

  @override
  String get eventMemorialChecklistConfiguredChip => 'Đã thiết lập';

  @override
  String get eventMemorialChecklistMismatchChip => 'Ngày chưa khớp';

  @override
  String get eventMemorialChecklistDeathDateLabel => 'Ngày mất';

  @override
  String get eventMemorialChecklistEventDateLabel => 'Ngày giỗ đang dùng';

  @override
  String get eventMemorialChecklistInvalidDeathDate => 'Ngày mất chưa hợp lệ';

  @override
  String get eventMemorialChecklistQuickSetupAction => 'Thiết lập nhanh';

  @override
  String get eventMemorialChecklistOpenEventAction => 'Mở sự kiện';

  @override
  String eventQuickMemorialTitle(Object memberName) {
    return 'Giỗ $memberName';
  }

  @override
  String eventQuickMemorialDescription(Object deathDate) {
    return 'Thiết lập nhanh từ ngày mất $deathDate. Hãy kiểm tra lại trước khi lưu.';
  }

  @override
  String get eventRitualChecklistSectionTitle => 'Danh sách dỗ trạp';

  @override
  String get eventRitualChecklistSectionDescription =>
      'Theo dõi mốc 49/50 ngày, 100 ngày, giỗ đầu và giỗ hết.';

  @override
  String eventRitualChecklistConfiguredCount(int count) {
    return 'Đã thiết lập: $count';
  }

  @override
  String eventRitualChecklistMissingCount(int count) {
    return 'Chưa thiết lập: $count';
  }

  @override
  String eventRitualChecklistMismatchCount(int count) {
    return 'Lệch ngày: $count';
  }

  @override
  String get eventRitualChecklistEmptyTitle => 'Chưa có danh sách dỗ trạp';

  @override
  String get eventRitualChecklistEmptyDescription =>
      'Khi thành viên có ngày mất hợp lệ, danh sách dỗ trạp sẽ xuất hiện tại đây.';

  @override
  String get eventRitualChecklistConfiguredChip => 'Đã thiết lập';

  @override
  String get eventRitualChecklistMissingChip => 'Chưa thiết lập';

  @override
  String get eventRitualChecklistMismatchChip => 'Cần kiểm tra';

  @override
  String get eventRitualChecklistDeathDateLabel => 'Ngày mất';

  @override
  String get eventRitualChecklistExpectedDateLabel => 'Ngày dự kiến';

  @override
  String get eventRitualChecklistEventDateLabel => 'Ngày đang thiết lập';

  @override
  String get eventRitualChecklistQuickSetupAction => 'Thiết lập nhanh';

  @override
  String get eventRitualChecklistOpenEventAction => 'Mở sự kiện';

  @override
  String get eventRitualMilestone49Days => 'Lễ 49 ngày';

  @override
  String get eventRitualMilestone50Days => 'Lễ 50 ngày';

  @override
  String get eventRitualMilestone100Days => 'Lễ 100 ngày';

  @override
  String get eventRitualMilestone1Year => 'Giỗ đầu (1 năm)';

  @override
  String get eventRitualMilestone2Year => 'Giỗ hết (2 năm)';

  @override
  String eventQuickRitualTitle(Object milestone, Object memberName) {
    return '$milestone - $memberName';
  }

  @override
  String eventQuickRitualDescription(Object milestone, Object deathDate) {
    return 'Thiết lập nhanh mốc $milestone dựa trên ngày mất $deathDate. Hãy kiểm tra phong tục chi/họ trước khi lưu.';
  }

  @override
  String get eventFilterSectionTitle => 'Tìm kiếm và bộ lọc';

  @override
  String get eventSearchLabel => 'Tìm sự kiện';

  @override
  String get eventSearchHint => 'Tiêu đề, địa điểm, thành viên hoặc mô tả';

  @override
  String get eventFilterTypeAll => 'Tất cả';

  @override
  String get eventFilterClearAction => 'Xóa';

  @override
  String get eventListSectionTitle => 'Danh sách sự kiện';

  @override
  String get eventListEmptyTitle => 'Chưa có sự kiện';

  @override
  String get eventListEmptyDescription =>
      'Hãy tạo sự kiện đầu tiên cho lịch họ tộc.';

  @override
  String get eventDetailTitle => 'Chi tiết sự kiện';

  @override
  String get eventEditAction => 'Chỉnh sửa';

  @override
  String get eventDetailNotFoundTitle => 'Không còn thấy sự kiện';

  @override
  String get eventDetailNotFoundDescription =>
      'Sự kiện có thể đã bị xóa hoặc ngoài phạm vi không gian hiện tại.';

  @override
  String get eventDetailTimingSection => 'Thời gian và lặp lại';

  @override
  String get eventDetailReminderSection => 'Mốc nhắc nhở';

  @override
  String get eventReminderEmptyTitle => 'Chưa cấu hình lời nhắc';

  @override
  String get eventReminderEmptyDescription =>
      'Thêm các mốc nhắc để thông báo trước khi sự kiện bắt đầu.';

  @override
  String get eventFieldType => 'Loại';

  @override
  String get eventFieldBranch => 'Chi';

  @override
  String get eventFieldTargetMember => 'Thành viên mục tiêu';

  @override
  String get eventFieldLocationName => 'Tên địa điểm';

  @override
  String get eventFieldLocationAddress => 'Địa chỉ';

  @override
  String get eventFieldDescription => 'Mô tả';

  @override
  String get eventFieldStartsAt => 'Bắt đầu';

  @override
  String get eventFieldEndsAt => 'Kết thúc';

  @override
  String get eventFieldTimezone => 'Múi giờ';

  @override
  String get eventFieldRecurring => 'Lặp lại';

  @override
  String get eventFieldRecurrenceRule => 'Quy tắc lặp';

  @override
  String get eventFieldVisibility => 'Phạm vi hiển thị';

  @override
  String get eventFieldStatus => 'Trạng thái';

  @override
  String get eventFieldUnset => 'Chưa thiết lập';

  @override
  String get eventRecurringYes => 'Có';

  @override
  String get eventRecurringNo => 'Không';

  @override
  String get eventFormCreateTitle => 'Tạo sự kiện';

  @override
  String get eventFormEditTitle => 'Chỉnh sửa sự kiện';

  @override
  String get eventFormTitleLabel => 'Tiêu đề';

  @override
  String get eventFormTitleHint => 'Ví dụ: Họp họ, lễ giỗ';

  @override
  String get eventFormTypeLabel => 'Loại sự kiện';

  @override
  String get eventFormBranchLabel => 'Phạm vi chi';

  @override
  String get eventFormTargetMemberLabel => 'Thành viên mục tiêu ngày giỗ';

  @override
  String get eventFormRecurringMemorialLabel => 'Lặp lại ngày giỗ hằng năm';

  @override
  String get eventFormStartsAtLabel => 'Bắt đầu';

  @override
  String get eventFormEndsAtLabel => 'Kết thúc';

  @override
  String get eventFormDateTimeHint => 'YYYY-MM-DD HH:mm';

  @override
  String get eventFormTimezoneLabel => 'Múi giờ';

  @override
  String get eventFormLocationNameLabel => 'Tên địa điểm';

  @override
  String get eventFormLocationAddressLabel => 'Địa chỉ địa điểm';

  @override
  String get eventFormDescriptionLabel => 'Mô tả';

  @override
  String get eventFormReminderSectionTitle => 'Mốc nhắc nhở';

  @override
  String get eventFormReminderPresetWeek => '+7 ngày';

  @override
  String get eventFormReminderPresetDay => '+1 ngày';

  @override
  String get eventFormReminderPresetHours => '+2 giờ';

  @override
  String get eventFormReminderCustomLabel => 'Mốc tùy chỉnh (phút)';

  @override
  String get eventFormReminderCustomHint => 'Ví dụ: 30';

  @override
  String get eventFormReminderAddAction => 'Thêm';

  @override
  String get eventFormSaveAction => 'Lưu sự kiện';

  @override
  String get eventValidationTitleRequired => 'Vui lòng nhập tiêu đề sự kiện.';

  @override
  String get eventValidationTimeRange =>
      'Thời gian bắt đầu/kết thúc không hợp lệ. Thời gian kết thúc phải sau thời gian bắt đầu.';

  @override
  String get eventValidationReminderOffsets =>
      'Mốc nhắc phải là số dương và không trùng lặp.';

  @override
  String get eventValidationMemorialTarget =>
      'Sự kiện giỗ lặp lại cần chọn thành viên mục tiêu.';

  @override
  String get eventValidationMemorialRule =>
      'Sự kiện giỗ lặp lại phải dùng quy tắc hằng năm.';

  @override
  String get eventErrorPermission =>
      'Phiên hiện tại không có quyền quản lý sự kiện.';

  @override
  String get eventErrorNotFound => 'Không tìm thấy sự kiện.';

  @override
  String get eventTypeClanGathering => 'Họp họ';

  @override
  String get eventTypeMeeting => 'Cuộc họp';

  @override
  String get eventTypeBirthday => 'Sinh nhật';

  @override
  String get eventTypeDeathAnniversary => 'Ngày giỗ';

  @override
  String get eventTypeOther => 'Khác';

  @override
  String get webNavHome => 'Trang chủ';

  @override
  String get webNavAboutUs => 'Về chúng tôi';

  @override
  String get webNavBeFamInfo => 'Thông tin BeFam';

  @override
  String get webNavOpenApp => 'Mở ứng dụng';

  @override
  String get webNavMenuTooltip => 'Mở menu điều hướng';

  @override
  String get webLandingBadge => 'Nền tảng gia phả hiện đại';

  @override
  String get webLandingTitle =>
      'BeFam giúp gia đình kết nối dữ liệu gia phả, sự kiện và quỹ trong một không gian thống nhất.';

  @override
  String get webLandingSubtitle =>
      'Từ cây gia phả nhiều thế hệ đến lịch ngày giỗ, BeFam giúp ban điều hành và từng thành viên theo dõi thông tin rõ ràng, nhất quán và dễ dùng.';

  @override
  String get webLandingPrimaryCta => 'Bắt đầu với BeFam';

  @override
  String get webLandingSecondaryCta => 'Tìm hiểu về BeFam';

  @override
  String get webLandingHighlightTitle => 'Quản trị họ tộc minh bạch';

  @override
  String get webLandingHighlightDescription =>
      'Theo dõi thành viên, kế hoạch sự kiện, gói dịch vụ và quyền truy cập trên cùng một nền tảng.';

  @override
  String get webLandingFeatureTreeTitle => 'Gia phả đa thế hệ';

  @override
  String get webLandingFeatureTreeDescription =>
      'Xem cây họ theo chi, đời và quan hệ để dễ quản lý thông tin tổ tiên - hậu duệ.';

  @override
  String get webLandingFeatureEventsTitle => 'Lịch sự kiện tập trung';

  @override
  String get webLandingFeatureEventsDescription =>
      'Lưu lịch họp họ, ngày giỗ, nhắc lịch quan trọng và trạng thái tham gia của thành viên.';

  @override
  String get webLandingFeatureBillingTitle => 'Quản lý gói dịch vụ';

  @override
  String get webLandingFeatureBillingDescription =>
      'Theo dõi gói đang dùng, gia hạn và lịch sử thanh toán ngay trong BeFam.';

  @override
  String get webAboutTitle => 'Về chúng tôi';

  @override
  String get webAboutSubtitle =>
      'BeFam được xây dựng để gìn giữ ký ức gia đình, hỗ trợ quản trị họ tộc minh bạch và gắn kết nhiều thế hệ trên cùng nền tảng số.';

  @override
  String get webAboutMissionTitle => 'Sứ mệnh';

  @override
  String get webAboutMissionDescription =>
      'Giúp mỗi họ tộc số hóa dữ liệu gia đình một cách dễ hiểu, dễ dùng và bền vững.';

  @override
  String get webAboutVisionTitle => 'Tầm nhìn';

  @override
  String get webAboutVisionDescription =>
      'Trở thành nền tảng gia phả số đáng tin cậy cho các cộng đồng gia đình Việt Nam.';

  @override
  String get webAboutTrustTitle => 'Cam kết';

  @override
  String get webAboutTrustDescription =>
      'Ưu tiên tính chính xác dữ liệu, minh bạch quyền truy cập và trải nghiệm đồng nhất trên mọi thiết bị.';

  @override
  String get webInfoTitle => 'Thông tin BeFam';

  @override
  String get webInfoSubtitle =>
      'Tổng quan nhanh về những gì BeFam đang cung cấp cho quản trị gia phả và hoạt động gia đình.';

  @override
  String get webInfoGenealogyTitle => 'Không gian gia phả';

  @override
  String get webInfoGenealogyDescription =>
      'Theo dõi hồ sơ thành viên, quan hệ huyết thống, nhánh chi và thông tin thế hệ trên một cấu trúc thống nhất.';

  @override
  String get webInfoNotificationsTitle => 'Thông báo và nhắc lịch';

  @override
  String get webInfoNotificationsDescription =>
      'Nhận thông báo cho sự kiện, khuyến học và các thay đổi quan trọng trong phạm vi gia tộc.';

  @override
  String get webInfoBillingTitle => 'Gói và thanh toán';

  @override
  String get webInfoBillingDescription =>
      'Quản lý quyền lợi theo gói, trạng thái hiệu lực và luồng thanh toán cho tổ chức gia phả.';

  @override
  String get webInfoHighlightsTitle => 'Điểm nổi bật hiện tại';

  @override
  String get webInfoHighlightsItemOne =>
      'Hỗ trợ tiếng Việt/English đồng bộ theo cấu hình người dùng.';

  @override
  String get webInfoHighlightsItemTwo =>
      'Thiết kế responsive cho điện thoại, tablet và desktop.';

  @override
  String get webInfoHighlightsItemThree =>
      'Kiến trúc Flutter + Firebase giúp mở rộng tính năng nhanh và nhất quán.';
}
