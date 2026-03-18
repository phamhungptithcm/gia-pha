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
    this.visualDensity = VisualDensity.standard,
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
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
    this.enableMapPinAction = true,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final bool enableMapPinAction;

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
      final resolved = await AddressActionTools.addressFromCurrentLocation(
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
          vi: 'Đã điền địa chỉ theo vị trí hiện tại của bạn.',
          en: 'Address filled from your current location.',
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
      final normalized = await AddressActionTools.normalizeAddress(
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
            vi: 'Không tìm thấy địa chỉ chính xác hơn. Đã giữ nguyên nội dung bạn nhập.',
            en: 'No more accurate result found. Your original address is kept.',
          ),
        );
        return;
      }
      _showSnack(
        context.l10n.pick(
          vi: 'Đã chuẩn hóa địa chỉ để chính xác hơn.',
          en: 'Address normalized for better accuracy.',
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

  Future<void> _openMapPin() async {
    final raw = widget.controller.text.trim();
    await AddressActionTools.openMapSearch(
      context,
      query: raw,
      label: context.l10n.pick(
        vi: 'Địa chỉ cần xác thực',
        en: 'Address to verify',
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isResolvingCurrentLocation
                  ? null
                  : _useCurrentLocation,
              icon: _isResolvingCurrentLocation
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
              label: Text(
                l10n.pick(vi: 'Dùng vị trí của tôi', en: 'Use my location'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isNormalizingAddress ? null : _normalizeAddress,
              icon: _isNormalizingAddress
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_outlined),
              label: Text(
                l10n.pick(vi: 'Kiểm tra địa chỉ', en: 'Validate address'),
              ),
            ),
            if (widget.enableMapPinAction)
              OutlinedButton.icon(
                onPressed: _openMapPin,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  l10n.pick(vi: 'Chọn trên bản đồ', en: 'Pick on map'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.pick(
            vi: 'Mẹo: dùng vị trí hiện tại hoặc chọn trên bản đồ để địa chỉ chính xác hơn.',
            en: 'Tip: use current location or map pin for better accuracy.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
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
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    try {
      final marks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (marks.isEmpty) {
        return null;
      }
      return _formatPlacemark(marks.first);
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

  static Uri _buildDirectionsUri({
    required String address,
    String? label,
    double? latitude,
    double? longitude,
  }) {
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

    final destination = (latitude != null && longitude != null)
        ? '$latitude,$longitude'
        : address;
    final queryLabel = (label?.trim().isNotEmpty == true)
        ? '${label!.trim()} $destination'
        : destination;
    return Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(queryLabel)}');
  }

  static Uri _buildSearchUri({required String query, String? label}) {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final q = label?.trim().isNotEmpty == true
          ? '${label!.trim()} $query'
          : query;
      return Uri.parse(
        'http://maps.apple.com/?q=${Uri.encodeQueryComponent(q)}',
      );
    }
    final q = label?.trim().isNotEmpty == true
        ? '${label!.trim()} $query'
        : query;
    return Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(q)}');
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
