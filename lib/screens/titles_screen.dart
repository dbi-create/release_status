import 'package:flutter/material.dart';

import 'package:release_status/data/demo_data.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/widgets/title_card.dart';

class TitlesScreen extends StatelessWidget {
  const TitlesScreen({
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
                        'Your Titles',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A private dashboard for titles you own or control. This is not a public catalog.',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.tonal(
                  onPressed: onAddTitle,
                  child: const Text('Add Title'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            for (final title in demoTitles) ...[
              if (isCompact)
                TitleCard(title: title, onViewStatus: () => onOpenTitle(title))
              else
                TitleListTileCard(
                  title: title,
                  onViewStatus: () => onOpenTitle(title),
                ),
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
