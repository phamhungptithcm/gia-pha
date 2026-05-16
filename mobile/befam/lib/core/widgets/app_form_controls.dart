import 'package:flutter/material.dart';

class AppRequiredFieldLabel extends StatelessWidget {
  const AppRequiredFieldLabel(this.label, {super.key, this.isRequired = true});

  static const markerKey = Key('app-required-field-marker');

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          Text(
            '*',
            key: markerKey,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

InputDecoration appFieldDecoration({
  required String label,
  bool required = false,
  String? hintText,
  String? helperText,
  String? suffixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
}) {
  return InputDecoration(
    label: required ? AppRequiredFieldLabel(label) : Text(label),
    hintText: hintText,
    helperText: helperText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
  );
}
