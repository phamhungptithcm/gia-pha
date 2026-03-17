import 'package:flutter/services.dart';

enum VnpayCheckoutOpenStatus { sdk, inAppBrowser, externalBrowser, failed }

class VnpayCheckoutOpenResult {
  const VnpayCheckoutOpenResult({required this.status, this.message});

  final VnpayCheckoutOpenStatus status;
  final String? message;
}

typedef ExternalVnpayFallbackLauncher = Future<bool> Function(Uri uri);

abstract interface class VnpayMobileSdkGateway {
  Future<VnpayCheckoutOpenResult> openCheckout({required Uri checkoutUri});
}

class MethodChannelVnpayMobileSdkGateway implements VnpayMobileSdkGateway {
  MethodChannelVnpayMobileSdkGateway({
    MethodChannel? channel,
    ExternalVnpayFallbackLauncher? externalFallbackLauncher,
  }) : _channel = channel ?? _defaultChannel,
       _externalFallbackLauncher = externalFallbackLauncher;

  static const MethodChannel _defaultChannel = MethodChannel(
    'befam.vnpay/mobile_sdk',
  );

  final MethodChannel _channel;
  final ExternalVnpayFallbackLauncher? _externalFallbackLauncher;

  @override
  Future<VnpayCheckoutOpenResult> openCheckout({
    required Uri checkoutUri,
  }) async {
    try {
      final response = await _channel.invokeMethod<Object?>('openCheckout', {
        'checkoutUrl': checkoutUri.toString(),
      });
      final map = _asStringMap(response);
      final status = (map['status'] ?? '').trim().toLowerCase();
      final message = map['message'];
      if (status == 'sdk') {
        return VnpayCheckoutOpenResult(
          status: VnpayCheckoutOpenStatus.sdk,
          message: message,
        );
      }
      if (status == 'in_app_browser') {
        return VnpayCheckoutOpenResult(
          status: VnpayCheckoutOpenStatus.inAppBrowser,
          message: message,
        );
      }
      if (status == 'external_browser') {
        return VnpayCheckoutOpenResult(
          status: VnpayCheckoutOpenStatus.externalBrowser,
          message: message,
        );
      }
      final fallback = await _openExternalFallback(checkoutUri);
      if (fallback != null) {
        return fallback;
      }
      return VnpayCheckoutOpenResult(
        status: VnpayCheckoutOpenStatus.failed,
        message: message,
      );
    } on MissingPluginException {
      final fallback = await _openExternalFallback(checkoutUri);
      if (fallback != null) {
        return fallback;
      }
      return const VnpayCheckoutOpenResult(
        status: VnpayCheckoutOpenStatus.failed,
        message: 'VNPay gateway is unavailable on this build.',
      );
    } on PlatformException catch (error) {
      final fallback = await _openExternalFallback(checkoutUri);
      if (fallback != null) {
        return fallback;
      }
      return VnpayCheckoutOpenResult(
        status: VnpayCheckoutOpenStatus.failed,
        message: error.message,
      );
    } catch (error) {
      final fallback = await _openExternalFallback(checkoutUri);
      if (fallback != null) {
        return fallback;
      }
      return VnpayCheckoutOpenResult(
        status: VnpayCheckoutOpenStatus.failed,
        message: '$error',
      );
    }
  }

  Future<VnpayCheckoutOpenResult?> _openExternalFallback(
    Uri checkoutUri,
  ) async {
    final fallbackLauncher = _externalFallbackLauncher;
    if (fallbackLauncher == null) {
      return null;
    }
    try {
      final opened = await fallbackLauncher(checkoutUri);
      if (!opened) {
        return const VnpayCheckoutOpenResult(
          status: VnpayCheckoutOpenStatus.failed,
        );
      }
      return const VnpayCheckoutOpenResult(
        status: VnpayCheckoutOpenStatus.externalBrowser,
      );
    } catch (error) {
      return VnpayCheckoutOpenResult(
        status: VnpayCheckoutOpenStatus.failed,
        message: '$error',
      );
    }
  }

  Map<String, String> _asStringMap(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final output = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String) {
        continue;
      }
      if (value is String) {
        output[key] = value;
      } else if (value != null) {
        output[key] = '$value';
      }
    }
    return output;
  }
}
