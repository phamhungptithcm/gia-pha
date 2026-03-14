import '../models/auth_issue.dart';

class ChildIdentifierFormatter {
  const ChildIdentifierFormatter._();

  static String normalize(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const AuthIssueException(
        AuthIssue(AuthIssueKey.childIdentifierRequired),
      );
    }

    final normalized = trimmed
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '');

    if (normalized.length < 4) {
      throw const AuthIssueException(
        AuthIssue(AuthIssueKey.childIdentifierInvalid),
      );
    }

    return normalized;
  }
}
