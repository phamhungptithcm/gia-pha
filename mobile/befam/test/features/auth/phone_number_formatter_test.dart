import 'package:befam/features/auth/services/phone_number_formatter.dart';
import 'package:befam/features/auth/models/auth_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumberFormatter', () {
    test('parses Vietnam local numbers to E.164 by default', () {
      final parsed = PhoneNumberFormatter.parse('0901234567');
      expect(parsed.e164, '+84901234567');
    });

    test('parses local number with selected country code', () {
      final parsed = PhoneNumberFormatter.parse(
        '6505551234',
        defaultCountryIso: 'US',
      );
      expect(parsed.e164, '+16505551234');
    });

    test('matches equivalent Vietnamese phone formats', () {
      final matched = PhoneNumberFormatter.areEquivalent(
        '+84901234567',
        '0901234567',
      );
      expect(matched, isTrue);
    });

    test('matches equivalent international phone formats', () {
      final matched = PhoneNumberFormatter.areEquivalent(
        '+16505551234',
        '6505551234',
        defaultCountryIso: 'US',
      );
      expect(matched, isTrue);
    });

    test('accepts VN number with or without leading zero', () {
      final withZero = PhoneNumberFormatter.parse(
        '0901234567',
        defaultCountryIso: 'VN',
      );
      final withoutZero = PhoneNumberFormatter.parse(
        '901234567',
        defaultCountryIso: 'VN',
      );
      expect(withZero.e164, '+84901234567');
      expect(withoutZero.e164, '+84901234567');
    });

    test('rejects US number if user starts with trunk zero', () {
      expect(
        () =>
            PhoneNumberFormatter.parse('06505551234', defaultCountryIso: 'US'),
        throwsA(
          isA<AuthIssueException>().having(
            (error) => error.issue.key,
            'issue',
            AuthIssueKey.phoneInvalidFormat,
          ),
        ),
      );
    });

    test('auto country resolves VN/US/CA by region code', () {
      expect(PhoneNumberFormatter.autoCountryIsoFromRegion('VN'), 'VN');
      expect(PhoneNumberFormatter.autoCountryIsoFromRegion('US'), 'US');
      expect(PhoneNumberFormatter.autoCountryIsoFromRegion('CA'), 'CA');
      expect(
        PhoneNumberFormatter.autoCountryIsoFromRegion('DE'),
        PhoneNumberFormatter.defaultCountryIsoCode,
      );
    });

    test('formats e164 to national input for trunk-zero countries', () {
      final display = PhoneNumberFormatter.toNationalInput(
        '+84901234567',
        defaultCountryIso: 'VN',
      );
      expect(display, '0901234567');
    });

    test('formats e164 to national input for non-trunk-zero countries', () {
      final display = PhoneNumberFormatter.toNationalInput(
        '+16505551234',
        defaultCountryIso: 'US',
      );
      expect(display, '6505551234');
    });
  });
}
