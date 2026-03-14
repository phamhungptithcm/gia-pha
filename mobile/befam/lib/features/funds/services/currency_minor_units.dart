class CurrencyMinorUnits {
  CurrencyMinorUnits._();

  static const Map<String, int> _minorUnitsByCurrency = {
    'VND': 0,
    'JPY': 0,
    'KRW': 0,
    'USD': 2,
    'EUR': 2,
    'GBP': 2,
    'AUD': 2,
    'CAD': 2,
    'SGD': 2,
  };

  static String normalizeCurrencyCode(String currency) {
    return currency.trim().toUpperCase();
  }

  static bool isValidCurrencyCode(String currency) {
    final normalized = normalizeCurrencyCode(currency);
    return RegExp(r'^[A-Z]{3}$').hasMatch(normalized);
  }

  static int minorUnitsFor(String currency) {
    final normalized = normalizeCurrencyCode(currency);
    return _minorUnitsByCurrency[normalized] ?? 2;
  }

  static int toMinorUnits({
    required String currency,
    required String amountInput,
  }) {
    final normalizedCurrency = normalizeCurrencyCode(currency);
    if (!isValidCurrencyCode(normalizedCurrency)) {
      throw const FormatException('invalid_currency');
    }

    final compact = amountInput.replaceAll(',', '').replaceAll(' ', '').trim();
    if (compact.isEmpty) {
      throw const FormatException('amount_required');
    }

    if (!RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(compact)) {
      throw const FormatException('invalid_amount');
    }

    final sign = compact.startsWith('-') ? -1 : 1;
    final digits = (compact.startsWith('-') || compact.startsWith('+'))
        ? compact.substring(1)
        : compact;

    final parts = digits.split('.');
    final wholePart = parts[0];
    final fractionPart = parts.length > 1 ? parts[1] : '';
    final fractionDigits = minorUnitsFor(normalizedCurrency);

    if (fractionDigits == 0) {
      if (fractionPart.isNotEmpty && int.tryParse(fractionPart) != 0) {
        throw const FormatException('fraction_not_supported');
      }

      return sign * int.parse(wholePart);
    }

    if (fractionPart.length > fractionDigits) {
      throw const FormatException('too_many_fraction_digits');
    }

    final paddedFraction = fractionPart.padRight(fractionDigits, '0');
    final wholeMinor = int.parse(wholePart) * _pow10(fractionDigits);
    final fractionMinor = int.parse(paddedFraction);
    return sign * (wholeMinor + fractionMinor);
  }

  static String formatMinorUnits({
    required int amountMinor,
    required String currency,
  }) {
    final normalizedCurrency = normalizeCurrencyCode(currency);
    final fractionDigits = minorUnitsFor(normalizedCurrency);
    final negative = amountMinor < 0;
    final absoluteMinor = amountMinor.abs();

    if (fractionDigits == 0) {
      final whole = _groupThousands(absoluteMinor.toString());
      return '${negative ? '-' : ''}$whole $normalizedCurrency';
    }

    final divisor = _pow10(fractionDigits);
    final wholePart = absoluteMinor ~/ divisor;
    final fractionPart = absoluteMinor % divisor;

    final wholeText = _groupThousands(wholePart.toString());
    final fractionText = fractionPart.toString().padLeft(fractionDigits, '0');

    return '${negative ? '-' : ''}$wholeText.$fractionText $normalizedCurrency';
  }

  static int _pow10(int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }

  static String _groupThousands(String digits) {
    if (digits.length <= 3) {
      return digits;
    }

    final buffer = StringBuffer();
    final firstGroup = digits.length % 3;
    var offset = 0;

    if (firstGroup != 0) {
      buffer.write(digits.substring(0, firstGroup));
      offset = firstGroup;
      if (offset < digits.length) {
        buffer.write(',');
      }
    }

    while (offset < digits.length) {
      buffer.write(digits.substring(offset, offset + 3));
      offset += 3;
      if (offset < digits.length) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }
}
