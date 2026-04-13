import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_ui_tokens.dart';
import '../../../features/auth/models/auth_session.dart';
import '../../../l10n/l10n.dart';
import '../services/ai_assist_service.dart';
import 'ai_result_status_chips.dart';

class AiAssistantLauncher extends StatelessWidget {
  const AiAssistantLauncher({
    super.key,
    required this.session,
    required this.currentScreenId,
    required this.currentScreenTitle,
    required this.onOpenDestinationRequested,
    this.activeClanName,
    this.extraBottomPadding = 0,
    this.service,
  });

  final AuthSession session;
  final String currentScreenId;
  final String currentScreenTitle;
  final String? activeClanName;
  final double extraBottomPadding;
  final ValueChanged<String> onOpenDestinationRequested;
  final AiAssistService? service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: extraBottomPadding),
      child: Semantics(
        button: true,
        label: l10n.pick(
          vi: 'Mở trợ lý BeFam AI',
          en: 'Open the BeFam AI assistant',
        ),
        child: Tooltip(
          message: l10n.pick(vi: 'Hỏi BeFam AI', en: 'Ask BeFam AI'),
          child: _AiBubbleButton(onTap: () => _openAssistantSheet(context)),
        ),
      ),
    );
  }

  Future<void> _openAssistantSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _AiAssistantSheet(
          session: session,
          currentScreenId: currentScreenId,
          currentScreenTitle: currentScreenTitle,
          activeClanName: activeClanName,
          onOpenDestinationRequested: onOpenDestinationRequested,
          service: service ?? createDefaultAiAssistService(),
        );
      },
    );
  }
}

class _AiBubbleButton extends StatelessWidget {
  const _AiBubbleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.45) ??
                    colorScheme.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                color: colorScheme.onPrimary,
                size: 30,
              ),
              Positioned(
                top: 16,
                right: 15,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.onPrimary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiAssistantSheet extends StatefulWidget {
  const _AiAssistantSheet({
    required this.session,
    required this.currentScreenId,
    required this.currentScreenTitle,
    required this.service,
    required this.onOpenDestinationRequested,
    this.activeClanName,
  });

  final AuthSession session;
  final String currentScreenId;
  final String currentScreenTitle;
  final String? activeClanName;
  final AiAssistService service;
  final ValueChanged<String> onOpenDestinationRequested;

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  final List<_AiTranscriptEntry> _entries = <_AiTranscriptEntry>[];
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeightFactor = screenHeight < 760 ? 0.92 : 0.84;

    return FractionallySizedBox(
      heightFactor: sheetHeightFactor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLg,
              4,
              tokens.spaceLg,
              viewInsets.bottom > 0
                  ? viewInsets.bottom + tokens.spaceLg
                  : tokens.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AssistantHeroCard(
                  currentScreenId: widget.currentScreenId,
                  currentScreenTitle: widget.currentScreenTitle,
                  activeClanName: widget.activeClanName,
                ),
                SizedBox(height: tokens.spaceLg),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(bottom: tokens.spaceSm),
                    children: _entries.isEmpty
                        ? [
                            _AssistantEmptyState(
                              currentScreenTitle: widget.currentScreenTitle,
                              prompts: _starterPrompts(context),
                              onPromptSelected: _submitPrompt,
                            ),
                          ]
                        : [
                            for (final entry in _entries)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: tokens.spaceMd,
                                ),
                                child: _TranscriptBubble(
                                  entry: entry,
                                  onQuickReplySelected: _submitPrompt,
                                  onOpenDestinationRequested:
                                      _openSuggestedDestination,
                                ),
                              ),
                            if (_isSending) const _AssistantTypingBubble(),
                          ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: tokens.spaceSm),
                  _AssistantErrorBanner(
                    message: _errorMessage!,
                    onOpenBilling: _shouldOfferBillingShortcut
                        ? () => _openSuggestedDestination('billing')
                        : null,
                  ),
                ],
                SizedBox(height: tokens.spaceSm),
                _AssistantComposer(
                  controller: _composerController,
                  focusNode: _composerFocusNode,
                  isSending: _isSending,
                  onSend: () => _submitPrompt(_composerController.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _shouldOfferBillingShortcut {
    final message = (_errorMessage ?? '').toLowerCase();
    return message.contains('paid') ||
        message.contains('premium') ||
        message.contains('gói') ||
        message.contains('permission');
  }

  List<String> _starterPrompts(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.currentScreenId) {
      'tree' => [
        l10n.pick(
          vi: 'Cách thêm thành viên đúng vào gia phả?',
          en: 'How do I add a member to the tree correctly?',
        ),
        l10n.pick(
          vi: 'Khi nào dùng cha mẹ, con cái và vợ chồng?',
          en: 'When should I use parent, child, and spouse links?',
        ),
        l10n.pick(
          vi: 'Tôi muốn tạo gia phả mới mà tránh bị trùng.',
          en: 'I want to create a new tree without creating duplicates.',
        ),
      ],
      'events' => [
        l10n.pick(
          vi: 'Cách tạo ngày giỗ và nhắc lịch cho cả nhà?',
          en: 'How do I create a memorial event and reminders for the family?',
        ),
        l10n.pick(
          vi: 'Nên dùng lịch âm hay dương cho sự kiện này?',
          en: 'Should I use the lunar or solar calendar for this event?',
        ),
        l10n.pick(
          vi: 'Làm sao để nội dung lời mời gọn mà đủ ý?',
          en: 'How can I keep the invitation short but complete?',
        ),
      ],
      'billing' => [
        l10n.pick(
          vi: 'Gói nào hợp với quy mô gia đình tôi?',
          en: 'Which plan fits my family size best?',
        ),
        l10n.pick(
          vi: 'Làm sao tắt quảng cáo cho cả gia phả?',
          en: 'How do I remove ads for the whole clan?',
        ),
        l10n.pick(
          vi: 'Khi thanh toán xong thì quyền lợi cập nhật thế nào?',
          en: 'How are entitlements updated after payment?',
        ),
      ],
      'profile' => [
        l10n.pick(
          vi: 'Làm sao hoàn thiện hồ sơ để người thân dễ nhận ra?',
          en: 'How do I complete my profile so relatives recognize it easily?',
        ),
        l10n.pick(
          vi: 'Đổi ngôn ngữ app ở đâu?',
          en: 'Where do I change the app language?',
        ),
        l10n.pick(
          vi: 'Tôi muốn quản lý thông báo quan trọng cho hồ sơ.',
          en: 'I want to manage important notifications for my profile.',
        ),
      ],
      _ => [
        l10n.pick(
          vi: 'Tôi mới dùng BeFam, nên bắt đầu từ đâu?',
          en: 'I am new to BeFam. Where should I start?',
        ),
        l10n.pick(
          vi: 'Cách thêm gia phả và mời người thân tham gia?',
          en: 'How do I add a family tree and invite relatives?',
        ),
        l10n.pick(
          vi: 'Tôi muốn quản lý giỗ kỵ và lịch họp gia đình.',
          en: 'I want to manage memorial rituals and family meetings.',
        ),
      ],
    };
  }

  Future<void> _submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || _isSending) {
      return;
    }

    final history = _entries
        .map(
          (entry) => AppAssistantConversationMessage(
            role: entry.role,
            text: entry.historyText,
          ),
        )
        .toList(growable: false);

    _composerController.clear();
    setState(() {
      _errorMessage = null;
      _isSending = true;
      _entries.add(_AiTranscriptEntry.user(trimmed));
    });
    _scrollToBottom();

    try {
      final reply = await widget.service.askAppAssistant(
        session: widget.session,
        locale: Localizations.localeOf(context).toLanguageTag(),
        currentScreenId: widget.currentScreenId,
        currentScreenTitle: widget.currentScreenTitle,
        activeClanName: widget.activeClanName,
        question: trimmed,
        history: history,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries.add(_AiTranscriptEntry.assistant(reply));
      });
    } on AiAssistServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _openSuggestedDestination(String destinationId) {
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOpenDestinationRequested(destinationId);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _AssistantHeroCard extends StatelessWidget {
  const _AssistantHeroCard({
    required this.currentScreenId,
    required this.currentScreenTitle,
    this.activeClanName,
  });

  final String currentScreenId;
  final String currentScreenTitle;
  final String? activeClanName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.uiTokens;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(tokens.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            Color.lerp(
                  colorScheme.primaryContainer,
                  colorScheme.tertiaryContainer,
                  0.5,
                ) ??
                colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.forum_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              SizedBox(width: tokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(
                        vi: 'BeFam AI Assistant',
                        en: 'BeFam AI Assistant',
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXs),
                    Text(
                      l10n.pick(
                        vi: 'Hỏi cách dùng app, quy trình gia phả, sự kiện và gói dịch vụ.',
                        en: 'Ask about app workflows, genealogy operations, events, and billing.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.86,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              Chip(
                avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(
                  l10n.pick(
                    vi: 'Dành cho gói trả phí',
                    en: 'Paid plan feature',
                  ),
                ),
              ),
              Chip(
                avatar: Icon(_iconForScreen(currentScreenId), size: 18),
                label: Text(currentScreenTitle),
              ),
              if ((activeClanName ?? '').trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(activeClanName!.trim()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.currentScreenTitle,
    required this.prompts,
    required this.onPromptSelected,
  });

  final String currentScreenTitle;
  final List<String> prompts;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(tokens.spaceLg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(
              vi: 'Đang ở $currentScreenTitle. Bạn có thể bắt đầu bằng một câu hỏi ngắn:',
              en: 'You are in $currentScreenTitle. Start with one of these questions:',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  onPressed: () => onPromptSelected(prompt),
                  avatar: const Icon(Icons.bolt_outlined, size: 18),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(prompt),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({
    required this.entry,
    required this.onQuickReplySelected,
    required this.onOpenDestinationRequested,
  });

  final _AiTranscriptEntry entry;
  final ValueChanged<String> onQuickReplySelected;
  final ValueChanged<String> onOpenDestinationRequested;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: entry.role == AppAssistantConversationRole.user
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: entry.role == AppAssistantConversationRole.user
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            border: Border.all(
              color: entry.role == AppAssistantConversationRole.user
                  ? colorScheme.primaryContainer
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: entry.role == AppAssistantConversationRole.user
                ? Text(
                    entry.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : _AssistantReplyBody(
                    reply: entry.reply!,
                    onQuickReplySelected: onQuickReplySelected,
                    onOpenDestinationRequested: onOpenDestinationRequested,
                  ),
          ),
        ),
      ),
    );
  }
}

class _AssistantReplyBody extends StatelessWidget {
  const _AssistantReplyBody({
    required this.reply,
    required this.onQuickReplySelected,
    required this.onOpenDestinationRequested,
  });

  final AppAssistantReply reply;
  final ValueChanged<String> onQuickReplySelected;
  final ValueChanged<String> onOpenDestinationRequested;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reply.answer.trim().isNotEmpty)
          Text(reply.answer, style: theme.textTheme.bodyLarge),
        if (reply.steps.isNotEmpty) ...[
          SizedBox(height: tokens.spaceMd),
          for (var index = 0; index < reply.steps.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == reply.steps.length - 1 ? 0 : tokens.spaceSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${index + 1}.',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spaceSm),
                  Expanded(child: Text(reply.steps[index])),
                ],
              ),
            ),
        ],
        if (reply.caution.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spaceMd),
          Container(
            padding: EdgeInsets.all(tokens.spaceMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.58,
              ),
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline, size: 18),
                ),
                SizedBox(width: tokens.spaceSm),
                Expanded(child: Text(reply.caution)),
              ],
            ),
          ),
        ],
        if (reply.quickReplies.isNotEmpty) ...[
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              for (final quickReply in reply.quickReplies)
                ActionChip(
                  onPressed: () => onQuickReplySelected(quickReply),
                  label: Text(quickReply),
                ),
            ],
          ),
        ],
        if (reply.suggestedDestination != null) ...[
          SizedBox(height: tokens.spaceMd),
          OutlinedButton.icon(
            onPressed: () =>
                onOpenDestinationRequested(reply.suggestedDestination!),
            icon: Icon(_iconForScreen(reply.suggestedDestination!)),
            label: Text(
              l10n.pick(
                vi: 'Mở ${l10n.shellDestinationTitle(reply.suggestedDestination!)}',
                en: 'Open ${l10n.shellDestinationTitle(reply.suggestedDestination!)}',
              ),
            ),
          ),
        ],
        if (kDebugMode) ...[
          SizedBox(height: tokens.spaceMd),
          AiResultStatusChips(
            usedFallback: reply.usedFallback,
            model: reply.model,
            liveLabel: l10n.pick(vi: 'AI thật', en: 'Live AI'),
            fallbackLabel: l10n.pick(vi: 'Fallback', en: 'Fallback'),
            modelPrefix: l10n.pick(vi: 'Model:', en: 'Model:'),
          ),
        ],
      ],
    );
  }
}

class _AssistantTypingBubble extends StatelessWidget {
  const _AssistantTypingBubble();

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceLg,
            vertical: tokens.spaceMd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantErrorBanner extends StatelessWidget {
  const _AssistantErrorBanner({required this.message, this.onOpenBilling});

  final String message;
  final VoidCallback? onOpenBilling;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          if (onOpenBilling != null) ...[
            SizedBox(width: tokens.spaceSm),
            TextButton(
              onPressed: onOpenBilling,
              child: Text(l10n.pick(vi: 'Mở gói', en: 'Open billing')),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantComposer extends StatelessWidget {
  const _AssistantComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceMd,
          tokens.spaceSm,
          tokens.spaceSm,
          tokens.spaceSm,
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSend = !isSending && value.text.trim().isNotEmpty;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => canSend ? onSend() : null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      hintText: l10n.pick(
                        vi: 'Hỏi cách dùng BeFam, ví dụ: tạo ngày giỗ, thêm thành viên...',
                        en: 'Ask about BeFam, for example: create a memorial event, add a member...',
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: canSend ? onSend : null,
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AiTranscriptEntry {
  _AiTranscriptEntry.user(this.text)
    : role = AppAssistantConversationRole.user,
      reply = null;

  _AiTranscriptEntry.assistant(AppAssistantReply response)
    : role = AppAssistantConversationRole.assistant,
      text = response.answer,
      reply = response;

  final AppAssistantConversationRole role;
  final String text;
  final AppAssistantReply? reply;

  String get historyText {
    if (role == AppAssistantConversationRole.user) {
      return text;
    }
    final response = reply;
    if (response == null) {
      return text;
    }
    return [
      response.answer.trim(),
      ...response.steps.map((step) => '- $step'),
      if (response.caution.trim().isNotEmpty) response.caution.trim(),
    ].where((line) => line.trim().isNotEmpty).join('\n');
  }
}

IconData _iconForScreen(String screenId) {
  return switch (screenId) {
    'tree' => Icons.account_tree_outlined,
    'events' => Icons.event_outlined,
    'billing' => Icons.workspace_premium_outlined,
    'profile' => Icons.person_outline,
    _ => Icons.space_dashboard_outlined,
  };
}
