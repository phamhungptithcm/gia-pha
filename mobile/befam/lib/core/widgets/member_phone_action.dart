import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';

enum _MemberPhoneAction { call, sms }

Future<void> showMemberPhoneActionSheet(
  BuildContext context, {
  required String phoneNumber,
  required String contactName,
}) async {
  final normalizedPhone = phoneNumber.trim();
  if (normalizedPhone.isEmpty) {
    return;
  }
  final l10n = context.l10n;
  final selected = await showModalBottomSheet<_MemberPhoneAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(l10n.pick(vi: 'Gọi nhanh', en: 'Quick call')),
              subtitle: Text(
                l10n.pick(vi: 'Gọi $contactName', en: 'Call $contactName'),
              ),
              onTap: () {
                Navigator.of(context).pop(_MemberPhoneAction.call);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: Text(l10n.pick(vi: 'Nhắn tin', en: 'Send message')),
              subtitle: Text(
                l10n.pick(
                  vi: 'Nhắn cho $contactName',
                  en: 'Message $contactName',
                ),
              ),
              onTap: () {
                Navigator.of(context).pop(_MemberPhoneAction.sms);
              },
            ),
          ],
        ),
      );
    },
  );

  if (selected == null || !context.mounted) {
    return;
  }

  final targetUri = switch (selected) {
    _MemberPhoneAction.call => Uri(scheme: 'tel', path: normalizedPhone),
    _MemberPhoneAction.sms => Uri(scheme: 'sms', path: normalizedPhone),
  };

  final launched = await launchUrl(
    targetUri,
    mode: LaunchMode.externalApplication,
  );
  if (launched || !context.mounted) {
    return;
  }

  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          l10n.pick(
            vi: 'Thiết bị hiện tại chưa mở được ứng dụng gọi/nhắn tin.',
            en: 'This device could not open call/message apps.',
          ),
        ),
      ),
    );
}

class MemberPhoneActionIconButton extends StatelessWidget {
  const MemberPhoneActionIconButton({
    super.key,
    required this.phoneNumber,
    required this.contactName,
    this.visualDensity = VisualDensity.compact,
    this.iconSize = 20,
    this.padding = EdgeInsets.zero,
    this.constraints = const BoxConstraints(minWidth: 36, minHeight: 36),
    this.alignment = Alignment.center,
  });

  final String phoneNumber;
  final String contactName;
  final VisualDensity visualDensity;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: context.l10n.pick(
        vi: 'Gọi hoặc nhắn tin',
        en: 'Call or message',
      ),
      visualDensity: visualDensity,
      iconSize: iconSize,
      padding: padding,
      constraints: constraints,
      alignment: alignment,
      onPressed: () {
        showMemberPhoneActionSheet(
          context,
          phoneNumber: normalizedPhone,
          contactName: contactName.trim().isEmpty
              ? context.l10n.pick(vi: 'thành viên này', en: 'this member')
              : contactName,
        );
      },
      icon: const Icon(Icons.phone_outlined),
    );
  }
}
