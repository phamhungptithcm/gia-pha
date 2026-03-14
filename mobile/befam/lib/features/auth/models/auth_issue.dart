enum AuthIssueKey {
  restoreSessionFailed,
  requestOtpBeforeVerify,
  otpMustBeSixDigits,
  phoneRequired,
  phoneInvalidFormat,
  childIdentifierRequired,
  childIdentifierInvalid,
  invalidPhoneNumber,
  invalidVerificationCode,
  sessionExpired,
  networkRequestFailed,
  tooManyRequests,
  quotaExceeded,
  userNotFound,
  operationNotAllowed,
  authUnavailable,
  preparationFailed,
}

class AuthIssue {
  const AuthIssue(this.key);

  final AuthIssueKey key;
}

class AuthIssueException implements Exception {
  const AuthIssueException(this.issue);

  final AuthIssue issue;
}
