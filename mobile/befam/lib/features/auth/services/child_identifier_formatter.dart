class ChildIdentifierFormatter {
  const ChildIdentifierFormatter._();

  static String normalize(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Enter a child identifier to continue.');
    }

    final normalized = trimmed
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '');

    if (normalized.length < 4) {
      throw FormatException(
        'Enter a valid child identifier with at least 4 characters.',
      );
    }

    return normalized;
  }
}
