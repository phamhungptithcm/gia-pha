import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdResponseDiagnostics {
  const AdResponseDiagnostics({
    this.responseId,
    this.mediationAdapterClassName,
    this.loadedAdapterClassName,
    this.mediationGroupName,
    this.mediationAbTestName,
    this.mediationAbTestVariant,
  });

  factory AdResponseDiagnostics.fromResponseInfo(ResponseInfo? responseInfo) {
    final responseExtras =
        responseInfo?.responseExtras ?? const <String, dynamic>{};
    return AdResponseDiagnostics(
      responseId: _normalizeDiagnosticValue(responseInfo?.responseId),
      mediationAdapterClassName: _normalizeDiagnosticValue(
        responseInfo?.mediationAdapterClassName,
      ),
      loadedAdapterClassName: _normalizeDiagnosticValue(
        responseInfo?.loadedAdapterResponseInfo?.adapterClassName,
      ),
      mediationGroupName: _normalizeDiagnosticValue(
        responseExtras['mediation_group_name'],
      ),
      mediationAbTestName: _normalizeDiagnosticValue(
        responseExtras['mediation_ab_test_name'],
      ),
      mediationAbTestVariant: _normalizeDiagnosticValue(
        responseExtras['mediation_ab_test_variant'],
      ),
    );
  }

  final String? responseId;
  final String? mediationAdapterClassName;
  final String? loadedAdapterClassName;
  final String? mediationGroupName;
  final String? mediationAbTestName;
  final String? mediationAbTestVariant;

  bool get hasAnyValue =>
      responseId != null ||
      mediationAdapterClassName != null ||
      loadedAdapterClassName != null ||
      mediationGroupName != null ||
      mediationAbTestName != null ||
      mediationAbTestVariant != null;
}

class AdPaidEvent {
  const AdPaidEvent({
    required this.valueMicros,
    required this.currencyCode,
    required this.precision,
    this.responseDiagnostics,
  });

  factory AdPaidEvent.fromAdValue({
    required double valueMicros,
    required PrecisionType precision,
    required String currencyCode,
    ResponseInfo? responseInfo,
  }) {
    final responseDiagnostics = AdResponseDiagnostics.fromResponseInfo(
      responseInfo,
    );
    return AdPaidEvent(
      valueMicros: valueMicros,
      currencyCode: currencyCode,
      precision: _precisionTypeName(precision),
      responseDiagnostics: responseDiagnostics.hasAnyValue
          ? responseDiagnostics
          : null,
    );
  }

  final double valueMicros;
  final String currencyCode;
  final String precision;
  final AdResponseDiagnostics? responseDiagnostics;
}

String? _normalizeDiagnosticValue(Object? value) {
  final normalized = '$value'.trim();
  if (normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

String _precisionTypeName(PrecisionType precision) {
  return switch (precision) {
    PrecisionType.estimated => 'estimated',
    PrecisionType.precise => 'precise',
    PrecisionType.publisherProvided => 'publisher_provided',
    PrecisionType.unknown => 'unknown',
  };
}
