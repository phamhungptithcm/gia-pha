import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';

class AddressDirectionIconButton extends StatelessWidget {
  const AddressDirectionIconButton({
    super.key,
    required this.address,
    this.label,
    this.iconSize = 20,
    this.visualDensity = VisualDensity.compact,
  });

  final String address;
  final String? label;
  final double iconSize;
  final VisualDensity visualDensity;

  @override
  Widget build(BuildContext context) {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: context.l10n.pick(vi: 'Mở chỉ đường', en: 'Open directions'),
      visualDensity: visualDensity,
      iconSize: iconSize,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: () async {
        await AddressActionTools.openDirections(
          context,
          address: normalizedAddress,
          label: label,
        );
      },
      icon: const Icon(Icons.near_me_outlined),
    );
  }
}

class AddressInputAssistRow extends StatefulWidget {
  const AddressInputAssistRow({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;

  @override
  State<AddressInputAssistRow> createState() => _AddressInputAssistRowState();
}

class _AddressInputAssistRowState extends State<AddressInputAssistRow> {
  bool _isResolvingCurrentLocation = false;
  bool _isNormalizingAddress = false;

  Future<void> _useCurrentLocation() async {
    if (_isResolvingCurrentLocation) {
      return;
    }
    setState(() {
      _isResolvingCurrentLocation = true;
    });
    try {
      final resolved = await AddressActionTools.cityCountryFromCurrentLocation(
        context,
      );
      if (!mounted || resolved == null || resolved.trim().isEmpty) {
        return;
      }
      widget.controller.text = resolved.trim();
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
      widget.onChanged?.call();
      _showSnack(
        context.l10n.pick(
          vi: 'Đã điền thành phố và quốc gia từ vị trí hiện tại.',
          en: 'Filled city and country from your current location.',
        ),
      );
      return;
    } on TimeoutException {
      _showSnack(
        context.l10n.pick(
          vi: 'Định vị mất quá lâu. Vui lòng thử lại.',
          en: 'Location lookup timed out. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _normalizeAddress() async {
    if (_isNormalizingAddress) {
      return;
    }
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) {
      _showSnack(
        context.l10n.pick(
          vi: 'Nhập địa chỉ trước khi chuẩn hóa.',
          en: 'Enter an address before normalizing.',
        ),
      );
      return;
    }
    setState(() {
      _isNormalizingAddress = true;
    });
    try {
      final normalized = await AddressActionTools.normalizeAddressToCityCountry(
        context,
        rawAddress: raw,
      );
      if (!mounted || normalized == null || normalized.trim().isEmpty) {
        return;
      }
      widget.controller.text = normalized.trim();
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
      widget.onChanged?.call();
      if (normalized.trim() == raw) {
        _showSnack(
          context.l10n.pick(
            vi: 'Địa chỉ đã ở định dạng thành phố, quốc gia.',
            en: 'Address is already in city, country format.',
          ),
        );
        return;
      }
      _showSnack(
        context.l10n.pick(
          vi: 'Đã chuẩn hóa về định dạng thành phố, quốc gia.',
          en: 'Address normalized to city, country.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isNormalizingAddress = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          onPressed: _isResolvingCurrentLocation ? null : _useCurrentLocation,
          avatar: _isResolvingCurrentLocation
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_outlined, size: 18),
          label: Text(l10n.pick(vi: 'Vị trí của tôi', en: 'My location')),
        ),
        ActionChip(
          onPressed: _isNormalizingAddress ? null : _normalizeAddress,
          avatar: _isNormalizingAddress
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text(l10n.pick(vi: 'Chuẩn hóa', en: 'Normalize')),
        ),
      ],
    );
  }
}

class AddressActionTools {
  static Future<void> openDirections(
    BuildContext context, {
    required String address,
    String? label,
  }) async {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) {
      return;
    }

    geocoding.Location? location;
    try {
      final resolved = await geocoding.locationFromAddress(normalizedAddress);
      if (resolved.isNotEmpty) {
        location = resolved.first;
      }
    } catch (_) {
      location = null;
    }

    final uri = _buildDirectionsUri(
      address: normalizedAddress,
      label: label,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
    final launched = await launchUrl(uri, mode: _mapLaunchMode());
    if (launched || !context.mounted) {
      return;
    }

    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Thiết bị không mở được ứng dụng bản đồ.',
              en: 'Unable to open a map application on this device.',
            ),
          ),
        ),
      );
  }

  static Future<void> openMapSearch(
    BuildContext context, {
    required String query,
    String? label,
  }) async {
    final normalizedQuery = query.trim();
    final targetQuery = normalizedQuery.isEmpty
        ? context.l10n.pick(vi: 'Việt Nam', en: 'Vietnam')
        : normalizedQuery;

    final uri = _buildSearchUri(query: targetQuery, label: label);
    final launched = await launchUrl(uri, mode: _mapLaunchMode());
    if (launched || !context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Không mở được map lúc này. Vui lòng thử lại.',
              en: 'Unable to open map right now. Please try again.',
            ),
          ),
        ),
      );
  }

  static Future<String?> addressFromCurrentLocation(
    BuildContext context,
  ) async {
    final hasPermission = await _ensureLocationPermission(context);
    if (!hasPermission) {
      return null;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
      if (position == null && context.mounted) {
        _showSnack(
          context,
          context.l10n.pick(
            vi: 'Không lấy được vị trí hiện tại.',
            en: 'Unable to determine your current location.',
          ),
        );
      }
    }

    if (position == null) {
      return null;
    }

    final resolved = await _reverseGeocodeAddress(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if ((resolved ?? '').trim().isEmpty && context.mounted) {
      _showSnack(
        context,
        context.l10n.pick(
          vi: 'Đã lấy được vị trí, nhưng chưa thể chuyển sang địa chỉ cụ thể.',
          en: 'Location found, but unable to resolve a readable address yet.',
        ),
      );
    }
    return resolved;
  }

  static Future<String?> cityCountryFromCurrentLocation(
    BuildContext context,
  ) async {
    final hasPermission = await _ensureLocationPermission(context);
    if (!hasPermission) {
      return null;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
      if (position == null && context.mounted) {
        _showSnack(
          context,
          context.l10n.pick(
            vi: 'Không lấy được vị trí hiện tại.',
            en: 'Unable to determine your current location.',
          ),
        );
      }
    }

    if (position == null) {
      return null;
    }

    final mark = await _reverseGeocodePlacemark(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final resolved = mark == null ? null : _formatPlacemarkCityCountry(mark);
    if ((resolved ?? '').trim().isEmpty && context.mounted) {
      _showSnack(
        context,
        context.l10n.pick(
          vi: 'Đã lấy được vị trí nhưng chưa xác định được thành phố/quốc gia.',
          en: 'Location found, but city/country could not be resolved yet.',
        ),
      );
    }
    return resolved;
  }

  static Future<String?> normalizeAddress(
    BuildContext context, {
    required String rawAddress,
  }) async {
    final normalizedRaw = rawAddress.trim();
    if (normalizedRaw.isEmpty) {
      return null;
    }
    try {
      final locations = await geocoding.locationFromAddress(normalizedRaw);
      if (locations.isEmpty) {
        return normalizedRaw;
      }
      final first = locations.first;
      final resolved = await _reverseGeocodeAddress(
        latitude: first.latitude,
        longitude: first.longitude,
      );
      return (resolved == null || resolved.trim().isEmpty)
          ? normalizedRaw
          : resolved.trim();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.pick(
                  vi: 'Không thể chuẩn hóa địa chỉ. Vui lòng kiểm tra lại.',
                  en: 'Unable to normalize this address. Please check and retry.',
                ),
              ),
            ),
          );
      }
      return null;
    }
  }

  static Future<String?> normalizeAddressToCityCountry(
    BuildContext context, {
    required String rawAddress,
  }) async {
    final normalizedRaw = rawAddress.trim();
    if (normalizedRaw.isEmpty) {
      return null;
    }
    try {
      final locations = await geocoding.locationFromAddress(normalizedRaw);
      if (locations.isEmpty) {
        return normalizedRaw;
      }
      final first = locations.first;
      final mark = await _reverseGeocodePlacemark(
        latitude: first.latitude,
        longitude: first.longitude,
      );
      if (mark == null) {
        return normalizedRaw;
      }
      final resolved = _formatPlacemarkCityCountry(mark).trim();
      return resolved.isEmpty ? normalizedRaw : resolved;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.pick(
                  vi: 'Không thể chuẩn hóa địa chỉ. Vui lòng kiểm tra lại.',
                  en: 'Unable to normalize this address. Please check and retry.',
                ),
              ),
            ),
          );
      }
      return null;
    }
  }

  static Future<List<String>> suggestAddresses({
    required String query,
    bool cityCountryOnly = false,
    int limit = 6,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 3 || limit <= 0) {
      return const [];
    }
    try {
      final locations = await geocoding.locationFromAddress(normalizedQuery);
      if (locations.isEmpty) {
        return const [];
      }

      final suggestions = <String>[];
      final seen = <String>{};
      for (final location in locations) {
        if (suggestions.length >= limit) {
          break;
        }
        final mark = await _reverseGeocodePlacemark(
          latitude: location.latitude,
          longitude: location.longitude,
        );
        final rawSuggestion = mark == null
            ? normalizedQuery
            : (cityCountryOnly
                  ? _formatPlacemarkCityCountry(mark)
                  : _formatPlacemark(mark));
        final suggestion = rawSuggestion.trim();
        if (suggestion.isEmpty) {
          continue;
        }
        final key = suggestion.toLowerCase();
        if (!seen.add(key)) {
          continue;
        }
        suggestions.add(suggestion);
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> _ensureLocationPermission(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        _showSnack(
          context,
          context.l10n.pick(
            vi: 'Vui lòng bật dịch vụ vị trí trên thiết bị.',
            en: 'Please enable location services on this device.',
          ),
          actionLabel: context.l10n.pick(vi: 'Mở cài đặt', en: 'Open settings'),
          onAction: Geolocator.openLocationSettings,
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showSnack(
          context,
          context.l10n.pick(
            vi: permission == LocationPermission.deniedForever
                ? 'Ứng dụng đã bị chặn quyền vị trí. Bạn có thể mở cài đặt để cấp lại.'
                : 'Bạn chưa cấp quyền vị trí cho ứng dụng.',
            en: permission == LocationPermission.deniedForever
                ? 'Location permission is permanently denied. Open settings to enable it.'
                : 'Location permission is not granted for this app.',
          ),
          actionLabel: context.l10n.pick(vi: 'Mở cài đặt', en: 'Open settings'),
          onAction: Geolocator.openAppSettings,
        );
      }
      return false;
    }
    return true;
  }

  static Future<String?> _reverseGeocodeAddress({
    required double latitude,
    required double longitude,
  }) async {
    final mark = await _reverseGeocodePlacemark(
      latitude: latitude,
      longitude: longitude,
    );
    if (mark == null) {
      return null;
    }
    return _formatPlacemark(mark);
  }

  static Future<geocoding.Placemark?> _reverseGeocodePlacemark({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final marks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (marks.isEmpty) {
        return null;
      }
      return marks.first;
    } catch (_) {
      return null;
    }
  }

  static String _formatPlacemark(geocoding.Placemark mark) {
    final parts = <String>[
      mark.street?.trim() ?? '',
      mark.subLocality?.trim() ?? '',
      mark.locality?.trim() ?? '',
      mark.subAdministrativeArea?.trim() ?? '',
      mark.administrativeArea?.trim() ?? '',
      mark.country?.trim() ?? '',
    ].where((part) => part.isNotEmpty).toList(growable: false);

    return parts.join(', ');
  }

  static String _formatPlacemarkCityCountry(geocoding.Placemark mark) {
    final city = mark.locality?.trim().isNotEmpty == true
        ? mark.locality!.trim()
        : (mark.subAdministrativeArea?.trim().isNotEmpty == true
              ? mark.subAdministrativeArea!.trim()
              : mark.administrativeArea?.trim() ?? '');
    final country = mark.country?.trim() ?? '';
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  static Uri _buildDirectionsUri({
    required String address,
    String? label,
    double? latitude,
    double? longitude,
  }) {
    if (kIsWeb) {
      return _buildGoogleDirectionsUri(
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (latitude != null && longitude != null) {
        return Uri.parse(
          'http://maps.apple.com/?daddr=$latitude,$longitude'
          '&q=${Uri.encodeQueryComponent(label?.trim().isNotEmpty == true ? label!.trim() : address)}',
        );
      }
      return Uri.parse(
        'http://maps.apple.com/?daddr=${Uri.encodeQueryComponent(address)}',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (latitude != null && longitude != null) {
        final displayLabel = (label?.trim().isNotEmpty == true)
            ? label!.trim()
            : address;
        final encodedDisplayLabel = Uri.encodeQueryComponent(displayLabel);
        return Uri.parse(
          'geo:$latitude,$longitude?q=$latitude,$longitude($encodedDisplayLabel)',
        );
      }
      return Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(address)}');
    }

    final destination = (latitude != null && longitude != null)
        ? '$latitude,$longitude'
        : address;
    final queryLabel = (label?.trim().isNotEmpty == true)
        ? '${label!.trim()} $destination'
        : destination;
    return _buildGoogleSearchUri(query: queryLabel);
  }

  static Uri _buildSearchUri({required String query, String? label}) {
    if (kIsWeb) {
      final q = label?.trim().isNotEmpty == true
          ? '${label!.trim()} $query'
          : query;
      return _buildGoogleSearchUri(query: q);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final q = label?.trim().isNotEmpty == true
          ? '${label!.trim()} $query'
          : query;
      return Uri.parse(
        'http://maps.apple.com/?q=${Uri.encodeQueryComponent(q)}',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final q = label?.trim().isNotEmpty == true
          ? '${label!.trim()} $query'
          : query;
      return Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(q)}');
    }

    final q = label?.trim().isNotEmpty == true
        ? '${label!.trim()} $query'
        : query;
    return _buildGoogleSearchUri(query: q);
  }

  static Uri _buildGoogleDirectionsUri({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    final destination = (latitude != null && longitude != null)
        ? '$latitude,$longitude'
        : address;
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeQueryComponent(destination)}',
    );
  }

  static Uri _buildGoogleSearchUri({required String query}) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(query)}',
    );
  }

  static LaunchMode _mapLaunchMode() {
    return kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
  }

  static void _showSnack(
    BuildContext context,
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: (actionLabel == null || onAction == null)
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: () {
                  unawaited(onAction());
                },
              ),
      ),
    );
  }
}
