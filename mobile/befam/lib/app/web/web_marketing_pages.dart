import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/',
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroSection(
              badge: l10n.webLandingBadge,
              title: l10n.webLandingTitle,
              subtitle: l10n.webLandingSubtitle,
              primaryLabel: l10n.webLandingPrimaryCta,
              secondaryLabel: l10n.webLandingSecondaryCta,
              onPrimaryPressed: () => context.go('/app'),
              onSecondaryPressed: () => context.go('/about-us'),
            ),
            const SizedBox(height: 28),
            _FeatureGrid(
              items: [
                _FeatureItem(
                  icon: Icons.account_tree_rounded,
                  title: l10n.webLandingFeatureTreeTitle,
                  description: l10n.webLandingFeatureTreeDescription,
                ),
                _FeatureItem(
                  icon: Icons.calendar_month_rounded,
                  title: l10n.webLandingFeatureEventsTitle,
                  description: l10n.webLandingFeatureEventsDescription,
                ),
                _FeatureItem(
                  icon: Icons.workspace_premium_rounded,
                  title: l10n.webLandingFeatureBillingTitle,
                  description: l10n.webLandingFeatureBillingDescription,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebAboutUsPage extends StatelessWidget {
  const WebAboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/about-us',
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: l10n.webAboutTitle,
              subtitle: l10n.webAboutSubtitle,
              icon: Icons.groups_2_rounded,
            ),
            const SizedBox(height: 20),
            _FeatureGrid(
              items: [
                _FeatureItem(
                  icon: Icons.favorite_rounded,
                  title: l10n.webAboutMissionTitle,
                  description: l10n.webAboutMissionDescription,
                ),
                _FeatureItem(
                  icon: Icons.visibility_rounded,
                  title: l10n.webAboutVisionTitle,
                  description: l10n.webAboutVisionDescription,
                ),
                _FeatureItem(
                  icon: Icons.security_rounded,
                  title: l10n.webAboutTrustTitle,
                  description: l10n.webAboutTrustDescription,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebBeFamInfoPage extends StatelessWidget {
  const WebBeFamInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _WebMarketingLayout(
      currentPath: '/befam-info',
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: l10n.webInfoTitle,
              subtitle: l10n.webInfoSubtitle,
              icon: Icons.info_rounded,
            ),
            const SizedBox(height: 20),
            _FeatureGrid(
              items: [
                _FeatureItem(
                  icon: Icons.hub_rounded,
                  title: l10n.webInfoGenealogyTitle,
                  description: l10n.webInfoGenealogyDescription,
                ),
                _FeatureItem(
                  icon: Icons.notifications_active_rounded,
                  title: l10n.webInfoNotificationsTitle,
                  description: l10n.webInfoNotificationsDescription,
                ),
                _FeatureItem(
                  icon: Icons.payments_rounded,
                  title: l10n.webInfoBillingTitle,
                  description: l10n.webInfoBillingDescription,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoBulletList(
              title: l10n.webInfoHighlightsTitle,
              points: [
                l10n.webInfoHighlightsItemOne,
                l10n.webInfoHighlightsItemTwo,
                l10n.webInfoHighlightsItemThree,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WebMarketingLayout extends StatelessWidget {
  const _WebMarketingLayout({required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.45),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _TopNavigation(currentPath: currentPath),
                    const SizedBox(height: 16),
                    Expanded(child: SingleChildScrollView(child: child)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    final navItems = [
      _NavItem(path: '/', label: l10n.webNavHome),
      _NavItem(path: '/about-us', label: l10n.webNavAboutUs),
      _NavItem(path: '/befam-info', label: l10n.webNavBeFamInfo),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.family_restroom_rounded),
            const SizedBox(width: 10),
            Text(
              'BeFam',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (!isCompact)
              ...navItems.map(
                (item) => _NavButton(
                  label: item.label,
                  isActive: currentPath == item.path,
                  onPressed: () => context.go(item.path),
                ),
              ),
            if (isCompact)
              PopupMenuButton<_NavItem>(
                tooltip: l10n.webNavMenuTooltip,
                onSelected: (item) => context.go(item.path),
                itemBuilder: (context) => navItems
                    .map(
                      (item) => PopupMenuItem<_NavItem>(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => context.go('/app'),
              child: Text(l10n.webNavOpenApp),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(badge),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.24,
          ),
        ),
        const SizedBox(height: 12),
        Text(subtitle, style: textTheme.titleMedium),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onPrimaryPressed,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(primaryLabel),
            ),
            OutlinedButton.icon(
              onPressed: onSecondaryPressed,
              icon: const Icon(Icons.info_outline_rounded),
              label: Text(secondaryLabel),
            ),
          ],
        ),
      ],
    );

    final highlight = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_tree_rounded,
            color: colorScheme.primary,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.webLandingHighlightTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.webLandingHighlightDescription,
            style: textTheme.bodyLarge,
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [content, const SizedBox(height: 18), highlight],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: content),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: highlight),
                ],
              ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});

  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 980
        ? 3
        : width >= 700
        ? 2
        : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 14.0;
        final totalSpacing = spacing * (columns - 1);
        final cardWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth.clamp(260, 520),
                  child: _FeatureCard(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBulletList extends StatelessWidget {
  const _InfoBulletList({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(onPressed: onPressed, child: Text(label)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _NavItem {
  const _NavItem({required this.path, required this.label});

  final String path;
  final String label;
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
