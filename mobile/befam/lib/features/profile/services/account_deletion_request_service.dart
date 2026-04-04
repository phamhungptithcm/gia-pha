import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/firebase_services.dart';

enum AccountDeletionRequestStateStatus {
  notRequested,
  pending,
  processing,
  completed,
}

enum AccountDeletionRequestServiceErrorCode {
  unauthenticated,
  permissionDenied,
  failedPrecondition,
  unavailable,
  unknown,
}

class AccountDeletionRequestServiceException implements Exception {
  const AccountDeletionRequestServiceException(this.code, [this.message]);

  final AccountDeletionRequestServiceErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

class AccountDeletionRequestState {
  const AccountDeletionRequestState({
    required this.status,
    this.requestedAtIso,
  });

  const AccountDeletionRequestState.notRequested()
    : status = AccountDeletionRequestStateStatus.notRequested,
      requestedAtIso = null;

  final AccountDeletionRequestStateStatus status;
  final String? requestedAtIso;

  bool get hasPendingRequest =>
      status == AccountDeletionRequestStateStatus.pending ||
      status == AccountDeletionRequestStateStatus.processing;
}

abstract interface class AccountDeletionRequestService {
  Future<AccountDeletionRequestState> loadStatus();

  Future<AccountDeletionRequestState> submitRequest({String? note});
}

class FirebaseAccountDeletionRequestService
    implements AccountDeletionRequestService {
  FirebaseAccountDeletionRequestService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  @override
  Future<AccountDeletionRequestState> loadStatus() async {
    try {
      final callable = _functions.httpsCallable(
        'getAccountDeletionRequestStatus',
      );
      final response = await callable.call();
      return _readState(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionRequestServiceException(
        _mapErrorCode(error.code),
        error.message,
      );
    } catch (error) {
      throw AccountDeletionRequestServiceException(
        AccountDeletionRequestServiceErrorCode.unknown,
        '$error',
      );
    }
  }

  @override
  Future<AccountDeletionRequestState> submitRequest({String? note}) async {
    try {
      final callable = _functions.httpsCallable('submitAccountDeletionRequest');
      final response = await callable.call(<String, dynamic>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
      return _readState(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionRequestServiceException(
        _mapErrorCode(error.code),
        error.message,
      );
    } catch (error) {
      throw AccountDeletionRequestServiceException(
        AccountDeletionRequestServiceErrorCode.unknown,
        '$error',
      );
    }
  }

  AccountDeletionRequestServiceErrorCode _mapErrorCode(String code) {
    return switch (code) {
      'unauthenticated' =>
        AccountDeletionRequestServiceErrorCode.unauthenticated,
      'permission-denied' =>
        AccountDeletionRequestServiceErrorCode.permissionDenied,
      'failed-precondition' =>
        AccountDeletionRequestServiceErrorCode.failedPrecondition,
      'unavailable' => AccountDeletionRequestServiceErrorCode.unavailable,
      _ => AccountDeletionRequestServiceErrorCode.unknown,
    };
  }

  AccountDeletionRequestState _readState(Object? payload) {
    final map = switch (payload) {
      Map<Object?, Object?> current => current,
      _ => const <Object?, Object?>{},
    };
    return AccountDeletionRequestState(
      status: _parseStatus(map['status']),
      requestedAtIso: _readString(map['requestedAtIso']),
    );
  }

  AccountDeletionRequestStateStatus _parseStatus(Object? value) {
    final normalized = _readString(value)?.toLowerCase() ?? '';
    return switch (normalized) {
      'pending' => AccountDeletionRequestStateStatus.pending,
      'processing' => AccountDeletionRequestStateStatus.processing,
      'completed' => AccountDeletionRequestStateStatus.completed,
      _ => AccountDeletionRequestStateStatus.notRequested,
    };
  }
}

AccountDeletionRequestService createDefaultAccountDeletionRequestService() {
  return FirebaseAccountDeletionRequestService();
}

String? _readString(Object? value) {
  return switch (value) {
    String current when current.trim().isNotEmpty => current.trim(),
    _ => null,
  };
}
