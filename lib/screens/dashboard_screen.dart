import 'package:flutter/material.dart';

import 'package:release_status/data/demo_data.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/widgets/platform_status_row.dart';
import 'package:release_status/widgets/summary_card.dart';
import 'package:release_status/widgets/title_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenTitle,
    required this.onAddTitle,
  });

  final ValueChanged<ReleaseTitle> onOpenTitle;
  final VoidCallback onAddTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 20 : 32,
          28,
          isCompact ? 20 : 32,
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                const SizedBox(width: 16),
                FilledButton.tonal(
                  key: const ValueKey<String>('add-title-button'),
                  onPressed: onAddTitle,
                  child: const Text('Add Title'),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              'Your Releases',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _SummaryGrid(isCompact: isCompact),
            const SizedBox(height: 32),
            Text(
              'Your Titles',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Only the titles you own, produce, distribute, or control.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final title in demoTitles) ...[
              TitleCard(title: title, onViewStatus: () => onOpenTitle(title)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              'Local Prototype  ·  Demonstration data only',
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      SummaryCard(
        label: 'TOTAL TITLES',
        value: '$demoTotalTitleCount',
        caption: 'Local demonstration catalog',
      ),
      SummaryCard(
        label: 'LIVE PLATFORMS',
        value: '$demoLivePlatformCount',
        caption: 'Across your licensed platforms',
        accentColor: StatusVisuals.live.color,
      ),
      SummaryCard(
        label: 'WAITING',
        value: '$demoWaitingPlatformCount',
        caption: 'Licensed, not yet detected',
        accentColor: StatusVisuals.waiting.color,
      ),
      const SummaryCard(
        label: 'STATUS CHANGES',
        value: '$demoStatusChangeCount',
        caption: 'Static demo number — not live monitoring',
      ),
    ];

    if (isCompact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            cards[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 4 : 2;
        final gap = 12.0;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}
