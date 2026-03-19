import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'address_action_tools.dart';

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.cityCountryOnly = false,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final int maxLines;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool cityCountryOnly;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isResolvingCurrentLocation = false;
  bool _isLoadingSuggestions = false;
  int _suggestionToken = 0;
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _suggestions.isNotEmpty) {
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus || !mounted) {
      return;
    }
    setState(() {
      _suggestions = const [];
      _isLoadingSuggestions = false;
    });
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (!widget.enabled) {
      return;
    }

    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = const [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_loadSuggestions(trimmed));
    });
  }

  Future<void> _loadSuggestions(String query) async {
    final requestToken = ++_suggestionToken;
    setState(() {
      _isLoadingSuggestions = true;
    });

    final suggestions = await AddressActionTools.suggestAddresses(
      query: query,
      cityCountryOnly: widget.cityCountryOnly,
      limit: 6,
    );

    if (!mounted || requestToken != _suggestionToken) {
      return;
    }

    final current = widget.controller.text.trim().toLowerCase();
    final filtered = suggestions
        .where((entry) => entry.trim().toLowerCase() != current)
        .toList(growable: false);
    setState(() {
      _isLoadingSuggestions = false;
      _suggestions = filtered;
    });
  }

  Future<void> _fillFromCurrentLocation() async {
    if (_isResolvingCurrentLocation || !widget.enabled) {
      return;
    }
    setState(() {
      _isResolvingCurrentLocation = true;
    });
    try {
      // ignore: use_build_context_synchronously
      final value = widget.cityCountryOnly
          // ignore: use_build_context_synchronously
          ? await AddressActionTools.cityCountryFromCurrentLocation(context)
          // ignore: use_build_context_synchronously
          : await AddressActionTools.addressFromCurrentLocation(context);
      final resolved = value?.trim() ?? '';
      if (!mounted || resolved.isEmpty) {
        return;
      }
      widget.controller.text = resolved;
      widget.controller.selection = TextSelection.collapsed(
        offset: resolved.length,
      );
      widget.onChanged?.call(resolved);
      setState(() {
        _suggestions = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrentLocation = false;
        });
      }
    }
  }

  void _applySuggestion(String suggestion) {
    final resolved = suggestion.trim();
    if (resolved.isEmpty) {
      return;
    }
    widget.controller.text = resolved;
    widget.controller.selection = TextSelection.collapsed(
      offset: resolved.length,
    );
    widget.onChanged?.call(resolved);
    setState(() {
      _suggestions = const [];
      _isLoadingSuggestions = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: _handleChanged,
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            suffixIcon: IconButton(
              tooltip: context.l10n.pick(
                vi: 'Vị trí của tôi',
                en: 'My location',
              ),
              onPressed: _isResolvingCurrentLocation
                  ? null
                  : _fillFromCurrentLocation,
              icon: _isResolvingCurrentLocation
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
            ),
          ),
        ),
        if (_focusNode.hasFocus &&
            (_isLoadingSuggestions || _suggestions.isNotEmpty)) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: _isLoadingSuggestions
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, index) =>
                        const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          suggestion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _applySuggestion(suggestion),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
