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

  /// No description provided for @genealogyWorkspaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Read model gia phả'**
  String get genealogyWorkspaceTitle;

  /// No description provided for @genealogyWorkspaceDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tải phạm vi của cả họ hoặc chi hiện tại, kiểm tra các điểm vào gốc, rồi xác minh chuỗi tổ tiên, hậu duệ, anh chị em và dữ liệu cây đã được cache trước khi bước sang màn hình cây trực quan.'**
  String get genealogyWorkspaceDescription;

  /// No description provided for @genealogyScopeClan.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi cả họ'**
  String get genealogyScopeClan;

  /// No description provided for @genealogyScopeBranch.
  ///
  /// In vi, this message translates to:
  /// **'Chi hiện tại'**
  String get genealogyScopeBranch;

  /// No description provided for @genealogyRefreshAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại dữ liệu cây'**
  String get genealogyRefreshAction;

  /// No description provided for @genealogyLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải không gian gia phả lúc này.'**
  String get genealogyLoadFailed;

  /// No description provided for @genealogyFromCache.
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng dữ liệu cache'**
  String get genealogyFromCache;

  /// No description provided for @genealogyLiveData.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh chụp mới nhất'**
  String get genealogyLiveData;

  /// No description provided for @genealogySummaryMembers.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get genealogySummaryMembers;

  /// No description provided for @genealogySummaryRelationships.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ'**
  String get genealogySummaryRelationships;

  /// No description provided for @genealogySummaryRoots.
  ///
  /// In vi, this message translates to:
  /// **'Điểm vào gốc'**
  String get genealogySummaryRoots;

  /// No description provided for @genealogySummaryScope.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi'**
  String get genealogySummaryScope;

  /// No description provided for @genealogyFocusMemberTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên trọng tâm'**
  String get genealogyFocusMemberTitle;

  /// No description provided for @genealogyAncestryPathTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chuỗi tổ tiên'**
  String get genealogyAncestryPathTitle;

  /// No description provided for @genealogyRootEntriesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm vào gốc của cây'**
  String get genealogyRootEntriesTitle;

  /// No description provided for @genealogyNoRootEntries.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có điểm vào gốc cho phạm vi này.'**
  String get genealogyNoRootEntries;

  /// No description provided for @genealogyMemberStructureTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước cấu trúc'**
  String get genealogyMemberStructureTitle;

  /// No description provided for @genealogyEmptyStateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thành viên nào trong phạm vi này.'**
  String get genealogyEmptyStateTitle;

  /// No description provided for @genealogyEmptyStateDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy tạo hồ sơ thành viên đầu tiên hoặc chuyển phạm vi để bắt đầu dựng đồ thị gia đình.'**
  String get genealogyEmptyStateDescription;

  /// No description provided for @genealogyGenerationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đời'**
  String get genealogyGenerationLabel;

  /// No description provided for @genealogyParentCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Cha mẹ'**
  String get genealogyParentCountLabel;

  /// No description provided for @genealogyChildCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Con'**
  String get genealogyChildCountLabel;

  /// No description provided for @genealogySpouseCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phối ngẫu'**
  String get genealogySpouseCountLabel;

  /// No description provided for @genealogySiblingCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Anh chị em'**
  String get genealogySiblingCountLabel;

  /// No description provided for @genealogyDescendantCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hậu duệ'**
  String get genealogyDescendantCountLabel;

  /// No description provided for @genealogyRootReasonCurrentMember.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên hiện tại'**
  String get genealogyRootReasonCurrentMember;

  /// No description provided for @genealogyRootReasonClanRoot.
  ///
  /// In vi, this message translates to:
  /// **'Gốc của họ'**
  String get genealogyRootReasonClanRoot;

  /// No description provided for @genealogyRootReasonScopeRoot.
  ///
  /// In vi, this message translates to:
  /// **'Gốc của phạm vi'**
  String get genealogyRootReasonScopeRoot;

  /// No description provided for @genealogyRootReasonBranchLeader.
  ///
  /// In vi, this message translates to:
  /// **'Trưởng chi'**
  String get genealogyRootReasonBranchLeader;

  /// No description provided for @genealogyRootReasonBranchViceLeader.
  ///
  /// In vi, this message translates to:
  /// **'Phó chi'**
  String get genealogyRootReasonBranchViceLeader;

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

  /// No description provided for @shellFieldClanId.
  ///
  /// In vi, this message translates to:
  /// **'Mã họ tộc'**
  String get shellFieldClanId;

  /// No description provided for @shellFieldBranchId.
  ///
  /// In vi, this message translates to:
  /// **'Mã chi'**
  String get shellFieldBranchId;

  /// No description provided for @shellFieldPrimaryRole.
  ///
  /// In vi, this message translates to:
  /// **'Vai trò chính'**
  String get shellFieldPrimaryRole;

  /// No description provided for @shellFieldAccessMode.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ truy cập'**
  String get shellFieldAccessMode;

  /// No description provided for @shellFieldSessionType.
  ///
  /// In vi, this message translates to:
  /// **'Loại phiên'**
  String get shellFieldSessionType;

  /// No description provided for @shellAccessModeUnlinked.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập chưa liên kết hồ sơ'**
  String get shellAccessModeUnlinked;

  /// No description provided for @shellAccessModeClaimed.
  ///
  /// In vi, this message translates to:
  /// **'Phiên thành viên đã liên kết'**
  String get shellAccessModeClaimed;

  /// No description provided for @shellAccessModeChild.
  ///
  /// In vi, this message translates to:
  /// **'Phiên truy cập trẻ em'**
  String get shellAccessModeChild;

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

  /// No description provided for @shellMemberAccessClaimedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ thành viên đã được liên kết'**
  String get shellMemberAccessClaimedTitle;

  /// No description provided for @shellMemberAccessClaimedDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên này đã gắn với một hồ sơ thành viên BeFam, và auth UID cũng đã được liên kết để truy cập trực tiếp hồ sơ đó.'**
  String get shellMemberAccessClaimedDescription;

  /// No description provided for @shellMemberAccessChildTitle.
  ///
  /// In vi, this message translates to:
  /// **'Truy cập trẻ em đã được xác minh qua OTP phụ huynh'**
  String get shellMemberAccessChildTitle;

  /// No description provided for @shellMemberAccessChildDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên này dùng OTP phụ huynh để mở ngữ cảnh thành viên của trẻ. Hồ sơ trẻ có thể được truy cập mà không liên kết vĩnh viễn auth UID.'**
  String get shellMemberAccessChildDescription;

  /// No description provided for @shellMemberAccessUnlinkedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng nhập nhưng chưa liên kết được hồ sơ thành viên'**
  String get shellMemberAccessUnlinkedTitle;

  /// No description provided for @shellMemberAccessUnlinkedDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên số điện thoại đã được xác minh, nhưng BeFam chưa ghép được số này với hồ sơ thành viên có thể nhận. Quyền truy cập theo họ tộc vẫn bị giới hạn cho tới khi hồ sơ được liên kết.'**
  String get shellMemberAccessUnlinkedDescription;

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

  /// No description provided for @shortcutTitleClan.
  ///
  /// In vi, this message translates to:
  /// **'Họ tộc'**
  String get shortcutTitleClan;

  /// No description provided for @shortcutDescriptionClan.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập hồ sơ họ tộc, ban điều hành chi và không gian quản trị đầu tiên.'**
  String get shortcutDescriptionClan;

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

  /// No description provided for @roleSuperAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Siêu quản trị'**
  String get roleSuperAdmin;

  /// No description provided for @roleClanAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị họ tộc'**
  String get roleClanAdmin;

  /// No description provided for @roleBranchAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị chi'**
  String get roleBranchAdmin;

  /// No description provided for @roleMember.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get roleMember;

  /// No description provided for @roleUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác định'**
  String get roleUnknown;

  /// No description provided for @clanDetailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý họ tộc'**
  String get clanDetailTitle;

  /// No description provided for @clanRefreshAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại'**
  String get clanRefreshAction;

  /// No description provided for @clanSaveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu hồ sơ họ tộc.'**
  String get clanSaveSuccess;

  /// No description provided for @clanBranchSaveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu thông tin chi.'**
  String get clanBranchSaveSuccess;

  /// No description provided for @clanNoContextTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản này chưa có ngữ cảnh họ tộc'**
  String get clanNoContextTitle;

  /// No description provided for @clanNoContextDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy liên kết tài khoản với một hồ sơ thành viên hoặc hoàn tất quy trình nhận hồ sơ trước khi quản lý họ tộc.'**
  String get clanNoContextDescription;

  /// No description provided for @clanCreateFirstTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khởi tạo hồ sơ họ tộc'**
  String get clanCreateFirstTitle;

  /// No description provided for @clanCreateFirstDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hồ sơ cốt lõi của họ tộc để nhóm có nơi quản lý các chi, ban điều hành và cấu trúc vận hành ban đầu.'**
  String get clanCreateFirstDescription;

  /// No description provided for @clanPermissionEditor.
  ///
  /// In vi, this message translates to:
  /// **'Có quyền quản trị'**
  String get clanPermissionEditor;

  /// No description provided for @clanPermissionViewer.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ xem'**
  String get clanPermissionViewer;

  /// No description provided for @clanSandboxSourceChip.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu sandbox cục bộ'**
  String get clanSandboxSourceChip;

  /// No description provided for @clanLiveSourceChip.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu Firestore trực tiếp'**
  String get clanLiveSourceChip;

  /// No description provided for @clanLoadErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải không gian họ tộc'**
  String get clanLoadErrorTitle;

  /// No description provided for @clanPermissionDeniedDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên hiện tại không có quyền lưu thay đổi trong cài đặt họ tộc hoặc danh sách chi.'**
  String get clanPermissionDeniedDescription;

  /// No description provided for @clanLoadErrorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra khi tải dữ liệu họ tộc. Hãy thử tải lại hoặc kiểm tra cấu hình Firebase.'**
  String get clanLoadErrorDescription;

  /// No description provided for @clanReadOnlyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở chế độ chỉ xem'**
  String get clanReadOnlyTitle;

  /// No description provided for @clanReadOnlyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên này vẫn xem được thông tin họ tộc, nhưng chỉ quản trị họ tộc hoặc quản trị chi đã liên kết mới có thể thay đổi cài đặt.'**
  String get clanReadOnlyDescription;

  /// No description provided for @clanStatBranches.
  ///
  /// In vi, this message translates to:
  /// **'Số chi'**
  String get clanStatBranches;

  /// No description provided for @clanStatMembers.
  ///
  /// In vi, this message translates to:
  /// **'Số thành viên'**
  String get clanStatMembers;

  /// No description provided for @clanStatYourRole.
  ///
  /// In vi, this message translates to:
  /// **'Vai trò của bạn'**
  String get clanStatYourRole;

  /// No description provided for @clanProfileSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ họ tộc'**
  String get clanProfileSectionTitle;

  /// No description provided for @clanCreateAction.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hồ sơ'**
  String get clanCreateAction;

  /// No description provided for @clanEditAction.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hồ sơ'**
  String get clanEditAction;

  /// No description provided for @clanProfileEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hồ sơ họ tộc'**
  String get clanProfileEmptyTitle;

  /// No description provided for @clanProfileEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy bắt đầu bằng tên họ tộc, người khai sáng và mô tả ngắn để các phần sau có ngữ cảnh đầy đủ.'**
  String get clanProfileEmptyDescription;

  /// No description provided for @clanFieldName.
  ///
  /// In vi, this message translates to:
  /// **'Tên họ tộc'**
  String get clanFieldName;

  /// No description provided for @clanFieldSlug.
  ///
  /// In vi, this message translates to:
  /// **'Slug'**
  String get clanFieldSlug;

  /// No description provided for @clanFieldCountry.
  ///
  /// In vi, this message translates to:
  /// **'Quốc gia'**
  String get clanFieldCountry;

  /// No description provided for @clanFieldFounder.
  ///
  /// In vi, this message translates to:
  /// **'Người khai sáng'**
  String get clanFieldFounder;

  /// No description provided for @clanFieldDescription.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get clanFieldDescription;

  /// No description provided for @clanFieldLogoUrl.
  ///
  /// In vi, this message translates to:
  /// **'Đường dẫn logo'**
  String get clanFieldLogoUrl;

  /// No description provided for @clanFieldUnset.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập'**
  String get clanFieldUnset;

  /// No description provided for @clanBranchSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các chi'**
  String get clanBranchSectionTitle;

  /// No description provided for @clanAddBranchAction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chi'**
  String get clanAddBranchAction;

  /// No description provided for @clanOpenBranchListAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở danh sách chi'**
  String get clanOpenBranchListAction;

  /// No description provided for @clanBranchEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có chi nào'**
  String get clanBranchEmptyTitle;

  /// No description provided for @clanBranchEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tạo chi đầu tiên để phân bổ lãnh đạo, phạm vi vận hành và các màn hình thành viên theo chi.'**
  String get clanBranchEmptyDescription;

  /// No description provided for @clanBranchCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã chi'**
  String get clanBranchCodeLabel;

  /// No description provided for @clanLeaderLabel.
  ///
  /// In vi, this message translates to:
  /// **'Trưởng chi'**
  String get clanLeaderLabel;

  /// No description provided for @clanViceLeaderLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phó chi'**
  String get clanViceLeaderLabel;

  /// No description provided for @clanGenerationHintLabel.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý đời'**
  String get clanGenerationHintLabel;

  /// No description provided for @clanEditBranchAction.
  ///
  /// In vi, this message translates to:
  /// **'Sửa chi'**
  String get clanEditBranchAction;

  /// No description provided for @clanEditorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Biên tập hồ sơ họ tộc'**
  String get clanEditorTitle;

  /// No description provided for @clanEditorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin này xuất hiện như lớp định danh chung cho toàn bộ ứng dụng và giúp đội vận hành thống nhất tên gọi, quốc gia, người khai sáng và mô tả nền.'**
  String get clanEditorDescription;

  /// No description provided for @clanFieldNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Họ Nguyễn Văn'**
  String get clanFieldNameHint;

  /// No description provided for @clanFieldSlugHint.
  ///
  /// In vi, this message translates to:
  /// **'ví dụ: ho-nguyen-van'**
  String get clanFieldSlugHint;

  /// No description provided for @clanFieldSlugHelper.
  ///
  /// In vi, this message translates to:
  /// **'Nếu bỏ trống, BeFam sẽ tự tạo slug từ tên họ tộc.'**
  String get clanFieldSlugHelper;

  /// No description provided for @clanValidationNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập tên họ tộc.'**
  String get clanValidationNameRequired;

  /// No description provided for @clanValidationCountryRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập mã quốc gia hợp lệ.'**
  String get clanValidationCountryRequired;

  /// No description provided for @clanFieldFounderHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Nguyễn Văn Thủy Tổ'**
  String get clanFieldFounderHint;

  /// No description provided for @clanFieldDescriptionHint.
  ///
  /// In vi, this message translates to:
  /// **'Tóm tắt nguồn gốc, phạm vi, hoặc ghi chú quản trị quan trọng của họ tộc.'**
  String get clanFieldDescriptionHint;

  /// No description provided for @clanSaveAction.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get clanSaveAction;

  /// No description provided for @clanBranchEditorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Biên tập chi'**
  String get clanBranchEditorTitle;

  /// No description provided for @clanBranchEditorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hoặc cập nhật chi để sắp xếp người phụ trách, mã nhận diện và gợi ý đời cho các luồng gia phả sau này.'**
  String get clanBranchEditorDescription;

  /// No description provided for @clanBranchNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên chi'**
  String get clanBranchNameLabel;

  /// No description provided for @clanBranchNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Chi Trưởng'**
  String get clanBranchNameHint;

  /// No description provided for @clanBranchCodeHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: CT01'**
  String get clanBranchCodeHint;

  /// No description provided for @clanValidationBranchNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập tên chi.'**
  String get clanValidationBranchNameRequired;

  /// No description provided for @clanValidationBranchCodeRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập mã chi.'**
  String get clanValidationBranchCodeRequired;

  /// No description provided for @clanValidationGenerationRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập gợi ý đời lớn hơn 0.'**
  String get clanValidationGenerationRequired;

  /// No description provided for @clanNoLeaderOption.
  ///
  /// In vi, this message translates to:
  /// **'Chưa gán trưởng chi'**
  String get clanNoLeaderOption;

  /// No description provided for @clanNoViceLeaderOption.
  ///
  /// In vi, this message translates to:
  /// **'Chưa gán phó chi'**
  String get clanNoViceLeaderOption;

  /// No description provided for @clanValidationViceDistinct.
  ///
  /// In vi, this message translates to:
  /// **'Trưởng chi và phó chi phải là hai người khác nhau.'**
  String get clanValidationViceDistinct;

  /// No description provided for @clanBranchListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách chi'**
  String get clanBranchListTitle;

  /// No description provided for @memberWorkspaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ thành viên'**
  String get memberWorkspaceTitle;

  /// No description provided for @memberRefreshAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại'**
  String get memberRefreshAction;

  /// No description provided for @memberNoContextTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản này chưa có ngữ cảnh thành viên'**
  String get memberNoContextTitle;

  /// No description provided for @memberNoContextDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy liên kết tài khoản với hồ sơ thành viên trước khi quản lý danh sách thành viên trong BeFam.'**
  String get memberNoContextDescription;

  /// No description provided for @memberWorkspaceHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý hồ sơ thành viên của họ tộc'**
  String get memberWorkspaceHeroTitle;

  /// No description provided for @memberWorkspaceHeroDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hồ sơ mới, chỉnh sửa hồ sơ đã liên kết, quản lý avatar và chuẩn bị dữ liệu thành viên cho cây gia phả, sự kiện và phân quyền.'**
  String get memberWorkspaceHeroDescription;

  /// No description provided for @memberReadOnlyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở chế độ chỉ xem'**
  String get memberReadOnlyTitle;

  /// No description provided for @memberReadOnlyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên này chỉ xem được hồ sơ của chính mình hoặc ngữ cảnh thành viên đã liên kết. Chỉ quản trị họ tộc hoặc quản trị chi mới có thể thêm thành viên mới.'**
  String get memberReadOnlyDescription;

  /// No description provided for @memberLoadErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải không gian thành viên'**
  String get memberLoadErrorTitle;

  /// No description provided for @memberLoadErrorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra khi tải hồ sơ thành viên. Hãy thử tải lại hoặc kiểm tra cấu hình Firebase.'**
  String get memberLoadErrorDescription;

  /// No description provided for @memberStatCount.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hồ sơ'**
  String get memberStatCount;

  /// No description provided for @memberStatVisible.
  ///
  /// In vi, this message translates to:
  /// **'Đang hiển thị'**
  String get memberStatVisible;

  /// No description provided for @memberStatRole.
  ///
  /// In vi, this message translates to:
  /// **'Vai trò của bạn'**
  String get memberStatRole;

  /// No description provided for @memberOwnProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ của bạn'**
  String get memberOwnProfileTitle;

  /// No description provided for @memberEditOwnProfileAction.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hồ sơ của tôi'**
  String get memberEditOwnProfileAction;

  /// No description provided for @memberFilterSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm và lọc'**
  String get memberFilterSectionTitle;

  /// No description provided for @memberListSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách thành viên'**
  String get memberListSectionTitle;

  /// No description provided for @memberAddAction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm thành viên'**
  String get memberAddAction;

  /// No description provided for @memberListEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hồ sơ phù hợp'**
  String get memberListEmptyTitle;

  /// No description provided for @memberListEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy tạo thành viên đầu tiên hoặc thay đổi bộ lọc để xem thêm hồ sơ.'**
  String get memberListEmptyDescription;

  /// No description provided for @memberSaveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu hồ sơ thành viên.'**
  String get memberSaveSuccess;

  /// No description provided for @memberAvatarUploadSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải avatar lên thành công.'**
  String get memberAvatarUploadSuccess;

  /// No description provided for @memberDetailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết thành viên'**
  String get memberDetailTitle;

  /// No description provided for @memberUploadAvatarAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh đại diện'**
  String get memberUploadAvatarAction;

  /// No description provided for @memberEditAction.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get memberEditAction;

  /// No description provided for @memberNotFoundTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy thành viên'**
  String get memberNotFoundTitle;

  /// No description provided for @memberNotFoundDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ thành viên này không còn khả dụng trong ngữ cảnh hiện tại.'**
  String get memberNotFoundDescription;

  /// No description provided for @memberDetailNoNickname.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có biệt danh'**
  String get memberDetailNoNickname;

  /// No description provided for @memberGenerationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đời'**
  String get memberGenerationLabel;

  /// No description provided for @memberDetailSummaryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cơ bản'**
  String get memberDetailSummaryTitle;

  /// No description provided for @memberFullNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get memberFullNameLabel;

  /// No description provided for @memberNicknameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Biệt danh'**
  String get memberNicknameLabel;

  /// No description provided for @memberFieldUnset.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập'**
  String get memberFieldUnset;

  /// No description provided for @memberPhoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get memberPhoneLabel;

  /// No description provided for @memberEmailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get memberEmailLabel;

  /// No description provided for @memberGenderLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính'**
  String get memberGenderLabel;

  /// No description provided for @memberBirthDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get memberBirthDateLabel;

  /// No description provided for @memberDeathDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất'**
  String get memberDeathDateLabel;

  /// No description provided for @memberJobTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nghề nghiệp'**
  String get memberJobTitleLabel;

  /// No description provided for @memberAddressLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get memberAddressLabel;

  /// No description provided for @memberBioLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiểu sử ngắn'**
  String get memberBioLabel;

  /// No description provided for @memberSocialLinksTitle.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết mạng xã hội'**
  String get memberSocialLinksTitle;

  /// No description provided for @memberSocialLinksEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có liên kết mạng xã hội'**
  String get memberSocialLinksEmptyTitle;

  /// No description provided for @memberSocialLinksEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thêm Facebook, Zalo hoặc LinkedIn để hồ sơ dễ liên hệ hơn.'**
  String get memberSocialLinksEmptyDescription;

  /// No description provided for @memberAvatarHint.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện sẽ được lưu vào Firebase Storage và dùng cho các màn hình hồ sơ sau này.'**
  String get memberAvatarHint;

  /// No description provided for @memberAddSheetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm thành viên'**
  String get memberAddSheetTitle;

  /// No description provided for @memberEditSheetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa thành viên'**
  String get memberEditSheetTitle;

  /// No description provided for @memberEditorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Điền thông tin cốt lõi để BeFam có thể tìm kiếm, xác minh và hiển thị hồ sơ thành viên chính xác theo chi và đời.'**
  String get memberEditorDescription;

  /// No description provided for @memberSaveErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu hồ sơ thành viên'**
  String get memberSaveErrorTitle;

  /// No description provided for @memberFullNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Nguyễn Văn Minh'**
  String get memberFullNameHint;

  /// No description provided for @memberValidationNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập họ và tên thành viên.'**
  String get memberValidationNameRequired;

  /// No description provided for @memberNicknameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Minh'**
  String get memberNicknameHint;

  /// No description provided for @memberBranchLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chi'**
  String get memberBranchLabel;

  /// No description provided for @memberValidationBranchRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn chi cho thành viên.'**
  String get memberValidationBranchRequired;

  /// No description provided for @memberGenderUnspecified.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác định'**
  String get memberGenderUnspecified;

  /// No description provided for @memberGenderMale.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get memberGenderMale;

  /// No description provided for @memberGenderFemale.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get memberGenderFemale;

  /// No description provided for @memberGenderOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get memberGenderOther;

  /// No description provided for @memberValidationGenerationRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập đời lớn hơn 0.'**
  String get memberValidationGenerationRequired;

  /// No description provided for @memberValidationDateInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập ngày theo định dạng YYYY-MM-DD hợp lệ.'**
  String get memberValidationDateInvalid;

  /// No description provided for @memberPhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'0901234567 hoặc +84901234567'**
  String get memberPhoneHint;

  /// No description provided for @memberValidationPhoneInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập số điện thoại hợp lệ.'**
  String get memberValidationPhoneInvalid;

  /// No description provided for @memberJobTitleHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Kỹ sư, giáo viên, quản lý'**
  String get memberJobTitleHint;

  /// No description provided for @memberAddressHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Đà Nẵng, Việt Nam'**
  String get memberAddressHint;

  /// No description provided for @memberSaveAction.
  ///
  /// In vi, this message translates to:
  /// **'Lưu hồ sơ'**
  String get memberSaveAction;

  /// No description provided for @memberSearchLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tìm thành viên'**
  String get memberSearchLabel;

  /// No description provided for @memberSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên, biệt danh hoặc số điện thoại'**
  String get memberSearchHint;

  /// No description provided for @memberFilterBranchLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lọc theo chi'**
  String get memberFilterBranchLabel;

  /// No description provided for @memberFilterAllBranches.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả chi'**
  String get memberFilterAllBranches;

  /// No description provided for @memberFilterGenerationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lọc theo đời'**
  String get memberFilterGenerationLabel;

  /// No description provided for @memberFilterAllGenerations.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả đời'**
  String get memberFilterAllGenerations;

  /// No description provided for @memberClearFiltersAction.
  ///
  /// In vi, this message translates to:
  /// **'Xóa bộ lọc'**
  String get memberClearFiltersAction;

  /// No description provided for @memberPhoneMissing.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có số điện thoại'**
  String get memberPhoneMissing;

  /// No description provided for @memberPermissionEditor.
  ///
  /// In vi, this message translates to:
  /// **'Có quyền chỉnh sửa'**
  String get memberPermissionEditor;

  /// No description provided for @memberPermissionViewer.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ xem'**
  String get memberPermissionViewer;

  /// No description provided for @memberSandboxChip.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu sandbox cục bộ'**
  String get memberSandboxChip;

  /// No description provided for @memberLiveChip.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu Firestore trực tiếp'**
  String get memberLiveChip;

  /// No description provided for @memberDuplicatePhoneError.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại này đã thuộc về một hồ sơ thành viên khác.'**
  String get memberDuplicatePhoneError;

  /// No description provided for @memberPermissionDeniedError.
  ///
  /// In vi, this message translates to:
  /// **'Phiên hiện tại không có quyền thay đổi hồ sơ thành viên này.'**
  String get memberPermissionDeniedError;

  /// No description provided for @memberAvatarUploadError.
  ///
  /// In vi, this message translates to:
  /// **'BeFam chưa thể tải ảnh đại diện lên lúc này.'**
  String get memberAvatarUploadError;

  /// No description provided for @relationshipInspectorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ gia đình'**
  String get relationshipInspectorTitle;

  /// No description provided for @relationshipInspectorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra các liên kết cha mẹ, con cái và hôn phối của hồ sơ này. Những thay đổi nhạy cảm chỉ dành cho quản trị đã liên kết.'**
  String get relationshipInspectorDescription;

  /// No description provided for @relationshipRefreshAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại quan hệ'**
  String get relationshipRefreshAction;

  /// No description provided for @relationshipAddParentAction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm cha hoặc mẹ'**
  String get relationshipAddParentAction;

  /// No description provided for @relationshipAddChildAction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm con'**
  String get relationshipAddChildAction;

  /// No description provided for @relationshipAddSpouseAction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm hôn phối'**
  String get relationshipAddSpouseAction;

  /// No description provided for @relationshipParentsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cha mẹ'**
  String get relationshipParentsTitle;

  /// No description provided for @relationshipChildrenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Con cái'**
  String get relationshipChildrenTitle;

  /// No description provided for @relationshipSpousesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hôn phối'**
  String get relationshipSpousesTitle;

  /// No description provided for @relationshipNoParents.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có liên kết cha mẹ.'**
  String get relationshipNoParents;

  /// No description provided for @relationshipNoChildren.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có liên kết con cái.'**
  String get relationshipNoChildren;

  /// No description provided for @relationshipNoSpouses.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có liên kết hôn phối.'**
  String get relationshipNoSpouses;

  /// No description provided for @relationshipCanonicalEdgeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cạnh quan hệ chuẩn'**
  String get relationshipCanonicalEdgeTitle;

  /// No description provided for @relationshipNoEdges.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cạnh quan hệ nào cho hồ sơ này.'**
  String get relationshipNoEdges;

  /// No description provided for @relationshipEdgeParentChild.
  ///
  /// In vi, this message translates to:
  /// **'Cha mẹ -> con'**
  String get relationshipEdgeParentChild;

  /// No description provided for @relationshipEdgeSpouse.
  ///
  /// In vi, this message translates to:
  /// **'Hôn phối'**
  String get relationshipEdgeSpouse;

  /// No description provided for @relationshipSourceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nguồn'**
  String get relationshipSourceLabel;

  /// No description provided for @relationshipErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật quan hệ'**
  String get relationshipErrorTitle;

  /// No description provided for @relationshipErrorDuplicateSpouse.
  ///
  /// In vi, this message translates to:
  /// **'Hai thành viên này đã có liên kết hôn phối.'**
  String get relationshipErrorDuplicateSpouse;

  /// No description provided for @relationshipErrorDuplicateParentChild.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết cha mẹ - con cái này đã tồn tại.'**
  String get relationshipErrorDuplicateParentChild;

  /// No description provided for @relationshipErrorCycle.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết cha mẹ - con cái này sẽ tạo chu trình không hợp lệ.'**
  String get relationshipErrorCycle;

  /// No description provided for @relationshipErrorPermissionDenied.
  ///
  /// In vi, this message translates to:
  /// **'Phiên hiện tại không có quyền thay đổi quan hệ nhạy cảm này.'**
  String get relationshipErrorPermissionDenied;

  /// No description provided for @relationshipErrorMemberNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy hồ sơ thành viên phù hợp để tạo quan hệ.'**
  String get relationshipErrorMemberNotFound;

  /// No description provided for @relationshipErrorSameMember.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo quan hệ với chính cùng một thành viên.'**
  String get relationshipErrorSameMember;

  /// No description provided for @relationshipPickParentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn cha hoặc mẹ'**
  String get relationshipPickParentTitle;

  /// No description provided for @relationshipPickChildTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn thành viên làm con'**
  String get relationshipPickChildTitle;

  /// No description provided for @relationshipPickSpouseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn hôn phối'**
  String get relationshipPickSpouseTitle;

  /// No description provided for @relationshipNoCandidates.
  ///
  /// In vi, this message translates to:
  /// **'Không còn ứng viên phù hợp cho thao tác này.'**
  String get relationshipNoCandidates;

  /// No description provided for @relationshipParentAddedSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm liên kết cha mẹ.'**
  String get relationshipParentAddedSuccess;

  /// No description provided for @relationshipChildAddedSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm liên kết con cái.'**
  String get relationshipChildAddedSuccess;

  /// No description provided for @relationshipSpouseAddedSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm liên kết hôn phối.'**
  String get relationshipSpouseAddedSuccess;

  /// No description provided for @notificationForegroundEvent.
  ///
  /// In vi, this message translates to:
  /// **'Có cập nhật sự kiện mới.'**
  String get notificationForegroundEvent;

  /// No description provided for @notificationForegroundScholarship.
  ///
  /// In vi, this message translates to:
  /// **'Có cập nhật khuyến học mới.'**
  String get notificationForegroundScholarship;

  /// No description provided for @notificationForegroundGeneral.
  ///
  /// In vi, this message translates to:
  /// **'Có thông báo mới.'**
  String get notificationForegroundGeneral;

  /// No description provided for @notificationOpenedEvent.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở thông báo sự kiện.'**
  String get notificationOpenedEvent;

  /// No description provided for @notificationOpenedScholarship.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở thông báo khuyến học.'**
  String get notificationOpenedScholarship;

  /// No description provided for @notificationOpenedGeneral.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở một thông báo.'**
  String get notificationOpenedGeneral;

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

  /// No description provided for @authIssueChildAccessNotReady.
  ///
  /// In vi, this message translates to:
  /// **'Mã trẻ em này đã tồn tại nhưng chưa được liên kết đầy đủ với luồng OTP phụ huynh.'**
  String get authIssueChildAccessNotReady;

  /// No description provided for @authIssueMemberAlreadyLinked.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ thành viên này đã được liên kết với một tài khoản khác.'**
  String get authIssueMemberAlreadyLinked;

  /// No description provided for @authIssueMemberClaimConflict.
  ///
  /// In vi, this message translates to:
  /// **'Có nhiều hơn một hồ sơ thành viên dùng cùng số điện thoại này. Hãy liên hệ quản trị viên họ tộc.'**
  String get authIssueMemberClaimConflict;

  /// No description provided for @authIssueParentVerificationMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại đã xác minh không khớp với số phụ huynh liên kết với mã truy cập trẻ em đó.'**
  String get authIssueParentVerificationMismatch;

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
