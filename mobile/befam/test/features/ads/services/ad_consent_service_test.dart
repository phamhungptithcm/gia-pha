import 'package:befam/features/ads/services/ad_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  test(
    'uses cached consent without showing form when ads can already load',
    () async {
      final consentInformation = _FakeConsentInformation(
        consentStatus: ConsentStatus.obtained,
        canRequestAdsResponses: <bool>[true],
        privacyOptionsRequirementStatus:
            PrivacyOptionsRequirementStatus.notRequired,
      );
      var showFormCalls = 0;
      final service = UmpAdConsentService(
        consentInformation: consentInformation,
        loadAndShowConsentFormIfRequired: (listener) async {
          showFormCalls += 1;
          listener(null);
        },
      );

      final result = await service.gatherConsent();

      expect(result.canRequestAds, isTrue);
      expect(result.consentStatus, ConsentStatus.obtained);
      expect(showFormCalls, 0);
    },
  );

  test('shows consent form when ads cannot be requested yet', () async {
    final consentInformation = _FakeConsentInformation(
      consentStatus: ConsentStatus.required,
      canRequestAdsResponses: <bool>[false, true],
      privacyOptionsRequirementStatus: PrivacyOptionsRequirementStatus.required,
    );
    var showFormCalls = 0;
    final service = UmpAdConsentService(
      consentInformation: consentInformation,
      loadAndShowConsentFormIfRequired: (listener) async {
        showFormCalls += 1;
        listener(null);
      },
    );

    final result = await service.gatherConsent();

    expect(result.canRequestAds, isTrue);
    expect(
      result.privacyOptionsRequirementStatus,
      PrivacyOptionsRequirementStatus.required,
    );
    expect(showFormCalls, 1);
  });

  test('falls back to cached consent when consent info update fails', () async {
    final consentInformation = _FakeConsentInformation(
      consentStatus: ConsentStatus.obtained,
      canRequestAdsResponses: <bool>[true],
      requestUpdateError: FormError(errorCode: 7, message: 'network'),
      privacyOptionsRequirementStatus:
          PrivacyOptionsRequirementStatus.notRequired,
    );
    final service = UmpAdConsentService(
      consentInformation: consentInformation,
      loadAndShowConsentFormIfRequired: (listener) async {
        listener(null);
      },
    );

    final result = await service.gatherConsent();

    expect(result.canRequestAds, isTrue);
    expect(result.requestErrorCode, 7);
  });
}

class _FakeConsentInformation extends ConsentInformation {
  _FakeConsentInformation({
    required this.consentStatus,
    required this.canRequestAdsResponses,
    required this.privacyOptionsRequirementStatus,
    this.requestUpdateError,
  });

  final ConsentStatus consentStatus;
  final List<bool> canRequestAdsResponses;
  final PrivacyOptionsRequirementStatus privacyOptionsRequirementStatus;
  final FormError? requestUpdateError;

  int _canRequestAdsIndex = 0;

  @override
  Future<bool> canRequestAds() async {
    if (_canRequestAdsIndex >= canRequestAdsResponses.length) {
      return canRequestAdsResponses.isEmpty
          ? false
          : canRequestAdsResponses.last;
    }
    final value = canRequestAdsResponses[_canRequestAdsIndex];
    _canRequestAdsIndex += 1;
    return value;
  }

  @override
  Future<ConsentStatus> getConsentStatus() async {
    return consentStatus;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async {
    return privacyOptionsRequirementStatus;
  }

  @override
  Future<bool> isConsentFormAvailable() async {
    return true;
  }

  @override
  Future<void> reset() async {}

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    final error = requestUpdateError;
    if (error != null) {
      failureListener(error);
      return;
    }
    successListener();
  }
}
