import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/app_logger.dart';

enum StoreIapPurchaseStatus { succeeded, canceled, failed }

class StoreIapPurchaseResult {
  const StoreIapPurchaseResult({
    required this.status,
    required this.platform,
    required this.productId,
    required this.payload,
    required this.errorMessage,
  });

  final StoreIapPurchaseStatus status;
  final String platform;
  final String productId;
  final Map<String, dynamic> payload;
  final String? errorMessage;

  bool get succeeded => status == StoreIapPurchaseStatus.succeeded;
  bool get canceled => status == StoreIapPurchaseStatus.canceled;
}

abstract interface class StoreIapGateway {
  Future<StoreIapPurchaseResult> purchaseSubscription({
    required String productId,
  });
}

class DefaultStoreIapGateway implements StoreIapGateway {
  DefaultStoreIapGateway({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  static const Duration _purchaseTimeout = Duration(minutes: 2);

  @override
  Future<StoreIapPurchaseResult> purchaseSubscription({
    required String productId,
  }) async {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty) {
      return StoreIapPurchaseResult(
        status: StoreIapPurchaseStatus.failed,
        platform: _platformForStore(),
        productId: productId,
        payload: const <String, dynamic>{},
        errorMessage: 'productId is required.',
      );
    }

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      return StoreIapPurchaseResult(
        status: StoreIapPurchaseStatus.failed,
        platform: _platformForStore(),
        productId: normalizedProductId,
        payload: const <String, dynamic>{},
        errorMessage: 'Store billing is not available on this device.',
      );
    }

    final productResponse = await _inAppPurchase.queryProductDetails({
      normalizedProductId,
    });
    if (productResponse.error case final error?) {
      return StoreIapPurchaseResult(
        status: StoreIapPurchaseStatus.failed,
        platform: _platformForStore(),
        productId: normalizedProductId,
        payload: const <String, dynamic>{},
        errorMessage: error.message,
      );
    }
    ProductDetails? productDetails;
    for (final item in productResponse.productDetails) {
      if (item.id == normalizedProductId) {
        productDetails = item;
        break;
      }
    }
    if (productDetails == null) {
      return StoreIapPurchaseResult(
        status: StoreIapPurchaseStatus.failed,
        platform: _platformForStore(),
        productId: normalizedProductId,
        payload: const <String, dynamic>{},
        errorMessage: 'Could not load product details from store.',
      );
    }

    final completer = Completer<StoreIapPurchaseResult>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _inAppPurchase.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != normalizedProductId) {
            continue;
          }
          if (purchase.status == PurchaseStatus.pending) {
            continue;
          }
          if (purchase.pendingCompletePurchase) {
            try {
              await _inAppPurchase.completePurchase(purchase);
            } catch (error, stackTrace) {
              AppLogger.warning(
                'Failed to complete store purchase.',
                error,
                stackTrace,
              );
            }
          }

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            if (!completer.isCompleted) {
              completer.complete(
                StoreIapPurchaseResult(
                  status: StoreIapPurchaseStatus.succeeded,
                  platform: _platformForStore(),
                  productId: normalizedProductId,
                  payload: <String, dynamic>{
                    'productId': normalizedProductId,
                    'purchaseId': purchase.purchaseID,
                    'transactionDate': purchase.transactionDate,
                    'verificationData':
                        purchase.verificationData.serverVerificationData,
                    'verificationSource': purchase.verificationData.source,
                    'localVerificationData':
                        purchase.verificationData.localVerificationData,
                  },
                  errorMessage: null,
                ),
              );
            }
            continue;
          }

          if (purchase.status == PurchaseStatus.canceled) {
            if (!completer.isCompleted) {
              completer.complete(
                StoreIapPurchaseResult(
                  status: StoreIapPurchaseStatus.canceled,
                  platform: _platformForStore(),
                  productId: normalizedProductId,
                  payload: const <String, dynamic>{},
                  errorMessage: null,
                ),
              );
            }
            continue;
          }

          final purchaseError = purchase.error;
          if (!completer.isCompleted) {
            completer.complete(
              StoreIapPurchaseResult(
                status: StoreIapPurchaseStatus.failed,
                platform: _platformForStore(),
                productId: normalizedProductId,
                payload: const <String, dynamic>{},
                errorMessage:
                    purchaseError?.message ?? 'Store purchase failed.',
              ),
            );
          }
        }
      },
      onError: (error, stackTrace) {
        AppLogger.warning('Store purchase stream failed.', error, stackTrace);
        if (!completer.isCompleted) {
          completer.complete(
            StoreIapPurchaseResult(
              status: StoreIapPurchaseStatus.failed,
              platform: _platformForStore(),
              productId: normalizedProductId,
              payload: const <String, dynamic>{},
              errorMessage: '$error',
            ),
          );
        }
      },
    );

    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: productDetails),
      );
      if (!started) {
        return StoreIapPurchaseResult(
          status: StoreIapPurchaseStatus.failed,
          platform: _platformForStore(),
          productId: normalizedProductId,
          payload: const <String, dynamic>{},
          errorMessage: 'Could not start store checkout.',
        );
      }
      return await completer.future.timeout(
        _purchaseTimeout,
        onTimeout: () => StoreIapPurchaseResult(
          status: StoreIapPurchaseStatus.failed,
          platform: _platformForStore(),
          productId: normalizedProductId,
          payload: const <String, dynamic>{},
          errorMessage: 'Timed out waiting for purchase confirmation.',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }
}

StoreIapGateway createDefaultStoreIapGateway() {
  return DefaultStoreIapGateway();
}

String _platformForStore() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    _ => 'android',
  };
}
