import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/services/app_logger.dart';

class AdConsentResult {
  const AdConsentResult({
    required this.canRequestAds,
    required this.consentStatus,
    required this.privacyOptionsRequirementStatus,
    this.requestErrorCode,
    this.formErrorCode,
  });

  final bool canRequestAds;
  final ConsentStatus consentStatus;
  final PrivacyOptionsRequirementStatus privacyOptionsRequirementStatus;
  final int? requestErrorCode;
  final int? formErrorCode;
}

typedef LoadAndShowConsentFormIfRequired =
    Future<void> Function(OnConsentFormDismissedListener listener);

typedef ShowPrivacyOptionsForm =
    Future<void> Function(OnConsentFormDismissedListener listener);

abstract interface class AdConsentService {
  Future<AdConsentResult> gatherConsent();

  Future<AdConsentResult> loadCurrentConsentState();

  Future<AdConsentResult> showPrivacyOptions();
}

class UmpAdConsentService implements AdConsentService {
  UmpAdConsentService({
    ConsentInformation? consentInformation,
    ConsentRequestParameters? requestParameters,
    LoadAndShowConsentFormIfRequired? loadAndShowConsentFormIfRequired,
    ShowPrivacyOptionsForm? showPrivacyOptionsForm,
  }) : _consentInformation = consentInformation ?? ConsentInformation.instance,
       _requestParameters = requestParameters ?? ConsentRequestParameters(),
       _loadAndShowConsentFormIfRequired =
           loadAndShowConsentFormIfRequired ??
           ConsentForm.loadAndShowConsentFormIfRequired,
       _showPrivacyOptionsForm =
           showPrivacyOptionsForm ?? ConsentForm.showPrivacyOptionsForm;

  final ConsentInformation _consentInformation;
  final ConsentRequestParameters _requestParameters;
  final LoadAndShowConsentFormIfRequired _loadAndShowConsentFormIfRequired;
  final ShowPrivacyOptionsForm _showPrivacyOptionsForm;

  @override
  Future<AdConsentResult> gatherConsent() async {
    if (kIsWeb) {
      return _webConsentResult();
    }

    int? requestErrorCode;
    int? formErrorCode;

    try {
      await _requestConsentInfoUpdate();
    } on FormError catch (error, stackTrace) {
      requestErrorCode = error.errorCode;
      AppLogger.warning(
        'UMP consent info update failed; using cached consent state if available.',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UMP consent info update threw an unexpected error.',
        error,
        stackTrace,
      );
    }

    var canRequestAds = await _safeCanRequestAds();
    if (!canRequestAds) {
      try {
        await _loadAndShowConsentFormIfRequired((formError) {
          formErrorCode = formError?.errorCode;
          if (formError != null) {
            AppLogger.warning(
              'UMP consent form dismissed with an error.',
              formError.message,
            );
          }
        });
      } catch (error, stackTrace) {
        AppLogger.warning(
          'UMP loadAndShowConsentFormIfRequired threw an unexpected error.',
          error,
          stackTrace,
        );
      }
      canRequestAds = await _safeCanRequestAds();
    }

    return AdConsentResult(
      canRequestAds: canRequestAds,
      consentStatus: await _safeConsentStatus(),
      privacyOptionsRequirementStatus:
          await _safePrivacyOptionsRequirementStatus(),
      requestErrorCode: requestErrorCode,
      formErrorCode: formErrorCode,
    );
  }

  @override
  Future<AdConsentResult> loadCurrentConsentState() async {
    if (kIsWeb) {
      return _webConsentResult();
    }

    int? requestErrorCode;
    try {
      await _requestConsentInfoUpdate();
    } on FormError catch (error, stackTrace) {
      requestErrorCode = error.errorCode;
      AppLogger.warning(
        'UMP consent state refresh failed; using cached consent state if available.',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UMP consent state refresh threw an unexpected error.',
        error,
        stackTrace,
      );
    }

    return AdConsentResult(
      canRequestAds: await _safeCanRequestAds(),
      consentStatus: await _safeConsentStatus(),
      privacyOptionsRequirementStatus:
          await _safePrivacyOptionsRequirementStatus(),
      requestErrorCode: requestErrorCode,
    );
  }

  @override
  Future<AdConsentResult> showPrivacyOptions() async {
    if (kIsWeb) {
      return _webConsentResult();
    }

    final currentState = await loadCurrentConsentState();
    if (currentState.privacyOptionsRequirementStatus !=
        PrivacyOptionsRequirementStatus.required) {
      return currentState;
    }

    int? formErrorCode;
    try {
      await _showPrivacyOptionsForm((formError) {
        formErrorCode = formError?.errorCode;
        if (formError != null) {
          AppLogger.warning(
            'UMP privacy options form dismissed with an error.',
            formError.message,
          );
        }
      });
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UMP showPrivacyOptionsForm threw an unexpected error.',
        error,
        stackTrace,
      );
    }

    final refreshedState = await loadCurrentConsentState();
    return AdConsentResult(
      canRequestAds: refreshedState.canRequestAds,
      consentStatus: refreshedState.consentStatus,
      privacyOptionsRequirementStatus:
          refreshedState.privacyOptionsRequirementStatus,
      requestErrorCode: refreshedState.requestErrorCode,
      formErrorCode: formErrorCode,
    );
  }

  AdConsentResult _webConsentResult() {
    return const AdConsentResult(
      canRequestAds: false,
      consentStatus: ConsentStatus.unknown,
      privacyOptionsRequirementStatus: PrivacyOptionsRequirementStatus.unknown,
    );
  }

  Future<void> _requestConsentInfoUpdate() {
    final completer = Completer<void>();
    _consentInformation.requestConsentInfoUpdate(
      _requestParameters,
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    return completer.future;
  }

  Future<bool> _safeCanRequestAds() async {
    try {
      return await _consentInformation.canRequestAds();
    } catch (error, stackTrace) {
      AppLogger.warning('UMP canRequestAds check failed.', error, stackTrace);
      return false;
    }
  }

  Future<ConsentStatus> _safeConsentStatus() async {
    try {
      return await _consentInformation.getConsentStatus();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UMP getConsentStatus check failed.',
        error,
        stackTrace,
      );
      return ConsentStatus.unknown;
    }
  }

  Future<PrivacyOptionsRequirementStatus>
  _safePrivacyOptionsRequirementStatus() async {
    try {
      return await _consentInformation.getPrivacyOptionsRequirementStatus();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'UMP getPrivacyOptionsRequirementStatus check failed.',
        error,
        stackTrace,
      );
      return PrivacyOptionsRequirementStatus.unknown;
    }
  }
}

AdConsentService createDefaultAdConsentService() {
  return UmpAdConsentService();
}
