import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../services/phone_number_formatter.dart';

class PhoneCountrySelectorField extends StatelessWidget {
  const PhoneCountrySelectorField({
    super.key,
    required this.selectedIsoCode,
    required this.onChanged,
    this.enabled = true,
    this.labelText,
    this.compact = true,
    this.minWidth = 108,
  });

  final String selectedIsoCode;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? labelText;
  final bool compact;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isVietnamese = locale.languageCode.toLowerCase().startsWith('vi');
    final l10n = context.l10n;
    final selected = PhoneNumberFormatter.resolveCountryOption(selectedIsoCode);

    if (!compact) {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selected.isoCode,
        decoration: InputDecoration(
          labelText:
              labelText ?? l10n.pick(vi: 'Mã quốc gia', en: 'Country code'),
        ),
        items: [
          for (final option in PhoneNumberFormatter.supportedCountries)
            DropdownMenuItem<String>(
              value: option.isoCode,
              child: Text(option.displayLabel(isVietnamese: isVietnamese)),
            ),
        ],
        onChanged: !enabled
            ? null
            : (value) {
                final normalized = value?.trim().toUpperCase();
                if (normalized == null || normalized.isEmpty) {
                  return;
                }
                onChanged(normalized);
              },
      );
    }

    final theme = Theme.of(context);
    final borderColor = enabled
        ? theme.colorScheme.outlineVariant
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    final textColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    Future<void> openPicker() async {
      if (!enabled) {
        return;
      }
      final pickedIso = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          final sheetTheme = Theme.of(sheetContext);
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    labelText ??
                        l10n.pick(vi: 'Chọn mã quốc gia', en: 'Pick country'),
                    style: sheetTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final option in PhoneNumberFormatter.supportedCountries)
                  ListTile(
                    leading: Text(option.flagEmoji),
                    title: Text(
                      isVietnamese ? option.labelVi : option.labelEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(option.nationalExample),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(option.dialCode),
                        if (option.isoCode == selected.isoCode) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check,
                            size: 18,
                            color: sheetTheme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(option.isoCode),
                  ),
              ],
            ),
          );
        },
      );
      final normalized = pickedIso?.trim().toUpperCase();
      if (normalized == null || normalized.isEmpty) {
        return;
      }
      onChanged(normalized);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: labelText ?? l10n.pick(vi: 'Mã quốc gia', en: 'Country code'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? openPicker : null,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selected.flagEmoji),
                  const SizedBox(width: 8),
                  Text(
                    selected.dialCode,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: textColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
