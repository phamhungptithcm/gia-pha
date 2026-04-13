import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_ui_tokens.dart';
import '../../../features/auth/models/auth_session.dart';
import '../../../features/auth/models/clan_context_option.dart';
import '../../../features/billing/services/billing_repository.dart';
import '../../../features/member/services/member_repository.dart';
import '../../../l10n/l10n.dart';
import '../services/ai_assist_service.dart';
import '../services/ai_product_analytics_service.dart';
import '../services/app_assistant_context_service.dart';
import 'ai_usage_quota_notice.dart';
import 'ai_result_status_chips.dart';

class AiAssistantLauncher extends StatelessWidget {
  const AiAssistantLauncher({
    super.key,
    required this.session,
    required this.currentScreenId,
    required this.currentScreenTitle,
    required this.onOpenDestinationRequested,
    required this.memberRepository,
    this.activeClanName,
    this.availableClanContexts = const [],
    this.extraBottomPadding = 0,
    this.service,
    this.contextService,
    this.analyticsService,
    this.billingRepository,
  });

  final AuthSession session;
  final String currentScreenId;
  final String currentScreenTitle;
  final String? activeClanName;
  final List<ClanContextOption> availableClanContexts;
  final double extraBottomPadding;
  final ValueChanged<String> onOpenDestinationRequested;
  final MemberRepository memberRepository;
  final AiAssistService? service;
  final AppAssistantContextService? contextService;
  final AiProductAnalyticsService? analyticsService;
  final BillingRepository? billingRepository;

  @override
  Widget build(BuildContext context) {
    final screenConfig = _assistantScreenConfig(
      context,
      currentScreenId,
      currentScreenTitle,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: extraBottomPadding),
      child: Semantics(
        button: true,
        label: screenConfig.launcherLabel,
        child: Tooltip(
          message: screenConfig.launcherTooltip,
          child: _AiBubbleButton(
            contextIcon: screenConfig.launcherIcon,
            onTap: () => _openAssistantSheet(context),
          ),
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
          availableClanContexts: availableClanContexts,
          onOpenDestinationRequested: onOpenDestinationRequested,
          service: service ?? createDefaultAiAssistService(),
          contextService:
              contextService ??
              MemberWorkspaceAssistantContextService(
                memberRepository: memberRepository,
              ),
          analyticsService:
              analyticsService ?? createDefaultAiProductAnalyticsService(),
          billingRepository: billingRepository,
        );
      },
    );
  }
}

class _AiBubbleButton extends StatelessWidget {
  const _AiBubbleButton({
    required this.contextIcon,
    required this.onTap,
  });

  final IconData contextIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.uiTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          key: const Key('shell-ai-assistant-button'),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface.withValues(alpha: 0.99),
                colorScheme.primaryContainer.withValues(alpha: 0.42),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.92),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: colorScheme.primary,
                size: 25,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    contextIcon,
                    color: colorScheme.onPrimary,
                    size: 10,
                  ),
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
    required this.contextService,
    required this.analyticsService,
    required this.onOpenDestinationRequested,
    this.billingRepository,
    this.activeClanName,
    this.availableClanContexts = const [],
  });

  final AuthSession session;
  final String currentScreenId;
  final String currentScreenTitle;
  final String? activeClanName;
  final List<ClanContextOption> availableClanContexts;
  final AiAssistService service;
  final AppAssistantContextService contextService;
  final AiProductAnalyticsService analyticsService;
  final ValueChanged<String> onOpenDestinationRequested;
  final BillingRepository? billingRepository;

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
  void initState() {
    super.initState();
    unawaited(
      widget.analyticsService.trackAssistantOpened(
        screenId: widget.currentScreenId,
        availableClanCount: widget.availableClanContexts.isEmpty
            ? ((widget.activeClanName ?? '').trim().isEmpty ? 0 : 1)
            : widget.availableClanContexts.length,
      ),
    );
  }

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
    final screenConfig = _assistantScreenConfig(
      context,
      widget.currentScreenId,
      widget.currentScreenTitle,
    );
    final sheetHeightFactor = screenHeight < 760 ? 0.93 : 0.82;
    final hasActiveClan = (widget.activeClanName ?? '').trim().isNotEmpty;

    return FractionallySizedBox(
      heightFactor: sheetHeightFactor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceMd,
              4,
              tokens.spaceMd,
              viewInsets.bottom > 0
                  ? viewInsets.bottom + tokens.spaceLg
                  : tokens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AssistantHeroCard(activeClanName: widget.activeClanName),
                if (hasActiveClan) SizedBox(height: tokens.spaceXs),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.zero,
                    children: _entries.isEmpty
                        ? [
                            _AssistantEmptyState(
                              currentScreenId: widget.currentScreenId,
                              currentScreenTitle: widget.currentScreenTitle,
                              prompts: screenConfig.starterPrompts,
                              onPromptSelected: _submitPrompt,
                            ),
                          ]
                        : [
                            for (final entry in _entries)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: tokens.spaceSm,
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
                  SizedBox(height: tokens.spaceXs),
                  _AssistantErrorBanner(message: _errorMessage!),
                ],
                SizedBox(height: tokens.spaceXs),
                AiUsageQuotaNotice(
                  session: widget.session,
                  billingRepository: widget.billingRepository,
                  requestCost: 2,
                  compact: true,
                  inline: true,
                  hideWhenNeutral: true,
                  usageHint: context.l10n.pick(
                    vi: 'Bạn có thể hỏi nhanh hoặc tìm người thân ngay tại đây.',
                    en: 'Ask a quick question or find a relative right here.',
                  ),
                ),
                SizedBox(height: tokens.spaceXs),
                _AssistantComposer(
                  controller: _composerController,
                  focusNode: _composerFocusNode,
                  isSending: _isSending,
                  hintText: screenConfig.composerHint,
                  onSend: () => _submitPrompt(_composerController.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || _isSending) {
      return;
    }
    final assistantStopwatch = Stopwatch()..start();
    final locale = Localizations.localeOf(context).toLanguageTag();

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
      final searchContext = await widget.contextService.buildSearchContext(
        session: widget.session,
        question: trimmed,
        activeClanName: widget.activeClanName,
        availableClanContexts: widget.availableClanContexts,
      );
      unawaited(
        widget.analyticsService.trackAssistantQuerySubmitted(
          screenId: widget.currentScreenId,
          hasSearchHint: searchContext.hasSearchHint,
          memberMatchCount: searchContext.memberMatches.length,
        ),
      );
      final reply = await widget.service.askAppAssistant(
        session: widget.session,
        locale: locale,
        currentScreenId: widget.currentScreenId,
        currentScreenTitle: widget.currentScreenTitle,
        activeClanName: widget.activeClanName,
        question: trimmed,
        history: history,
        searchContext: searchContext,
      );
      assistantStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        widget.analyticsService.trackAssistantQueryCompleted(
          screenId: widget.currentScreenId,
          usedFallback: reply.usedFallback,
          hasSearchHint: searchContext.hasSearchHint,
          memberMatchCount: searchContext.memberMatches.length,
          elapsedMs: assistantStopwatch.elapsedMilliseconds,
        ),
      );
      setState(() {
        _entries.add(
          _AiTranscriptEntry.assistant(reply, searchContext: searchContext),
        );
      });
    } on AiAssistServiceException catch (error) {
      assistantStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        widget.analyticsService.trackAssistantQueryFailed(
          screenId: widget.currentScreenId,
          reason: error.code ?? 'unknown',
          elapsedMs: assistantStopwatch.elapsedMilliseconds,
        ),
      );
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      assistantStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        widget.analyticsService.trackAssistantQueryFailed(
          screenId: widget.currentScreenId,
          reason: 'unknown',
          elapsedMs: assistantStopwatch.elapsedMilliseconds,
        ),
      );
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
    unawaited(
      widget.analyticsService.trackAssistantDestinationOpened(
        screenId: widget.currentScreenId,
        destinationId: destinationId,
      ),
    );
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
  const _AssistantHeroCard({this.activeClanName});

  final String? activeClanName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final clanLabel = (activeClanName ?? '').trim();
    if (clanLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.82),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceSm + 2,
            vertical: tokens.spaceXs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: tokens.spaceSm),
              Flexible(
                child: Text(
                  clanLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.currentScreenId,
    required this.currentScreenTitle,
    required this.prompts,
    required this.onPromptSelected,
  });

  final String currentScreenId;
  final String currentScreenTitle;
  final List<String> prompts;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    final screenConfig = _assistantScreenConfig(
      context,
      currentScreenId,
      currentScreenTitle,
    );

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceXs, bottom: tokens.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            screenConfig.promptIntro,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.spaceSm),
          for (final prompt in prompts.take(2))
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spaceSm),
              child: _AssistantStarterCard(
                icon: screenConfig.launcherIcon,
                prompt: prompt,
                onTap: () => onPromptSelected(prompt),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantStarterCard extends StatelessWidget {
  const _AssistantStarterCard({
    required this.icon,
    required this.prompt,
    required this.onTap,
  });

  final IconData icon;
  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: Ink(
        padding: EdgeInsets.all(tokens.spaceSm + 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface.withValues(alpha: 0.98),
              colorScheme.primaryContainer.withValues(alpha: 0.20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: Icon(icon, size: 18, color: colorScheme.primary),
            ),
            SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Text(
                prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(tokens.radiusPill),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
        constraints: const BoxConstraints(maxWidth: 500),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: entry.role == AppAssistantConversationRole.user
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            border: Border.all(
              color: entry.role == AppAssistantConversationRole.user
                  ? colorScheme.primaryContainer
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceSm + 2),
            child: entry.role == AppAssistantConversationRole.user
                ? Text(
                    entry.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      height: 1.35,
                    ),
                  )
                : _AssistantReplyBody(
                    reply: entry.reply!,
                    searchContext: entry.searchContext,
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
    required this.searchContext,
    required this.onQuickReplySelected,
    required this.onOpenDestinationRequested,
  });

  final AppAssistantReply reply;
  final AppAssistantSearchContext? searchContext;
  final ValueChanged<String> onQuickReplySelected;
  final ValueChanged<String> onOpenDestinationRequested;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final quickReplies = reply.quickReplies.take(2).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reply.answer.trim().isNotEmpty)
          Text(
            reply.answer,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        if (searchContext?.hasMemberMatches == true) ...[
          SizedBox(height: tokens.spaceSm),
          _AssistantMemberMatchSection(searchContext: searchContext!),
        ],
        if (reply.steps.isNotEmpty) ...[
          SizedBox(height: tokens.spaceSm),
          for (var index = 0; index < reply.steps.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == reply.steps.length - 1 ? 0 : tokens.spaceXs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${index + 1}.',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spaceSm),
                  Expanded(
                    child: Text(
                      reply.steps[index],
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (reply.caution.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spaceSm),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spaceMd,
              vertical: tokens.spaceSm,
            ),
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
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline, size: 16),
                ),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(
                    reply.caution,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (quickReplies.isNotEmpty) ...[
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              for (final quickReply in quickReplies)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onQuickReplySelected(quickReply),
                  label: Text(quickReply),
                ),
            ],
          ),
        ],
        if (reply.suggestedDestination != null) ...[
          SizedBox(height: tokens.spaceSm),
          TextButton.icon(
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
          SizedBox(height: tokens.spaceSm),
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

class _AssistantMemberMatchSection extends StatelessWidget {
  const _AssistantMemberMatchSection({required this.searchContext});

  final AppAssistantSearchContext searchContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    final clanLabel = searchContext.activeClanName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.pick(
            vi: clanLabel.isEmpty
                ? 'Người phù hợp'
                : 'Người phù hợp trong $clanLabel',
            en: clanLabel.isEmpty
                ? 'Matches'
                : 'Matches in $clanLabel',
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.spaceXs),
        for (final match in searchContext.memberMatches)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spaceXs),
            child: _AssistantMemberMatchCard(match: match),
          ),
      ],
    );
  }
}

class _AssistantMemberMatchCard extends StatelessWidget {
  const _AssistantMemberMatchCard({required this.match});

  final AppAssistantMemberMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.uiTokens;
    final meta = <String>[
      if (match.nickName.trim().isNotEmpty &&
          match.nickName.trim().toLowerCase() !=
              match.displayName.trim().toLowerCase())
        context.l10n.pick(
          vi: 'Gọi ${match.nickName.trim()}',
          en: 'Called ${match.nickName.trim()}',
        ),
      if (match.branchName.trim().isNotEmpty) match.branchName.trim(),
      if (match.generation > 0)
        context.l10n.pick(
          vi: 'Đời ${match.generation}',
          en: 'Generation ${match.generation}',
        ),
      if (match.birthDate.trim().isNotEmpty)
        context.l10n.pick(
          vi: 'Sinh ${match.birthDate.trim()}',
          en: 'Born ${match.birthDate.trim()}',
        ),
      if (match.deathDate.trim().isNotEmpty)
        context.l10n.pick(
          vi: 'Mất ${match.deathDate.trim()}',
          en: 'Died ${match.deathDate.trim()}',
        ),
      if (match.jobTitle.trim().isNotEmpty) match.jobTitle.trim(),
    ];

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.displayName.trim().isEmpty
                ? match.fullName
                : match.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in meta.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                    child: Text(
                      item,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
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
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(width: tokens.spaceSm),
              Text(
                context.l10n.pick(
                  vi: 'Đang trả lời...',
                  en: 'Thinking...',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantErrorBanner extends StatelessWidget {
  const _AssistantErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;

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
    required this.hintText,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final String hintText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceSm + 2,
          tokens.spaceXs + 2,
          tokens.spaceSm,
          tokens.spaceXs + 2,
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSend = !isSending && value.text.trim().isNotEmpty;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 17,
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => canSend ? onSend() : null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      hintText: hintText,
                      isCollapsed: true,
                    ),
                  ),
                ),
                IconButton.filledTonal(
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
      reply = null,
      searchContext = null;

  _AiTranscriptEntry.assistant(AppAssistantReply response, {this.searchContext})
    : role = AppAssistantConversationRole.assistant,
      text = response.answer,
      reply = response;

  final AppAssistantConversationRole role;
  final String text;
  final AppAssistantReply? reply;
  final AppAssistantSearchContext? searchContext;

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

class _AssistantScreenConfig {
  const _AssistantScreenConfig({
    required this.launcherLabel,
    required this.launcherTooltip,
    required this.launcherIcon,
    required this.panelTitle,
    required this.panelSubtitle,
    required this.promptIntro,
    required this.composerHint,
    required this.starterPrompts,
  });

  final String launcherLabel;
  final String launcherTooltip;
  final IconData launcherIcon;
  final String panelTitle;
  final String panelSubtitle;
  final String promptIntro;
  final String composerHint;
  final List<String> starterPrompts;
}

_AssistantScreenConfig _assistantScreenConfig(
  BuildContext context,
  String screenId,
  String currentScreenTitle,
) {
  final l10n = context.l10n;
  return switch (screenId) {
    'tree' => _AssistantScreenConfig(
      launcherLabel: l10n.pick(
        vi: 'Mở trợ lý chat cho gia phả',
        en: 'Open chat helper for the family tree',
      ),
      launcherTooltip: l10n.pick(vi: 'Hỏi trong cây', en: 'Ask in tree'),
      launcherIcon: Icons.account_tree_outlined,
      panelTitle: l10n.pick(
        vi: 'Hỏi nhanh trong gia phả',
        en: 'Ask quickly in the family tree',
      ),
      panelSubtitle: l10n.pick(
        vi: 'Tìm người thân, hỏi chi, đời, hoặc xác minh nhanh thông tin trong cây đang mở.',
        en: 'Find relatives, ask about branches or generations, and verify details in the active tree.',
      ),
      promptIntro: l10n.pick(
        vi: 'Bạn muốn tìm ai hoặc hỏi điều gì trong gia phả này?',
        en: 'Who would you like to find or ask about in this tree?',
      ),
      composerHint: l10n.pick(
        vi: 'Ví dụ: tìm Nguyễn Minh, người này thuộc chi nào...',
        en: 'For example: find Nguyen Minh, which branch is this person in...',
      ),
      starterPrompts: [
        l10n.pick(
          vi: 'Tìm Nguyễn Minh trong gia phả này',
          en: 'Find Nguyen Minh in this clan',
        ),
        l10n.pick(
          vi: 'Nguyễn Minh thuộc chi nào và đời thứ mấy?',
          en: 'Which branch and generation is Nguyen Minh in?',
        ),
      ],
    ),
    'events' => _AssistantScreenConfig(
      launcherLabel: l10n.pick(
        vi: 'Mở trợ lý chat cho sự kiện',
        en: 'Open chat helper for events',
      ),
      launcherTooltip: l10n.pick(vi: 'Hỏi sự kiện', en: 'Ask about events'),
      launcherIcon: Icons.event_outlined,
      panelTitle: l10n.pick(
        vi: 'Hỏi nhanh về sự kiện',
        en: 'Ask quickly about events',
      ),
      panelSubtitle: l10n.pick(
        vi: 'Tôi giúp bạn tạo ngày giỗ, chọn lịch âm dương, và sắp nhắc lịch cho dễ nhớ.',
        en: 'I can help with memorial events, lunar dates, and reminders.',
      ),
      promptIntro: l10n.pick(
        vi: 'Bạn muốn tạo sự kiện như thế nào?',
        en: 'How would you like to set up this event?',
      ),
      composerHint: l10n.pick(
        vi: 'Ví dụ: cách tạo ngày giỗ, nhắc lịch trước 3 ngày...',
        en: 'For example: create a memorial event, remind me 3 days before...',
      ),
      starterPrompts: [
        l10n.pick(
          vi: 'Cách tạo ngày giỗ và nhắc lịch cho cả nhà?',
          en: 'How do I create a memorial event and reminders for the family?',
        ),
        l10n.pick(
          vi: 'Nên dùng lịch âm hay dương cho sự kiện này?',
          en: 'Should I use the lunar or solar calendar for this event?',
        ),
      ],
    ),
    'billing' => _AssistantScreenConfig(
      launcherLabel: l10n.pick(
        vi: 'Mở trợ lý chat cho gói dịch vụ',
        en: 'Open chat helper for billing',
      ),
      launcherTooltip: l10n.pick(vi: 'Hỏi về gói', en: 'Ask about plans'),
      launcherIcon: Icons.workspace_premium_outlined,
      panelTitle: l10n.pick(
        vi: 'Hỏi nhanh về gói',
        en: 'Ask quickly about plans',
      ),
      panelSubtitle: l10n.pick(
        vi: 'Tôi giúp bạn hiểu gói hiện tại, quyền lợi, và lựa chọn nào phù hợp hơn.',
        en: 'I can help explain the current plan, benefits, and what fits better.',
      ),
      promptIntro: l10n.pick(
        vi: 'Bạn đang muốn hiểu rõ điều gì về gói hiện tại?',
        en: 'What would you like to understand about your current plan?',
      ),
      composerHint: l10n.pick(
        vi: 'Ví dụ: gói nào hợp, quyền lợi khác nhau thế nào...',
        en: 'For example: which plan fits, how entitlements differ...',
      ),
      starterPrompts: [
        l10n.pick(
          vi: 'Gói nào hợp với quy mô gia đình tôi?',
          en: 'Which plan fits my family size best?',
        ),
        l10n.pick(
          vi: 'Làm sao tắt quảng cáo cho cả gia phả?',
          en: 'How do I remove ads for the whole clan?',
        ),
      ],
    ),
    'profile' => _AssistantScreenConfig(
      launcherLabel: l10n.pick(
        vi: 'Mở trợ lý chat cho hồ sơ',
        en: 'Open chat helper for profile',
      ),
      launcherTooltip: l10n.pick(vi: 'Hỏi hồ sơ', en: 'Ask about profile'),
      launcherIcon: Icons.person_outline,
      panelTitle: l10n.pick(
        vi: 'Hỏi nhanh về hồ sơ',
        en: 'Ask quickly about your profile',
      ),
      panelSubtitle: l10n.pick(
        vi: 'Tôi giúp bạn hoàn thiện hồ sơ, chỉnh thông báo, và tìm cài đặt cần dùng.',
        en: 'I can help complete your profile, adjust notifications, and find the right settings.',
      ),
      promptIntro: l10n.pick(
        vi: 'Bạn muốn chỉnh gì trong hồ sơ hoặc cài đặt cá nhân?',
        en: 'What would you like to adjust in your profile or personal settings?',
      ),
      composerHint: l10n.pick(
        vi: 'Ví dụ: đổi ngôn ngữ, hoàn thiện hồ sơ, chỉnh thông báo...',
        en: 'For example: change language, complete my profile, adjust notifications...',
      ),
      starterPrompts: [
        l10n.pick(
          vi: 'Làm sao hoàn thiện hồ sơ để người thân dễ nhận ra?',
          en: 'How do I complete my profile so relatives recognize it easily?',
        ),
        l10n.pick(
          vi: 'Đổi ngôn ngữ app ở đâu?',
          en: 'Where do I change the app language?',
        ),
      ],
    ),
    _ => _AssistantScreenConfig(
      launcherLabel: l10n.pick(
        vi: 'Mở trợ lý chat nhanh',
        en: 'Open quick chat helper',
      ),
      launcherTooltip: l10n.pick(vi: 'Hỏi nhanh', en: 'Quick help'),
      launcherIcon: Icons.chat_bubble_outline_rounded,
      panelTitle: l10n.pick(
        vi: 'Hỏi nhanh trong $currentScreenTitle',
        en: 'Quick help for $currentScreenTitle',
      ),
      panelSubtitle: l10n.pick(
        vi: 'Tôi sẽ bám vào cửa sổ hiện tại để trả lời ngắn gọn và dễ làm theo.',
        en: 'I will stay focused on the current screen and answer in a concise, practical way.',
      ),
      promptIntro: l10n.pick(
        vi: 'Bạn muốn hỏi gì ở màn này?',
        en: 'What would you like to ask on this screen?',
      ),
      composerHint: l10n.pick(
        vi: 'Hỏi ngắn gọn về tác vụ bạn đang làm...',
        en: 'Ask a short question about the task you are doing...',
      ),
      starterPrompts: [
        l10n.pick(
          vi: 'Tìm người thân trong gia phả hiện tại',
          en: 'Find a relative in the active clan',
        ),
        l10n.pick(
          vi: 'Tôi mới dùng BeFam, nên bắt đầu từ đâu?',
          en: 'I am new to BeFam. Where should I start?',
        ),
      ],
    ),
  };
}
