import '../models/auth_issue.dart';

class ParsedPhoneNumber {
  const ParsedPhoneNumber({required this.rawInput, required this.e164});

  final String rawInput;
  final String e164;
}

class PhoneCountryOption {
  const PhoneCountryOption({
    required this.isoCode,
    required this.dialCode,
    required this.flagEmoji,
    required this.nationalExample,
    required this.labelVi,
    required this.labelEn,
    this.allowTrunkPrefixZero = false,
  });

  final String isoCode;
  final String dialCode;
  final String flagEmoji;
  final String nationalExample;
  final String labelVi;
  final String labelEn;
  final bool allowTrunkPrefixZero;

  String displayLabel({required bool isVietnamese}) {
    final base = isVietnamese ? labelVi : labelEn;
    return '$base ($dialCode)';
  }
}

class PhoneNumberFormatter {
  const PhoneNumberFormatter._();

  static const String defaultCountryIsoCode = 'VN';

  static const List<PhoneCountryOption> supportedCountries = [
    PhoneCountryOption(
      isoCode: 'VN',
      dialCode: '+84',
      flagEmoji: '🇻🇳',
      nationalExample: '0901234567',
      labelVi: 'Việt Nam',
      labelEn: 'Vietnam',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'US',
      dialCode: '+1',
      flagEmoji: '🇺🇸',
      nationalExample: '6505551234',
      labelVi: 'Hoa Kỳ',
      labelEn: 'United States',
    ),
    PhoneCountryOption(
      isoCode: 'CA',
      dialCode: '+1',
      flagEmoji: '🇨🇦',
      nationalExample: '4165551234',
      labelVi: 'Canada',
      labelEn: 'Canada',
    ),
    PhoneCountryOption(
      isoCode: 'AU',
      dialCode: '+61',
      flagEmoji: '🇦🇺',
      nationalExample: '0412345678',
      labelVi: 'Úc',
      labelEn: 'Australia',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'JP',
      dialCode: '+81',
      flagEmoji: '🇯🇵',
      nationalExample: '09012345678',
      labelVi: 'Nhật Bản',
      labelEn: 'Japan',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'KR',
      dialCode: '+82',
      flagEmoji: '🇰🇷',
      nationalExample: '01012345678',
      labelVi: 'Hàn Quốc',
      labelEn: 'South Korea',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'SG',
      dialCode: '+65',
      flagEmoji: '🇸🇬',
      nationalExample: '81234567',
      labelVi: 'Singapore',
      labelEn: 'Singapore',
    ),
    PhoneCountryOption(
      isoCode: 'TW',
      dialCode: '+886',
      flagEmoji: '🇹🇼',
      nationalExample: '0912345678',
      labelVi: 'Đài Loan',
      labelEn: 'Taiwan',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'DE',
      dialCode: '+49',
      flagEmoji: '🇩🇪',
      nationalExample: '015112345678',
      labelVi: 'Đức',
      labelEn: 'Germany',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'FR',
      dialCode: '+33',
      flagEmoji: '🇫🇷',
      nationalExample: '0612345678',
      labelVi: 'Pháp',
      labelEn: 'France',
      allowTrunkPrefixZero: true,
    ),
    PhoneCountryOption(
      isoCode: 'GB',
      dialCode: '+44',
      flagEmoji: '🇬🇧',
      nationalExample: '07123456789',
      labelVi: 'Vương quốc Anh',
      labelEn: 'United Kingdom',
      allowTrunkPrefixZero: true,
    ),
  ];

  static ParsedPhoneNumber parse(String input, {String? defaultCountryIso}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const AuthIssueException(AuthIssue(AuthIssueKey.phoneRequired));
    }

    final digitsAndPlus = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsAndPlus.isEmpty) {
      throw const AuthIssueException(
        AuthIssue(AuthIssueKey.phoneInvalidFormat),
      );
    }

    final fallbackCountry = resolveCountryOption(defaultCountryIso);
    final fallbackDialDigits = fallbackCountry.dialCode.substring(1);
    final digitsOnly = digitsAndPlus.replaceAll(RegExp(r'[^0-9]'), '');
    late String normalized;

    if (digitsAndPlus.startsWith('+')) {
      normalized =
          '+${digitsAndPlus.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else if (digitsAndPlus.startsWith('00')) {
      normalized =
          '+${digitsAndPlus.substring(2).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else if (digitsOnly.startsWith('0')) {
      if (!fallbackCountry.allowTrunkPrefixZero) {
        throw const AuthIssueException(
          AuthIssue(AuthIssueKey.phoneInvalidFormat),
        );
      }
      final nationalDigits = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
      if (nationalDigits.isEmpty) {
        throw const AuthIssueException(
          AuthIssue(AuthIssueKey.phoneInvalidFormat),
        );
      }
      normalized = '+$fallbackDialDigits$nationalDigits';
    } else if (_looksLikeInternationalNumber(digitsOnly, fallbackDialDigits)) {
      normalized = '+$digitsOnly';
    } else {
      normalized = '+$fallbackDialDigits$digitsOnly';
    }

    normalized = _normalizeTrunkPrefix(normalized);

    if (!RegExp(r'^\+[1-9]\d{8,14}$').hasMatch(normalized)) {
      throw const AuthIssueException(
        AuthIssue(AuthIssueKey.phoneInvalidFormat),
      );
    }

    return ParsedPhoneNumber(rawInput: trimmed, e164: normalized);
  }

  static String? tryParseE164(String? input, {String? defaultCountryIso}) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return parse(trimmed, defaultCountryIso: defaultCountryIso).e164;
    } catch (_) {
      return null;
    }
  }

  static bool areEquivalent(
    String? left,
    String? right, {
    String? defaultCountryIso,
  }) {
    final leftKeys = comparisonKeys(left, defaultCountryIso: defaultCountryIso);
    final rightKeys = comparisonKeys(
      right,
      defaultCountryIso: defaultCountryIso,
    );
    if (leftKeys.isEmpty || rightKeys.isEmpty) {
      return false;
    }
    for (final candidate in leftKeys) {
      if (rightKeys.contains(candidate)) {
        return true;
      }
    }
    return false;
  }

  static Set<String> comparisonKeys(
    String? input, {
    String? defaultCountryIso,
  }) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const <String>{};
    }

    final keys = <String>{};
    final e164 = tryParseE164(trimmed, defaultCountryIso: defaultCountryIso);
    if (e164 != null) {
      keys.add(e164);
      keys.add(e164.substring(1));
      final split = _splitCountryAndNational(e164);
      if (split != null) {
        final national = split.nationalDigits;
        if (national.isNotEmpty) {
          keys.add(national);
          if (!national.startsWith('0')) {
            keys.add('0$national');
          }
          keys.add('${split.country.dialCode.substring(1)}$national');
        }
      }
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      keys.add(digits);
    }
    final plusAndDigits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (plusAndDigits.startsWith('+') && plusAndDigits.length > 1) {
      keys.add(
        '+${plusAndDigits.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}',
      );
    }

    return keys;
  }

  static List<String> lookupVariants(
    String input, {
    String? defaultCountryIso,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final variants = <String>{};
    final e164 = tryParseE164(trimmed, defaultCountryIso: defaultCountryIso);
    if (e164 != null) {
      variants.add(e164);
      variants.add(e164.substring(1));
      final split = _splitCountryAndNational(e164);
      if (split != null) {
        final countryDigits = split.country.dialCode.substring(1);
        final national = split.nationalDigits;
        if (national.isNotEmpty) {
          variants.add(national);
          variants.add('0$national');
          variants.add('$countryDigits$national');
          variants.add('+$countryDigits$national');
        }
      }
    }

    variants.add(trimmed);
    variants.add(trimmed.replaceAll(RegExp(r'\s+'), ''));

    return variants
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static PhoneCountryOption resolveCountryOption(String? isoCode) {
    final normalized = (isoCode ?? '').trim().toUpperCase();
    for (final option in supportedCountries) {
      if (option.isoCode == normalized) {
        return option;
      }
    }
    return supportedCountries.first;
  }

  static String autoCountryIsoFromRegion(String? regionCode) {
    final normalized = (regionCode ?? '').trim().toUpperCase();
    switch (normalized) {
      case 'VN':
        return 'VN';
      case 'US':
        return 'US';
      case 'CA':
        return 'CA';
      default:
        return defaultCountryIsoCode;
    }
  }

  static String nationalNumberHint(String? isoCode) {
    return resolveCountryOption(isoCode).nationalExample;
  }

  static String phoneInputGuidance(
    String? isoCode, {
    required bool isVietnamese,
  }) {
    final country = resolveCountryOption(isoCode);
    if (country.allowTrunkPrefixZero) {
      return isVietnamese
          ? 'Có thể nhập với hoặc không có số 0 đầu. Ví dụ: ${country.nationalExample}'
          : 'You can enter with or without a leading 0. Example: ${country.nationalExample}';
    }
    return isVietnamese
        ? 'Nhập số nội địa, không cần ${country.dialCode} và không thêm số 0 ở đầu.'
        : 'Enter the national number only. Do not include ${country.dialCode} or a leading 0.';
  }

  static String toNationalInput(String? input, {String? defaultCountryIso}) {
    final trimmed = (input ?? '').trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final preferredCountry = resolveCountryOption(defaultCountryIso);
    final parsed = tryParseE164(
      trimmed,
      defaultCountryIso: preferredCountry.isoCode,
    );
    if (parsed != null) {
      final split = _splitCountryAndNational(parsed);
      if (split != null && split.nationalDigits.isNotEmpty) {
        if (split.country.allowTrunkPrefixZero &&
            !split.nationalDigits.startsWith('0')) {
          return '0${split.nationalDigits}';
        }
        return split.nationalDigits;
      }
      return parsed;
    }

    var normalized = trimmed.replaceAll(RegExp(r'\s+'), '');
    final preferredDialCode = preferredCountry.dialCode;
    if (normalized.startsWith(preferredDialCode)) {
      normalized = normalized.substring(preferredDialCode.length);
    } else if (normalized.startsWith(preferredDialCode.substring(1))) {
      normalized = normalized.substring(preferredDialCode.length - 1);
    } else if (normalized.startsWith('00${preferredDialCode.substring(1)}')) {
      normalized = normalized.substring(preferredDialCode.length + 1);
    }

    if (preferredCountry.allowTrunkPrefixZero &&
        normalized.isNotEmpty &&
        !normalized.startsWith('0')) {
      normalized = '0$normalized';
    }
    return normalized;
  }

  static PhoneCountryOption inferCountryOption(
    String? phone, {
    String fallbackIso = defaultCountryIsoCode,
  }) {
    final e164 = tryParseE164(phone, defaultCountryIso: fallbackIso);
    if (e164 == null) {
      return resolveCountryOption(fallbackIso);
    }
    final split = _splitCountryAndNational(e164);
    if (split == null) {
      return resolveCountryOption(fallbackIso);
    }
    return split.country;
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

  static bool _looksLikeInternationalNumber(
    String digits,
    String fallbackDialDigits,
  ) {
    return digits.isNotEmpty &&
        digits.startsWith(fallbackDialDigits) &&
        digits.length > fallbackDialDigits.length + 6;
  }

  static _CountrySplit? _splitCountryAndNational(String e164) {
    for (final option in _countriesByDialDesc) {
      if (e164.startsWith(option.dialCode) &&
          e164.length > option.dialCode.length) {
        return _CountrySplit(
          country: option,
          nationalDigits: e164.substring(option.dialCode.length),
        );
      }
    }
    return null;
  }

  static String _normalizeTrunkPrefix(String normalizedE164) {
    final split = _splitCountryAndNational(normalizedE164);
    if (split == null || !split.country.allowTrunkPrefixZero) {
      return normalizedE164;
    }
    final national = split.nationalDigits;
    if (!national.startsWith('0')) {
      return normalizedE164;
    }
    final trimmedNational = national.replaceFirst(RegExp(r'^0+'), '');
    if (trimmedNational.isEmpty) {
      return normalizedE164;
    }
    return '${split.country.dialCode}$trimmedNational';
  }

  static final List<PhoneCountryOption> _countriesByDialDesc =
      [...supportedCountries]..sort(
        (left, right) => right.dialCode.length.compareTo(left.dialCode.length),
      );
}

class _CountrySplit {
  const _CountrySplit({required this.country, required this.nationalDigits});

  final PhoneCountryOption country;
  final String nationalDigits;
}
