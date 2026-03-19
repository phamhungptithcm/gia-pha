import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';

enum SocialPlatform { facebook, zalo, linkedin }

extension SocialPlatformUiX on SocialPlatform {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      SocialPlatform.facebook => l10n.pick(vi: 'Facebook', en: 'Facebook'),
      SocialPlatform.zalo => l10n.pick(vi: 'Zalo', en: 'Zalo'),
      SocialPlatform.linkedin => l10n.pick(vi: 'LinkedIn', en: 'LinkedIn'),
    };
  }

  IconData iconData() {
    return switch (this) {
      SocialPlatform.facebook => Icons.facebook,
      SocialPlatform.zalo => Icons.forum_outlined,
      SocialPlatform.linkedin => Icons.work_outline,
    };
  }
}

String? normalizeSocialLinkForStorage(
  SocialPlatform platform,
  String rawInput,
) {
  final trimmed = rawInput.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final urlCandidate = _tryParseUrlLike(trimmed);
  if (urlCandidate != null) {
    return urlCandidate.toString();
  }

  final token = _normalizeHandleToken(trimmed);
  if (token.isEmpty) {
    return null;
  }

  return switch (platform) {
    SocialPlatform.facebook => Uri.https(
      'www.facebook.com',
      '/$token',
    ).toString(),
    SocialPlatform.zalo => Uri.https('zalo.me', '/$token').toString(),
    SocialPlatform.linkedin =>
      token.startsWith('in/') || token.startsWith('company/')
          ? Uri.https('www.linkedin.com', '/$token').toString()
          : Uri.https('www.linkedin.com', '/in/$token').toString(),
  };
}

Future<void> openSocialLink(
  BuildContext context, {
  required SocialPlatform platform,
  required String rawInput,
  bool openConnectIfEmpty = false,
}) async {
  final l10n = context.l10n;
  final platformLabel = platform.label(context);
  final noLinkMessage = l10n.pick(
    vi: 'Chưa có liên kết $platformLabel.',
    en: 'No $platformLabel link yet.',
  );
  final openFailedMessage = l10n.pick(
    vi: 'Không mở được $platformLabel trên thiết bị này.',
    en: 'Unable to open $platformLabel on this device.',
  );
  final connectHintMessage = l10n.pick(
    vi: 'Sau khi đăng nhập, hãy quay lại dán liên kết hoặc tên tài khoản để lưu.',
    en: 'After sign in, come back and paste your profile link or username to save.',
  );

  final normalized = normalizeSocialLinkForStorage(platform, rawInput);
  final targetUri = normalized == null
      ? (openConnectIfEmpty ? _connectUri(platform) : null)
      : Uri.parse(normalized);
  if (targetUri == null) {
    _showSnack(context, noLinkMessage);
    return;
  }

  final launched = await launchUrl(
    targetUri,
    mode: LaunchMode.externalApplication,
  );
  if (!context.mounted) {
    return;
  }
  if (!launched) {
    _showSnack(context, openFailedMessage);
    return;
  }

  if (normalized == null && openConnectIfEmpty) {
    _showSnack(context, connectHintMessage);
  }
}

class SocialLinkActionIconButton extends StatelessWidget {
  const SocialLinkActionIconButton({
    super.key,
    required this.platform,
    required this.rawValue,
    this.openConnectIfEmpty = false,
    this.iconSize = 20,
    this.visualDensity = VisualDensity.standard,
    this.onPressedOverride,
  });

  final SocialPlatform platform;
  final String rawValue;
  final bool openConnectIfEmpty;
  final double iconSize;
  final VisualDensity visualDensity;
  final Future<void> Function(BuildContext context)? onPressedOverride;

  @override
  Widget build(BuildContext context) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty && !openConnectIfEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final actionLabel = normalized.isEmpty
        ? l10n.pick(vi: 'Liên kết', en: 'Connect')
        : l10n.pick(vi: 'Mở', en: 'Open');
    return IconButton(
      tooltip: '$actionLabel ${platform.label(context)}',
      visualDensity: visualDensity,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      iconSize: iconSize,
      onPressed: () async {
        if (onPressedOverride != null) {
          await onPressedOverride!(context);
          return;
        }
        await openSocialLink(
          context,
          platform: platform,
          rawInput: normalized,
          openConnectIfEmpty: openConnectIfEmpty,
        );
      },
      icon: Icon(platform.iconData()),
    );
  }
}

class SocialLinkFieldConnectButton extends StatelessWidget {
  const SocialLinkFieldConnectButton({
    super.key,
    required this.platform,
    required this.controller,
    this.onNormalized,
  });

  final SocialPlatform platform;
  final TextEditingController controller;
  final VoidCallback? onNormalized;

  @override
  Widget build(BuildContext context) {
    return SocialLinkActionIconButton(
      platform: platform,
      rawValue: controller.text,
      openConnectIfEmpty: true,
      visualDensity: VisualDensity.compact,
      onPressedOverride: (context) async {
        final normalized = normalizeSocialLinkForStorage(
          platform,
          controller.text,
        );
        if (normalized != null && normalized != controller.text.trim()) {
          controller.text = normalized;
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
          onNormalized?.call();
        }
        await openSocialLink(
          context,
          platform: platform,
          rawInput: controller.text,
          openConnectIfEmpty: true,
        );
      },
    );
  }
}

Uri? _tryParseUrlLike(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final hasScheme = trimmed.contains('://');
  final looksLikeUrl =
      hasScheme || trimmed.contains('.') || trimmed.contains('/');
  if (!looksLikeUrl) {
    return null;
  }

  final candidate = hasScheme ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.host.trim().isEmpty) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  return uri.replace(scheme: 'https');
}

String _normalizeHandleToken(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.replaceFirst(RegExp(r'^@+'), '').replaceAll(' ', '');
}

Uri _connectUri(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.facebook => Uri.parse('https://www.facebook.com/login'),
    SocialPlatform.zalo => Uri.parse(
      'https://id.zalo.me/account?continue=https%3A%2F%2Fzalo.me',
    ),
    SocialPlatform.linkedin => Uri.parse('https://www.linkedin.com/login'),
  };
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
