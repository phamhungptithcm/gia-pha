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
  String get authSandboxChip => 'Môi trường thử nghiệm';

  @override
  String get authLiveFirebaseChip => 'Xác thực Firebase thật';

  @override
  String get authHeroTitle => 'Xác thực là cột mốc tiếp theo của BeFam.';

  @override
  String get authHeroSandboxDescription =>
      'Bản dựng cục bộ dùng môi trường OTP an toàn để thử luồng số điện thoại và mã trẻ em mà không cần chờ SMS thật. Dùng mã 123456 cho luồng demo.';

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
  String get authBootstrapNoteReadySandbox =>
      'Firebase đã sẵn sàng và môi trường xác thực thử nghiệm đang hoạt động để kiểm thử giao diện cục bộ.';

  @override
  String get authBootstrapNoteReadyLive =>
      'Firebase đã sẵn sàng và ứng dụng sẽ thử xác thực số điện thoại thật.';

  @override
  String get authBootstrapNotePending =>
      'Khởi tạo Firebase vẫn cần được xử lý, vì vậy đăng nhập nên ở môi trường thử nghiệm cho tới khi cấu hình đám mây ổn định.';

  @override
  String get authPhoneHelperSandbox =>
      'Dùng số demo bên dưới để kiểm thử cục bộ nhanh. BeFam có thể tự điền mã OTP thử nghiệm ở bước tiếp theo.';

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
  String authOtpDebugCode(Object hint) {
    return 'Mã OTP thử nghiệm: $hint';
  }

  @override
  String get authOtpAutofillDemo => 'Tự điền mã demo';

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
  String get authQuickBenefitSandbox => 'Kiểm thử cục bộ an toàn';

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
  String get shellHomeLabel => 'Trang chủ';

  @override
  String get shellHomeTitle => 'Bảng điều khiển khởi tạo';

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
  String get shellFieldSessionType => 'Loại phiên';

  @override
  String get shellSessionTypeSandbox => 'Phiên thử nghiệm cục bộ';

  @override
  String get shellSessionTypeFirebase => 'Phiên xác thực Firebase';

  @override
  String get shellFieldFirebaseProject => 'Dự án Firebase';

  @override
  String get shellFieldStorageBucket => 'Storage bucket';

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
  String get authIssueOperationNotAllowed =>
      'Phương thức đăng nhập này chưa được bật cho dự án Firebase hiện tại.';

  @override
  String get authIssueAuthUnavailable => 'Hiện chưa thể hoàn tất xác thực.';

  @override
  String get authIssuePreparationFailed =>
      'Có lỗi xảy ra khi chuẩn bị đăng nhập. Hãy thử lại.';
}
