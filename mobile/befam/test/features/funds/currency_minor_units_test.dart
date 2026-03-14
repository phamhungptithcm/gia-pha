import 'package:befam/features/funds/services/currency_minor_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns expected minor units for VND and USD', () {
    expect(CurrencyMinorUnits.minorUnitsFor('VND'), 0);
    expect(CurrencyMinorUnits.minorUnitsFor('USD'), 2);
  });

  test('converts amount input to minor units', () {
    expect(
      CurrencyMinorUnits.toMinorUnits(currency: 'VND', amountInput: '500000'),
      500000,
    );
    expect(
      CurrencyMinorUnits.toMinorUnits(currency: 'USD', amountInput: '12.34'),
      1234,
    );
  });

  test('formats minor units to currency text', () {
    expect(
      CurrencyMinorUnits.formatMinorUnits(
        amountMinor: 2500000,
        currency: 'VND',
      ),
      '2,500,000 VND',
    );
    expect(
      CurrencyMinorUnits.formatMinorUnits(amountMinor: -1535, currency: 'USD'),
      '-15.35 USD',
    );
  });
}
