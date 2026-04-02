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

  /// No description provided for @authBootstrapNoteReadyLive.
  ///
  /// In vi, this message translates to:
  /// **'Firebase đã sẵn sàng và ứng dụng sẽ thử xác thực số điện thoại thật.'**
  String get authBootstrapNoteReadyLive;

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
  /// **'Nhà'**
  String get shellHomeLabel;

  /// No description provided for @shellHomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trang tổng quan'**
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
  /// **'Không gian cây gia phả'**
  String get genealogyWorkspaceTitle;

  /// No description provided for @genealogyWorkspaceDescription.
  ///
  /// In vi, this message translates to:
  /// **'Xem cây gia phả theo phạm vi cả họ hoặc chi hiện tại.'**
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
  /// **'Hãy thêm thành viên đầu tiên hoặc đổi phạm vi để bắt đầu.'**
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

  /// No description provided for @genealogyMemberStatusLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tình trạng'**
  String get genealogyMemberStatusLabel;

  /// No description provided for @genealogyMemberAliveStatus.
  ///
  /// In vi, this message translates to:
  /// **'Còn sống'**
  String get genealogyMemberAliveStatus;

  /// No description provided for @genealogyMemberDeceasedStatus.
  ///
  /// In vi, this message translates to:
  /// **'Đã mất'**
  String get genealogyMemberDeceasedStatus;

  /// No description provided for @genealogyViewMemberInfoAction.
  ///
  /// In vi, this message translates to:
  /// **'Xem thông tin thành viên'**
  String get genealogyViewMemberInfoAction;

  /// No description provided for @genealogyMetricNodes.
  ///
  /// In vi, this message translates to:
  /// **'Nút: {count}'**
  String genealogyMetricNodes(int count);

  /// No description provided for @genealogyMetricEdges.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết: {count}'**
  String genealogyMetricEdges(int count);

  /// No description provided for @genealogyMetricLayout.
  ///
  /// In vi, this message translates to:
  /// **'Bố cục: {millis}ms'**
  String genealogyMetricLayout(int millis);

  /// No description provided for @genealogyMetricAverage.
  ///
  /// In vi, this message translates to:
  /// **'TB: {millis}ms'**
  String genealogyMetricAverage(int millis);

  /// No description provided for @genealogyMetricPeak.
  ///
  /// In vi, this message translates to:
  /// **'Đỉnh: {millis}ms'**
  String genealogyMetricPeak(int millis);

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

  /// No description provided for @profileRefreshAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại hồ sơ'**
  String get profileRefreshAction;

  /// No description provided for @profileOpenSettingsAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở cài đặt'**
  String get profileOpenSettingsAction;

  /// No description provided for @profileNoContextTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiếu ngữ cảnh thành viên'**
  String get profileNoContextTitle;

  /// No description provided for @profileNoContextDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy liên kết tài khoản với hồ sơ thành viên trước khi quản lý cài đặt cá nhân.'**
  String get profileNoContextDescription;

  /// No description provided for @profileUpdateSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật hồ sơ thành công.'**
  String get profileUpdateSuccess;

  /// No description provided for @profileUpdateErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật hồ sơ'**
  String get profileUpdateErrorTitle;

  /// No description provided for @profileDetailsSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết hồ sơ'**
  String get profileDetailsSectionTitle;

  /// No description provided for @profileAccountSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get profileAccountSectionTitle;

  /// No description provided for @profileLogoutDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất?'**
  String get profileLogoutDialogTitle;

  /// No description provided for @profileLogoutDialogDescription.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể đăng nhập lại bất cứ lúc nào bằng tài khoản đã liên kết.'**
  String get profileLogoutDialogDescription;

  /// No description provided for @profileSettingsLogoutDescription.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận này giúp tránh đăng xuất nhầm khi bạn đang điều chỉnh cài đặt.'**
  String get profileSettingsLogoutDescription;

  /// No description provided for @profileCancelAction.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get profileCancelAction;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get profileSettingsTitle;

  /// No description provided for @profileSettingsOverviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan cài đặt'**
  String get profileSettingsOverviewTitle;

  /// No description provided for @profileSettingsOverviewDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý ngôn ngữ hiển thị, tùy chọn thông báo và phiên làm việc của bạn trong BeFam.'**
  String get profileSettingsOverviewDescription;

  /// No description provided for @profileLanguageSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get profileLanguageSectionTitle;

  /// No description provided for @profileLanguageSectionDescription.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ hiển thị cho toàn bộ ứng dụng.'**
  String get profileLanguageSectionDescription;

  /// No description provided for @profileLanguageVietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get profileLanguageVietnamese;

  /// No description provided for @profileLanguageVietnameseSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mặc định cho người dùng tại Việt Nam'**
  String get profileLanguageVietnameseSubtitle;

  /// No description provided for @profileLanguageEnglish.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Anh'**
  String get profileLanguageEnglish;

  /// No description provided for @profileLanguageEnglishSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị tiếng Anh trên toàn bộ ứng dụng'**
  String get profileLanguageEnglishSubtitle;

  /// No description provided for @profileSecuritySectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Riêng tư và bảo mật'**
  String get profileSecuritySectionTitle;

  /// No description provided for @profileSecurityPlaceholderTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt bảo mật đang được hoàn thiện'**
  String get profileSecurityPlaceholderTitle;

  /// No description provided for @profileSecurityPlaceholderDescription.
  ///
  /// In vi, this message translates to:
  /// **'Các tùy chọn đăng nhập nâng cao và kiểm soát phiên sẽ được bổ sung ở đợt phát hành tiếp theo.'**
  String get profileSecurityPlaceholderDescription;

  /// No description provided for @profileSessionSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập'**
  String get profileSessionSectionTitle;

  /// No description provided for @profileNotificationFundAlerts.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo giao dịch quỹ'**
  String get profileNotificationFundAlerts;

  /// No description provided for @profileEditSheetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get profileEditSheetTitle;

  /// No description provided for @profileEditSheetDescription.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật thông tin thành viên và liên kết liên hệ để hồ sơ luôn đầy đủ, dễ dùng.'**
  String get profileEditSheetDescription;

  /// No description provided for @profileSaveErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu hồ sơ'**
  String get profileSaveErrorTitle;

  /// No description provided for @profileFacebookUrlLabel.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết Facebook'**
  String get profileFacebookUrlLabel;

  /// No description provided for @profileZaloUrlLabel.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết Zalo'**
  String get profileZaloUrlLabel;

  /// No description provided for @profileLinkedinUrlLabel.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết LinkedIn'**
  String get profileLinkedinUrlLabel;

  /// No description provided for @profileSavingAction.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu...'**
  String get profileSavingAction;

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
  /// **'Kho lưu trữ'**
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
  /// **'Tạo hồ sơ họ tộc để bắt đầu quản lý chi và thành viên.'**
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
  /// **'Bắt đầu với tên họ tộc, người khai sáng và mô tả ngắn.'**
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
  /// **'Tạo chi đầu tiên để phân quyền và quản lý thành viên.'**
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
  /// **'Cập nhật chi, người phụ trách và gợi ý đời.'**
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
  /// **'Liên kết tài khoản với hồ sơ thành viên để quản lý danh sách.'**
  String get memberNoContextDescription;

  /// No description provided for @memberWorkspaceHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý hồ sơ thành viên của họ tộc'**
  String get memberWorkspaceHeroTitle;

  /// No description provided for @memberWorkspaceHeroDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý hồ sơ thành viên theo chi và đời.'**
  String get memberWorkspaceHeroDescription;

  /// No description provided for @memberReadOnlyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở chế độ chỉ xem'**
  String get memberReadOnlyTitle;

  /// No description provided for @memberReadOnlyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên này chỉ có quyền xem. Chỉ quản trị họ tộc hoặc quản trị chi mới thêm thành viên.'**
  String get memberReadOnlyDescription;

  /// No description provided for @memberLoadErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải không gian thành viên'**
  String get memberLoadErrorTitle;

  /// No description provided for @memberLoadErrorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải hồ sơ thành viên. Hãy thử lại.'**
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
  /// **'Chưa có hồ sơ phù hợp. Hãy tạo mới hoặc đổi bộ lọc.'**
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
  /// **'Điền thông tin chính để tạo hồ sơ thành viên.'**
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

  /// No description provided for @memberPlanLimitExceededError.
  ///
  /// In vi, this message translates to:
  /// **'Gói hiện tại đã đạt giới hạn thành viên. Vui lòng nâng cấp gói để thêm thành viên mới.'**
  String get memberPlanLimitExceededError;

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

  /// No description provided for @notificationInboxHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hộp thư thông báo'**
  String get notificationInboxHeroTitle;

  /// No description provided for @notificationInboxHeroDescription.
  ///
  /// In vi, this message translates to:
  /// **'Xem các cập nhật mới nhất về sự kiện và khuyến học gửi đến hồ sơ thành viên của bạn.'**
  String get notificationInboxHeroDescription;

  /// No description provided for @notificationInboxUnreadCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} chưa đọc'**
  String notificationInboxUnreadCount(int count);

  /// No description provided for @notificationInboxAllRead.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã xem hết thông báo'**
  String get notificationInboxAllRead;

  /// No description provided for @notificationInboxSourceSandbox.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu sandbox cục bộ'**
  String get notificationInboxSourceSandbox;

  /// No description provided for @notificationInboxSourceLive.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu Firestore trực tiếp'**
  String get notificationInboxSourceLive;

  /// No description provided for @notificationInboxNoContextTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thể mở hộp thư thông báo'**
  String get notificationInboxNoContextTitle;

  /// No description provided for @notificationInboxNoContextDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phiên hiện tại chưa liên kết với hồ sơ thành viên nên chưa có hộp thư để hiển thị.'**
  String get notificationInboxNoContextDescription;

  /// No description provided for @notificationInboxLoadErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải thông báo'**
  String get notificationInboxLoadErrorTitle;

  /// No description provided for @notificationInboxLoadErrorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy kéo để tải lại hoặc thử lại ngay. Nếu lỗi tiếp tục, hãy kiểm tra kết nối Firebase và quyền truy cập.'**
  String get notificationInboxLoadErrorDescription;

  /// No description provided for @notificationInboxRetryAction.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get notificationInboxRetryAction;

  /// No description provided for @notificationInboxEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thông báo nào'**
  String get notificationInboxEmptyTitle;

  /// No description provided for @notificationInboxEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Khi có cập nhật sự kiện hoặc khuyến học, thông báo sẽ xuất hiện tại đây.'**
  String get notificationInboxEmptyDescription;

  /// No description provided for @notificationInboxUnreadChip.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đọc'**
  String get notificationInboxUnreadChip;

  /// No description provided for @notificationInboxReadChip.
  ///
  /// In vi, this message translates to:
  /// **'Đã đọc'**
  String get notificationInboxReadChip;

  /// No description provided for @notificationInboxTargetEvent.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get notificationInboxTargetEvent;

  /// No description provided for @notificationInboxTargetScholarship.
  ///
  /// In vi, this message translates to:
  /// **'Khuyến học'**
  String get notificationInboxTargetScholarship;

  /// No description provided for @notificationInboxTargetGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Chung'**
  String get notificationInboxTargetGeneric;

  /// No description provided for @notificationInboxTargetUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get notificationInboxTargetUnknown;

  /// No description provided for @notificationInboxFallbackTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật thông báo'**
  String get notificationInboxFallbackTitle;

  /// No description provided for @notificationInboxFallbackBody.
  ///
  /// In vi, this message translates to:
  /// **'Mở thông báo này để xem thêm chi tiết.'**
  String get notificationInboxFallbackBody;

  /// No description provided for @notificationInboxOpenAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở'**
  String get notificationInboxOpenAction;

  /// No description provided for @notificationInboxMarkReadAction.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu đã đọc'**
  String get notificationInboxMarkReadAction;

  /// No description provided for @notificationInboxMarkReadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thể đánh dấu thông báo này là đã đọc lúc này.'**
  String get notificationInboxMarkReadFailed;

  /// No description provided for @notificationInboxLoadMoreAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải thêm thông báo'**
  String get notificationInboxLoadMoreAction;

  /// No description provided for @notificationInboxPaginationDone.
  ///
  /// In vi, this message translates to:
  /// **'Không còn thông báo nào khác.'**
  String get notificationInboxPaginationDone;

  /// No description provided for @notificationTargetEventTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo sự kiện'**
  String get notificationTargetEventTitle;

  /// No description provided for @notificationTargetEventDescription.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đích này xác nhận luồng deep-link đã điều hướng đến phần sự kiện.'**
  String get notificationTargetEventDescription;

  /// No description provided for @notificationTargetScholarshipTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo khuyến học'**
  String get notificationTargetScholarshipTitle;

  /// No description provided for @notificationTargetScholarshipDescription.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đích này xác nhận luồng deep-link đã điều hướng đến kết quả khuyến học.'**
  String get notificationTargetScholarshipDescription;

  /// No description provided for @notificationTargetUnknownTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đích thông báo'**
  String get notificationTargetUnknownTitle;

  /// No description provided for @notificationTargetUnknownDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo này chưa có điểm đích được hỗ trợ.'**
  String get notificationTargetUnknownDescription;

  /// No description provided for @notificationTargetReferenceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã tham chiếu'**
  String get notificationTargetReferenceLabel;

  /// No description provided for @notificationTargetPayloadTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề thông báo'**
  String get notificationTargetPayloadTitleLabel;

  /// No description provided for @notificationTargetPayloadBodyLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung thông báo'**
  String get notificationTargetPayloadBodyLabel;

  /// No description provided for @notificationTargetUnknownReference.
  ///
  /// In vi, this message translates to:
  /// **'Không có'**
  String get notificationTargetUnknownReference;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt thông báo'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý lời nhắc và loại thông báo bạn muốn nhận trên thiết bị này.'**
  String get notificationSettingsDescription;

  /// No description provided for @notificationSettingsPushChannel.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo đẩy (khuyên dùng)'**
  String get notificationSettingsPushChannel;

  /// No description provided for @notificationSettingsEmailChannel.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo qua email'**
  String get notificationSettingsEmailChannel;

  /// No description provided for @notificationSettingsSmsOtpOnlyNote.
  ///
  /// In vi, this message translates to:
  /// **'SMS chỉ dùng cho xác minh OTP.'**
  String get notificationSettingsSmsOtpOnlyNote;

  /// No description provided for @notificationSettingsEventUpdates.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc lịch và cập nhật sự kiện'**
  String get notificationSettingsEventUpdates;

  /// No description provided for @notificationSettingsScholarshipUpdates.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả và cập nhật duyệt khuyến học'**
  String get notificationSettingsScholarshipUpdates;

  /// No description provided for @notificationSettingsGeneralUpdates.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo chung của họ tộc'**
  String get notificationSettingsGeneralUpdates;

  /// No description provided for @notificationSettingsQuietHours.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ giờ yên lặng'**
  String get notificationSettingsQuietHours;

  /// No description provided for @notificationSettingsPlaceholderNote.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi sẽ được lưu vào cài đặt hồ sơ và áp dụng cho phiên sử dụng tiếp theo.'**
  String get notificationSettingsPlaceholderNote;

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

  /// No description provided for @authIssueWebDomainNotAuthorized.
  ///
  /// In vi, this message translates to:
  /// **'Tên miền hiện tại chưa được bật trong Firebase Authentication. Hãy thêm tên miền này vào danh sách Authorized domains.'**
  String get authIssueWebDomainNotAuthorized;

  /// No description provided for @authIssueRecaptchaVerificationFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh reCAPTCHA chưa thành công. Hãy tải lại trang và thử lại.'**
  String get authIssueRecaptchaVerificationFailed;

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

  /// No description provided for @eventWorkspaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không gian sự kiện'**
  String get eventWorkspaceTitle;

  /// No description provided for @eventRefreshAction.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại sự kiện'**
  String get eventRefreshAction;

  /// No description provided for @eventCreateAction.
  ///
  /// In vi, this message translates to:
  /// **'Tạo sự kiện'**
  String get eventCreateAction;

  /// No description provided for @eventSaveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu sự kiện thành công.'**
  String get eventSaveSuccess;

  /// No description provided for @eventNoContextTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần ngữ cảnh họ tộc'**
  String get eventNoContextTitle;

  /// No description provided for @eventNoContextDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy đăng nhập bằng hồ sơ đã liên kết họ tộc để xem và quản lý sự kiện.'**
  String get eventNoContextDescription;

  /// No description provided for @eventHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch chung họ tộc'**
  String get eventHeroTitle;

  /// No description provided for @eventHeroDescription.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi lễ nghi, ngày giỗ và lời nhắc trong một nơi.'**
  String get eventHeroDescription;

  /// No description provided for @eventReadOnlyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ có quyền xem'**
  String get eventReadOnlyTitle;

  /// No description provided for @eventReadOnlyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản này chỉ xem được sự kiện, chưa thể tạo hoặc chỉnh sửa.'**
  String get eventReadOnlyDescription;

  /// No description provided for @eventLoadErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải sự kiện'**
  String get eventLoadErrorTitle;

  /// No description provided for @eventLoadErrorDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy thử tải lại. Nếu lỗi còn tiếp diễn, kiểm tra mạng và quyền truy cập.'**
  String get eventLoadErrorDescription;

  /// No description provided for @eventStatTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng sự kiện'**
  String get eventStatTotal;

  /// No description provided for @eventStatUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Sắp diễn ra'**
  String get eventStatUpcoming;

  /// No description provided for @eventStatMemorial.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện giỗ'**
  String get eventStatMemorial;

  /// No description provided for @eventMemorialChecklistSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách giỗ kỵ'**
  String get eventMemorialChecklistSectionTitle;

  /// No description provided for @eventMemorialChecklistSectionDescription.
  ///
  /// In vi, this message translates to:
  /// **'Đối chiếu ngày mất với sự kiện giỗ để tránh thiếu sót.'**
  String get eventMemorialChecklistSectionDescription;

  /// No description provided for @eventMemorialChecklistConfiguredCount.
  ///
  /// In vi, this message translates to:
  /// **'Đã thiết lập: {count}'**
  String eventMemorialChecklistConfiguredCount(int count);

  /// No description provided for @eventMemorialChecklistMissingCount.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập: {count}'**
  String eventMemorialChecklistMissingCount(int count);

  /// No description provided for @eventMemorialChecklistMismatchCount.
  ///
  /// In vi, this message translates to:
  /// **'Cần kiểm tra ngày: {count}'**
  String eventMemorialChecklistMismatchCount(int count);

  /// No description provided for @eventMemorialChecklistEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu giỗ kỵ'**
  String get eventMemorialChecklistEmptyTitle;

  /// No description provided for @eventMemorialChecklistEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Khi thành viên có ngày mất, danh sách giỗ kỵ sẽ hiển thị tại đây.'**
  String get eventMemorialChecklistEmptyDescription;

  /// No description provided for @eventMemorialChecklistMissingChip.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập'**
  String get eventMemorialChecklistMissingChip;

  /// No description provided for @eventMemorialChecklistConfiguredChip.
  ///
  /// In vi, this message translates to:
  /// **'Đã thiết lập'**
  String get eventMemorialChecklistConfiguredChip;

  /// No description provided for @eventMemorialChecklistMismatchChip.
  ///
  /// In vi, this message translates to:
  /// **'Ngày chưa khớp'**
  String get eventMemorialChecklistMismatchChip;

  /// No description provided for @eventMemorialChecklistDeathDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất'**
  String get eventMemorialChecklistDeathDateLabel;

  /// No description provided for @eventMemorialChecklistEventDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày giỗ đang dùng'**
  String get eventMemorialChecklistEventDateLabel;

  /// No description provided for @eventMemorialChecklistInvalidDeathDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất chưa hợp lệ'**
  String get eventMemorialChecklistInvalidDeathDate;

  /// No description provided for @eventMemorialChecklistQuickSetupAction.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập nhanh'**
  String get eventMemorialChecklistQuickSetupAction;

  /// No description provided for @eventMemorialChecklistOpenEventAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở sự kiện'**
  String get eventMemorialChecklistOpenEventAction;

  /// No description provided for @eventQuickMemorialTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giỗ {memberName}'**
  String eventQuickMemorialTitle(Object memberName);

  /// No description provided for @eventQuickMemorialDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập nhanh từ ngày mất {deathDate}. Hãy kiểm tra lại trước khi lưu.'**
  String eventQuickMemorialDescription(Object deathDate);

  /// No description provided for @eventRitualChecklistSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách dỗ trạp'**
  String get eventRitualChecklistSectionTitle;

  /// No description provided for @eventRitualChecklistSectionDescription.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi mốc 49/50 ngày, 100 ngày, giỗ đầu và giỗ hết.'**
  String get eventRitualChecklistSectionDescription;

  /// No description provided for @eventRitualChecklistConfiguredCount.
  ///
  /// In vi, this message translates to:
  /// **'Đã thiết lập: {count}'**
  String eventRitualChecklistConfiguredCount(int count);

  /// No description provided for @eventRitualChecklistMissingCount.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập: {count}'**
  String eventRitualChecklistMissingCount(int count);

  /// No description provided for @eventRitualChecklistMismatchCount.
  ///
  /// In vi, this message translates to:
  /// **'Lệch ngày: {count}'**
  String eventRitualChecklistMismatchCount(int count);

  /// No description provided for @eventRitualChecklistEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có danh sách dỗ trạp'**
  String get eventRitualChecklistEmptyTitle;

  /// No description provided for @eventRitualChecklistEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Khi thành viên có ngày mất hợp lệ, danh sách dỗ trạp sẽ xuất hiện tại đây.'**
  String get eventRitualChecklistEmptyDescription;

  /// No description provided for @eventRitualChecklistConfiguredChip.
  ///
  /// In vi, this message translates to:
  /// **'Đã thiết lập'**
  String get eventRitualChecklistConfiguredChip;

  /// No description provided for @eventRitualChecklistMissingChip.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập'**
  String get eventRitualChecklistMissingChip;

  /// No description provided for @eventRitualChecklistMismatchChip.
  ///
  /// In vi, this message translates to:
  /// **'Cần kiểm tra'**
  String get eventRitualChecklistMismatchChip;

  /// No description provided for @eventRitualChecklistDeathDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất'**
  String get eventRitualChecklistDeathDateLabel;

  /// No description provided for @eventRitualChecklistExpectedDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày dự kiến'**
  String get eventRitualChecklistExpectedDateLabel;

  /// No description provided for @eventRitualChecklistEventDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày đang thiết lập'**
  String get eventRitualChecklistEventDateLabel;

  /// No description provided for @eventRitualChecklistQuickSetupAction.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập nhanh'**
  String get eventRitualChecklistQuickSetupAction;

  /// No description provided for @eventRitualChecklistOpenEventAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở sự kiện'**
  String get eventRitualChecklistOpenEventAction;

  /// No description provided for @eventRitualMilestone49Days.
  ///
  /// In vi, this message translates to:
  /// **'Lễ 49 ngày'**
  String get eventRitualMilestone49Days;

  /// No description provided for @eventRitualMilestone50Days.
  ///
  /// In vi, this message translates to:
  /// **'Lễ 50 ngày'**
  String get eventRitualMilestone50Days;

  /// No description provided for @eventRitualMilestone100Days.
  ///
  /// In vi, this message translates to:
  /// **'Lễ 100 ngày'**
  String get eventRitualMilestone100Days;

  /// No description provided for @eventRitualMilestone1Year.
  ///
  /// In vi, this message translates to:
  /// **'Giỗ đầu (1 năm)'**
  String get eventRitualMilestone1Year;

  /// No description provided for @eventRitualMilestone2Year.
  ///
  /// In vi, this message translates to:
  /// **'Giỗ hết (2 năm)'**
  String get eventRitualMilestone2Year;

  /// No description provided for @eventQuickRitualTitle.
  ///
  /// In vi, this message translates to:
  /// **'{milestone} - {memberName}'**
  String eventQuickRitualTitle(Object milestone, Object memberName);

  /// No description provided for @eventQuickRitualDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập nhanh mốc {milestone} dựa trên ngày mất {deathDate}. Hãy kiểm tra phong tục chi/họ trước khi lưu.'**
  String eventQuickRitualDescription(Object milestone, Object deathDate);

  /// No description provided for @eventFilterSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm và bộ lọc'**
  String get eventFilterSectionTitle;

  /// No description provided for @eventSearchLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tìm sự kiện'**
  String get eventSearchLabel;

  /// No description provided for @eventSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề, địa điểm, thành viên hoặc mô tả'**
  String get eventSearchHint;

  /// No description provided for @eventFilterTypeAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get eventFilterTypeAll;

  /// No description provided for @eventFilterClearAction.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get eventFilterClearAction;

  /// No description provided for @eventListSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách sự kiện'**
  String get eventListSectionTitle;

  /// No description provided for @eventListEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có sự kiện'**
  String get eventListEmptyTitle;

  /// No description provided for @eventListEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Hãy tạo sự kiện đầu tiên cho lịch họ tộc.'**
  String get eventListEmptyDescription;

  /// No description provided for @eventDetailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết sự kiện'**
  String get eventDetailTitle;

  /// No description provided for @eventEditAction.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get eventEditAction;

  /// No description provided for @eventDetailNotFoundTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không còn thấy sự kiện'**
  String get eventDetailNotFoundTitle;

  /// No description provided for @eventDetailNotFoundDescription.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện có thể đã bị xóa hoặc ngoài phạm vi không gian hiện tại.'**
  String get eventDetailNotFoundDescription;

  /// No description provided for @eventDetailTimingSection.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian và lặp lại'**
  String get eventDetailTimingSection;

  /// No description provided for @eventDetailReminderSection.
  ///
  /// In vi, this message translates to:
  /// **'Mốc nhắc nhở'**
  String get eventDetailReminderSection;

  /// No description provided for @eventReminderEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa cấu hình lời nhắc'**
  String get eventReminderEmptyTitle;

  /// No description provided for @eventReminderEmptyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Thêm các mốc nhắc để thông báo trước khi sự kiện bắt đầu.'**
  String get eventReminderEmptyDescription;

  /// No description provided for @eventFieldType.
  ///
  /// In vi, this message translates to:
  /// **'Loại'**
  String get eventFieldType;

  /// No description provided for @eventFieldBranch.
  ///
  /// In vi, this message translates to:
  /// **'Chi'**
  String get eventFieldBranch;

  /// No description provided for @eventFieldTargetMember.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên mục tiêu'**
  String get eventFieldTargetMember;

  /// No description provided for @eventFieldLocationName.
  ///
  /// In vi, this message translates to:
  /// **'Tên địa điểm'**
  String get eventFieldLocationName;

  /// No description provided for @eventFieldLocationAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get eventFieldLocationAddress;

  /// No description provided for @eventFieldDescription.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get eventFieldDescription;

  /// No description provided for @eventFieldStartsAt.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get eventFieldStartsAt;

  /// No description provided for @eventFieldEndsAt.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get eventFieldEndsAt;

  /// No description provided for @eventFieldTimezone.
  ///
  /// In vi, this message translates to:
  /// **'Múi giờ'**
  String get eventFieldTimezone;

  /// No description provided for @eventFieldRecurring.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại'**
  String get eventFieldRecurring;

  /// No description provided for @eventFieldRecurrenceRule.
  ///
  /// In vi, this message translates to:
  /// **'Quy tắc lặp'**
  String get eventFieldRecurrenceRule;

  /// No description provided for @eventFieldVisibility.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi hiển thị'**
  String get eventFieldVisibility;

  /// No description provided for @eventFieldStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get eventFieldStatus;

  /// No description provided for @eventFieldUnset.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thiết lập'**
  String get eventFieldUnset;

  /// No description provided for @eventRecurringYes.
  ///
  /// In vi, this message translates to:
  /// **'Có'**
  String get eventRecurringYes;

  /// No description provided for @eventRecurringNo.
  ///
  /// In vi, this message translates to:
  /// **'Không'**
  String get eventRecurringNo;

  /// No description provided for @eventFormCreateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo sự kiện'**
  String get eventFormCreateTitle;

  /// No description provided for @eventFormEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa sự kiện'**
  String get eventFormEditTitle;

  /// No description provided for @eventFormTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề'**
  String get eventFormTitleLabel;

  /// No description provided for @eventFormTitleHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Họp họ, lễ giỗ'**
  String get eventFormTitleHint;

  /// No description provided for @eventFormTypeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Loại sự kiện'**
  String get eventFormTypeLabel;

  /// No description provided for @eventFormBranchLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi chi'**
  String get eventFormBranchLabel;

  /// No description provided for @eventFormTargetMemberLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên mục tiêu ngày giỗ'**
  String get eventFormTargetMemberLabel;

  /// No description provided for @eventFormRecurringMemorialLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại ngày giỗ hằng năm'**
  String get eventFormRecurringMemorialLabel;

  /// No description provided for @eventFormStartsAtLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get eventFormStartsAtLabel;

  /// No description provided for @eventFormEndsAtLabel.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get eventFormEndsAtLabel;

  /// No description provided for @eventFormDateTimeHint.
  ///
  /// In vi, this message translates to:
  /// **'YYYY-MM-DD HH:mm'**
  String get eventFormDateTimeHint;

  /// No description provided for @eventFormTimezoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Múi giờ'**
  String get eventFormTimezoneLabel;

  /// No description provided for @eventFormLocationNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên địa điểm'**
  String get eventFormLocationNameLabel;

  /// No description provided for @eventFormLocationAddressLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ địa điểm'**
  String get eventFormLocationAddressLabel;

  /// No description provided for @eventFormDescriptionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get eventFormDescriptionLabel;

  /// No description provided for @eventFormReminderSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mốc nhắc nhở'**
  String get eventFormReminderSectionTitle;

  /// No description provided for @eventFormReminderPresetWeek.
  ///
  /// In vi, this message translates to:
  /// **'+7 ngày'**
  String get eventFormReminderPresetWeek;

  /// No description provided for @eventFormReminderPresetDay.
  ///
  /// In vi, this message translates to:
  /// **'+1 ngày'**
  String get eventFormReminderPresetDay;

  /// No description provided for @eventFormReminderPresetHours.
  ///
  /// In vi, this message translates to:
  /// **'+2 giờ'**
  String get eventFormReminderPresetHours;

  /// No description provided for @eventFormReminderCustomLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mốc tùy chỉnh (phút)'**
  String get eventFormReminderCustomLabel;

  /// No description provided for @eventFormReminderCustomHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 30'**
  String get eventFormReminderCustomHint;

  /// No description provided for @eventFormReminderAddAction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get eventFormReminderAddAction;

  /// No description provided for @eventFormSaveAction.
  ///
  /// In vi, this message translates to:
  /// **'Lưu sự kiện'**
  String get eventFormSaveAction;

  /// No description provided for @eventValidationTitleRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tiêu đề sự kiện.'**
  String get eventValidationTitleRequired;

  /// No description provided for @eventValidationTimeRange.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian bắt đầu/kết thúc không hợp lệ. Thời gian kết thúc phải sau thời gian bắt đầu.'**
  String get eventValidationTimeRange;

  /// No description provided for @eventValidationReminderOffsets.
  ///
  /// In vi, this message translates to:
  /// **'Mốc nhắc phải là số dương và không trùng lặp.'**
  String get eventValidationReminderOffsets;

  /// No description provided for @eventValidationMemorialTarget.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện giỗ lặp lại cần chọn thành viên mục tiêu.'**
  String get eventValidationMemorialTarget;

  /// No description provided for @eventValidationMemorialRule.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện giỗ lặp lại phải dùng quy tắc hằng năm.'**
  String get eventValidationMemorialRule;

  /// No description provided for @eventErrorPermission.
  ///
  /// In vi, this message translates to:
  /// **'Phiên hiện tại không có quyền quản lý sự kiện.'**
  String get eventErrorPermission;

  /// No description provided for @eventErrorNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy sự kiện.'**
  String get eventErrorNotFound;

  /// No description provided for @eventTypeClanGathering.
  ///
  /// In vi, this message translates to:
  /// **'Họp họ'**
  String get eventTypeClanGathering;

  /// No description provided for @eventTypeMeeting.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc họp'**
  String get eventTypeMeeting;

  /// No description provided for @eventTypeBirthday.
  ///
  /// In vi, this message translates to:
  /// **'Sinh nhật'**
  String get eventTypeBirthday;

  /// No description provided for @eventTypeDeathAnniversary.
  ///
  /// In vi, this message translates to:
  /// **'Ngày giỗ'**
  String get eventTypeDeathAnniversary;

  /// No description provided for @eventTypeOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get eventTypeOther;

  /// No description provided for @webNavHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get webNavHome;

  /// No description provided for @webNavAboutUs.
  ///
  /// In vi, this message translates to:
  /// **'Về chúng tôi'**
  String get webNavAboutUs;

  /// No description provided for @webNavBeFamInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin BeFam'**
  String get webNavBeFamInfo;

  /// No description provided for @webNavOpenApp.
  ///
  /// In vi, this message translates to:
  /// **'Mở ứng dụng'**
  String get webNavOpenApp;

  /// No description provided for @webNavMenuTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Mở menu điều hướng'**
  String get webNavMenuTooltip;

  /// No description provided for @webLandingBadge.
  ///
  /// In vi, this message translates to:
  /// **'Nền tảng gia phả số cho dòng tộc hiện đại'**
  String get webLandingBadge;

  /// No description provided for @webLandingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giữ cội nguồn sống trong đời sống hiện đại.'**
  String get webLandingTitle;

  /// No description provided for @webLandingSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'BeFam kết nối gia phả, sự kiện, quỹ họ và quản trị thành viên trong một không gian dữ liệu thống nhất, dễ dùng cho mọi thế hệ.'**
  String get webLandingSubtitle;

  /// No description provided for @webLandingPrimaryCta.
  ///
  /// In vi, this message translates to:
  /// **'Mở ứng dụng'**
  String get webLandingPrimaryCta;

  /// No description provided for @webLandingSecondaryCta.
  ///
  /// In vi, this message translates to:
  /// **'Xem câu chuyện BeFam'**
  String get webLandingSecondaryCta;

  /// No description provided for @webLandingHighlightTitle.
  ///
  /// In vi, this message translates to:
  /// **'Vận hành dòng tộc rõ ràng và an toàn'**
  String get webLandingHighlightTitle;

  /// No description provided for @webLandingHighlightDescription.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi thành viên, sự kiện, tài chính và quyền truy cập theo vai trò trên cùng một hệ thống.'**
  String get webLandingHighlightDescription;

  /// No description provided for @webLandingFeatureTreeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gia phả đa thế hệ'**
  String get webLandingFeatureTreeTitle;

  /// No description provided for @webLandingFeatureTreeDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý quan hệ huyết thống theo chi, đời và vai vế để các thế hệ dễ tra cứu, cập nhật.'**
  String get webLandingFeatureTreeDescription;

  /// No description provided for @webLandingFeatureEventsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sự kiện tập trung'**
  String get webLandingFeatureEventsTitle;

  /// No description provided for @webLandingFeatureEventsDescription.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi lịch giỗ, họp họ và các mốc quan trọng với nhắc lịch chủ động cho thành viên.'**
  String get webLandingFeatureEventsDescription;

  /// No description provided for @webLandingFeatureBillingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý gói dịch vụ'**
  String get webLandingFeatureBillingTitle;

  /// No description provided for @webLandingFeatureBillingDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý gói dịch vụ, gia hạn và trạng thái thanh toán trên một luồng rõ ràng, minh bạch.'**
  String get webLandingFeatureBillingDescription;

  /// No description provided for @webAboutTitle.
  ///
  /// In vi, this message translates to:
  /// **'Về chúng tôi'**
  String get webAboutTitle;

  /// No description provided for @webAboutSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'BeFam ra đời từ mong muốn giữ kết nối họ tộc khi con cháu học tập, làm việc và sinh sống ở nhiều nơi.'**
  String get webAboutSubtitle;

  /// No description provided for @webAboutMissionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sứ mệnh'**
  String get webAboutMissionTitle;

  /// No description provided for @webAboutMissionDescription.
  ///
  /// In vi, this message translates to:
  /// **'Giúp mỗi dòng họ số hóa dữ liệu gia đình theo cách dễ hiểu, dễ dùng và bền vững theo thời gian.'**
  String get webAboutMissionDescription;

  /// No description provided for @webAboutVisionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tầm nhìn'**
  String get webAboutVisionTitle;

  /// No description provided for @webAboutVisionDescription.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành nền tảng vận hành họ tộc đáng tin cậy cho cộng đồng gia đình Việt ở mọi nơi.'**
  String get webAboutVisionDescription;

  /// No description provided for @webAboutTrustTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cam kết'**
  String get webAboutTrustTitle;

  /// No description provided for @webAboutTrustDescription.
  ///
  /// In vi, this message translates to:
  /// **'Ưu tiên bảo mật dữ liệu, minh bạch quyền truy cập và trải nghiệm nhất quán trên mọi thiết bị.'**
  String get webAboutTrustDescription;

  /// No description provided for @webInfoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin BeFam'**
  String get webInfoTitle;

  /// No description provided for @webInfoSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan những gì BeFam đang cung cấp để quản trị gia phả, kết nối thành viên và vận hành họ tộc hiệu quả.'**
  String get webInfoSubtitle;

  /// No description provided for @webInfoGenealogyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không gian gia phả'**
  String get webInfoGenealogyTitle;

  /// No description provided for @webInfoGenealogyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi hồ sơ thành viên, quan hệ huyết thống, nhánh chi và thông tin thế hệ trong cùng một cấu trúc dữ liệu.'**
  String get webInfoGenealogyDescription;

  /// No description provided for @webInfoNotificationsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo và nhắc lịch'**
  String get webInfoNotificationsTitle;

  /// No description provided for @webInfoNotificationsDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nhận thông báo về sự kiện, khuyến học và các thay đổi quan trọng để không bỏ sót mốc cần theo dõi.'**
  String get webInfoNotificationsDescription;

  /// No description provided for @webInfoBillingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gói và thanh toán'**
  String get webInfoBillingTitle;

  /// No description provided for @webInfoBillingDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý quyền lợi theo gói, trạng thái hiệu lực và thanh toán theo quy tắc rõ ràng, dễ kiểm soát.'**
  String get webInfoBillingDescription;

  /// No description provided for @webInfoHighlightsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm nổi bật của nền tảng'**
  String get webInfoHighlightsTitle;

  /// No description provided for @webInfoHighlightsItemOne.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ tiếng Việt và tiếng Anh theo cấu hình người dùng.'**
  String get webInfoHighlightsItemOne;

  /// No description provided for @webInfoHighlightsItemTwo.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế responsive cho điện thoại, máy tính bảng và desktop.'**
  String get webInfoHighlightsItemTwo;

  /// No description provided for @webInfoHighlightsItemThree.
  ///
  /// In vi, this message translates to:
  /// **'Kiến trúc Flutter + Firebase giúp mở rộng nhanh, ổn định và nhất quán.'**
  String get webInfoHighlightsItemThree;
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
