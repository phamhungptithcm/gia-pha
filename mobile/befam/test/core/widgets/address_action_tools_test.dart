import 'package:befam/core/widgets/address_action_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location feedback snackbar floats above bottom actions', () {
    final snackBar = AddressActionTools.buildFeedbackSnackBar(
      message: 'Location permission is not granted for this app.',
      actionLabel: 'Open settings',
      onAction: () async => true,
    );

    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.action, isNotNull);

    final margin = snackBar.margin!.resolve(TextDirection.ltr);
    expect(margin.left, 16);
    expect(margin.right, 16);
    expect(margin.bottom, greaterThanOrEqualTo(96));
  });
}
