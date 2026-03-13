class ParsedPhoneNumber {
  const ParsedPhoneNumber({required this.rawInput, required this.e164});

  final String rawInput;
  final String e164;
}

class PhoneNumberFormatter {
  const PhoneNumberFormatter._();

  static ParsedPhoneNumber parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Enter your phone number to continue.');
    }

    final digitsAndPlus = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    late final String normalized;

    if (digitsAndPlus.startsWith('+')) {
      normalized =
          '+${digitsAndPlus.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else if (digitsAndPlus.startsWith('00')) {
      normalized = '+${digitsAndPlus.substring(2)}';
    } else if (digitsAndPlus.startsWith('0')) {
      normalized = '+84${digitsAndPlus.substring(1)}';
    } else {
      normalized = '+$digitsAndPlus';
    }

    if (!RegExp(r'^\+[1-9]\d{8,14}$').hasMatch(normalized)) {
      throw FormatException(
        'Enter a valid phone number with country code or local Vietnamese format.',
      );
    }

    return ParsedPhoneNumber(rawInput: trimmed, e164: normalized);
  }

  static String mask(String phoneE164) {
    if (phoneE164.length <= 6) {
      return phoneE164;
    }

    final visiblePrefix = phoneE164.substring(0, 3);
    final visibleSuffix = phoneE164.substring(phoneE164.length - 2);
    final hiddenLength =
        phoneE164.length - visiblePrefix.length - visibleSuffix.length;
    final hidden = List.filled(hiddenLength, '*').join();
    return '$visiblePrefix$hidden$visibleSuffix';
  }
}
