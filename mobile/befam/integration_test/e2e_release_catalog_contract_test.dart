import 'package:flutter_test/flutter_test.dart';

import 'support/release_case_catalog.dart';
import 'support/release_suite_registry.dart';

void main() {
  group('Release catalog contract', () {
    test('execution template catalog is loaded', () {
      expect(releaseCatalogCases, hasLength(106));
      expect(releaseCatalogCaseIds, hasLength(106));
    });

    test('automated e2e case IDs are mapped to release execution template', () {
      final missing = missingAutomatedReleaseCaseIds();
      expect(
        missing,
        isEmpty,
        reason:
            'These automated E2E case IDs are missing in release-test-execution-template.csv: $missing',
      );
    });

    test('dashboard-level totals from template are consistent', () {
      final p0Total = releaseCatalogCases
          .where((entry) => entry.priority == 'P0')
          .length;
      final p1Total = releaseCatalogCases
          .where((entry) => entry.priority == 'P1')
          .length;
      final automatedP0 = automatedReleaseCases
          .where((entry) => entry.priority == 'P0')
          .length;
      final automatedP1 = automatedReleaseCases
          .where((entry) => entry.priority == 'P1')
          .length;

      expect(releaseCatalogCases.length, 106);
      expect(p0Total, 61);
      expect(p1Total, 45);
      expect(automatedReleaseCases.length, 10);
      expect(automatedP0, 9);
      expect(automatedP1, 1);
    });
  });
}
