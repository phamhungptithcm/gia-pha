import 'package:intl/intl.dart';

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
    String? locale,
  }) {
    final normalizedCurrency = normalizeCurrencyCode(currency);
    final fractionDigits = minorUnitsFor(normalizedCurrency);
    final resolvedLocale = (locale ?? '').trim().isEmpty
        ? Intl.getCurrentLocale()
        : locale!.trim();
    final divisor = _pow10(fractionDigits);
    final value = amountMinor / divisor;

    final formatter = NumberFormat.decimalPattern(resolvedLocale)
      ..minimumFractionDigits = fractionDigits
      ..maximumFractionDigits = fractionDigits;

    return '${formatter.format(value)} $normalizedCurrency';
  }

  static int _pow10(int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }
}
