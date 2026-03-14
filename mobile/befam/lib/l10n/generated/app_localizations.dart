import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('vi'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'BeFam'**
  String get appTitle;

  /// No description provided for @authSignInNeedsAttention.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập cần được kiểm tra'**
  String get authSignInNeedsAttention;

  /// No description provided for @authLoadingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang chuẩn bị phiên BeFam của bạn'**
  String get authLoadingTitle;

  /// No description provided for @authLoadingReadyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Firebase đã sẵn sàng. BeFam đang khôi phục phiên đăng nhập gần nhất.'**
  String get authLoadingReadyDescription;

  /// No description provided for @authLoadingPendingDescription.
  ///
  /// In vi, this message translates to:
  /// **'BeFam vẫn đang kiểm tra trạng thái Firebase trên thiết bị này.'**
  String get authLoadingPendingDescription;

  /// No description provided for @authFirebaseReadyChip.
  ///
  /// In vi, this message translates to:
  /// **'Firebase sẵn sàng'**
  String get authFirebaseReadyChip;

  /// No description provided for @authBootstrapPendingChip.
  ///
  /// In vi, this message translates to:
  /// **'Khởi tạo đang chờ'**
  String get authBootstrapPendingChip;

  /// No description provided for @authSandboxChip.
  ///
  /// In vi, this message translates to:
  /// **'Môi trường thử nghiệm'**
  String get authSandboxChip;

  /// No description provided for @authLiveFirebaseChip.
  ///
  /// In vi, this message translates to:
  /// **'Xác thực Firebase thật'**
  String get authLiveFirebaseChip;

  /// No description provided for @authHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác thực là cột mốc tiếp theo của BeFam.'**
  String get authHeroTitle;

  /// No description provided for @authHeroSandboxDescription.
  ///
  /// In vi, this message translates to:
  /// **'Bản dựng cục bộ dùng môi trường OTP an toàn để thử luồng số điện thoại và mã trẻ em mà không cần chờ SMS thật. Dùng mã 123456 cho luồng demo.'**
  String get authHeroSandboxDescription;

  /// No description provided for @authHeroLiveDescription.
  ///
  /// In vi, this message translates to:
  /// **'Bản dựng này dùng luồng xác thực Firebase thật cho xác minh số điện thoại và khôi phục phiên.'**
  String get authHeroLiveDescription;

  /// No description provided for @authMethodPhoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục bằng số điện thoại'**
  String get authMethodPhoneTitle;

  /// No description provided for @authMethodPhoneDescription.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số điện thoại của bạn để nhận OTP và khôi phục danh tính BeFam.'**
  String get authMethodPhoneDescription;

  /// No description provided for @authMethodPhoneButton.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số điện thoại'**
  String get authMethodPhoneButton;

  /// No description provided for @authMethodChildTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục bằng mã trẻ em'**
  String get authMethodChildTitle;

  /// No description provided for @authMethodChildDescription.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu từ mã trẻ em, xác định số điện thoại phụ huynh liên kết và xác minh quyền truy cập bằng OTP.'**
  String get authMethodChildDescription;

  /// No description provided for @authMethodChildButton.
  ///
  /// In vi, this message translates to:
  /// **'Dùng mã trẻ em'**
  String get authMethodChildButton;

  /// No description provided for @authBootstrapNoteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú khởi tạo hiện tại'**
  String get authBootstrapNoteTitle;

  /// No description provided for @authBootstrapNoteReadySandbox.
  ///
  /// In vi, this message translates to:
  /// **'Firebase đã sẵn sàng và môi trường xác thực thử nghiệm đang hoạt động để kiểm thử giao diện cục bộ.'**
  String get authBootstrapNoteReadySandbox;

  /// No description provided for @authBootstrapNoteReadyLive.
  ///
  /// In vi, this message translates to:
  /// **'Firebase đã sẵn sàng và ứng dụng sẽ thử xác thực số điện thoại thật.'**
  String get authBootstrapNoteReadyLive;

  /// No description provided for @authBootstrapNotePending.
  ///
  /// In vi, this message translates to:
  /// **'Khởi tạo Firebase vẫn cần được xử lý, vì vậy đăng nhập nên ở môi trường thử nghiệm cho tới khi cấu hình đám mây ổn định.'**
  String get authBootstrapNotePending;

  /// No description provided for @authPhoneHelperSandbox.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số demo bên dưới để kiểm thử cục bộ nhanh. BeFam có thể tự điền mã OTP thử nghiệm ở bước tiếp theo.'**
  String get authPhoneHelperSandbox;

  /// No description provided for @authPhoneHelperLive.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số Việt Nam nội địa hoặc định dạng quốc tế đầy đủ. BeFam chỉ dùng số này để xác thực an toàn.'**
  String get authPhoneHelperLive;

  /// No description provided for @authPhoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh số điện thoại'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số điện thoại theo định dạng Việt Nam hoặc E.164 đầy đủ. BeFam sẽ gửi OTP đến số này.'**
  String get authPhoneDescription;

  /// No description provided for @authPhoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'0901234567 hoặc +84901234567'**
  String get authPhoneHint;

  /// No description provided for @authPhoneDemoButton.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số demo 0901234567'**
  String get authPhoneDemoButton;

  /// No description provided for @authSendOtp.
  ///
  /// In vi, this message translates to:
  /// **'Gửi OTP'**
  String get authSendOtp;

  /// No description provided for @authSendingOtp.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi OTP...'**
  String get authSendingOtp;

  /// No description provided for @authChildTitle.
  ///
  /// In vi, this message translates to:
  /// **'Truy cập bằng mã trẻ em'**
  String get authChildTitle;

  /// No description provided for @authChildDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã trẻ em của gia đình. BeFam sẽ xác định số điện thoại phụ huynh liên kết và gửi OTP xác minh.'**
  String get authChildDescription;

  /// No description provided for @authChildLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã trẻ em'**
  String get authChildLabel;

  /// No description provided for @authChildHint.
  ///
  /// In vi, this message translates to:
  /// **'BEFAM-CHILD-001'**
  String get authChildHint;

  /// No description provided for @authChildHelper.
  ///
  /// In vi, this message translates to:
  /// **'Dùng mã truy cập trẻ em do quản trị viên gia đình cung cấp.'**
  String get authChildHelper;

  /// No description provided for @authChildQuickTesting.
  ///
  /// In vi, this message translates to:
  /// **'Mã dùng nhanh để kiểm thử cục bộ'**
  String get authChildQuickTesting;

  /// No description provided for @authContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get authContinue;

  /// No description provided for @authResolvingParentPhone.
  ///
  /// In vi, this message translates to:
  /// **'Đang xác định số phụ huynh...'**
  String get authResolvingParentPhone;

  /// No description provided for @authOtpMissingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh OTP'**
  String get authOtpMissingTitle;

  /// No description provided for @authOtpMissingDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy yêu cầu mã mới trước khi thử xác minh quyền truy cập.'**
  String get authOtpMissingDescription;

  /// No description provided for @authOtpTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh OTP'**
  String get authOtpTitle;

  /// No description provided for @authOtpDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã gồm 6 chữ số đã gửi đến {maskedDestination}.'**
  String authOtpDescription(Object maskedDestination);

  /// No description provided for @authOtpDebugCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã OTP thử nghiệm: {hint}'**
  String authOtpDebugCode(Object hint);

  /// No description provided for @authOtpAutofillDemo.
  ///
  /// In vi, this message translates to:
  /// **'Tự điền mã demo'**
  String get authOtpAutofillDemo;

  /// No description provided for @authOtpChildIdentifier.
  ///
  /// In vi, this message translates to:
  /// **'Mã trẻ em: {childIdentifier}'**
  String authOtpChildIdentifier(Object childIdentifier);

  /// No description provided for @authContinueNow.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục ngay'**
  String get authContinueNow;

  /// No description provided for @authVerifyingOtp.
  ///
  /// In vi, this message translates to:
  /// **'Đang xác minh OTP...'**
  String get authVerifyingOtp;

  /// No description provided for @authResendIn.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại sau {seconds} giây'**
  String authResendIn(int seconds);

  /// No description provided for @authResendOtp.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại OTP'**
  String get authResendOtp;

  /// No description provided for @authOtpHelpText.
  ///
  /// In vi, this message translates to:
  /// **'Nhập hoặc dán mã. BeFam sẽ tự tiếp tục ngay sau chữ số thứ sáu.'**
  String get authOtpHelpText;

  /// No description provided for @authQuickBenefitsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn cách vào BeFam dễ nhất'**
  String get authQuickBenefitsTitle;

  /// No description provided for @authQuickBenefitsDescription.
  ///
  /// In vi, this message translates to:
  /// **'BeFam giữ luồng đăng nhập ngắn gọn, hướng dẫn từng bước và tự tiếp tục khi OTP hoàn tất.'**
  String get authQuickBenefitsDescription;

  /// No description provided for @authQuickBenefitAutoContinue.
  ///
  /// In vi, this message translates to:
  /// **'OTP 6 số tự tiếp tục'**
  String get authQuickBenefitAutoContinue;

  /// No description provided for @authQuickBenefitMultipleAccess.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ số điện thoại và mã trẻ em'**
  String get authQuickBenefitMultipleAccess;

  /// No description provided for @authQuickBenefitSandbox.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm thử cục bộ an toàn'**
  String get authQuickBenefitSandbox;

  /// No description provided for @authQuickBenefitLive.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh Firebase thật'**
  String get authQuickBenefitLive;

  /// No description provided for @authBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get authBack;

  /// No description provided for @authEntryMethodPhoneSummary.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập bằng điện thoại'**
  String get authEntryMethodPhoneSummary;

  /// No description provided for @authEntryMethodChildSummary.
  ///
  /// In vi, this message translates to:
  /// **'Truy cập bằng mã trẻ em'**
  String get authEntryMethodChildSummary;

  /// No description provided for @authEntryMethodPhoneInline.
  ///
  /// In vi, this message translates to:
  /// **'số điện thoại'**
  String get authEntryMethodPhoneInline;

  /// No description provided for @authEntryMethodChildInline.
  ///
  /// In vi, this message translates to:
  /// **'mã trẻ em'**
  String get authEntryMethodChildInline;

  /// No description provided for @shellHomeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get shellHomeLabel;

  /// No description provided for @shellHomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng điều khiển khởi tạo'**
  String get shellHomeTitle;

  /// No description provided for @shellTreeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Gia phả'**
  String get shellTreeLabel;

  /// No description provided for @shellTreeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cây gia phả'**
  String get shellTreeTitle;

  /// No description provided for @shellEventsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get shellEventsLabel;

  /// No description provided for @shellEventsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get shellEventsTitle;

  /// No description provided for @shellProfileLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get shellProfileLabel;

  /// No description provided for @shellProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get shellProfileTitle;

  /// No description provided for @shellTreeWorkspaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không gian gia phả'**
  String get shellTreeWorkspaceTitle;

  /// No description provided for @shellTreeWorkspaceDescription.
  ///
  /// In vi, this message translates to:
  /// **'Khung ứng dụng đã sẵn sàng cho trải nghiệm cây gia phả theo nhánh và công việc dựng cây lớn.'**
  String get shellTreeWorkspaceDescription;

  /// No description provided for @shellEventsWorkspaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không gian sự kiện'**
  String get shellEventsWorkspaceTitle;

  /// No description provided for @shellEventsWorkspaceDescription.
  ///
  /// In vi, this message translates to:
  /// **'Lịch họ tộc, ngày giỗ và lời nhắc sẽ được triển khai tại đây tiếp theo.'**
  String get shellEventsWorkspaceDescription;

  /// No description provided for @shellProfileWorkspaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không gian hồ sơ'**
  String get shellProfileWorkspaceTitle;

  /// No description provided for @shellProfileWorkspaceDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin thành viên, cài đặt và bối cảnh gia đình sẽ phát triển từ phần giữ chỗ này.'**
  String get shellProfileWorkspaceDescription;

  /// No description provided for @shellMoreActions.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác khác'**
  String get shellMoreActions;

  /// No description provided for @shellLogout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get shellLogout;

  /// No description provided for @shellWelcomeBack.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng trở lại, {displayName}.'**
  String shellWelcomeBack(Object displayName);

  /// No description provided for @shellBootstrapNeedsCloud.
  ///
  /// In vi, this message translates to:
  /// **'Khung khởi tạo đã sẵn sàng, nhưng Firebase vẫn cần hoàn tất cấu hình đám mây.'**
  String get shellBootstrapNeedsCloud;

  /// No description provided for @shellSignedInMethod.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đăng nhập bằng {method}, và khung BeFam đã sẵn sàng cho các nhóm tính năng tiếp theo.'**
  String shellSignedInMethod(Object method);

  /// No description provided for @shellCloudSetupNeeded.
  ///
  /// In vi, this message translates to:
  /// **'Nền tảng di động đã sẵn sàng cục bộ. Cloud Firestore vẫn cần được bật để hoàn tất triển khai backend.'**
  String get shellCloudSetupNeeded;

  /// No description provided for @shellTagFreezedJson.
  ///
  /// In vi, this message translates to:
  /// **'Freezed + JSON'**
  String get shellTagFreezedJson;

  /// No description provided for @shellTagFirebaseCore.
  ///
  /// In vi, this message translates to:
  /// **'Firebase cốt lõi'**
  String get shellTagFirebaseCore;

  /// No description provided for @shellTagAuthSessionLive.
  ///
  /// In vi, this message translates to:
  /// **'Phiên xác thực đang hoạt động'**
  String get shellTagAuthSessionLive;

  /// No description provided for @shellTagCrashlyticsEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Crashlytics đã bật'**
  String get shellTagCrashlyticsEnabled;

  /// No description provided for @shellTagLocalLoggerActive.
  ///
  /// In vi, this message translates to:
  /// **'Logger cục bộ đang hoạt động'**
  String get shellTagLocalLoggerActive;

  /// No description provided for @shellTagShellPlaceholders.
  ///
  /// In vi, this message translates to:
  /// **'Các phần giữ chỗ'**
  String get shellTagShellPlaceholders;

  /// No description provided for @shellPriorityWorkspaces.
  ///
  /// In vi, this message translates to:
  /// **'Không gian ưu tiên'**
  String get shellPriorityWorkspaces;

  /// No description provided for @shellPriorityWorkspacesDescription.
  ///
  /// In vi, this message translates to:
  /// **'Các phần giữ chỗ này khớp với những bề mặt sản phẩm đầu tiên trong kế hoạch triển khai.'**
  String get shellPriorityWorkspacesDescription;

  /// No description provided for @shellSignedInContext.
  ///
  /// In vi, this message translates to:
  /// **'Ngữ cảnh đã đăng nhập'**
  String get shellSignedInContext;

  /// No description provided for @shellFieldDisplayName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get shellFieldDisplayName;

  /// No description provided for @shellFieldLoginMethod.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức đăng nhập'**
  String get shellFieldLoginMethod;

  /// No description provided for @shellFieldPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get shellFieldPhone;

  /// No description provided for @shellFieldChildId.
  ///
  /// In vi, this message translates to:
  /// **'Mã trẻ em'**
  String get shellFieldChildId;

  /// No description provided for @shellFieldMemberId.
  ///
  /// In vi, this message translates to:
  /// **'Mã thành viên'**
  String get shellFieldMemberId;

  /// No description provided for @shellFieldSessionType.
  ///
  /// In vi, this message translates to:
  /// **'Loại phiên'**
  String get shellFieldSessionType;

  /// No description provided for @shellSessionTypeSandbox.
  ///
  /// In vi, this message translates to:
  /// **'Phiên thử nghiệm cục bộ'**
  String get shellSessionTypeSandbox;

  /// No description provided for @shellSessionTypeFirebase.
  ///
  /// In vi, this message translates to:
  /// **'Phiên xác thực Firebase'**
  String get shellSessionTypeFirebase;

  /// No description provided for @shellFieldFirebaseProject.
  ///
  /// In vi, this message translates to:
  /// **'Dự án Firebase'**
  String get shellFieldFirebaseProject;

  /// No description provided for @shellFieldStorageBucket.
  ///
  /// In vi, this message translates to:
  /// **'Storage bucket'**
  String get shellFieldStorageBucket;

  /// No description provided for @shellFieldCrashHandling.
  ///
  /// In vi, this message translates to:
  /// **'Xử lý lỗi'**
  String get shellFieldCrashHandling;

  /// No description provided for @shellCrashHandlingRelease.
  ///
  /// In vi, this message translates to:
  /// **'Crashlytics ghi nhận lỗi trên bản phát hành.'**
  String get shellCrashHandlingRelease;

  /// No description provided for @shellCrashHandlingLocal.
  ///
  /// In vi, this message translates to:
  /// **'Logger hoạt động cục bộ và Crashlytics tắt ngoài bản phát hành.'**
  String get shellCrashHandlingLocal;

  /// No description provided for @shellFieldCoreServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ cốt lõi'**
  String get shellFieldCoreServices;

  /// No description provided for @shellCoreServicesWaiting.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết Firebase cốt lõi đang chờ khởi tạo.'**
  String get shellCoreServicesWaiting;

  /// No description provided for @shellFieldStartupNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú khởi động'**
  String get shellFieldStartupNote;

  /// No description provided for @shellShortcutStatusLive.
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng'**
  String get shellShortcutStatusLive;

  /// No description provided for @shellShortcutStatusBootstrap.
  ///
  /// In vi, this message translates to:
  /// **'Khởi tạo'**
  String get shellShortcutStatusBootstrap;

  /// No description provided for @shellShortcutStatusPlanned.
  ///
  /// In vi, this message translates to:
  /// **'Đã lên kế hoạch'**
  String get shellShortcutStatusPlanned;

  /// No description provided for @shellReadinessReady.
  ///
  /// In vi, this message translates to:
  /// **'Firebase sẵn sàng'**
  String get shellReadinessReady;

  /// No description provided for @shellReadinessPending.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình đám mây đang chờ'**
  String get shellReadinessPending;

  /// No description provided for @shortcutTitleTree.
  ///
  /// In vi, this message translates to:
  /// **'Cây gia phả'**
  String get shortcutTitleTree;

  /// No description provided for @shortcutDescriptionTree.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu trải nghiệm gia phả với điều hướng theo nhánh.'**
  String get shortcutDescriptionTree;

  /// No description provided for @shortcutTitleMembers.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get shortcutTitleMembers;

  /// No description provided for @shortcutDescriptionMembers.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ thành viên, nhận hồ sơ và chuẩn bị những luồng dữ liệu đầu tiên.'**
  String get shortcutDescriptionMembers;

  /// No description provided for @shortcutTitleEvents.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get shortcutTitleEvents;

  /// No description provided for @shortcutDescriptionEvents.
  ///
  /// In vi, this message translates to:
  /// **'Lên kế hoạch sự kiện họ tộc, ngày giỗ và lời nhắc trong lịch dùng chung.'**
  String get shortcutDescriptionEvents;

  /// No description provided for @shortcutTitleFunds.
  ///
  /// In vi, this message translates to:
  /// **'Quỹ'**
  String get shortcutTitleFunds;

  /// No description provided for @shortcutDescriptionFunds.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi quỹ đóng góp, lịch sử giao dịch và số dư minh bạch.'**
  String get shortcutDescriptionFunds;

  /// No description provided for @shortcutTitleScholarship.
  ///
  /// In vi, this message translates to:
  /// **'Khuyến học'**
  String get shortcutTitleScholarship;

  /// No description provided for @shortcutDescriptionScholarship.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhận thành tích học tập và sau này liên kết phần thưởng với các nhánh gia đình.'**
  String get shortcutDescriptionScholarship;

  /// No description provided for @shortcutTitleProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get shortcutTitleProfile;

  /// No description provided for @shortcutDescriptionProfile.
  ///
  /// In vi, this message translates to:
  /// **'Dành sẵn không gian cá nhân cho cài đặt thành viên, người giám hộ và ngữ cảnh.'**
  String get shortcutDescriptionProfile;

  /// No description provided for @authIssueRestoreSessionFailed.
  ///
  /// In vi, this message translates to:
  /// **'BeFam chưa thể khôi phục phiên đăng nhập trước đó.'**
  String get authIssueRestoreSessionFailed;

  /// No description provided for @authIssueRequestOtpBeforeVerify.
  ///
  /// In vi, this message translates to:
  /// **'Hãy yêu cầu OTP trước khi thử xác minh.'**
  String get authIssueRequestOtpBeforeVerify;

  /// No description provided for @authIssueOtpMustBeSixDigits.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập OTP gồm 6 chữ số để tiếp tục.'**
  String get authIssueOtpMustBeSixDigits;

  /// No description provided for @authIssuePhoneRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập số điện thoại để tiếp tục.'**
  String get authIssuePhoneRequired;

  /// No description provided for @authIssuePhoneInvalidFormat.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập số điện thoại hợp lệ với mã quốc gia hoặc định dạng Việt Nam.'**
  String get authIssuePhoneInvalidFormat;

  /// No description provided for @authIssueChildIdentifierRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập mã trẻ em để tiếp tục.'**
  String get authIssueChildIdentifierRequired;

  /// No description provided for @authIssueChildIdentifierInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập mã trẻ em hợp lệ có ít nhất 4 ký tự.'**
  String get authIssueChildIdentifierInvalid;

  /// No description provided for @authIssueInvalidPhoneNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại chưa hợp lệ. Hãy kiểm tra lại và thử lại.'**
  String get authIssueInvalidPhoneNumber;

  /// No description provided for @authIssueInvalidVerificationCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã xác minh chưa khớp. Hãy kiểm tra OTP và thử lại.'**
  String get authIssueInvalidVerificationCode;

  /// No description provided for @authIssueSessionExpired.
  ///
  /// In vi, this message translates to:
  /// **'Phiên xác minh đã hết hạn. Hãy yêu cầu OTP mới để tiếp tục.'**
  String get authIssueSessionExpired;

  /// No description provided for @authIssueNetworkRequestFailed.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối mạng thất bại. Hãy kiểm tra internet và thử lại.'**
  String get authIssueNetworkRequestFailed;

  /// No description provided for @authIssueTooManyRequests.
  ///
  /// In vi, this message translates to:
  /// **'Có quá nhiều lần thử xác thực. Hãy chờ một chút rồi thử lại.'**
  String get authIssueTooManyRequests;

  /// No description provided for @authIssueQuotaExceeded.
  ///
  /// In vi, this message translates to:
  /// **'Hạn mức OTP tạm thời đã đạt. Hãy thử lại sau.'**
  String get authIssueQuotaExceeded;

  /// No description provided for @authIssueUserNotFound.
  ///
  /// In vi, this message translates to:
  /// **'BeFam chưa tìm thấy hồ sơ gia đình phù hợp với thông tin này.'**
  String get authIssueUserNotFound;

  /// No description provided for @authIssueOperationNotAllowed.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức đăng nhập này chưa được bật cho dự án Firebase hiện tại.'**
  String get authIssueOperationNotAllowed;

  /// No description provided for @authIssueAuthUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Hiện chưa thể hoàn tất xác thực.'**
  String get authIssueAuthUnavailable;

  /// No description provided for @authIssuePreparationFailed.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra khi chuẩn bị đăng nhập. Hãy thử lại.'**
  String get authIssuePreparationFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
