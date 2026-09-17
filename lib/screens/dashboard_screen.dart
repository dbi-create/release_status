import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/state/catalog_attention.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/catalog_header_actions.dart';
import 'package:release_status/widgets/platform_status_row.dart';
import 'package:release_status/widgets/title_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenTitle,
    required this.onAddTitle,
    required this.onOpenTitles,
  });

  final ValueChanged<ReleaseTitle> onOpenTitle;
  final VoidCallback onAddTitle;
  final VoidCallback onOpenTitles;

  @override
  Widget build(BuildContext context) {
    final catalog = TitleCatalogScope.of(context);
    final monitor = AvailabilityMonitorScope.of(context);
    final titles = catalog.titles;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final showPageBrand = MediaQuery.sizeOf(context).width >= 960;
    final progress = catalog.checkProgress;

    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 20 : 32,
          isCompact ? 8 : 28,
          isCompact ? 20 : 32,
          isCompact ? 96 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPageBrand)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ReleaseStatus',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your titles. Your platforms. Your status.',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CatalogHeaderActions(
                      checking: catalog.isChecking,
                      canCheck: titles.isNotEmpty && !catalog.isChecking,
                      notificationCount: catalog.attention.notificationCount,
                      onCheckAll: () => catalog.checkAllTitles(monitor),
                      onNotifications: () => openCatalogNotifications(
                        context,
                        onOpenTitle: onOpenTitle,
                        catalog: catalog,
                      ),
                    ),
                  ],
                ),
              ),
            if (progress != null) ...[
              const SizedBox(height: 16),
              _CheckProgressBanner(
                progress: progress,
                busy: catalog.isChecking,
                onDismiss: catalog.dismissCheckProgress,
              ),
            ],
            const SizedBox(height: 12),
            _CatalogHighlights(
              catalog: catalog,
              onOpenTitles: onOpenTitles,
            ),
            const SizedBox(height: 32),
            Text(
              'PINNED (${catalog.pinnedTitles.length})',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: kPinnedColor,
              ),
            ),
            const SizedBox(height: 16),
            if (titles.isEmpty)
              _EmptyCatalogCard(onAddTitle: onAddTitle)
            else if (catalog.pinnedTitles.isEmpty)
              const _EmptyPinnedCard()
            else
              for (final title in catalog.pinnedTitles) ...[
                TitleCard(
                  title: title,
                  onViewStatus: () => onOpenTitle(title),
                  showDelete: false,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            Text(
              'Stored on this device  ·  Not a public catalog',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openCatalogNotifications(
  BuildContext context, {
  required ValueChanged<ReleaseTitle> onOpenTitle,
  required TitleCatalog catalog,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return ListenableBuilder(
        listenable: catalog,
        builder: (dialogContext, _) {
          final attention = catalog.attention;
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Notifications')),
                TextButton(
                  key: const ValueKey<String>('clear-notifications-button'),
                  onPressed: attention.isEmpty
                      ? null
                      : catalog.clearNotifications,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: attention.isEmpty
                          ? null
                          : Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: (MediaQuery.sizeOf(dialogContext).width - 48).clamp(0, 480),
              child: attention.isEmpty
                  ? Text(
                      'No notifications right now.',
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    )
                  : SingleChildScrollView(
                      child: _AttentionSection(
                        attention: attention,
                        onOpenTitleId: (id) {
                          Navigator.of(dialogContext).pop();
                          final title = catalog.titleById(id);
                          if (title != null) {
                            onOpenTitle(title);
                          }
                        },
                      ),
                    ),
            ),
            actions: [
              TextButton(
                key: const ValueKey<String>('close-notifications-button'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _CheckProgressBanner extends StatelessWidget {
  const _CheckProgressBanner({
    required this.progress,
    required this.busy,
    required this.onDismiss,
  });

  final CatalogCheckProgress progress;
  final bool busy;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                progress.failedTitleNames.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: progress.failedTitleNames.isEmpty
                    ? StatusVisuals.live.color
                    : colorScheme.error,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                key: const ValueKey<String>('check-all-progress'),
                progress.label,
                style: textTheme.bodyMedium,
              ),
            ),
            if (!busy)
              TextButton(
                key: const ValueKey<String>('dismiss-check-all-button'),
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({
    required this.attention,
    required this.onOpenTitleId,
  });

  final CatalogAttention attention;
  final ValueChanged<String> onOpenTitleId;

  @override
  Widget build(BuildContext context) {
    if (attention.discoveredByTitle.isEmpty) {
      return const SizedBox.shrink();
    }
    return _AttentionCard(
      items: attention.discoveredByTitle,
      onOpenTitleId: onOpenTitleId,
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.items,
    required this.onOpenTitleId,
  });

  final List<AttentionItem> items;
  final ValueChanged<String>? onOpenTitleId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              InkWell(
                onTap: item.titleId.isEmpty || onOpenTitleId == null
                    ? null
                    : () => onOpenTitleId!(item.titleId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text.rich(
                    _platformCountSummary(
                      item,
                      baseStyle: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                      errorColor: colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

TextSpan _platformCountSummary(
  AttentionItem item, {
  required TextStyle? baseStyle,
  required Color errorColor,
}) {
  final count = item.platformCount;
  final summary = item.summary;
  if (count == null) {
    return TextSpan(text: summary, style: baseStyle);
  }

  final prefix = '${item.titleName} is on ';
  if (!summary.startsWith(prefix)) {
    return TextSpan(text: summary, style: baseStyle);
  }

  final number = '$count';
  final numberColor = count == 0
      ? errorColor
      : StatusVisuals.live.color;

  return TextSpan(
    style: baseStyle,
    children: [
      TextSpan(text: prefix),
      TextSpan(
        text: number,
        style: baseStyle?.copyWith(
          color: numberColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(text: summary.substring(prefix.length + number.length)),
    ],
  );
}

class _EmptyCatalogCard extends StatelessWidget {
  const _EmptyCatalogCard({required this.onAddTitle});

  final VoidCallback onAddTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            Text(
              'No titles yet',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a title you own or control, then list the platforms that licensed it.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAddTitle, child: const Text('Add Title')),
          ],
        ),
      ),
    );
  }
}

class _EmptyPinnedCard extends StatelessWidget {
  const _EmptyPinnedCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            Text(
              'Nothing pinned yet',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open a title from Your Titles and tap Pin to keep it on the dashboard.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogHighlights extends StatelessWidget {
  const _CatalogHighlights({
    required this.catalog,
    required this.onOpenTitles,
  });

  final TitleCatalog catalog;
  final VoidCallback onOpenTitles;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: _HighlightStatCard(
            label: 'ADDED TITLES',
            value: catalog.totalTitleCount,
            colors: const [Color(0xFF2E5A86), Color(0xFF4A7FB5)],
            textTheme: textTheme,
            onTap: onOpenTitles,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HighlightStatCard(
            label: 'LIVE CHANNELS',
            value: catalog.livePlatformCount,
            colors: const [Color(0xFF2E8A58), Color(0xFF4CAF7A)],
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }
}

class _HighlightStatCard extends StatelessWidget {
  const _HighlightStatCard({
    required this.label,
    required this.value,
    required this.colors,
    required this.textTheme,
    this.onTap,
  });

  final String label;
  final int value;
  final List<Color> colors;
  final TextTheme textTheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      ),
    );
  }
}
